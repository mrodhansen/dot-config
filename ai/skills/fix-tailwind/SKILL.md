---
name: fix-tailwind
description: Normalizes all Tailwind classes in a PR's touched .tsx/.jsx files to use ONLY values defined in the project's tailwind.config (colors, spacing, fontSize, fontFamily, borderRadius, etc.). Replaces arbitrary values (e.g. `text-[#abc123]`, `p-[13px]`, `bg-[rgb(...)]`), off-scale tokens (e.g. `text-blue-50`, `bg-gray-700`), and any class that doesn't resolve to a config value with the closest available default. Also collapses raw hex/rgb to the nearest configured palette entry. Always creates a code-only git worktree first (same as /worktree-quick; yarn install is mandatory) so /fix-tailwind 1234 does not need a prior /worktree-quick. Use when user says "/fix-tailwind", "/fix-tailwind <PR#>", "fix tailwind in this PR", "normalize tailwind classes", or "snap tailwind to config".
---

# /fix-tailwind — Snap Tailwind classes in a PR to config defaults

Goal: make every Tailwind class in changed `.tsx` / `.jsx` / `.ts` / `.js` frontend files resolve against the project's `tailwind.config.{js,ts}`. Anything arbitrary, off-scale, or undefined is rewritten to the **closest matching config value**. Nothing else in the file is touched.

**Usage:**
- `/fix-tailwind` — operate on the current branch's diff vs. `origin/main`.
- `/fix-tailwind <PR-number>` — check out the PR locally (or read its diff via `gh pr diff`) and operate on that PR's touched files.
- `/fix-tailwind <PR-url>` — same, parsed from URL.

`/fix-tailwind 1234` is enough — this skill creates the code-only worktree itself. Do **not** require a prior `/worktree-quick`. **Yarn install is mandatory** on every worktree (create, reuse, already-isolated).

---

## Core Rules

1. **Eliminate arbitrary values.** Any utility containing `[...]` (e.g. `text-[#abc123]`, `p-[13px]`, `bg-[rgb(0,0,0)]`, `w-[42%]`, `gap-[7px]`) **must** be replaced with the closest matching config token. This is a **hard rule**, not a preference. The only exception is when no analog exists *at all* in the relevant scale (e.g. a one-off `grid-cols-[1fr_auto_2fr]` template, a custom `clip-path-[...]`, an `animate-[...]` with no named keyframe). In those rare cases, leave the class and list it in the report under "Skipped — no config analog".
2. **Config is the source of truth.** Read `tailwind.config.{js,ts,cjs,mjs}` (and any imported theme files / CSS-variable definitions it depends on). Build the allowed-value table from `theme` + `theme.extend` (plus Tailwind's built-in defaults for any property not fully overridden).
3. **Only edit changed files.** Use `git diff --name-only` against the base. Filter to `.tsx`, `.jsx`, `.ts`, `.js` — and only those that actually contain JSX or `className=` / `class=` / `clsx(` / `cn(` / `cva(` / `tw\`...\`` usages.
4. **Only edit class strings.** Never modify TS logic, imports, props, types, or non-class string literals. Class extraction must be precise (see Phase 3).
5. **Closest match, not "creative" match.** If a value has no exact config equivalent, pick the **numerically/perceptually closest** entry from the same property family. Don't guess intent. Don't pick a semantic token unless the original was semantic.
6. **Off-scale named tokens are also rewrites.** `bg-gray-100` (no `gray` in palette), `text-blue-50`, `bg-blue-900` (outside the 100–800 scale), `rounded-md` (when `md` isn't in the configured radius set) — all get snapped to the closest configured value, same as arbitrary values.
7. **Never invent new classes.** Substitution only. If no reasonable closest match exists in the relevant scale, leave the class alone and report it.
8. **Never strip `dark:`, `hover:`, `md:`, `[&>...]`, group/peer, or other variant prefixes.** Variants are preserved verbatim; only the trailing utility token is rewritten. Note: `[&>...]` and `data-[state=open]:` are *variant brackets*, not arbitrary *values* — they are NOT subject to rule 1.
9. **Never reorder, dedupe, or "tidy" classes** beyond the substitutions required. Whitespace and class order must match input.
10. **Idempotent.** Running twice produces no further changes.
11. **Do not run formatters or linters** (no `prettier`, no `eslint --fix`). Edits are minimal and surgical.

---

## Execution Flow

```
0. Code-only worktree       -> /worktree-quick script + yarn + session_move (always)
1. Resolve target           -> current branch OR PR# OR PR URL
2. Get changed files        -> git diff --name-only (filtered)
3. Load tailwind config     -> build allowed-value tables per property family
4. For each file:
     a. Extract class strings (className=, clsx, cn, cva, tw``)
     b. Tokenize each string into utilities (preserving variants)
     c. For each utility: classify family, check against config, replace if needed
     d. Reassemble + Edit the file (only if changes were made)
5. Report                   -> per-file before/after table + summary
```

---

## Phase 0: Code-only worktree (always, before any work)

Work **never** runs in the primary checkout. Isolate first with the same script as `/worktree-quick`, then continue in that worktree. **Do not** wait for `/worktree-quick`. **Do not** use `/monorepo-worktree`. **Do not** stop after create.

**Yarn is mandatory on every worktree.** Create, reuse, and already-isolated all require `yarn install` in the worktree with exit 0 (10 min timeout). Never skip because `node_modules` exists. Never skip on reuse. If the create script already ran yarn in this turn and you watched it exit 0, that create counts; reuse / already-isolated **must still yarn**.

User arguments: `$ARGUMENTS`

### Parse target

PR numbers / `#N` / `pr N` / GitHub `.../pull/N` / git refs are worktree targets.

| TARGET | Action |
|--------|--------|
| PR / URL | `~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh <n-or-url>` |
| Branch / ref | `…/quick-worktree.sh <ref>` |
| Empty | `gh pr view --json number -q .number`. If that fails and cwd is already `*-quick-*`, skip create. Else if current branch is not `main`/`master`, worktree that branch. Else ask for a PR number. |

Remember `PR_NUMBER`. Later `gh pr view` must use `gh pr view ${PR_NUMBER}`.

### Create or reuse

Do **not** hand-roll `git worktree add`. Skip create only if cwd is already a matching `*-quick-*` worktree. If path already exists: **reuse**. If reusing and **clean**, fetch+reset to latest. If **dirty**, do not `reset --hard`.

### Yarn (always)

```bash
(cd "<path>" && yarn install)
```

Reuse / already-isolated: **always** run this. Wait for exit 0.

### Move the session, then work

OpenCode: `tools.opencode.session_move` with `directory` = absolute worktree path. Continue this session. Then **immediately** continue. Do **not** destroy the worktree when finished.

---

## Phase 1: Resolve Target

```bash
# No arg → current branch diff vs base
git branch --show-current
BASE=$(git remote show origin | grep 'HEAD branch' | awk '{print $NF}')
git merge-base HEAD origin/$BASE
```

If a PR number/URL was given:
```bash
# Get PR head SHA + base, fetch, build a diff range
gh pr view <PR> --json headRefName,baseRefName,headRepository,number
gh pr diff <PR> --name-only        # quick file list
gh pr checkout <PR>                 # only if user wants edits committed locally
```
If the user only wants a *report* (no edits) for a remote PR, use `gh pr diff <PR>` and operate on the diff content rather than checked-out files. Default: edit locally only if the PR is already checked out; otherwise prompt.

---

## Phase 2: Collect Changed Files

```bash
git diff --name-only $(git merge-base HEAD origin/$BASE)..HEAD \
  | grep -E '\.(tsx|jsx|ts|js)$' \
  | grep -vE '(\.test\.|\.spec\.|\.stories\.|/node_modules/|/dist/|/build/)'
```

For each candidate, quickly check it actually contains class strings (`grep -lE 'className=|class=|clsx\(|cn\(|cva\(|tw\`'`). Skip pure-logic files.

If a repo has **multiple `tailwind.config`** files (monorepo with multiple apps), pick the config whose `content` glob matches the file being edited. If no config matches, skip the file and note it.

---

## Phase 3: Load the Tailwind Config

Read `tailwind.config.{js,ts,cjs,mjs}` for the relevant app. Resolve everything statically — do not execute it. Specifically extract:

| Family | Where to look | Build set of |
|---|---|---|
| Colors | `theme.colors`, `theme.extend.colors` | `{<color>-<shade>}` keys, including `DEFAULT`, plus semantic tokens (`primary`, `muted`, etc.). Resolve hex values for distance comparisons. CSS-variable-backed colors (`hsl(var(--x))`) are kept as opaque tokens — match them by name only. |
| Spacing | `theme.spacing`, `theme.extend.spacing` (fallback to Tailwind defaults if absent) | px/rem values per key |
| Font size | `theme.fontSize`, `theme.extend.fontSize` | sizes per key |
| Font family | `theme.fontFamily`, `theme.extend.fontFamily` | family names |
| Border radius | `theme.borderRadius`, `theme.extend.borderRadius` | sizes per key |
| Border width | `theme.borderWidth`, `theme.extend.borderWidth` | widths per key |
| Box shadow | `theme.boxShadow`, `theme.extend.boxShadow` | named shadows |
| Z-index | `theme.zIndex`, `theme.extend.zIndex` | numeric/name keys |
| Opacity | `theme.opacity`, `theme.extend.opacity` | percent keys |
| Line height | `theme.lineHeight`, `theme.extend.lineHeight` | sizes per key |
| Letter spacing | `theme.letterSpacing`, `theme.extend.letterSpacing` | sizes per key |
| Animations | `theme.animation`, `theme.extend.animation` | names |
| Keyframes | `theme.keyframes`, `theme.extend.keyframes` | names |

If a property is **not extended**, fall back to Tailwind's built-in defaults for that property (the project still allows them). Treat the union of `defaults ∪ extend` as "allowed".

If a property is **fully overridden** (declared in `theme.<prop>` not `theme.extend.<prop>`), only the override values are allowed.

> Important for this monorepo's convention: scales typically run `100…800`. So `bg-blue-50`, `bg-blue-900`, `bg-gray-*` (no `gray` in config) are all **off-scale** and must be remapped.

---

## Phase 4: Tokenize and Rewrite

For each extracted class string:

### 4.1 Split utilities
Split on whitespace. For each utility, peel off variant prefixes (everything before the final `:`, supporting arbitrary variants like `[&>div]:`, `data-[state=open]:`, `dark:`, `md:`, `group-hover:`, etc.). Keep prefixes verbatim. Rewrite only the trailing utility token.

Also handle:
- `!` important prefix (`!text-red-500`) → preserve.
- `-` negative prefix (`-mt-4`) → preserve.

### 4.2 Classify the utility
Match against known Tailwind property prefixes to determine the family:

| Prefix examples | Family |
|---|---|
| `text-`, `bg-`, `border-`, `ring-`, `from-`, `via-`, `to-`, `fill-`, `stroke-`, `placeholder-`, `accent-`, `caret-`, `divide-`, `outline-`, `decoration-`, `shadow-` (color form) | color |
| `p-`, `px-`, `py-`, `pt-`, `pr-`, `pb-`, `pl-`, `m-`, `mx-`, `my-`, `mt-`, `mr-`, `mb-`, `ml-`, `gap-`, `gap-x-`, `gap-y-`, `space-x-`, `space-y-`, `inset-`, `top-`, `right-`, `bottom-`, `left-`, `w-`, `h-`, `min-w-`, `min-h-`, `max-w-`, `max-h-`, `size-`, `translate-x-`, `translate-y-` | spacing |
| `text-` (with size keys: xs/sm/base/lg/xl/…/9xl, or arbitrary) | fontSize |
| `font-` (sans/serif/mono/custom names) | fontFamily |
| `font-` (thin/normal/bold/…/numeric) | fontWeight (Tailwind defaults; rarely extended) |
| `rounded-`, `rounded-{side}-` | borderRadius |
| `border-`, `border-{side}-` (numeric) | borderWidth |
| `shadow-` (non-color) | boxShadow |
| `z-` | zIndex |
| `opacity-`, `bg-opacity-`, `text-opacity-`, etc. | opacity |
| `leading-` | lineHeight |
| `tracking-` | letterSpacing |
| `animate-` | animation |

⚠️ `text-*` is ambiguous (color or fontSize or alignment). Disambiguate by checking what the suffix matches in the config. `text-center` is alignment (always allowed). `text-blue-500` is color. `text-sm` is size. `text-[14px]` is fontSize arbitrary. `text-[#abc]` is color arbitrary.

### 4.3 Decide if rewrite needed

A utility is **already valid** if:
- It's not parameterized (e.g. `flex`, `grid`, `block`, alignment, display, layout, etc.) — leave alone.
- Its suffix exactly matches a configured key in its property family AND does not use `[…]` arbitrary syntax.

A utility **needs rewrite** if (any of):
- It uses arbitrary `[…]` syntax of any kind: `[#hex]`, `[rgb(...)]`, `[hsl(...)]`, `[var(--…)]`, `[Npx]`, `[Nrem]`, `[N%]`, `[Nch]`, `[calc(...)]`, etc. Per Rule 1, this is a hard requirement — find the closest config token. Only skip if no analog exists in the entire scale.
- Its arbitrary value is even *exactly* equal to a configured token (e.g. `text-[#0968F6]` when `blue.500 = #0968F6` — still rewrite to `text-blue-500` for consistency; eliminating brackets is the goal).
- Its suffix uses a key not in config: `bg-gray-100` (no `gray` in palette), `text-blue-50` / `text-blue-900` (outside 100–800 scale), `rounded-md` when not in configured radius set, etc.

**Decision tree for any utility containing `[`:**
```
contains [...] arbitrary value?
├── YES → must rewrite
│   ├── closest config match exists in this family? → rewrite to it
│   └── no analog at all? → leave + add to "Skipped — no config analog" report
└── NO → check named-token validity (off-scale handling above)
```

### 4.4 Pick the closest config value

**Colors**:
1. Resolve the input to a concrete color (parse hex/rgb/hsl; for `text-blue-50` etc., resolve against Tailwind's built-in palette so we know what hex it would produce).
2. Convert to Lab and pick the configured color with smallest ΔE (CIE76 is fine).
3. Tie-break by family name match (if input was `blue-*`, prefer a `blue-*` config entry over equally-close non-blue).
4. Never substitute a semantic token (`primary`, `muted`, etc.) unless the input was *also* semantic and is now missing — semantic intent must come from the developer.
5. If the closest match is a CSS-variable-backed token (e.g. `neutral-*`), allow it only when the input was also neutral / gray.

**Spacing / sizes (px/rem)**:
1. Convert input and all config values to px (1rem = 16px unless `theme.fontSize.base` says otherwise).
2. Pick the entry with smallest absolute px delta.
3. Tie-break: prefer the smaller value (avoid silently inflating layout).

**Font size**:
1. Same as spacing, but only against the fontSize scale (including custom keys like `xxs: 10px`, `tiny: 13px`).

**Border radius / border width / line height / letter spacing / opacity / z-index**:
1. Numeric closest match; for named-only scales (e.g. `shadow-sm/md/lg`), if input is arbitrary, pick by closest blur radius / numeric magnitude inferred from the config's resolved value.

**Animations / keyframes / fontFamily**:
1. No "closest" — exact match only. If no match, **leave the class alone** and add a note to the report. Don't guess.

### 4.5 Construct the replacement
Rebuild the utility as `<variants>:<new-suffix>`, preserving `!` and `-` prefixes. Reassemble the full class string with the original whitespace.

If the rebuilt token is identical to the original, no edit.

---

## Phase 5: Apply Edits

For each file with at least one substitution:
1. Use the `Edit` tool with `replace_all: true` only when the old class string appears multiple times **and** the substitution is identical for all occurrences. Otherwise edit each occurrence with enough surrounding context to make it unique.
2. Never use `Write` to rewrite the whole file — too risky.
3. After all edits in a file, re-read the file and verify the changed regions parse as before (nothing other than class strings was touched).

If a file uses dynamic class construction (template literals with `${...}` interpolation, `clsx({ [computed]: ... })`), only rewrite the **static segments** of class strings. Skip interpolated sections — don't touch them.

---

## Phase 6: Report

Output a single markdown table per file:

```
### apps/web-crm/src/.../foo.tsx

| Line | Before | After | Reason |
|------|--------|-------|--------|
| 42 | text-[#0968F6] | text-blue-500 | exact hex match in config |
| 58 | bg-gray-100 | bg-neutral-100 | gray not in palette; closest neutral |
| 73 | p-[13px] | p-3 | 13px → 12px (closest spacing, Δ1px) |
| 91 | text-blue-50 | text-blue-100 | 50 not in scale (100–800) |
| 104 | rounded-md | rounded-default | md not in config; default=0.6125rem closest |
```

Followed by a summary:

```
## Summary
- Files scanned: N
- Files modified: M
- Total substitutions: K
- Skipped (no closest match): J
  - <list any unresolved utilities>
- Off-scale colors collapsed: …
- Arbitrary values normalized: …
```

If `--dry-run` was passed (or user said "preview" / "don't apply"), produce the report only — no Edits.

---

## Important Edge Cases

- **`className={cn(...)}` / `clsx(...)`**: walk every string-literal argument; the rules above apply to each. Object-key forms (`{ 'text-red-500': cond }`) — rewrite the key string.
- **`cva(...)` variants**: rewrite class strings inside the `variants`/`compoundVariants`/`defaultVariants` objects.
- **Tagged templates** (`tw\`...\``, `styled\`...\``): treat the entire template literal as a class string; tokenize and rewrite static segments only.
- **JSX spread** (`{...props}`): no className visible; ignore.
- **Inline styles** (`style={{ color: '#abc' }}`): out of scope. This skill only touches Tailwind class strings.
- **Custom CSS files / `.css` / `.scss`**: out of scope.
- **`@apply` directives** in CSS: out of scope (would need a separate pass against `.css` files; not part of this skill).
- **Variants on arbitrary values** (`md:bg-[#abc]`): preserve `md:`, rewrite the suffix.
- **Multiple semantic tokens for same color**: never pick `primary` over `blue-500` automatically — semantic intent is human.
- **Empty / pass-through classes**: `className=""` or `className={undefined}` → no-op.

---

## Safety Rails

| Situation | Action |
|---|---|
| Tailwind config missing or unparseable | Stop. Report which config was sought and where it's expected. |
| File has merge conflict markers | Skip file. Report. |
| File would change > 50 utilities | Show the user the proposed diff first, ask before applying. |
| Multiple tailwind configs and no `content` glob matches the file | Skip file. Report. |
| Animation/keyframe/fontFamily with no exact match | Leave alone. Report under "Skipped". |
| User passes `--dry-run` or `preview` | Report only. No Edits. |

---

## What This Skill Does NOT Do

- Does not run `prettier`, `eslint`, or any formatter.
- Does not commit or push. Edits are left in the working tree for the user to review.
- Does not touch `.css` / `.scss` / `.module.css` files or `@apply` rules.
- Does not refactor layout, swap components, or change non-class code.
- Does not pick semantic tokens (`primary`, `muted`, `accent`, etc.) when the input was a hue token — that's a design decision, not a normalization.
- Does not add new utility classes that weren't there. Substitution only.

---

## Quick Reference: Common Substitutions in This Repo

(Built from `apps/web-crm/tailwind.config.js` — color scales run **100–800**, neutral runs **100–900**.)

| Off-config | Likely fix |
|---|---|
| `text-blue-50` | `text-blue-100` |
| `bg-blue-900` | `bg-blue-800` |
| `text-gray-*` | `text-neutral-*` (closest shade) |
| `bg-slate-*` / `bg-zinc-*` / `bg-stone-*` | `bg-neutral-*` (closest shade) |
| `text-[#0968F6]` | `text-blue-500` |
| `rounded-md` | If `md` not in config, use `rounded-default` or closest configured radius |
| `text-[10px]` | `text-xxs` |
| `text-[13px]` | `text-tiny` |
| `font-DM_Sans` / `font-['DM_Sans']` | `font-sans` |

These are illustrative — always re-derive from the actual config at run time, not from this table.

**Always isolate in a code-only worktree first** (Phase 0). **Yarn install is mandatory** on every worktree (create, reuse, already-isolated). Never skip yarn because `node_modules` exists.

User arguments: $ARGUMENTS
