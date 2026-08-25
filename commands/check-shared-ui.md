---
description: Checks frontend diffs for native HTML controls (especially buttons) and shared-component className chrome. Replaces natives with design-system primitives, requires predefined variant/size/shape/appearance, and strips style overrides except positioning (sizing only rarely). Use when user says "/check-shared-ui", "/check-shared-ui <PR#>", "check shared components", "no native buttons", or "shared UI chrome".
---

# /check-shared-ui — Shared primitives, no chrome overrides

Goal: every **changed** frontend file uses design-system primitives instead of native controls, and every shared primitive is styled **only** through its predefined `variant` / `size` / `shape` / `appearance` props. `className` / `style` on those primitives may contain **positioning** and, rarely, **sizing**. Chrome overrides are a hard fail.

**Usage:**
- `/check-shared-ui` — current branch vs `origin/main` (or detected default branch)
- `/check-shared-ui <PR-number>` / `/check-shared-ui <PR-url>` — that PR's touched files
- `/check-shared-ui --dry-run` / `preview` — report only, no edits

User arguments: $ARGUMENTS

---

## Core Rules

1. **No native interactive HTML** when a design-system primitive exists. `<button>`, raw `<input>`, `<textarea>`, `<select>`, naked checkbox/radio, hand-rolled dialog/sheet — replace with the shared component.
2. **Chrome comes from the primitive's predefined styles.** Read the component's `cva` (`variant`, `size`, `shape`, `appearance`, …). Pick the closest existing key. Do **not** invent a look via `className`.
3. **No style overrides on shared primitives.** `className` / `style` / `style={{…}}` must not set color, background, border, shadow, radius, font, opacity-as-chrome, hover/focus/active/disabled chrome, or `!` important.
4. **`className` allowlist is tiny.** Positioning is allowed. Sizing is allowed only when layout truly requires it (`w-full`, `min-w-0`, `flex-1`) — prefer the `size` prop. Padding, gap, and height that fight the size variant are **overrides** — strip them.
5. **`variant="unstyled"` (or equivalent) + restyle is cheating.** Forbidden unless the file **is** the design-system primitive.
6. **Import from the design-system**, not local clones (`components/ui/button`, `Shared/`, `AtomicDesign/`, numbered `dialog2` / `select4`).
7. **Only edit changed frontend files** (plus the import line if a replacement needs it). Do not restyle unrelated files. Do not touch `.css` / `.scss`.
8. **Idempotent.** Running twice produces no further changes.
9. **Do not run formatters.** Surgical edits only. Do not commit.

---

## Canon map (re-read the live files; this table is a start)

Discover primitives from the repo at run time:

- Future Mortgage CRM: `libs/design-system/src/ui/` imported as `@future-mortgage/design-system/src/ui/<name>`
- Call-site rules: `apps/web-crm/src/app/components/AGENTS.md`
- Runtime stripper (safety net, **looser** than this command): `libs/design-system/src/utils/layout-class-name.ts`

| Native / smell | Shared primitive | Style props |
|---|---|---|
| `<button>` | `Button` | `variant`, `size`, `shape` |
| `<input>` (text-like) | `Input` | `appearance`, `inputSize`, `shape` |
| `<textarea>` | `Textarea` | same family as Input |
| `<select>` | `Select` | `appearance` |
| `<input type="checkbox">` | `Checkbox` | size / variant on that file |
| `<input type="radio">` | `RadioGroup` | |
| `<input type="checkbox">` toggle look | `Switch` | `size` |
| hand-rolled modal | `Dialog` / `AlertDialog` / overlays (`ConfirmDialog`, `FormSheet`, `FormModal`) | |
| hand-rolled drawer | `Sheet` | `overlay` |
| ad-hoc pill / status chip | `Badge` | `variant`, `size`, `shape` |
| local `components/ui/*` clone | design-system `ui/` | |

If the repo is **not** this monorepo, find the equivalent shared UI kit (`src/components/ui`, `packages/ui`, etc.) and apply the same rules against **that** kit's `cva` variants.

---

## Execution Flow

```
1. Resolve target           -> branch OR PR# OR PR URL
2. Collect changed files    -> git diff, frontend only
3. Load primitive catalog   -> each ui/*.tsx: export name, cva keys, pickLayoutClassName?
4. Scan + classify          -> native controls, wrong imports, chrome className, rare sizing
5. Fix                      -> replace natives, set variant props, strip chrome className
6. Report                   -> per-file table + summary
```

---

## Phase 1: Resolve Target

```bash
git branch --show-current
BASE=$(git remote show origin | grep 'HEAD branch' | awk '{print $NF}')
git merge-base HEAD origin/$BASE
```

PR number/URL:

```bash
gh pr view <PR> --json headRefName,baseRefName,headRepository,number
gh pr diff <PR> --name-only
```

Edit locally only if the PR is already checked out; otherwise report from `gh pr diff` (or prompt to check out).

---

## Phase 2: Collect Changed Files

```bash
git diff --name-only $(git merge-base HEAD origin/$BASE)..HEAD \
  | grep -E '\.(tsx|jsx)$' \
  | grep -vE '(\.test\.|\.spec\.|\.stories\.|/node_modules/|/dist/|/build/)'
```

Also include unstaged/uncommitted working-tree changes on those paths (`git diff` + `git diff --cached`).

**Skip (do not "fix" primitives to use themselves):**
- `libs/design-system/src/ui/**` (or the repo's primitive directory)
- files that **are** the shared component definition

Still **scan** those primitive files if they changed: they must own chrome via `cva` and run `pickLayoutClassName` / `pickLayoutStyle` on consumer `className`/`style`. Flag primitives that merge raw `className` into chrome.

---

## Phase 3: Load the Primitive Catalog

For each shared UI module:

1. Exported component names (`Button`, `Input`, …)
2. `cva` variant keys and allowed values (`variant: primary | secondary | …`)
3. Default variants
4. Whether `className` is passed through `pickLayoutClassName`

Build a lookup: tag name / typical class smell → primitive + how to pick a variant.

---

## Phase 4: Classify Violations

Walk JSX in each changed file.

### 4.1 Native control (HIGH)

Flag:

```tsx
<button>…</button>
<input>   <!-- not type=hidden / file / csrf / radio+checkbox already mapped -->
<textarea>
<select>
```

**Allowed natives (do not replace):**
- `<input type="hidden">`, file inputs that are visually hidden behind a `Button`/`Label`
- `<input type="file">` when the visible trigger is already a shared `Button`
- SVG / math / canvas internals
- The primitive's own inner DOM (`button.tsx` rendering `<button>` / `Slot`)

`asChild` on `Button` wrapping an `<a>` is fine. A raw `<button>` wrapping an icon is **not**.

### 4.2 Wrong import (HIGH)

```ts
import { Button } from '@/app/components/ui/button';
import { Button } from '../../components/ui/button';
```

Must be the design-system (or this repo's canon path). Also flag `buttonVariants(...)` applied to a native `<button>`.

### 4.3 Chrome override on a shared primitive (HIGH)

On `<Button>`, `<Input>`, `<Textarea>`, `<SelectTrigger>`, `<Checkbox>`, `<Switch>`, `<Badge>`, and any other primitive that documents layout-only `className`:

**Forbidden tokens** (after stripping `sm:` / `md:` / `lg:` / `xl:` / `2xl:` — state variants like `hover:` / `focus:` / `active:` / `disabled:` / `data-[…]` / `aria-[…]` on chrome are also forbidden):

- Color / chrome: `bg-*`, `text-*` (except `text-left|center|right`), `border*`, `ring-*`, `outline-*`, `shadow-*`, `from-*`, `via-*`, `to-*`, `fill-*`, `stroke-*`, `opacity-*`, `backdrop-*`
- Type: `font-*`, `leading-*`, `tracking-*`, `underline`, `italic`
- Shape chrome: `rounded-*`
- Size-as-chrome: `h-*`, `px-*`, `py-*`, `p-*`, `pt-*`, `gap-*` when the primitive has a `size` / `inputSize` prop — use the prop
- `!` important on any of the above
- Inline `style` keys outside the layout set: `color`, `background*`, `border*`, `font*`, `boxShadow`, `opacity`, `borderRadius`, …

**Allowed positioning:**

`static` `relative` `absolute` `fixed` `sticky`  
`top-*` `right-*` `bottom-*` `left-*` `inset-*` `z-*`  
`m-*` `mx-*` `my-*` `mt-*` `mb-*` `ml-*` `mr-*` `ms-*` `me-*`  
`self-*` `justify-self-*` `place-self-*` `order-*`  
`col-span-*` `col-start-*` `row-span-*`  
`translate-*` `transform` (overlay alignment only)

**Rarely allowed sizing** (keep, but list under "Rare sizing" in the report — do not add new ones unless layout is broken without them):

`w-full` `w-auto` `min-w-0` `max-w-*` `flex-1` `flex-none` `grow` `shrink-0`

Any other `w-*` / `h-*` / `size-*` / `min-h-*` on a primitive → strip or map to `size` / `inputSize`. If mapping is unclear, flag and do not guess a one-off pixel size.

### 4.4 Missing / invalid predefined style (MEDIUM)

- Primitive used with no `variant` / `appearance` when the visual is clearly not the default (e.g. a ghost/icon/destructive look implemented via leftover classes)
- `variant="something-not-in-cva"`
- Closest existing variant exists but caller used chrome classes instead

Map leftover chrome to a real key (examples — **always re-read the live `cva`**):

| Smell | Typical Button fix |
|---|---|
| accent / primary fill | `variant="primary"` |
| zinc/dark fill | `variant="secondary"` |
| border + transparent | `variant="outline"` or `glass` |
| no fill, hover wash | `variant="ghost"` |
| red fill | `variant="destructive"` |
| red ghost | `variant="destructive-ghost"` |
| underline text | `variant="link"` |
| icon-only, ~24px | `size="icon-sm"` |
| icon-only, ~40px | `size="icon"` |
| compact toolbar | `size="xs"` or `sm` |
| uppercase tracking | `size="action"` |
| pill | `shape="pill"` |

### 4.5 Primitive definition regression (HIGH, only if those files changed)

Changed files under the shared UI kit must:
- Define chrome in `cva` (or a shared styles helper), not at each call site
- Pipe consumer `className` through `pickLayoutClassName`
- Pipe consumer `style` through `pickLayoutStyle`

Do **not** widen `pickLayoutClassName` to allow chrome so a call site "works".

---

## Phase 5: Apply Fixes

For each HIGH/MEDIUM finding that has a clear fix:

1. **Replace native `<button>`** with `<Button …>` (same `type`, `onClick`, `disabled`, `aria-*`, children). Add the canon import if missing. Remove now-unused imports.
2. **Same for Input / Textarea / Select / Checkbox / Switch / Badge** when the mapping is 1:1.
3. **Set** `variant` / `size` / `shape` / `appearance` from the catalog. Delete the chrome classes those props replace.
4. **Strip** remaining forbidden tokens from `className`. If `className` becomes empty, remove the prop.
5. **Strip** forbidden `style` keys. If empty, remove `style`.
6. **Rewrite** wrong imports to the canon path.

**Do not auto-fix** (report only):
- A control whose closest primitive is unclear (custom segmented control, canvas toolbar, contenteditable)
- A file that would need a **new** design-system variant — propose the variant name + `cva` snippet, do not invent it in the call site
- > 20 replacements in one file — show the plan, ask before applying

Never use `Write` to rewrite a whole file. `Edit` only.

---

## Phase 6: Report

```
### apps/web-crm/src/.../foo.tsx

| Line | Finding | Action |
|------|---------|--------|
| 42 | native `<button>` | → `<Button variant="ghost" size="icon-sm">` |
| 58 | `<Button className="bg-red-500 text-white">` | stripped chrome; `variant="destructive"` |
| 73 | `<Button className="h-12 px-8">` | stripped size override; `size="lg"` |
| 91 | `<Button className="absolute right-2">` | kept (positioning) |
| 104 | `<Button className="w-full">` | kept (rare sizing) |
```

```
## Summary
- Files scanned: N
- Files modified: M
- Natives replaced: B buttons, I inputs, …
- Chrome classNames stripped: K
- Rare sizing left in place: R
- Needs new DS variant (not invented): …
- Skipped / needs human: …
```

`--dry-run` / `preview` → report only.

---

## Safety Rails

| Situation | Action |
|---|---|
| No frontend files in the diff | Stop. Say so. |
| File is the primitive itself | Do not replace inner DOM. Check `cva` + `pickLayoutClassName` only. |
| Merge conflict markers | Skip file. |
| Hidden file input + visible Button | Leave the hidden input. |
| `asChild` + `<a>` / router `Link` | Leave the child element. |
| Unclear mapping / new look | Report + propose a DS variant. Do not chrome-override. |
| User said dry-run / preview | Report only. |

---

## What This Command Does NOT Do

- Does not run `/fix-tailwind` (token snap is a different command). After this pass, remaining layout classes should already be config tokens.
- Does not add new design-system variants unless the user explicitly asks.
- Does not restyle page-level layout wrappers (`div`, `section`, `main`) — only native controls and shared primitive call sites.
- Does not commit or push.
