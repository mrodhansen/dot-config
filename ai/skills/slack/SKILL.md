---
name: slack
description: Post messages to Genius Slack as Martin (slackatui user token). Use when the user says post to Slack, ping someone in Slack, tell #prworld a PR is ready, send a Slack message, or "slack this". Not a slash command — load this skill and run the helper script.
---

# slack — post as Martin

Post to the Genius Slack workspace. **Skill only** (no `/slack` command). Auth is Martin's slackatui user token in macOS Keychain.

Script (never prints tokens):

```bash
~/.ai/skills/slack/scripts/slack-post.py
```

## When to use

User asks to post / ping / tell Slack. Then load this skill and run the script. Do **not** post unless they asked.

## Fast path

```bash
# Channel message
~/.ai/skills/slack/scripts/slack-post.py post \
  --channel prworld \
  --text "https://github.com/Future-Mortgage/monorepo/pull/2133 this is ready again"

# Ping someone, then the text
~/.ai/skills/slack/scripts/slack-post.py post \
  --channel prworld \
  --mention Ben \
  --text "https://github.com/Future-Mortgage/monorepo/pull/2133 this is ready again"

# Thread reply (thread_ts from a prior post)
~/.ai/skills/slack/scripts/slack-post.py post \
  --channel prworld \
  --thread-ts 1789776717.232189 \
  --text "Review comments are done and pushed."

# Direct message one person (exact handle / real name / display name / U… / @me; never a substring guess)
~/.ai/skills/slack/scripts/slack-post.py dm --to "Marcus Henke" \
  --text "https://github.com/Future-Mortgage/monorepo/pull/2133 approved"
~/.ai/skills/slack/scripts/slack-post.py dm --to @me --text "note to self"
~/.ai/skills/slack/scripts/slack-post.py dm --to Ben --text "x" --dry-run   # resolve only

# Resolve names
~/.ai/skills/slack/scripts/slack-post.py channels
~/.ai/skills/slack/scripts/slack-post.py users
```

Stdout on success: permalink, `ts=`, `channel=`. Give the user the permalink.

## Rules

1. **Auth.** Token from `SLACK_USER_TOKEN` / `SLACK_BOT_TOKEN`, else Keychain service `slackatui`. If `AUTH_MISSING`: tell them to run `slackatui auth`. Do not invent tokens. Never print the token or keychain JSON.
2. **Channel.** `--channel prworld` or `#prworld` or `C…`. `#prworld` is where PRs get review pings.
3. **Mentions.** `--mention Ben` (repeatable). Script resolves to `<@U…>` and prepends. Common: Ben (`ben.bengoetxea`, rereview), Marcus (`marcus.henke` / mdhenke), Blake (`blake.bianchi`). Martin's rereview pattern in `#prworld`: ping Ben + PR link + "this is ready again".
4. **Voice.** Short, like Martin's existing `#prworld` messages. Not a changelog. Not "I have completed the requested review items."
5. **Don't.** Don't post from this skill unprompted. Don't create `commands/slack.md`. Don't dump the user/channel list into chat unless you need it to resolve a name.

## Fail hard

| stderr | Action |
|--------|--------|
| `AUTH_MISSING` | Stop. Tell user to `slackatui auth` (or set `SLACK_USER_TOKEN`). |
| `CHANNEL_NOT_FOUND` / `USER_NOT_FOUND` | Run `channels` / `users`, pick the right name, retry once. If still missing, ask. |
| `not_in_channel` / `invalid_auth` | Stop and report the Slack error code. |
