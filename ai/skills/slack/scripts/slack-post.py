#!/usr/bin/env python3
"""Post to Slack as the slackatui user. Never prints tokens."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request

KEYCHAIN_SERVICE = "slackatui"
KEYCHAIN_ACCOUNTS = ("default", "T0AAYE6T63W")


class SlackError(Exception):
    def __init__(self, message: str, *, code: str = "SLACK_ERROR"):
        super().__init__(message)
        self.code = code


def load_token() -> str:
    env = __import__("os").environ
    for key in ("SLACK_USER_TOKEN", "SLACK_BOT_TOKEN"):
        value = env.get(key, "").strip()
        if value:
            return value

    last_err = "no slackatui tokens in keychain"
    for account in KEYCHAIN_ACCOUNTS:
        try:
            raw = subprocess.check_output(
                [
                    "security",
                    "find-generic-password",
                    "-s",
                    KEYCHAIN_SERVICE,
                    "-a",
                    account,
                    "-w",
                ],
                stderr=subprocess.DEVNULL,
                text=True,
            ).strip()
        except subprocess.CalledProcessError:
            continue
        try:
            data = json.loads(raw)
        except json.JSONDecodeError:
            last_err = "keychain value is not JSON"
            continue
        token = (data.get("user_token") or data.get("bot_token") or "").strip()
        if token:
            return token
        last_err = "keychain JSON has no user_token or bot_token"

    raise SlackError(
        f"{last_err}. Run `slackatui auth` or set SLACK_USER_TOKEN.",
        code="AUTH_MISSING",
    )


def api(token: str, method: str, payload: dict | None = None, **params) -> dict:
    headers = {"Authorization": f"Bearer {token}"}
    if payload is None:
        url = f"https://slack.com/api/{method}?{urllib.parse.urlencode(params)}"
        req = urllib.request.Request(url, headers=headers)
    else:
        req = urllib.request.Request(
            f"https://slack.com/api/{method}",
            data=json.dumps(payload).encode(),
            headers={**headers, "Content-Type": "application/json"},
        )
    try:
        with urllib.request.urlopen(req) as resp:
            body = json.loads(resp.read().decode())
    except urllib.error.HTTPError as exc:
        raise SlackError(f"HTTP {exc.code} calling {method}", code="HTTP") from exc
    if not body.get("ok"):
        raise SlackError(
            body.get("error") or f"{method} failed",
            code=str(body.get("error") or "API"),
        )
    return body


def paginate_users(token: str) -> list[dict]:
    members: list[dict] = []
    cursor = ""
    while True:
        kwargs: dict = {"limit": 200}
        if cursor:
            kwargs["cursor"] = cursor
        data = api(token, "users.list", **kwargs)
        members.extend(data.get("members") or [])
        cursor = (data.get("response_metadata") or {}).get("next_cursor") or ""
        if not cursor:
            return members


def paginate_channels(token: str) -> list[dict]:
    channels: list[dict] = []
    cursor = ""
    while True:
        kwargs: dict = {
            "types": "public_channel,private_channel",
            "limit": 200,
            "exclude_archived": "true",
        }
        if cursor:
            kwargs["cursor"] = cursor
        data = api(token, "conversations.list", **kwargs)
        channels.extend(data.get("channels") or [])
        cursor = (data.get("response_metadata") or {}).get("next_cursor") or ""
        if not cursor:
            return channels


def norm(value: str) -> str:
    return value.strip().lstrip("#@").lower()


def resolve_channel(token: str, name_or_id: str) -> str:
    raw = name_or_id.strip()
    if raw.startswith("C") and raw[1:].isalnum() and len(raw) >= 9:
        return raw
    want = norm(raw)
    for ch in paginate_channels(token):
        if norm(ch.get("name") or "") == want:
            return ch["id"]
    raise SlackError(f"channel not found: {name_or_id}", code="CHANNEL_NOT_FOUND")


def resolve_user(token: str, name_or_id: str) -> str:
    raw = name_or_id.strip()
    if raw.startswith("U") and raw[1:].isalnum() and len(raw) >= 9:
        return raw
    want = norm(raw)
    for member in paginate_users(token):
        if member.get("deleted") or member.get("is_bot"):
            continue
        profile = member.get("profile") or {}
        candidates = [
            member.get("id") or "",
            member.get("name") or "",
            member.get("real_name") or "",
            profile.get("display_name") or "",
            profile.get("real_name") or "",
        ]
        if any(norm(c) == want for c in candidates if c):
            return member["id"]
        if any(want in norm(c) for c in candidates if c):
            return member["id"]
    raise SlackError(f"user not found: {name_or_id}", code="USER_NOT_FOUND")


def resolve_user_exact(token: str, name_or_id: str) -> str:
    """DM targets: exact id / @me / handle / real name / display name. No substring guesses."""
    raw = name_or_id.strip()
    if raw == "@me":
        return api(token, "auth.test")["user_id"]
    if raw.startswith("U") and raw[1:].isalnum() and len(raw) >= 9:
        return raw
    want = norm(raw)
    matches = []
    for member in paginate_users(token):
        if member.get("deleted") or member.get("is_bot"):
            continue
        profile = member.get("profile") or {}
        candidates = [
            member.get("name") or "",
            member.get("real_name") or "",
            profile.get("display_name") or "",
            profile.get("real_name") or "",
        ]
        if any(norm(c) == want for c in candidates if c):
            matches.append(member["id"])
    if len(matches) == 1:
        return matches[0]
    if not matches:
        raise SlackError(f"user not found (exact match): {name_or_id}", code="USER_NOT_FOUND")
    raise SlackError(f"ambiguous user {name_or_id}: {', '.join(matches)}", code="USER_AMBIGUOUS")


def cmd_dm(args: argparse.Namespace) -> int:
    token = load_token()
    user_id = resolve_user_exact(token, args.to)
    if args.dry_run:
        print(f"dry-run: would DM {user_id}: {args.text}")
        return 0
    channel = api(token, "conversations.open", {"users": user_id})["channel"]["id"]
    out = api(token, "chat.postMessage", {"channel": channel, "text": args.text})
    print(permalink(channel, out["ts"]))
    print(f"ts={out['ts']}")
    print(f"channel={channel}")
    print(f"user={user_id}")
    return 0


def permalink(channel: str, ts: str) -> str:
    return f"https://trygenius.slack.com/archives/{channel}/p{ts.replace('.', '')}"


def cmd_post(args: argparse.Namespace) -> int:
    token = load_token()
    channel = resolve_channel(token, args.channel)
    text = args.text
    mentions = args.mention or []
    if mentions:
        tags = " ".join(f"<@{resolve_user(token, m)}>" for m in mentions)
        text = f"{tags} {text}".strip()
    payload: dict = {"channel": channel, "text": text}
    if args.thread_ts:
        payload["thread_ts"] = args.thread_ts
    out = api(token, "chat.postMessage", payload)
    ts = out["ts"]
    print(permalink(channel, ts))
    if args.thread_ts:
        print(f"thread_ts={args.thread_ts}")
    print(f"ts={ts}")
    print(f"channel={channel}")
    return 0


def cmd_list_channels(args: argparse.Namespace) -> int:
    token = load_token()
    for ch in paginate_channels(token):
        flag = "private" if ch.get("is_private") else "public"
        print(f"{ch['id']}\t#{ch.get('name')}\t{flag}")
    return 0


def cmd_list_users(args: argparse.Namespace) -> int:
    token = load_token()
    for member in paginate_users(token):
        if member.get("deleted") or member.get("is_bot"):
            continue
        profile = member.get("profile") or {}
        display = profile.get("display_name") or member.get("real_name") or ""
        print(f"{member['id']}\t{member.get('name')}\t{display}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="cmd", required=True)

    post = sub.add_parser("post", help="Post a channel message")
    post.add_argument("--channel", required=True, help="Name (#prworld) or id (C…)")
    post.add_argument("--text", required=True)
    post.add_argument(
        "--mention",
        action="append",
        default=[],
        help="User name or id to ping (repeatable). Prepended as <@U…>.",
    )
    post.add_argument("--thread-ts", default="", help="Reply in this thread")
    post.set_defaults(func=cmd_post)

    dm = sub.add_parser("dm", help="Direct-message one person (or @me)")
    dm.add_argument("--to", required=True, help="@me, U… id, or exact handle / real name / display name")
    dm.add_argument("--text", required=True)
    dm.add_argument("--dry-run", action="store_true", help="Resolve the target, send nothing")
    dm.set_defaults(func=cmd_dm)

    chans = sub.add_parser("channels", help="List channels")
    chans.set_defaults(func=cmd_list_channels)

    users = sub.add_parser("users", help="List users")
    users.set_defaults(func=cmd_list_users)

    args = parser.parse_args()
    try:
        return args.func(args)
    except SlackError as exc:
        print(f"{exc.code}: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
