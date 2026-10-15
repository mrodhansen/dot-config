"""Event diff tests. Run: python3 -m unittest discover -s ~/.ai/skills/watch-pr/tests"""
from __future__ import annotations

import sys
import unittest
from dataclasses import replace
from pathlib import Path
from typing import List, Optional

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))

from watch_pr import (  # noqa: E402
    Check,
    IssueComment,
    Review,
    ReviewRequest,
    Snapshot,
    State,
    Thread,
    ThreadComment,
    diff,
)

ME = "martin"
OTHER = "marcus"


def snap(**kw) -> Snapshot:
    base = dict(
        me=ME,
        number=7,
        url="https://github.com/o/r/pull/7",
        title="t",
        author=ME,
        state="OPEN",
        is_draft=False,
        is_cross_repo=False,
        mergeable="MERGEABLE",
        merge_state="BLOCKED",
        review_decision="REVIEW_REQUIRED",
        head_ref="feat/x",
        base_ref="main",
        head_oid="a" * 40,
        head_author=ME,
        checks=[],
        reviews=[],
        threads=[],
        issue_comments=[],
        review_requests=[],
        truncated=[],
    )
    base.update(kw)
    return Snapshot(**base)


def review(id: str, author: str, state: str = "COMMENTED", at: str = "2026-10-14T10:00:00Z", commit: Optional[str] = "a" * 40, body: bool = True) -> Review:
    return Review(id=id, author=author, is_bot=False, state=state, submitted_at=at, commit_oid=commit, has_body=body)


def comment(id: str, author: str, at: str, review_id: Optional[str], reply: bool) -> ThreadComment:
    return ThreadComment(id=id, author=author, created_at=at, review_id=review_id, is_reply=reply)


def thread(id: str, comments: List[ThreadComment], resolved: bool = False, resolved_by: Optional[str] = None) -> Thread:
    return Thread(id=id, path="src/a.ts", line=3, is_resolved=resolved, resolved_by=resolved_by, is_outdated=False, started_by=comments[0].author, comments=comments)


def kinds(events: List[str]) -> List[str]:
    return [e.split(" ", 1)[0] for e in events]


def step(prev: Optional[State], cur: Snapshot, role: str):
    return diff(prev, cur, role)


class AuthorTests(unittest.TestCase):
    def test_baseline_surfaces_existing_conflict_and_failures(self):
        s = snap(mergeable="CONFLICTING", merge_state="DIRTY", checks=[Check("typecheck", "fail", "FAILURE"), Check("lint", "pass", "SUCCESS")])
        events, state = step(None, s, "author")
        self.assertEqual(kinds(events), ["BASELINE", "CONFLICT", "CI_FAILED"])
        self.assertIn("attempt=1", events[2])
        self.assertEqual(state.known_mergeable, "CONFLICTING")

    def test_conflict_fires_once_and_unknown_does_not_reset(self):
        _, s1 = step(None, snap(), "author")
        e2, s2 = step(s1, snap(mergeable="CONFLICTING"), "author")
        self.assertEqual(kinds(e2), ["CONFLICT"])
        e3, s3 = step(s2, snap(mergeable="UNKNOWN"), "author")
        self.assertEqual(e3, [])
        e4, _ = step(s3, snap(mergeable="CONFLICTING"), "author")
        self.assertEqual(e4, [], "UNKNOWN in between must not re-fire CONFLICT")

    def test_same_check_failing_after_fix_push_counts_attempts(self):
        fail = [Check("test", "fail", "FAILURE")]
        _, s1 = step(None, snap(checks=fail), "author")
        e_same, s1b = step(s1, snap(checks=fail), "author")
        self.assertEqual(e_same, [], "same failure on same head is not new")
        _, s2 = step(s1b, snap(head_oid="b" * 40, checks=[Check("test", "pending", "IN_PROGRESS")]), "author")
        e3, _ = step(s2, snap(head_oid="b" * 40, checks=fail), "author")
        self.assertEqual(kinds(e3), ["CI_FAILED"])
        self.assertIn("attempt=2", e3[0])

    def test_green_resets_streak(self):
        _, s1 = step(None, snap(checks=[Check("test", "fail", "FAILURE")]), "author")
        e2, s2 = step(s1, snap(head_oid="b" * 40, checks=[Check("test", "pass", "SUCCESS")]), "author")
        self.assertEqual(kinds(e2), ["CI_GREEN"])
        e3, _ = step(s2, snap(head_oid="c" * 40, checks=[Check("test", "fail", "FAILURE")]), "author")
        self.assertIn("attempt=1", e3[0])

    def test_new_review_vs_reply_only_review_vs_my_own(self):
        _, s1 = step(None, snap(), "author")
        r = review("R1", OTHER, body=False)
        t = thread("T1", [comment("C1", OTHER, "2026-10-14T10:00:00Z", "R1", reply=False)])
        e2, s2 = step(s1, snap(reviews=[r], threads=[t]), "author")
        self.assertEqual(kinds(e2), ["NEW_REVIEW"], "thread comments inside a new review are not separate replies")
        self.assertIn("threads=1", e2[0])

        reply_review = review("R2", OTHER, body=False, at="2026-10-14T11:00:00Z")
        t2 = replace(t, comments=t.comments + [comment("C2", OTHER, "2026-10-14T11:00:00Z", "R2", reply=True)])
        e3, s3 = step(s2, snap(reviews=[r, reply_review], threads=[t2]), "author")
        self.assertEqual(kinds(e3), ["NEW_REPLY"], "a lone reply is wrapped in a review by GitHub but is not a review")

        mine = review("R3", ME, body=False, at="2026-10-14T12:00:00Z")
        t3 = replace(t2, comments=t2.comments + [comment("C3", ME, "2026-10-14T12:00:00Z", "R3", reply=True)])
        e4, _ = step(s3, snap(reviews=[r, reply_review, mine], threads=[t3], issue_comments=[IssueComment("I1", ME, False, "2026-10-14T12:00:00Z")]), "author")
        self.assertEqual(e4, [], "my own activity never triggers")

    def test_baseline_surfaces_body_only_review_posted_before_the_watch(self):
        early_request = ReviewRequest(reviewer=OTHER, requested_by=ME, created_at="2026-10-14T09:00:00Z")
        s = snap(reviews=[review("R1", OTHER)], review_requests=[early_request])
        events, _ = step(None, s, "author")
        self.assertEqual(kinds(events), ["BASELINE", "UNANSWERED_REVIEWS"], "a review with no threads must not vanish into the baseline")
        self.assertIn(f"by={OTHER}", events[1])
        self.assertIn("count=1", events[1])

    def test_baseline_changes_requested_without_body_is_unanswered(self):
        events, _ = step(None, snap(reviews=[review("R1", OTHER, state="CHANGES_REQUESTED", body=False)]), "author")
        self.assertEqual(kinds(events), ["BASELINE", "UNANSWERED_REVIEWS"])

    def test_baseline_review_already_answered_is_quiet(self):
        r = review("R1", OTHER, at="2026-10-14T10:00:00Z")
        later = "2026-10-14T11:00:00Z"
        answered = {
            "my PR comment after it": snap(reviews=[r], issue_comments=[IssueComment("I1", ME, False, later)]),
            "re-requested after it": snap(reviews=[r], review_requests=[ReviewRequest(reviewer=OTHER, requested_by=ME, created_at=later)]),
            "its threads all resolved": snap(
                reviews=[r], threads=[thread("T1", [comment("C1", OTHER, r.submitted_at, "R1", reply=False)], resolved=True, resolved_by=ME)]
            ),
            "they approved since": snap(reviews=[r, review("R2", OTHER, state="APPROVED", at=later, body=False)]),
        }
        for why, s in answered.items():
            with self.subTest(why):
                events, _ = step(None, s, "author")
                self.assertEqual(kinds(events), ["BASELINE"])

    def test_baseline_comment_before_the_review_does_not_answer_it(self):
        s = snap(reviews=[review("R1", OTHER, at="2026-10-14T10:00:00Z")], issue_comments=[IssueComment("I1", ME, False, "2026-10-14T09:00:00Z")])
        events, _ = step(None, s, "author")
        self.assertEqual(kinds(events), ["BASELINE", "UNANSWERED_REVIEWS"])

    def test_baseline_thread_only_review_is_left_to_unanswered_threads(self):
        t = thread("T1", [comment("C1", OTHER, "2026-10-14T10:00:00Z", "R1", reply=False)])
        events, _ = step(None, snap(reviews=[review("R1", OTHER, body=False)], threads=[t]), "author")
        self.assertEqual(kinds(events), ["BASELINE", "UNANSWERED_THREADS"])

    def test_bot_issue_comments_ignored(self):
        _, s1 = step(None, snap(), "author")
        e2, _ = step(s1, snap(issue_comments=[IssueComment("I1", "github-actions", True, "2026-10-14T10:00:00Z")]), "author")
        self.assertEqual(e2, [])

    def test_approval_lost_after_my_push(self):
        approved = review("R1", OTHER, state="APPROVED")
        _, s1 = step(None, snap(reviews=[approved], review_decision="APPROVED", merge_state="CLEAN", checks=[Check("t", "pass", "SUCCESS")]), "author")
        e2, _ = step(s1, snap(reviews=[approved], review_decision="REVIEW_REQUIRED", head_oid="b" * 40), "author")
        self.assertEqual(kinds(e2), ["APPROVAL_LOST"])
        self.assertIn(f"approvers={OTHER}", e2[0])

    def test_ready_to_merge_once(self):
        ok = dict(review_decision="APPROVED", merge_state="CLEAN", checks=[Check("t", "pass", "SUCCESS")])
        _, s1 = step(None, snap(), "author")
        e2, s2 = step(s1, snap(**ok), "author")
        self.assertIn("READY_TO_MERGE", kinds(e2))
        e3, _ = step(s2, snap(**ok), "author")
        self.assertEqual(e3, [])

    def test_review_request_sent_marks_rereview(self):
        r = review("R1", OTHER)
        _, s1 = step(None, snap(reviews=[r]), "author")
        req = ReviewRequest(reviewer=OTHER, requested_by=ME, created_at="2026-10-14T12:00:00Z")
        e2, _ = step(s1, snap(reviews=[r], review_requests=[req]), "author")
        self.assertEqual(kinds(e2), ["REVIEW_REQUEST_SENT"])
        self.assertIn("rereview=true", e2[0])

    def test_merged_stops_everything_else(self):
        _, s1 = step(None, snap(), "author")
        e2, _ = step(s1, snap(state="MERGED", mergeable="CONFLICTING"), "author")
        self.assertEqual(kinds(e2), ["PR_MERGED"])


class ReviewerTests(unittest.TestCase):
    def other_pr(self, **kw) -> Snapshot:
        return snap(author=OTHER, head_author=OTHER, **kw)

    def reviewed(self, **kw) -> Snapshot:
        my_review = review("R1", ME, at="2026-10-14T10:00:00Z", commit="a" * 40)
        t = thread("T1", [comment("C1", ME, "2026-10-14T10:00:00Z", "R1", reply=False)])
        kw.setdefault("reviews", [my_review])
        kw.setdefault("threads", [t])
        return self.other_pr(**kw)

    def test_unreviewed_pr_waits(self):
        events, _ = step(None, self.other_pr(), "reviewer")
        self.assertEqual(kinds(events), ["BASELINE", "AWAITING_MY_REVIEW"])

    def test_push_is_debounced_one_quiet_poll(self):
        _, s1 = step(None, self.reviewed(), "reviewer")
        e2, s2 = step(s1, self.reviewed(head_oid="b" * 40), "reviewer")
        self.assertEqual(kinds(e2), ["NEW_COMMITS"], "no check while the author may still be pushing")
        e3, s3 = step(s2, self.reviewed(head_oid="b" * 40), "reviewer")
        self.assertEqual(kinds(e3), ["ADDRESS_CHECK_DUE"])
        self.assertIn("reason=quiet", e3[0])
        e4, _ = step(s3, self.reviewed(head_oid="b" * 40), "reviewer")
        self.assertEqual(e4, [], "fires once per activity")

    def test_baseline_with_moved_head_is_due_immediately(self):
        events, _ = step(None, self.reviewed(head_oid="b" * 40), "reviewer")
        self.assertEqual(kinds(events), ["BASELINE", "ADDRESS_CHECK_DUE"])
        self.assertIn("reason=baseline", events[1])

    def test_rerequest_after_my_review_fires_now(self):
        _, s1 = step(None, self.reviewed(), "reviewer")
        req = ReviewRequest(reviewer=ME, requested_by=OTHER, created_at="2026-10-14T11:00:00Z")
        e2, _ = step(s1, self.reviewed(head_oid="b" * 40, review_requests=[req]), "reviewer")
        self.assertEqual(kinds(e2), ["RE_REQUESTED", "NEW_COMMITS", "ADDRESS_CHECK_DUE"])
        self.assertIn("reason=re-requested", e2[2])

    def test_request_older_than_my_review_is_not_a_rerequest(self):
        old = ReviewRequest(reviewer=ME, requested_by=OTHER, created_at="2026-10-14T09:00:00Z")
        events, _ = step(None, self.reviewed(review_requests=[old]), "reviewer")
        self.assertEqual(kinds(events), ["BASELINE"])

    def test_author_reply_without_push_is_due_after_quiet(self):
        _, s1 = step(None, self.reviewed(), "reviewer")
        t = thread("T1", [comment("C1", ME, "2026-10-14T10:00:00Z", "R1", False), comment("C2", OTHER, "2026-10-14T11:00:00Z", "R9", True)])
        e2, s2 = step(s1, self.reviewed(threads=[t]), "reviewer")
        self.assertEqual(kinds(e2), ["AUTHOR_REPLIED"])
        e3, _ = step(s2, self.reviewed(threads=[t]), "reviewer")
        self.assertEqual(kinds(e3), ["ADDRESS_CHECK_DUE"])
        self.assertIn("new_replies=1", e3[0])

    def test_my_thread_reply_does_not_count_as_a_review(self):
        _, s1 = step(None, self.reviewed(), "reviewer")
        reply_only = review("R2", ME, at="2026-10-14T12:00:00Z", commit="b" * 40, body=False)
        t = thread("T1", [comment("C1", ME, "2026-10-14T10:00:00Z", "R1", False), comment("C2", ME, "2026-10-14T12:00:00Z", "R2", True)])
        _, s2 = step(s1, self.reviewed(head_oid="b" * 40, reviews=[self.reviewed().reviews[0], reply_only], threads=[t]), "reviewer")
        e3, _ = step(s2, self.reviewed(head_oid="b" * 40, reviews=[self.reviewed().reviews[0], reply_only], threads=[t]), "reviewer")
        self.assertEqual(kinds(e3), ["ADDRESS_CHECK_DUE"], "a lone reply at the new head must not hide the push")

    def test_my_new_review_posts_event_and_clears_due(self):
        _, s1 = step(None, self.reviewed(head_oid="b" * 40), "reviewer")
        approve = review("R2", ME, state="APPROVED", at="2026-10-14T12:00:00Z", commit="b" * 40, body=False)
        e2, _ = step(s1, self.reviewed(head_oid="b" * 40, reviews=[self.reviewed().reviews[0], approve]), "reviewer")
        self.assertEqual(kinds(e2), ["MY_REVIEW_POSTED"])
        self.assertIn("state=APPROVED", e2[0])
        self.assertIn("first=false", e2[0])

    def test_dismissed_approval_is_still_my_last_review(self):
        older = review("R1", ME, at="2026-10-14T10:00:00Z", commit="a" * 40)
        approval = review("R2", ME, state="APPROVED", at="2026-10-14T11:00:00Z", commit="b" * 40, body=False)
        _, s1 = step(None, self.reviewed(head_oid="b" * 40, reviews=[older, approval]), "reviewer")
        dismissed = replace(approval, state="DISMISSED")
        _, s2 = step(s1, self.reviewed(head_oid="c" * 40, reviews=[older, dismissed]), "reviewer")
        e3, _ = step(s2, self.reviewed(head_oid="c" * 40, reviews=[older, dismissed]), "reviewer")
        self.assertEqual(kinds(e3), ["ADDRESS_CHECK_DUE"])
        self.assertIn(f"review_commit={'b' * 8}", e3[0], "re-check from the approval, not the older review")
        self.assertIn("my_review=DISMISSED", e3[0])

    def test_new_conflict_and_ci_failure_reported_to_reviewer(self):
        _, s1 = step(None, self.reviewed(), "reviewer")
        e2, _ = step(s1, self.reviewed(mergeable="CONFLICTING", checks=[Check("test", "fail", "FAILURE")]), "reviewer")
        self.assertEqual(kinds(e2), ["CONFLICT", "CI_FAILED"])

    def test_breakage_that_predates_the_watch_is_not_reported_to_reviewer(self):
        events, _ = step(None, self.reviewed(mergeable="CONFLICTING", checks=[Check("test", "fail", "FAILURE")]), "reviewer")
        self.assertEqual(kinds(events), ["BASELINE"])

    def test_ci_green_reported_to_reviewer(self):
        _, s1 = step(None, self.reviewed(checks=[Check("test", "pending", "IN_PROGRESS")]), "reviewer")
        e2, _ = step(s1, self.reviewed(checks=[Check("test", "pass", "SUCCESS")]), "reviewer")
        self.assertEqual(kinds(e2), ["CI_GREEN"])

    def test_thread_resolved_by_author(self):
        _, s1 = step(None, self.reviewed(), "reviewer")
        t = thread("T1", [comment("C1", ME, "2026-10-14T10:00:00Z", "R1", False)], resolved=True, resolved_by=OTHER)
        e2, _ = step(s1, self.reviewed(threads=[t]), "reviewer")
        self.assertEqual(kinds(e2), ["MY_THREAD_RESOLVED"])


if __name__ == "__main__":
    unittest.main()
