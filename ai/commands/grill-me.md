---
description: Relentless interview that sharpens a plan until every design-tree branch is resolved. Use when user says "/grill-me", "grill me", or "stress-test this plan".
---

# /grill-me

Interview the user relentlessly until you reach a shared understanding. Map this as a **design tree**: every decision branches into the decisions that hang off it.

Topic: `$ARGUMENTS` (or the current conversation if arguments are empty). Do **not** implement, spec, or ticket anything until the user confirms shared understanding.

## Rounds and the frontier

Work the tree in **rounds**. The **frontier** is every decision whose prerequisites are already settled: the questions you can ask *now* without guessing at answers you have not heard yet.

Ask the **whole frontier** in one round. Number each question and give your recommended answer. Then **wait** for the user's answers before the next round.

A question whose answer depends on another question still open in this round belongs to a *later* round, not this one.

Each round the user answers reshapes the tree: settled decisions push the frontier outward and unblock questions that depended on them. Recompute the frontier and ask the next round.

## Round format

Use this markdown in the conversation. Do **not** use the structured Question tool — design questions need paragraphs and a recommended answer.

```
❓ **Q1** - **<question title>**: <question body, might be multiple paragraphs, including multiple choices>

➡️ <your recommended answer>

---

❓ **Q2** - **<question title>**: <question body, might be multiple paragraphs, including multiple choices>

➡️ <your recommended answer>
```

## Facts vs decisions

Finding **facts** is your job, never the user's. When a frontier question needs a fact from the environment (filesystem, git, code, docs), dispatch a sub-agent to find it; don't ask the user for anything you could look up yourself. Don't block on it: a running exploration is an unsettled prerequisite, so only the questions downstream of it wait for the sub-agent to report; ask the rest of the frontier now.

The **decisions** are the user's: put each to them and wait.

## Done

The session is done when the frontier is empty: every branch of the design tree visited, nothing left silently assumed.

Then:

1. Restate the settled tree in a short recap (decisions + rejected alternatives).
2. Wait for the user to confirm shared understanding.
3. Do **not** act on it until they confirm. After confirm, stop unless they ask to implement (`/peer-review`, `/implement-as-stack`, `/pr`, etc.).

User arguments: $ARGUMENTS
