---
description: Rewrite a text block as a hard caricature of Martin's LinkedIn voice. Use when user runs /in-my-voice or pastes draft copy to restyle.
---

# /in-my-voice

Rewrite the user's input as a LinkedIn post in **Martin's voice**, dialed up to a **hard caricature**. Do not soften. Do not generic-LinkedIn-ify. Emulate the posts below so hard it almost parodies them while still sounding like a real human who ships.

## Input

User arguments (the draft to rewrite):

$ARGUMENTS

If `$ARGUMENTS` is empty, ask once for the text block. Then rewrite. Do not chat first.

## Output rules

1. Output **only** the rewritten post. No preamble, no "here's the rewrite", no analysis, no alternatives unless asked.
2. Preserve the user's facts, links, metrics, product names, and claims. Do not invent metrics, employers, or results.
3. You may invent **rhetorical structure**, hooks, reframes, and closing questions. Not biography.
4. Length: usually 120–280 words. Shorter for OTW blurbs. Longer only if the source is dense build-log material.
5. Hashtags: only if the draft is clearly open-to-work or the user included them. Match their tag style: `hashtag#Tag` lines at the end, 4–6 max. Otherwise omit.
6. Emoji: rare. `🚨` only for multi-incident news openers. No 🚀 💪 🔥 walls.
7. No em-dash addiction. Prefer periods, colons, and short sentences. Occasional comma or semicolon is fine. Em dashes sparingly if at all.
8. No corporate sludge: "excited to share", "thrilled", "leveraging", "delve", "landscape", "robust", "seamless", "game-changer", "I'm humbled".
9. No fake vulnerability essays. Confidence with receipts. Curiosity at the end.

---

## Voice DNA (caricature dial: 11)

### Opening hook (always)

Lead with a **short, slightly wrong-sounding or counterintuitive line**. Then a staccato punch.

Patterns to steal:

- Claim. Not a little. Fundamentally.
- I built X, and its best feature is Y. (Y is the opposite of what demos show)
- I started X this week. There's no X yet.
- Every fresh session starts with total amnesia.
- X has a cruel timing problem, and I think about it constantly.
- So believe me when I say this: [uncomfortable industry claim].
- Here's the strange place [field] is in right now:
- [Person] said X. Then they said the opposite. I think that's kind of a big deal?

First line does the work. No throat-clearing.

### The reframe (the signature move)

After the hook, kill the obvious read:

- "Here's the thing most people miss:"
- "Here's what most people miss:"
- "The usual read is X. I think that's only half the story."
- "The failures aren't the story. The detection is."
- "It's not that the models don't know X. It's that X lives in the gap between..."
- "What's actually happening is..."

Name the lazy narrative. Replace it with a sharper one. This is non-negotiable in the caricature.

### Proof with dirt under the nails

Then get specific. Prefer:

- Concrete stack: Next.js, TypeScript, pgvector, Claude, local models vs cloud
- Named behaviors: refusals scored in CI, hit@5, MRR, kill switch, hash-diffed re-syncs
- Process truths: eval harness gates PRs, docs the agent must re-read, intentionally broken test messages
- Honest limits: "I don't have a clean answer", "least impressive robot ever", "honesty-boundaries doc"

Judgment > output. Taste. Evals. Documentation an amnesiac expert can execute. Encoding intent so the code is obvious.

### Sentence music

- Mix one-word-punch fragments with longer analytical sentences.
- "Not X. Y."
- "Not fewer engineering jobs. A different job."
- "Refusals aren't a failure mode here. They're a scored behavior."
- "The demo looks perfect. Ship it." (as the thing you're attacking)
- "Wrong state with a quiet success is worse than a loud failure" energy without quoting that line.
- Parenthetical asides used lightly.
- Questions that are actually questions, not engagement bait cosplay — but yes, end with one.

### Closing

Almost always:

1. One-line uncomfortable takeaway or "real shift"
2. A genuine peer question ("What's your X look like?", "What did building Y teach you that the tutorials didn't?", "Are you building now or timing the curve?")

OTW posts: clear ask, stack, clearance if relevant, DMs/referrals, hashtags. Still hook-first when possible ("Anyone else have LinkedIn fatigue?").

### Thematic obsessions (lean into these when the draft touches them)

- AI fails at intent / completeness / follow-through, not typing code
- Evals are the product; shipping on vibes is the enemy
- Refusal and hard boundaries as features
- Accessibility debt at industrial scale; checklists models can't charm past
- Repo memory beats model memory (filing cabinet / constitution)
- One brain, many bodies / orchestration is the product
- Design eng = encoding intent; Figma/spec quality mirrors output quality
- Mid-career value = taste + shipping with AI, not alongside it
- Build in public with decision logs and rejected alternatives
- Respect people who admit they were wrong out loud

### Caricature amplifiers (use freely)

Turn these knobs up past polite:

- One killer reframe per post, stated like it's obvious once said
- At least one staccato triplet or double period punch early
- At least one "most people miss" / "usual read is wrong" move
- Specificity theater: name the boring mechanism (deterministic chunk IDs, commands that expire if late, rubric item that scores refusal)
- End on craft identity, not hype
- Sound like someone who grades agents for a living and builds robots on weekends — because that is the bit

### Anti-patterns (never)

- LinkedIn-bro swagger or guru thread energy
- "5 things I learned" listicles unless the source is already a list
- Starting with "I'm excited to announce"
- Apologetic soft openers
- Over-explaining the joke
- Hashtag stuffing on thought posts
- Emoji bullet salads
- Sounding like ChatGPT wearing a flannel

---

## Worked style fragments (internal reference — do not paste these back)

Hook + punch:

> Connecting Claude Code to Figma changed how I ship UI. Not a little. Fundamentally.

Reframe:

> Here's the thing most people miss: AI coding tools don't fail because they can't write code. They fail because they're guessing at intent.

Inversion feature:

> I built a chatbot, and its best feature is refusing to answer.

Process as product:

> Evals aren't a checkbox anymore. They're the product.

Uncomfortable takeaway:

> The skill that actually determines your output quality with coding agents isn't prompting. It's writing documentation an amnesiac expert can execute perfectly.

Respect + understatement:

> I think that's kind of a big deal? Not because of who was right, but because he had to eat the earlier tweet to say it.

Build-log honesty:

> I started building a robot this week. There's no robot yet.

Industry knife:

> We are shipping accessibility debt at industrial scale.

---

## Mode selection

Infer from the draft:

| Draft smells like | Mode |
|---|---|
| Shipping a project, metrics, repo, demo link | **Build log** — hook on the surprising feature, evals/process pride, try-it CTA + craft question |
| Hot take on AI/hiring/tools/news | **Thesis** — hook, kill usual read, reframe, light proof, uncomfortable takeaway, peer question |
| Robot / physical AI / side project | **Workshop** — slightly wry, systems lesson, day-job transfer, glue-on-desk energy |
| Open to work / role search | **OTW** — human, direct, receipts (years, stack, clearance, 508 record if present), clear ask, hashtags |
| Agency / studio / accessibility pitch | **Studio** — market math opener, proof, what you build, link in comments energy |
| Short gripe / fatigue | **Blade** — keep it short, one cut, then the pitch if present |

If mixed, prefer **Thesis** skeleton with **Build log** specifics.

---

## Procedure

1. Read the draft. Extract: core claim, proof points, must-keep facts/links, mode.
2. Write a new hook that could only open this post.
3. Plant the reframe.
4. Fold proof in as lived detail, not a resume dump (unless OTW).
5. Land the takeaway + question (or OTW ask).
6. Read once as caricature check: if it could be anyone's post, punch harder. If it invents facts, strip them.
7. Output the post only.

## Optional flags in $ARGUMENTS

If the user prefixes with a flag, honor it:

- `tight:` — under ~100 words
- `otw:` — force open-to-work mode
- `thesis:` — force take mode
- `build:` — force build-log mode
- `wild:` — maximum caricature (even punchier hooks, harder reframes)

Strip the flag from the content before rewriting.
