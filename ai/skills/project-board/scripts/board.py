#!/usr/bin/env python3
"""Post issues to the Future Mortgage CRM project board (github.com/orgs/Future-Mortgage/projects/1).

Field and option names are resolved live through `gh`, and every name, label and parent is
validated BEFORE anything is written. Then: create issue -> add to board -> set fields -> link parent.

  board.py fields
  board.py post --title T --body-file F [--repo monorepo] [--status Todo] [--priority P1]
                [--area "CRM Features"] [--category Bug] [--owner Martin]
                [--assignee LOGIN]... [--label NAME]... [--parent REF] [--start DATE] [--end DATE] [--dry-run]
  board.py set  --issue REF [same field flags] [--parent REF] [--dry-run]

REF = 1234 | repo#1234 | https://github.com/Future-Mortgage/<repo>/issues/1234
Option values match case-insensitively, exact first, then unique prefix ("P1" -> "P1 - High").
"""
from __future__ import annotations

import argparse
import datetime
import json
import re
import subprocess
import sys

ORG = "Future-Mortgage"
PROJECT_NUMBER = "1"
DEFAULT_REPO = "monorepo"
SINGLE_SELECT_FIELDS = {
    "status": "Status",
    "priority": "Priority",
    "area": "Area",
    "category": "Category",
    "owner": "Owner",
}
DATE_FIELDS = {"start": "Start Date", "end": "End Date"}
GITHUB_TITLE_MAX = 256

ISSUE_QUERY = """
query($owner: String!, $repo: String!, $number: Int!) {
  repository(owner: $owner, name: $repo) {
    issue(number: $number) { id url title state parent { url } }
  }
}
"""
ADD_SUB_ISSUE = """
mutation($parent: ID!, $child: ID!) {
  addSubIssue(input: {issueId: $parent, subIssueId: $child}) { issue { url } }
}
"""


class BoardError(Exception):
    pass


def gh(*args: str, stdin: str | None = None) -> str:
    result = subprocess.run(["gh", *args], capture_output=True, text=True, input=stdin)
    if result.returncode != 0:
        raise BoardError(f"GH_FAILED: gh {' '.join(args[:3])}\n{result.stderr.strip()}")
    return result.stdout


def gh_json(*args: str) -> dict | list:
    return json.loads(gh(*args))


def load_board() -> tuple[str, dict[str, dict]]:
    project = gh_json("project", "view", PROJECT_NUMBER, "--owner", ORG, "--format", "json")
    fields = gh_json(
        "project", "field-list", PROJECT_NUMBER, "--owner", ORG, "--format", "json", "--limit", "100"
    )["fields"]
    return project["id"], {field["name"]: field for field in fields}


def board_field(fields: dict[str, dict], name: str) -> dict:
    if name not in fields:
        raise BoardError(f"FIELD_NOT_FOUND: {name!r}. Board fields: {', '.join(fields)}")
    return fields[name]


def resolve_option(field: dict, wanted: str) -> dict:
    options = field.get("options")
    if not options:
        raise BoardError(f"FIELD_NOT_SINGLE_SELECT: {field['name']}")
    needle = wanted.strip().lower()
    exact = [option for option in options if option["name"].lower() == needle]
    if exact:
        return exact[0]
    prefixed = [option for option in options if option["name"].lower().startswith(needle)]
    if len(prefixed) == 1:
        return prefixed[0]
    valid = ", ".join(option["name"] for option in options)
    raise BoardError(f"OPTION_NOT_FOUND: {field['name']}={wanted!r}. Valid: {valid}")


def plan_field_edits(fields: dict[str, dict], args: argparse.Namespace) -> list[tuple[dict, list[str], str]]:
    edits = []
    for arg_name, field_name in SINGLE_SELECT_FIELDS.items():
        wanted = getattr(args, arg_name)
        if wanted is None:
            continue
        field = board_field(fields, field_name)
        option = resolve_option(field, wanted)
        edits.append((field, ["--single-select-option-id", option["id"]], f"{field_name}={option['name']}"))
    for arg_name, field_name in DATE_FIELDS.items():
        wanted = getattr(args, arg_name)
        if wanted is None:
            continue
        try:
            datetime.date.fromisoformat(wanted)
        except ValueError:
            raise BoardError(f"BAD_DATE: --{arg_name} {wanted!r} (use YYYY-MM-DD)")
        field = board_field(fields, field_name)
        edits.append((field, ["--date", wanted], f"{field_name}={wanted}"))
    return edits


def parse_issue_ref(ref: str, default_repo: str) -> tuple[str, int]:
    ref = ref.strip()
    url = re.fullmatch(rf"https://github\.com/{ORG}/([\w.-]+)/issues/(\d+)/?", ref)
    if url:
        return url.group(1), int(url.group(2))
    short = re.fullmatch(r"(?:([\w.-]+)#|#)?(\d+)", ref)
    if short:
        return short.group(1) or default_repo, int(short.group(2))
    raise BoardError(f"BAD_ISSUE_REF: {ref!r} (use 1234, repo#1234, or the issue URL)")


def lookup_issue(repo: str, number: int) -> dict:
    data = gh_json(
        "api", "graphql",
        "-f", f"query={ISSUE_QUERY}",
        "-f", f"owner={ORG}",
        "-f", f"repo={repo}",
        "-F", f"number={number}",
    )
    issue = data["data"]["repository"]["issue"]
    if issue is None:
        raise BoardError(f"ISSUE_NOT_FOUND: {ORG}/{repo}#{number}")
    return issue


def check_labels(repo: str, labels: list[str]) -> None:
    if not labels:
        return
    existing = {label["name"] for label in gh_json("label", "list", "-R", f"{ORG}/{repo}", "--limit", "500", "--json", "name")}
    missing = [label for label in labels if label not in existing]
    if missing:
        raise BoardError(
            f"LABEL_NOT_FOUND: {missing} in {ORG}/{repo}. Pick an existing label (gh label list -R {ORG}/{repo}) "
            "or ask before creating one."
        )


def read_body(path: str) -> str:
    body = sys.stdin.read() if path == "-" else open(path, encoding="utf-8").read()
    if not body.strip():
        raise BoardError("EMPTY_BODY: issue body is empty")
    return body


def apply_to_board(issue: dict, project_id: str, edits: list, parent: dict | None) -> None:
    item = gh_json("project", "item-add", PROJECT_NUMBER, "--owner", ORG, "--url", issue["url"], "--format", "json")
    if "id" not in item:
        raise BoardError(f"ITEM_ADD_NO_ID: unexpected item-add output {item}")
    print(f"item={item['id']}")
    for field, value_args, label in edits:
        gh("project", "item-edit", "--id", item["id"], "--project-id", project_id, "--field-id", field["id"], *value_args)
        print(f"set {label}")
    if parent is None:
        return
    current_parent = (issue.get("parent") or {}).get("url")
    if current_parent == parent["url"]:
        print(f"parent={parent['url']} (already linked)")
        return
    if current_parent is not None:
        raise BoardError(f"HAS_OTHER_PARENT: {issue['url']} is already a sub-issue of {current_parent}")
    gh("api", "graphql", "-f", f"query={ADD_SUB_ISSUE}", "-f", f"parent={parent['id']}", "-f", f"child={issue['id']}")
    print(f"parent={parent['url']}")


def print_plan(action: str, edits: list, parent: dict | None, extra: list[str]) -> None:
    print(f"DRY RUN — {action}")
    for line in extra:
        print(f"  {line}")
    for _, _, label in edits:
        print(f"  set {label}")
    if parent:
        print(f"  parent={parent['url']} ({parent['title']})")


def cmd_fields(_: argparse.Namespace) -> None:
    _, fields = load_board()
    for name, field in fields.items():
        options = field.get("options")
        if options:
            print(f"{name}: {' | '.join(option['name'] for option in options)}")
        else:
            print(f"{name}: ({field['type']})")


def cmd_post(args: argparse.Namespace) -> None:
    title = args.title.strip()
    if not title:
        raise BoardError("EMPTY_TITLE")
    if len(title) > GITHUB_TITLE_MAX:
        raise BoardError(f"TITLE_TOO_LONG: {len(title)} chars (max {GITHUB_TITLE_MAX})")
    body = read_body(args.body_file)
    project_id, fields = load_board()
    edits = plan_field_edits(fields, args)
    check_labels(args.repo, args.label)
    parent = lookup_issue(*parse_issue_ref(args.parent, args.repo)) if args.parent else None

    if args.dry_run:
        print_plan(
            "post",
            edits,
            parent,
            [f"repo={ORG}/{args.repo}", f"title={title}", f"labels={args.label}", f"assignees={args.assignee}"],
        )
        return

    create = ["issue", "create", "-R", f"{ORG}/{args.repo}", "--title", title, "--body-file", "-"]
    for label in args.label:
        create += ["--label", label]
    for assignee in args.assignee:
        create += ["--assignee", assignee]
    url = gh(*create, stdin=body).strip().splitlines()[-1]
    print(f"issue={url}")

    try:
        issue = lookup_issue(*parse_issue_ref(url, args.repo))
        apply_to_board(issue, project_id, edits, parent)
    except BoardError:
        print(
            f"PARTIAL: {url} was created but the board update failed. Fix the cause, then rerun "
            f"`board.py set --issue {url}` with the same field flags.",
            file=sys.stderr,
        )
        raise


def cmd_set(args: argparse.Namespace) -> None:
    repo, number = parse_issue_ref(args.issue, args.repo)
    issue = lookup_issue(repo, number)
    project_id, fields = load_board()
    edits = plan_field_edits(fields, args)
    parent = lookup_issue(*parse_issue_ref(args.parent, repo)) if args.parent else None
    if not edits and parent is None:
        raise BoardError("NOTHING_TO_SET: pass at least one field flag or --parent")
    if args.dry_run:
        print_plan("set", edits, parent, [f"issue={issue['url']} ({issue['title']})"])
        return
    print(f"issue={issue['url']}")
    apply_to_board(issue, project_id, edits, parent)


def add_field_flags(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--repo", default=DEFAULT_REPO, help=f"repo in {ORG} (default {DEFAULT_REPO})")
    for arg_name, field_name in SINGLE_SELECT_FIELDS.items():
        parser.add_argument(f"--{arg_name}", help=f"board {field_name} option")
    for arg_name, field_name in DATE_FIELDS.items():
        parser.add_argument(f"--{arg_name}", help=f"board {field_name} (YYYY-MM-DD)")
    parser.add_argument("--parent", help="parent issue REF (makes this a sub-issue)")
    parser.add_argument("--dry-run", action="store_true", help="validate and print the plan, write nothing")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("fields", help="print live board fields and options").set_defaults(run=cmd_fields)

    post = sub.add_parser("post", help="create an issue and put it on the board")
    post.add_argument("--title", required=True)
    post.add_argument("--body-file", required=True, help="markdown body file, or - for stdin")
    post.add_argument("--assignee", action="append", default=[], help="GitHub login (repeatable)")
    post.add_argument("--label", action="append", default=[], help="existing repo label (repeatable)")
    add_field_flags(post)
    post.set_defaults(run=cmd_post)

    set_ = sub.add_parser("set", help="add an existing issue to the board and/or set its fields")
    set_.add_argument("--issue", required=True, help="issue REF")
    add_field_flags(set_)
    set_.set_defaults(run=cmd_set)

    args = parser.parse_args()
    try:
        args.run(args)
    except BoardError as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
