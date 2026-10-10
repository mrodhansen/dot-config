---
name: askpass
description: GUI password/passphrase prompt so sudo, ssh, ssh-add, git, and similar never take a secret through chat. Use when a command needs a sudo password, SSH identity passphrase, git credentials, or any secret and there is no TTY. Load this skill instead of asking the user to type a password in the conversation. Not a slash command.
---

# askpass — GUI secret prompt

**Skill only** (no `/askpass` command). Pops a system dialog. The secret goes to `sudo` / `ssh` / `git` over a pipe. It must never appear in chat, tool output, logs, or commit messages.

Script:

```bash
~/.ai/skills/askpass/scripts/askpass
```

## When to use

Any time a command would block on a password and the agent has no TTY: `sudo`, `ssh`, `ssh-add`, `scp`, `rsync`, `git fetch` / `push` / `pull` over SSH, HTTPS git credentials.

Do **not** ask the user to paste a password into the conversation. Do **not** use `sudo -S` with a password you collected. Load this skill and wrap the command.

## Fast path

```bash
# sudo (uses SUDO_ASKPASS + sudo -A)
~/.ai/skills/askpass/scripts/askpass sudo pacman -Syu
~/.ai/skills/askpass/scripts/askpass sudo -- install -d /opt/foo

# ssh / git / ssh-add (SSH_ASKPASS_REQUIRE=force)
~/.ai/skills/askpass/scripts/askpass ssh mmini
~/.ai/skills/askpass/scripts/askpass git push
~/.ai/skills/askpass/scripts/askpass ssh-add ~/.ssh/id_ed25519
~/.ai/skills/askpass/scripts/askpass with rsync -a ./ mmini:~/src/

# secret as a child env var (not printed)
~/.ai/skills/askpass/scripts/askpass env PGPASSWORD --prompt "Postgres password" -- psql -h localhost -U me

# secret on the child's stdin only
~/.ai/skills/askpass/scripts/askpass stdin --prompt "sudo password" -- sudo -S whoami
```

The wrapper blocks until the dialog is confirmed or cancelled. Tell the user a password dialog is on screen.

## Rules

1. **Never capture the secret.** Do not run bare `askpass "prompt"`. Do not `password=$(askpass …)`. Do not `sudo -S` / `sshpass` with a value you read. Protocol mode prints the password on stdout for `sudo`/`ssh` only.
2. **Never print it.** Not in chat, not in a file, not in `set -x` traces.
3. **Prefer wrappers.** `askpass sudo …` and `askpass with …` / `askpass ssh|git|ssh-add …`. Those exec the real command; you only see that command's output.
4. **Prompt must say what is being unlocked** (host, key path, package). The GUI title is `Agent password`; ssh/sudo pass their own prompt through.
5. **Cancel / empty is failure.** stderr `askpass: CANCELLED` or `askpass: EMPTY`. Stop. Do not retry in a loop. Do not fall back to asking in chat.
6. **Don't.** Don't create `commands/askpass.md`. Don't enable passwordless sudo from this skill. Don't store the secret in Keychain unless the user asked.

## Fail hard

| stderr | Action |
|--------|--------|
| `CANCELLED` | User dismissed the dialog. Stop and say so. |
| `EMPTY` | Nothing entered. Stop. |
| `NO_GUI` | Linux missing zenity/kdialog. Stop; do not invent a TTY prompt. |
| `usage:` / exit 2 | Wrong invocation. Fix args; do not run protocol mode. |
