#!/usr/bin/env python3
"""Poll one GitHub PR, diff against the last saved snapshot, print one line per event.

Deterministic on purpose: no LLM runs here. The /watch-pr skill streams `watch`
stdout through Monitor so the agent only wakes when something changed.

Subcommands:
  watch    poll forever (every --interval s), print events; exits on merge/close
  once     one poll + diff (live dry run); --no-save keeps state untouched
  status   fresh snapshot summary + recent activity log (answer "what's going on")
  threads  review threads with bodies (input for the reviewer address check)
  log      append a line to the PR activity log (dispatcher + workers)
  dm       Slack-DM a GitHub user (or @me), deduped against the activity log
  reset    forget saved state (next poll is a baseline)

Event line format:  KIND pr=N key=value ... | human text
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

ROLES = ("author", "reviewer")
GH_ERROR_ALERT_AFTER = 3
DEFAULT_INTERVAL_S = 300
DEFAULT_STATE_DIR = Path(os.environ.get("WATCH_PR_STATE_DIR", Path.home() / ".cache" / "watch-pr"))

CHECK_FAIL_CONCLUSIONS = {"FAILURE", "TIMED_OUT", "CANCELLED", "ACTION_REQUIRED", "STARTUP_FAILURE", "STALE"}
CHECK_PASS_CONCLUSIONS = {"SUCCESS", "NEUTRAL"}
CHECK_SKIP_CONCLUSIONS = {"SKIPPED"}
STATUS_FAIL_STATES = {"FAILURE", "ERROR"}
STATUS_PENDING_STATES = {"PENDING", "EXPECTED"}
DECISIVE_REVIEW_STATES = {"APPROVED", "CHANGES_REQUESTED", "DISMISSED"}  # DISMISSED = stale approval after a push
ANSWERABLE_REVIEW_STATES = {"CHANGES_REQUESTED", "COMMENTED"}  # a latest review in these states wants an answer
GHOST_LOGIN = "ghost"  # GitHub's name for a deleted account
SLACK_POST = Path.home() / ".ai" / "skills" / "slack" / "scripts" / "slack-post.py"
PEOPLE_FILE = Path(os.environ.get("WATCH_PR_PEOPLE", Path.home() / ".config" / "watch-pr" / "people.json"))
DM_DEDUPE_WINDOW_S = 30 * 60


class GhError(Exception):
    """gh/network failure. Transient: the watch loop retries."""


class ParseError(Exception):
    """GitHub returned a shape we do not understand. Fatal: fix the script."""


# ---------------------------------------------------------------- model


@dataclass
class Check:
    name: str
    bucket: str  # pass | fail | pending | skip
    detail: str


@dataclass
class Review:
    id: str
    author: str
    is_bot: bool
    state: str
    submitted_at: str
    commit_oid: Optional[str]  # None when the reviewed commit was force-pushed away
    has_body: bool


@dataclass
class ThreadComment:
    id: str
    author: str
    created_at: str
    review_id: Optional[str]
    is_reply: bool


@dataclass
class Thread:
    id: str
    path: str
    line: Optional[int]  # None once outdated
    is_resolved: bool
    resolved_by: Optional[str]
    is_outdated: bool
    started_by: str
    comments: List[ThreadComment]


@dataclass
class IssueComment:
    id: str
    author: str
    is_bot: bool
    created_at: str


@dataclass
class ReviewRequest:
    reviewer: str
    requested_by: str
    created_at: str


@dataclass
class Snapshot:
    me: str
    number: int
    url: str
    title: str
    author: str
    state: str  # OPEN | CLOSED | MERGED
    is_draft: bool
    is_cross_repo: bool
    mergeable: str  # MERGEABLE | CONFLICTING | UNKNOWN
    merge_state: str
    review_decision: Optional[str]
    head_ref: str
    base_ref: str
    head_oid: str
    head_author: Optional[str]  # None when the commit email is not linked to a GitHub user
    checks: List[Check]
    reviews: List[Review]
    threads: List[Thread]
    issue_comments: List[IssueComment]
    review_requests: List[ReviewRequest]
    truncated: List[str]


@dataclass
class State:
    role: str
    snapshot: Snapshot
    known_mergeable: str  # last non-UNKNOWN mergeable value
    fail_streaks: Dict[str, List[str]] = field(default_factory=dict)  # check -> head shas it failed on, in a row
    activity_key: Optional[str] = None  # reviewer: head + latest reply seen last poll
    check_due_key: Optional[str] = None  # reviewer: activity key ADDRESS_CHECK_DUE last fired for


# ---------------------------------------------------------------- parsing (boundary)


def req(obj: Any, key: str, where: str) -> Any:
    if not isinstance(obj, dict) or key not in obj:
        raise ParseError(f"missing {where}.{key}")
    return obj[key]


def login_of(actor: Any) -> str:
    if actor is None:
        return GHOST_LOGIN
    return str(req(actor, "login", "actor"))


def is_bot(actor: Any) -> bool:
    return actor is not None and req(actor, "__typename", "actor") == "Bot"


def truncated_if(conn: Any, name: str, direction: str, out: List[str]) -> None:
    info = req(conn, "pageInfo", name)
    if req(info, direction, f"{name}.pageInfo"):
        out.append(name)


SNAPSHOT_QUERY = """
query($owner: String!, $name: String!, $number: Int!) {
  viewer { login }
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      number url title state isDraft isCrossRepository mergeable mergeStateStatus reviewDecision
      headRefName baseRefName headRefOid
      author { login __typename }
      commits(last: 1) { nodes { commit {
        oid
        author { user { login } }
        statusCheckRollup { contexts(first: 100) {
          pageInfo { hasNextPage }
          nodes {
            __typename
            ... on CheckRun { name status conclusion startedAt }
            ... on StatusContext { context state createdAt }
          }
        } }
      } } }
      reviews(last: 100) {
        pageInfo { hasPreviousPage }
        nodes { id state submittedAt body author { login __typename } commit { oid } }
      }
      reviewThreads(first: 100) {
        pageInfo { hasNextPage }
        nodes {
          id path line isResolved isOutdated resolvedBy { login }
          comments(first: 100) {
            pageInfo { hasNextPage }
            nodes { id createdAt author { login __typename } replyTo { id } pullRequestReview { id } }
          }
        }
      }
      comments(last: 100) {
        pageInfo { hasPreviousPage }
        nodes { id createdAt author { login __typename } }
      }
      timelineItems(last: 50, itemTypes: [REVIEW_REQUESTED_EVENT]) {
        nodes { ... on ReviewRequestedEvent {
          createdAt actor { login }
          requestedReviewer { __typename ... on User { login } }
        } }
      }
    }
  }
}
"""

THREADS_QUERY = """
query($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      reviewThreads(first: 100) {
        pageInfo { hasNextPage }
        nodes {
          id path line originalLine isResolved isOutdated resolvedBy { login }
          comments(first: 100) {
            nodes {
              id databaseId url body createdAt
              author { login }
              replyTo { id }
              diffHunk
              commit { oid }
              originalCommit { oid }
            }
          }
        }
      }
    }
  }
}
"""


def bucket_check_run(node: Dict[str, Any]) -> Check:
    name = str(req(node, "name", "CheckRun"))
    status = str(req(node, "status", "CheckRun"))
    conclusion = req(node, "conclusion", "CheckRun")
    if status != "COMPLETED" or conclusion is None:
        return Check(name, "pending", status)
    if conclusion in CHECK_FAIL_CONCLUSIONS:
        return Check(name, "fail", conclusion)
    if conclusion in CHECK_PASS_CONCLUSIONS:
        return Check(name, "pass", conclusion)
    if conclusion in CHECK_SKIP_CONCLUSIONS:
        return Check(name, "skip", conclusion)
    raise ParseError(f"unknown CheckRun conclusion {conclusion!r} on {name}")


def bucket_status_context(node: Dict[str, Any]) -> Check:
    name = str(req(node, "context", "StatusContext"))
    state = str(req(node, "state", "StatusContext"))
    if state == "SUCCESS":
        return Check(name, "pass", state)
    if state in STATUS_FAIL_STATES:
        return Check(name, "fail", state)
    if state in STATUS_PENDING_STATES:
        return Check(name, "pending", state)
    raise ParseError(f"unknown StatusContext state {state!r} on {name}")


def parse_checks(commit: Dict[str, Any], truncated: List[str]) -> List[Check]:
    rollup = req(commit, "statusCheckRollup", "commit")
    if rollup is None:
        return []
    contexts = req(rollup, "contexts", "statusCheckRollup")
    truncated_if(contexts, "checks", "hasNextPage", truncated)
    # Re-runs report the same name more than once: pending wins, else the latest start.
    latest: Dict[str, Tuple[str, Check]] = {}
    for node in req(contexts, "nodes", "contexts"):
        kind = req(node, "__typename", "context")
        if kind == "CheckRun":
            check, at = bucket_check_run(node), str(req(node, "startedAt", "CheckRun") or "")
        elif kind == "StatusContext":
            check, at = bucket_status_context(node), str(req(node, "createdAt", "StatusContext"))
        else:
            raise ParseError(f"unknown check context type {kind!r}")
        seen = latest.get(check.name)
        if seen is None or seen[1].bucket != "pending" and (check.bucket == "pending" or at > seen[0]):
            latest[check.name] = (at, check)
    return sorted((c for _, c in latest.values()), key=lambda c: c.name)


def parse_snapshot(data: Dict[str, Any]) -> Snapshot:
    me = login_of(req(data, "viewer", "data"))
    pr = req(req(data, "repository", "data"), "pullRequest", "repository")
    if pr is None:
        raise ParseError("pull request not found")
    truncated: List[str] = []

    commits = req(req(pr, "commits", "pr"), "nodes", "commits")
    if len(commits) != 1:
        raise ParseError(f"expected 1 head commit, got {len(commits)}")
    commit = req(commits[0], "commit", "commits")
    head_user = req(req(commit, "author", "commit"), "user", "commit.author")

    reviews_conn = req(pr, "reviews", "pr")
    truncated_if(reviews_conn, "reviews", "hasPreviousPage", truncated)
    reviews = [
        Review(
            id=str(req(n, "id", "review")),
            author=login_of(req(n, "author", "review")),
            is_bot=is_bot(req(n, "author", "review")),
            state=str(req(n, "state", "review")),
            submitted_at=str(req(n, "submittedAt", "review")),
            commit_oid=None if req(n, "commit", "review") is None else str(req(n["commit"], "oid", "review.commit")),
            has_body=bool(str(req(n, "body", "review")).strip()),
        )
        for n in req(reviews_conn, "nodes", "reviews")
        if req(n, "state", "review") != "PENDING"  # your own unsubmitted draft
    ]

    threads_conn = req(pr, "reviewThreads", "pr")
    truncated_if(threads_conn, "reviewThreads", "hasNextPage", truncated)
    threads: List[Thread] = []
    for t in req(threads_conn, "nodes", "reviewThreads"):
        comments_conn = req(t, "comments", "thread")
        truncated_if(comments_conn, "threadComments", "hasNextPage", truncated)
        comments = [
            ThreadComment(
                id=str(req(c, "id", "comment")),
                author=login_of(req(c, "author", "comment")),
                created_at=str(req(c, "createdAt", "comment")),
                review_id=None if req(c, "pullRequestReview", "comment") is None else str(c["pullRequestReview"]["id"]),
                is_reply=req(c, "replyTo", "comment") is not None,
            )
            for c in req(comments_conn, "nodes", "comments")
        ]
        if not comments:
            raise ParseError(f"thread {t.get('id')} has no comments")
        resolved_by = req(t, "resolvedBy", "thread")
        threads.append(
            Thread(
                id=str(req(t, "id", "thread")),
                path=str(req(t, "path", "thread")),
                line=req(t, "line", "thread"),
                is_resolved=bool(req(t, "isResolved", "thread")),
                resolved_by=None if resolved_by is None else login_of(resolved_by),
                is_outdated=bool(req(t, "isOutdated", "thread")),
                started_by=comments[0].author,
                comments=comments,
            )
        )

    issue_conn = req(pr, "comments", "pr")
    truncated_if(issue_conn, "comments", "hasPreviousPage", truncated)
    issue_comments = [
        IssueComment(
            id=str(req(n, "id", "issueComment")),
            author=login_of(req(n, "author", "issueComment")),
            is_bot=is_bot(req(n, "author", "issueComment")),
            created_at=str(req(n, "createdAt", "issueComment")),
        )
        for n in req(issue_conn, "nodes", "comments")
    ]

    review_requests: List[ReviewRequest] = []
    for n in req(req(pr, "timelineItems", "pr"), "nodes", "timelineItems"):
        reviewer = req(n, "requestedReviewer", "ReviewRequestedEvent")
        if reviewer is None or req(reviewer, "__typename", "requestedReviewer") != "User":
            continue  # team requests are not a personal re-request
        review_requests.append(
            ReviewRequest(
                reviewer=login_of(reviewer),
                requested_by=login_of(req(n, "actor", "ReviewRequestedEvent")),
                created_at=str(req(n, "createdAt", "ReviewRequestedEvent")),
            )
        )

    return Snapshot(
        me=me,
        number=int(req(pr, "number", "pr")),
        url=str(req(pr, "url", "pr")),
        title=str(req(pr, "title", "pr")),
        author=login_of(req(pr, "author", "pr")),
        state=str(req(pr, "state", "pr")),
        is_draft=bool(req(pr, "isDraft", "pr")),
        is_cross_repo=bool(req(pr, "isCrossRepository", "pr")),
        mergeable=str(req(pr, "mergeable", "pr")),
        merge_state=str(req(pr, "mergeStateStatus", "pr")),
        review_decision=req(pr, "reviewDecision", "pr"),
        head_ref=str(req(pr, "headRefName", "pr")),
        base_ref=str(req(pr, "baseRefName", "pr")),
        head_oid=str(req(pr, "headRefOid", "pr")),
        head_author=None if head_user is None else login_of(head_user),
        checks=parse_checks(commit, truncated),
        reviews=reviews,
        threads=threads,
        issue_comments=issue_comments,
        review_requests=review_requests,
        truncated=truncated,
    )


def snapshot_from_dict(d: Dict[str, Any]) -> Snapshot:
    return Snapshot(
        **{
            **d,
            "checks": [Check(**c) for c in d["checks"]],
            "reviews": [Review(**r) for r in d["reviews"]],
            "threads": [
                Thread(**{**t, "comments": [ThreadComment(**c) for c in t["comments"]]}) for t in d["threads"]
            ],
            "issue_comments": [IssueComment(**c) for c in d["issue_comments"]],
            "review_requests": [ReviewRequest(**r) for r in d["review_requests"]],
        }
    )


def state_from_dict(d: Dict[str, Any]) -> State:
    return State(**{**d, "snapshot": snapshot_from_dict(d["snapshot"])})


# ---------------------------------------------------------------- gh


def gh(args: List[str]) -> str:
    try:
        proc = subprocess.run(
            ["gh", *args], capture_output=True, text=True, timeout=90, env={**os.environ, "NO_COLOR": "1"}
        )
    except subprocess.TimeoutExpired as exc:
        raise GhError(f"gh timed out: {' '.join(args[:3])}") from exc
    if proc.returncode != 0:
        raise GhError(proc.stderr.strip() or f"gh exited {proc.returncode}")
    return proc.stdout


def gh_graphql(query: str, owner: str, name: str, number: int) -> Dict[str, Any]:
    out = gh(["api", "graphql", "-f", f"query={query}", "-f", f"owner={owner}", "-f", f"name={name}", "-F", f"number={number}"])
    try:
        payload = json.loads(out)
    except json.JSONDecodeError as exc:
        raise GhError(f"gh returned non-JSON: {out[:200]}") from exc
    if "errors" in payload:
        raise GhError(json.dumps(payload["errors"])[:500])
    return req(payload, "data", "graphql")


def fetch_snapshot(repo: str, number: int) -> Snapshot:
    owner, name = split_repo(repo)
    return parse_snapshot(gh_graphql(SNAPSHOT_QUERY, owner, name, number))


def split_repo(repo: str) -> Tuple[str, str]:
    parts = repo.split("/")
    if len(parts) != 2 or not all(parts):
        raise SystemExit(f"--repo must be owner/name, got {repo!r}")
    return parts[0], parts[1]


# ---------------------------------------------------------------- diff (pure)


def ev(kind: str, snap: Snapshot, text: str, **kv: Any) -> str:
    fields = " ".join(f"{k}={v}" for k, v in kv.items() if v is not None)
    return f"{kind} pr={snap.number}{' ' + fields if fields else ''} | {text}"


def short(oid: Optional[str]) -> str:
    return oid[:8] if oid else "none"


def substantive_review_ids(snap: Snapshot) -> set:
    """Reviews that are a real review pass, not a lone thread reply (GitHub wraps every reply in a review)."""
    opened_threads = {c.review_id for t in snap.threads for c in t.comments if not c.is_reply and c.review_id}
    return {r.id for r in snap.reviews if r.state in DECISIVE_REVIEW_STATES or r.has_body or r.id in opened_threads}


def last_review_by(snap: Snapshot, login: str) -> Optional[Review]:
    ids = substantive_review_ids(snap)
    mine = [r for r in snap.reviews if r.author == login and r.id in ids]
    return max(mine, key=lambda r: r.submitted_at) if mine else None


def latest_reviews(snap: Snapshot) -> Dict[str, Review]:
    ids = substantive_review_ids(snap)
    out: Dict[str, Review] = {}
    for r in sorted(snap.reviews, key=lambda r: r.submitted_at):
        if r.id in ids:
            out[r.author] = r
    return out


def unanswered_reviews(snap: Snapshot) -> List[Review]:
    """Each other reviewer's latest review that asks for something you have not answered yet.

    Only reviews with a body (or CHANGES_REQUESTED): thread-only reviews are covered by their threads.
    Answered = you commented on the PR or re-requested that reviewer after it (the review-fix flow does
    both), or every thread it opened is resolved.
    """
    me = snap.me
    out: List[Review] = []
    for author, r in latest_reviews(snap).items():
        if author == me or r.state not in ANSWERABLE_REVIEW_STATES:
            continue
        if not r.has_body and r.state != "CHANGES_REQUESTED":
            continue
        opened = [t for t in snap.threads if t.comments[0].review_id == r.id]
        if opened and all(t.is_resolved for t in opened):
            continue
        if any(c.author == me and c.created_at > r.submitted_at for c in snap.issue_comments):
            continue
        if any(q.requested_by == me and q.reviewer == author and q.created_at > r.submitted_at for q in snap.review_requests):
            continue
        out.append(r)
    return sorted(out, key=lambda r: r.submitted_at)


def all_green(checks: List[Check]) -> bool:
    return bool(checks) and all(c.bucket in ("pass", "skip") for c in checks)


def ready_to_merge(snap: Snapshot) -> bool:
    return snap.state == "OPEN" and not snap.is_draft and snap.merge_state == "CLEAN" and snap.review_decision in ("APPROVED", None)


def baseline_line(snap: Snapshot, role: str) -> str:
    counts: Dict[str, int] = {}
    for c in snap.checks:
        counts[c.bucket] = counts.get(c.bucket, 0) + 1
    checks = ",".join(f"{k}:{v}" for k, v in sorted(counts.items())) or "none"
    open_threads = sum(1 for t in snap.threads if not t.is_resolved)
    return ev(
        "BASELINE",
        snap,
        f"watching as {role}: {snap.title}",
        role=role,
        state=snap.state,
        mergeable=snap.mergeable,
        merge_state=snap.merge_state,
        decision=snap.review_decision,
        head=short(snap.head_oid),
        checks=checks,
        open_threads=open_threads,
    )


def update_fail_streaks(prev: Dict[str, List[str]], cur: Snapshot) -> Dict[str, List[str]]:
    out: Dict[str, List[str]] = {}
    for check in cur.checks:
        streak = list(prev.get(check.name, []))
        if check.bucket == "fail":
            if cur.head_oid not in streak:
                streak.append(cur.head_oid)
            out[check.name] = streak
        elif check.bucket == "pending" and streak:
            out[check.name] = streak
    return out


def health_events(prev: Optional[State], cur: Snapshot, state: State) -> List[str]:
    """Merge conflicts and failing checks on the current head, each reported once."""
    events: List[str] = []
    p = prev.snapshot if prev else None
    was_conflicting = prev is not None and prev.known_mergeable == "CONFLICTING"
    if state.known_mergeable == "CONFLICTING" and not was_conflicting:
        events.append(ev("CONFLICT", cur, f"{cur.head_ref} conflicts with {cur.base_ref}", merge_state=cur.merge_state))

    prev_fail = {c.name for c in p.checks if c.bucket == "fail"} if p and p.head_oid == cur.head_oid else set()
    for check in cur.checks:
        if check.bucket == "fail" and check.name not in prev_fail:
            attempt = len(state.fail_streaks.get(check.name, []))
            events.append(ev("CI_FAILED", cur, f"{check.name} {check.detail}", sha=short(cur.head_oid), check=check.name, attempt=attempt))

    if p is not None and all_green(cur.checks) and not (p.head_oid == cur.head_oid and all_green(p.checks)):
        events.append(ev("CI_GREEN", cur, "all checks passed", sha=short(cur.head_oid)))
    return events


def author_events(prev: Optional[State], cur: Snapshot, state: State) -> List[str]:
    me = cur.me
    p = prev.snapshot if prev else None
    events = health_events(prev, cur, state)  # baseline included: you own fixing them


    prev_review_ids = {r.id for r in p.reviews} if p else set()
    substantive = substantive_review_ids(cur)
    new_reviews = [r for r in cur.reviews if r.id not in prev_review_ids and r.author != me and r.id in substantive]
    if p is not None:
        for r in new_reviews:
            opened = sum(1 for t in cur.threads for c in t.comments if c.review_id == r.id and not c.is_reply)
            events.append(ev("NEW_REVIEW", cur, f"{r.author} {r.state}", by=r.author, state=r.state, threads=opened, review=r.id))

        new_review_ids = {r.id for r in new_reviews}
        prev_comment_ids = {c.id for t in p.threads for c in t.comments}
        for t in cur.threads:
            fresh = [c for c in t.comments if c.id not in prev_comment_ids and c.author != me and c.review_id not in new_review_ids]
            if fresh:
                events.append(ev("NEW_REPLY", cur, f"{fresh[-1].author} on {t.path}", by=fresh[-1].author, thread=t.id, path=t.path))

        prev_issue_ids = {c.id for c in p.issue_comments}
        for c in cur.issue_comments:
            if c.id not in prev_issue_ids and c.author != me and not c.is_bot:
                events.append(ev("NEW_COMMENT", cur, f"{c.author} commented", by=c.author, comment=c.id))

        approval_lost = p.review_decision == "APPROVED" and cur.review_decision != "APPROVED" and cur.head_oid != p.head_oid
        if approval_lost:
            approvers = sorted(a for a, r in latest_reviews(p).items() if r.state == "APPROVED" and a != me)
            events.append(
                ev("APPROVAL_LOST", cur, "new push dismissed the approval", approvers=",".join(approvers) or "none", decision=cur.review_decision)
            )
        elif cur.review_decision != p.review_decision:
            events.append(ev("DECISION", cur, f"review decision {p.review_decision} -> {cur.review_decision}", value=cur.review_decision))

        prev_request_keys = {(r.reviewer, r.created_at) for r in p.review_requests}
        for r in cur.review_requests:
            if (r.reviewer, r.created_at) in prev_request_keys or r.requested_by != me or r.reviewer == me:
                continue
            rereview = any(x.author == r.reviewer for x in cur.reviews if x.id in substantive)
            events.append(ev("REVIEW_REQUEST_SENT", cur, f"you requested {r.reviewer}", to=r.reviewer, rereview=str(rereview).lower()))
    else:
        waiting = [t for t in cur.threads if not t.is_resolved and t.comments[-1].author != me]
        if waiting:
            events.append(ev("UNANSWERED_THREADS", cur, f"{len(waiting)} unresolved threads where the last word is not yours", count=len(waiting)))
        pending = unanswered_reviews(cur)
        if pending:
            reviewers = ",".join(r.author for r in pending)
            events.append(
                ev("UNANSWERED_REVIEWS", cur, f"{len(pending)} reviews posted before the watch with no answer from you", count=len(pending), by=reviewers)
            )

    if ready_to_merge(cur) and not (p is not None and ready_to_merge(p)):
        events.append(ev("READY_TO_MERGE", cur, "approved, green, no conflicts"))
    return events


def reviewer_events(prev: Optional[State], cur: Snapshot, state: State) -> List[str]:
    me = cur.me
    p = prev.snapshot if prev else None
    # Only new ones: the author owns them, and a baseline DM about old breakage is noise.
    events: List[str] = health_events(prev, cur, state) if p is not None else []
    mine = last_review_by(cur, me)

    since = mine.submitted_at if mine else ""
    prev_request_keys = {(r.reviewer, r.created_at) for r in p.review_requests} if p else set()
    fresh_requests = [
        r for r in cur.review_requests
        if r.reviewer == me and r.created_at > since and (r.reviewer, r.created_at) not in prev_request_keys
    ]
    re_requested = bool(fresh_requests) and mine is not None
    if fresh_requests:
        kind = "RE_REQUESTED" if mine else "REVIEW_REQUESTED"
        events.append(ev(kind, cur, f"{fresh_requests[-1].requested_by} requested your review", by=fresh_requests[-1].requested_by))

    if p is not None and mine is not None:
        prev_ids = {r.id for r in p.reviews}
        substantive = substantive_review_ids(cur)
        if mine.id not in prev_ids:
            first = not any(r.author == me and r.id in substantive and r.submitted_at < mine.submitted_at for r in cur.reviews)
            events.append(
                ev("MY_REVIEW_POSTED", cur, f"you posted {mine.state} on {cur.author}'s PR", state=mine.state, first=str(first).lower(), author=cur.author)
            )

    if mine is None:
        if p is None:
            events.append(ev("AWAITING_MY_REVIEW", cur, f"you have not reviewed {cur.author}'s PR yet", author=cur.author))
        return events

    if p is not None and cur.head_oid != p.head_oid and cur.head_author != me:
        events.append(ev("NEW_COMMITS", cur, f"head {short(p.head_oid)} -> {short(cur.head_oid)}", head=short(cur.head_oid), by=cur.head_author))

    prev_comment_ids = {c.id for t in p.threads for c in t.comments} if p else set()
    prev_resolved = {t.id for t in p.threads if t.is_resolved} if p else set()
    replies_after: List[ThreadComment] = []
    for t in cur.threads:
        if t.started_by != me:
            continue
        others = [c for c in t.comments if c.author != me and c.created_at > mine.submitted_at]
        replies_after.extend(others)
        if p is not None:
            fresh = [c for c in others if c.id not in prev_comment_ids]
            if fresh:
                events.append(ev("AUTHOR_REPLIED", cur, f"{fresh[-1].author} on {t.path}", by=fresh[-1].author, thread=t.id, path=t.path))
            if t.is_resolved and t.id not in prev_resolved and t.resolved_by != me:
                events.append(ev("MY_THREAD_RESOLVED", cur, f"{t.resolved_by} resolved your thread on {t.path}", by=t.resolved_by, thread=t.id, path=t.path))

    latest_reply = max(replies_after, key=lambda c: c.created_at).id if replies_after else "-"
    activity = f"{cur.head_oid}:{latest_reply}"
    has_activity = cur.head_oid != mine.commit_oid or bool(replies_after)
    quiet = prev is not None and prev.activity_key == activity
    state.activity_key = activity
    if has_activity and state.check_due_key != activity and cur.state == "OPEN":
        reason = "re-requested" if re_requested else "baseline" if p is None else "quiet" if quiet else None
        if reason is not None:
            state.check_due_key = activity
            events.append(
                ev(
                    "ADDRESS_CHECK_DUE",
                    cur,
                    "author activity since your last review has settled",
                    review_commit=short(mine.commit_oid),
                    my_review=mine.state,
                    head=short(cur.head_oid),
                    new_replies=len(replies_after),
                    reason=reason,
                )
            )
    return events


def diff(prev: Optional[State], cur: Snapshot, role: str) -> Tuple[List[str], State]:
    if role not in ROLES:
        raise ValueError(f"role must be one of {ROLES}, got {role!r}")
    p = prev.snapshot if prev else None
    state = State(
        role=role,
        snapshot=cur,
        known_mergeable=cur.mergeable if cur.mergeable != "UNKNOWN" else (prev.known_mergeable if prev else "UNKNOWN"),
        fail_streaks=update_fail_streaks(prev.fail_streaks if prev else {}, cur),
        activity_key=prev.activity_key if prev else None,
        check_due_key=prev.check_due_key if prev else None,
    )

    if p is not None and p.state == "OPEN" and cur.state != "OPEN":
        return [ev(f"PR_{cur.state}", cur, f"PR {cur.state.lower()}")], state

    events: List[str] = [] if p is not None else [baseline_line(cur, role)]
    new_truncation = [t for t in cur.truncated if p is None or t not in p.truncated]
    if new_truncation:
        events.append(ev("WATCH_LIMIT", cur, f"page limit hit on {','.join(new_truncation)}; events there may be missed"))
    if p is not None and p.is_draft and not cur.is_draft:
        events.append(ev("READY_FOR_REVIEW", cur, "draft marked ready for review"))

    events.extend(author_events(prev, cur, state) if role == "author" else reviewer_events(prev, cur, state))
    return events, state


# ---------------------------------------------------------------- state + log files


def state_key(repo: str, number: int) -> str:
    return f"{repo.replace('/', '-')}-{number}"


def state_path(state_dir: Path, repo: str, number: int) -> Path:
    return state_dir / f"{state_key(repo, number)}.json"


def log_path(state_dir: Path, repo: str, number: int) -> Path:
    return state_dir / f"{state_key(repo, number)}.log"


def load_state(state_dir: Path, repo: str, number: int) -> Optional[State]:
    path = state_path(state_dir, repo, number)
    if not path.exists():
        return None
    try:
        return state_from_dict(json.loads(path.read_text()))
    except (KeyError, TypeError, json.JSONDecodeError) as exc:
        raise ParseError(f"corrupt state file {path}: {exc}. Run `reset` to start over.") from exc


def save_state(state_dir: Path, repo: str, number: int, state: State) -> None:
    state_dir.mkdir(parents=True, exist_ok=True)
    path = state_path(state_dir, repo, number)
    tmp = path.with_suffix(".tmp")
    tmp.write_text(json.dumps(asdict(state), indent=1))
    tmp.replace(path)


def now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def append_log(state_dir: Path, repo: str, number: int, who: str, line: str) -> None:
    state_dir.mkdir(parents=True, exist_ok=True)
    with log_path(state_dir, repo, number).open("a") as fh:
        fh.write(f"{now_iso()} [{who}] {line}\n")


def resolve_role(requested: str, snap: Snapshot, prev: Optional[State]) -> str:
    if requested in ROLES:
        return requested
    if requested != "auto":
        raise SystemExit(f"--role must be auto|author|reviewer, got {requested!r}")
    if prev is not None:
        return prev.role
    return "author" if snap.author == snap.me else "reviewer"


# ---------------------------------------------------------------- commands


def poll(args: argparse.Namespace, save: bool) -> Tuple[List[str], State]:
    prev = load_state(args.state_dir, args.repo, args.pr)
    cur = fetch_snapshot(args.repo, args.pr)
    role = resolve_role(args.role, cur, prev)
    if prev is not None and prev.role != role:
        prev = None  # role switch: start a fresh baseline for the new view
    events, state = diff(prev, cur, role)
    if save:
        save_state(args.state_dir, args.repo, args.pr, state)
        for line in events:
            append_log(args.state_dir, args.repo, args.pr, "watch", line)
    return events, state


def emit(line: str) -> None:
    print(line, flush=True)


def cmd_watch(args: argparse.Namespace) -> int:
    errors = 0
    while True:
        try:
            events, state = poll(args, save=True)
        except GhError as exc:
            errors += 1
            if errors == GH_ERROR_ALERT_AFTER:
                emit(f"WATCH_ERROR pr={args.pr} consecutive={errors} | {str(exc)[:300]}")
            time.sleep(args.interval)
            continue
        except ParseError as exc:
            emit(f"WATCH_ERROR pr={args.pr} fatal=true | {exc}")
            return 2
        if errors >= GH_ERROR_ALERT_AFTER:
            emit(f"WATCH_RECOVERED pr={args.pr} | gh calls succeed again after {errors} failures")
        errors = 0
        for line in events:
            emit(line)
        if state.snapshot.state != "OPEN":
            return 0
        time.sleep(args.interval)


def cmd_once(args: argparse.Namespace) -> int:
    try:
        events, _ = poll(args, save=not args.no_save)
    except (GhError, ParseError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    for line in events:
        emit(line)
    return 0


def cmd_status(args: argparse.Namespace) -> int:
    prev = load_state(args.state_dir, args.repo, args.pr)
    snap = fetch_snapshot(args.repo, args.pr)
    role = resolve_role(args.role, snap, prev)
    print(f"PR #{snap.number}  {snap.title}\n{snap.url}")
    print(f"role: {role}   you: {snap.me}   author: {snap.author}")
    print(
        f"state: {snap.state}  draft: {'yes' if snap.is_draft else 'no'}  mergeable: {snap.mergeable} ({snap.merge_state})"
        f"  decision: {snap.review_decision}"
    )
    print(f"head: {short(snap.head_oid)} by {snap.head_author}  ({snap.head_ref} -> {snap.base_ref})")
    if snap.checks:
        for bucket in ("fail", "pending", "pass", "skip"):
            names = [c.name for c in snap.checks if c.bucket == bucket]
            if names:
                print(f"checks {bucket}: {', '.join(names)}")
    else:
        print("checks: none on head" + (" (CI does not run while the branch conflicts)" if snap.mergeable == "CONFLICTING" else ""))
    latest: Dict[str, Review] = {}
    for r in snap.reviews:
        if r.id in substantive_review_ids(snap):
            latest[r.author] = r
    for r in latest.values():
        print(f"review: {r.author} {r.state} {r.submitted_at} @ {short(r.commit_oid)}")
    open_threads = [t for t in snap.threads if not t.is_resolved]
    waiting_on_me = [t for t in open_threads if t.comments[-1].author != snap.me]
    print(f"threads: {len(open_threads)} unresolved ({len(waiting_on_me)} where the last word is not yours)")
    if role == "author":
        pending = unanswered_reviews(snap)
        print(f"reviews awaiting your answer: {len(pending)}")
        for r in pending:
            print(f"  {r.author} {r.state} {r.submitted_at} @ {short(r.commit_oid)}")
    mine = last_review_by(snap, snap.me)
    if role == "reviewer":
        if mine is None:
            print("your review: none yet")
        else:
            my_open = [t for t in open_threads if t.started_by == snap.me]
            print(f"your last review: {mine.state} @ {short(mine.commit_oid)}  head now {short(snap.head_oid)}  your open threads: {len(my_open)}")
    log = log_path(args.state_dir, args.repo, args.pr)
    if log.exists():
        lines = log.read_text().splitlines()[-args.tail:]
        print(f"recent activity ({len(lines)}):")
        for line in lines:
            print(f"  {line}")
    else:
        print("recent activity: none logged yet")
    return 0


def cmd_threads(args: argparse.Namespace) -> int:
    owner, name = split_repo(args.repo)
    data = gh_graphql(THREADS_QUERY, owner, name, args.pr)
    conn = req(req(req(data, "repository", "data"), "pullRequest", "repository"), "reviewThreads", "pr")
    started_by = args.started_by
    if started_by == "@me":
        started_by = gh(["api", "user", "--jq", ".login"]).strip()
    out = []
    for t in req(conn, "nodes", "reviewThreads"):
        comments = req(req(t, "comments", "thread"), "nodes", "comments")
        if not comments:
            raise ParseError(f"thread {t.get('id')} has no comments")
        if started_by and login_of(comments[0]["author"]) != started_by:
            continue
        if args.unresolved and t["isResolved"]:
            continue
        out.append(
            {
                "id": t["id"],
                "path": t["path"],
                "line": t["line"],
                "originalLine": t["originalLine"],
                "isResolved": t["isResolved"],
                "isOutdated": t["isOutdated"],
                "resolvedBy": None if t["resolvedBy"] is None else login_of(t["resolvedBy"]),
                "diffHunk": comments[0]["diffHunk"],
                "comments": [
                    {
                        "id": c["id"],
                        "databaseId": c["databaseId"],
                        "url": c["url"],
                        "author": login_of(c["author"]),
                        "createdAt": c["createdAt"],
                        "commit": None if c["commit"] is None else c["commit"]["oid"],
                        "originalCommit": None if c["originalCommit"] is None else c["originalCommit"]["oid"],
                        "body": c["body"],
                    }
                    for c in comments
                ],
            }
        )
    if req(req(conn, "pageInfo", "reviewThreads"), "hasNextPage", "pageInfo"):
        print("WARNING: more than 100 threads; only the first 100 are listed", file=sys.stderr)
    print(json.dumps(out, indent=1))
    return 0


def cmd_log(args: argparse.Namespace) -> int:
    append_log(args.state_dir, args.repo, args.pr, args.who, " ".join(args.message))
    return 0


def slack_target(login: str) -> Optional[str]:
    """GitHub login -> Slack handle from people.json only. No name guessing: a wrong DM is worse than none.

    A login mapped to null (bots) returns None = never DM.
    """
    if login == "@me":
        return "@me"
    if not PEOPLE_FILE.exists():
        raise SystemExit(f"USER_NOT_MAPPED: {PEOPLE_FILE} missing; map every GitHub login to a Slack handle")
    try:
        people = json.loads(PEOPLE_FILE.read_text())
    except json.JSONDecodeError as exc:
        raise SystemExit(f"invalid JSON in {PEOPLE_FILE}: {exc}") from exc
    if not isinstance(people, dict) or login not in people:
        raise SystemExit(f"USER_NOT_MAPPED: GitHub {login} is not in {PEOPLE_FILE}; add \"{login}\": \"<slack handle>\" (or null for a bot)")
    target = people[login]
    if target is not None and not isinstance(target, str):
        raise SystemExit(f"invalid mapping for {login} in {PEOPLE_FILE}: expected a Slack handle or null")
    return target


def recently_sent(state_dir: Path, repo: str, number: int, marker: str) -> bool:
    log = log_path(state_dir, repo, number)
    if not log.exists():
        return False
    cutoff = time.time() - DM_DEDUPE_WINDOW_S
    for line in reversed(log.read_text().splitlines()):
        stamp = line.split(" ", 1)[0]
        try:
            at = datetime.strptime(stamp, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc).timestamp()
        except ValueError:
            continue
        if at < cutoff:
            return False
        if line.endswith(marker):
            return True
    return False


def cmd_dm(args: argparse.Namespace) -> int:
    marker = f"[dm] to={args.to} {args.text}"
    if recently_sent(args.state_dir, args.repo, args.pr, marker):
        print(f"skipped: same DM to {args.to} sent within {DM_DEDUPE_WINDOW_S // 60} min")
        return 0
    target = slack_target(args.to)
    if target is None:
        print(f"skipped: {args.to} is mapped to null (not a person)")
        return 0
    cmd = [sys.executable, str(SLACK_POST), "dm", "--to", target, "--text", args.text]
    if args.dry_run:
        cmd.append("--dry-run")
    proc = subprocess.run(cmd, capture_output=True, text=True)
    sys.stdout.write(proc.stdout)
    if proc.returncode != 0:
        sys.stderr.write(proc.stderr)
        print(f"DM to {args.to} ({target}) failed; map them in {PEOPLE_FILE} if USER_NOT_FOUND", file=sys.stderr)
        return proc.returncode
    if not args.dry_run:
        state_dir = args.state_dir
        state_dir.mkdir(parents=True, exist_ok=True)
        with log_path(state_dir, args.repo, args.pr).open("a") as fh:
            fh.write(f"{now_iso()} {marker}\n")
    return 0


def cmd_reset(args: argparse.Namespace) -> int:
    path = state_path(args.state_dir, args.repo, args.pr)
    if path.exists():
        path.unlink()
        print(f"removed {path}")
    else:
        print(f"no state at {path}")
    return 0


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="cmd", required=True)

    def common(p: argparse.ArgumentParser) -> None:
        p.add_argument("--repo", required=True, help="owner/name")
        p.add_argument("--pr", required=True, type=int)
        p.add_argument("--state-dir", type=Path, default=DEFAULT_STATE_DIR)

    for name in ("watch", "once", "status"):
        p = sub.add_parser(name)
        common(p)
        p.add_argument("--role", default="auto", help="auto|author|reviewer (auto: author if you opened the PR)")
        if name == "watch":
            p.add_argument("--interval", type=int, default=DEFAULT_INTERVAL_S)
        if name == "once":
            p.add_argument("--no-save", action="store_true")
        if name == "status":
            p.add_argument("--tail", type=int, default=20)

    p = sub.add_parser("threads")
    common(p)
    p.add_argument("--started-by", default="@me", help="login, @me, or '' for all")
    p.add_argument("--unresolved", action="store_true")

    p = sub.add_parser("log")
    common(p)
    p.add_argument("--who", required=True)
    p.add_argument("message", nargs="+")

    p = sub.add_parser("dm")
    common(p)
    p.add_argument("--to", required=True, help="GitHub login or @me")
    p.add_argument("--text", required=True)
    p.add_argument("--dry-run", action="store_true")

    p = sub.add_parser("reset")
    common(p)

    args = parser.parse_args(argv)
    handler = {
        "watch": cmd_watch,
        "once": cmd_once,
        "status": cmd_status,
        "threads": cmd_threads,
        "log": cmd_log,
        "dm": cmd_dm,
        "reset": cmd_reset,
    }[args.cmd]
    return handler(args)


if __name__ == "__main__":
    sys.exit(main())
