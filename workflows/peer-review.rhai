// peer-review — plan → implement → specialist review → adversarial verify →
// independent triage → fix → optional delta re-review. Improves on the
// peer-review skill with fail-closed verification, implementer/judge
// separation, early exit, and budget-aware round structure.

let meta = #{
    name: "peer-review",
    description: "Peer-reviewed build: plan, implement, parallel specialists, adversarial verify findings, independent triage, fix, optional delta re-review",
    when_to_use: "When you want /peer-review quality (plan+implement+multi-specialist rounds) with adversarial verification and no implementer-as-judge bias",
    phases: [
        #{ title: "Resolve", detail: "task / PRD / issue into a bound spec" },
        #{ title: "Plan", detail: "structured plan with consumer map, authZ, failure modes" },
        #{ title: "Implement", detail: "build against the plan; record files touched" },
        #{ title: "Review", detail: "parallel specialists (7 actionable + architecture advisory)" },
        #{ title: "Verify", detail: "independent skeptics prove each finding is real" },
        #{ title: "Triage", detail: "fresh judge accepts / rejects / defers confirmed findings only" },
        #{ title: "Fix", detail: "implement accepted changes; type-harden soft-fails" },
        #{ title: "Re-review", detail: "optional delta pass on fixed files only" },
        #{ title: "Summary", detail: "durable report + deferred list + architecture advisory if needed" },
    ],
};

// ── Schemas ────────────────────────────────────────────────────────────────

let plan_schema = #{
    "type": "object",
    "required": ["goal", "approach", "files", "consumer_map", "invariants", "authz", "failure_modes", "out_of_scope", "open_questions", "implementation_steps"],
    "properties": #{
        "goal": #{ "type": "string" },
        "approach": #{ "type": "string" },
        "files": #{ "type": "array", "items": #{ "type": "string" }, "maxItems": 40 },
        "consumer_map": #{ "type": "string" },
        "invariants": #{ "type": "string" },
        "authz": #{ "type": "string" },
        "failure_modes": #{ "type": "string" },
        "out_of_scope": #{ "type": "string" },
        "open_questions": #{ "type": "string" },
        "implementation_steps": #{ "type": "array", "items": #{ "type": "string" }, "maxItems": 20 },
    },
};

let implement_schema = #{
    "type": "object",
    "required": ["summary", "files_touched", "build_ok", "notes"],
    "properties": #{
        "summary": #{ "type": "string" },
        "files_touched": #{ "type": "array", "items": #{ "type": "string" }, "maxItems": 60 },
        "build_ok": #{ "type": "boolean" },
        "notes": #{ "type": "string" },
    },
};

let findings_schema = #{
    "type": "object",
    "required": ["findings", "summary"],
    "properties": #{
        "summary": #{ "type": "string" },
        "findings": #{
            "type": "array",
            "maxItems": 6,
            "items": #{
                "type": "object",
                "required": ["title", "severity", "file", "observation", "why", "suggested_change"],
                "properties": #{
                    "title": #{ "type": "string" },
                    "severity": #{ "type": "string" },
                    "file": #{ "type": "string" },
                    "line": #{ "type": "string" },
                    "observation": #{ "type": "string" },
                    "why": #{ "type": "string" },
                    "suggested_change": #{ "type": "string" },
                },
            },
        },
    },
};

let arch_schema = #{
    "type": "object",
    "required": ["verdict", "note"],
    "properties": #{
        "verdict": #{ "type": "string" },
        "note": #{ "type": "string" },
    },
};

let verdict_schema = #{
    "type": "object",
    "required": ["real", "reason", "evidence"],
    "properties": #{
        "real": #{ "type": "boolean" },
        "reason": #{ "type": "string" },
        "evidence": #{ "type": "string" },
    },
};

let triage_schema = #{
    "type": "object",
    "required": ["decisions"],
    "properties": #{
        "decisions": #{
            "type": "array",
            "maxItems": 24,
            "items": #{
                "type": "object",
                "required": ["index", "decision", "reasoning"],
                "properties": #{
                    "index": #{ "type": "integer" },
                    "decision": #{ "type": "string" },
                    "reasoning": #{ "type": "string" },
                    "implementation_note": #{ "type": "string" },
                },
            },
        },
    },
};

let fix_schema = #{
    "type": "object",
    "required": ["summary", "files_touched", "build_ok", "applied", "rejected_during_apply"],
    "properties": #{
        "summary": #{ "type": "string" },
        "files_touched": #{ "type": "array", "items": #{ "type": "string" }, "maxItems": 60 },
        "build_ok": #{ "type": "boolean" },
        "applied": #{ "type": "array", "items": #{ "type": "string" }, "maxItems": 24 },
        "rejected_during_apply": #{
            "type": "array",
            "maxItems": 12,
            "items": #{
                "type": "object",
                "required": ["title", "reason"],
                "properties": #{
                    "title": #{ "type": "string" },
                    "reason": #{ "type": "string" },
                },
            },
        },
    },
};

let summary_schema = #{
    "type": "object",
    "required": ["report_markdown"],
    "properties": #{
        "report_markdown": #{ "type": "string" },
    },
};

// ── Args ───────────────────────────────────────────────────────────────────

let task = if args == () { () } else { args.task };
if task == () {
    pause("verification", "Pass args.task — free-form description, a PRD path, or a GitHub issue (#42 / URL). Optional: args.rounds (1 or 2, default 2), args.base (git base branch).");
}

let max_rounds = 2;
if args != () && args.rounds != () {
    // Rhai has no int parse from arbitrary; accept number only.
    if type_of(args.rounds) == "i64" || type_of(args.rounds) == "f64" {
        if args.rounds == 1 { max_rounds = 1; }
        if args.rounds == 2 { max_rounds = 2; }
    }
}

let base_branch = "main";
if args != () && args.base != () && type_of(args.base) == "string" && args.base != "" {
    base_branch = args.base;
}

const MAX_VERIFY = 12;
const MAX_FINDINGS_PER_SPECIALIST = 6;

// ── Helpers ────────────────────────────────────────────────────────────────

fn trimmed(s) {
    if type_of(s) == "string" {
        s.trim();
        s
    } else {
        ""
    }
}

// Canned validate_only outputs are small fixed objects — never assume arrays exist.
fn as_array(x) {
    if x == () { return []; }
    if type_of(x) == "array" { return x; }
    []
}

fn as_string(x) {
    if x == () { return ""; }
    if type_of(x) == "string" { return x; }
    json_encode(x)
}

fn severity_rank(sev) {
    let s = trimmed(sev);
    if s == "blocker" || s == "BLOCKER" || s == "critical" || s == "CRITICAL" { return 4; }
    if s == "major" || s == "MAJOR" || s == "high" || s == "HIGH" { return 3; }
    if s == "minor" || s == "MINOR" || s == "medium" || s == "MEDIUM" { return 2; }
    1
}

fn merge_files(a, b) {
    let out = [];
    for p in a {
        let seen = false;
        for q in out {
            if q == p { seen = true; }
        }
        if !seen { out.push(p); }
    }
    for p in b {
        let seen = false;
        for q in out {
            if q == p { seen = true; }
        }
        if !seen { out.push(p); }
    }
    out
}

fn files_prompt_block(files) {
    let block = "";
    let i = 0;
    for f in files {
        if i > 0 { block += "\n"; }
        block += "- ";
        block += f;
        i += 1;
    }
    if block == "" { block = "(no files listed — discover via git status / git diff against base)"; }
    block
}

fn findings_prompt_block(findings) {
    let block = "";
    let i = 0;
    for f in findings {
        block += "\n### INDEX ";
        block += i.to_string();
        block += " — ";
        block += f.title;
        block += "\n- Specialty: ";
        block += f.specialty;
        block += "\n- Severity: ";
        block += f.severity;
        block += "\n- File: ";
        block += f.file;
        if f.line != () && f.line != "" {
            block += ":";
            block += f.line;
        }
        block += "\n- Observation: ";
        block += f.observation;
        block += "\n- Why: ";
        block += f.why;
        block += "\n- Suggested change: ";
        block += f.suggested_change;
        block += "\n";
        i += 1;
    }
    block
}

fn shared_review_rules() {
    let s = "";
    s += "SHARED RULES:\n";
    s += "1. Use read_file / grep / git tools to inspect the ACTUAL code. Do not answer from memory.\n";
    s += "2. Read every listed file fully (not just hunks). For wiring/dual-path issues, also read consumers outside the list.\n";
    s += "3. Stay in your specialty. Skip issues owned by other specialists unless inseparable.\n";
    s += "4. Do not modify code. Review only.\n";
    s += "5. Be specific: file path, line if possible, concrete change. Vague advice is invalid.\n";
    s += "6. Respect OUT OF SCOPE in the plan — do not raise those.\n";
    s += "7. Empty findings is valid ONLY after you read the code and found nothing in your specialty. Summary must say clean.\n";
    s += "8. Cap at 6 findings. Prefer highest severity. Severity: blocker | major | minor | nit.\n";
    s += "9. Never invent issues to fill the quota.\n";
    s
}

fn specialty_body(name) {
    if name == "correctness" {
        let s = "";
        s += "SPECIALTY: Correctness / plan-fit / edge cases\n";
        s += "Review ONLY for: plan vs implementation mismatches; logic bugs; edge cases; off-by-one; null derefs; race/async ordering; incomplete error handling that is pure correctness; missing cleanup; wrong status codes; copy-paste bugs.\n";
        s += "Do NOT deep-dive: injection/auth catalogs, silent-fallback catalogs, R1-R10 checklists, unused-import/dead-symbol cleanup, extract-to-shared DRY, or test-suite design.\n";
        return s;
    }
    if name == "security" {
        let s = "";
        s += "SPECIALTY: Security / authZ / secrets\n";
        s += "Review ONLY for: injection (SQL/NoSQL/command/XSS/template); missing/weak auth; thin tenant checks without assignment/role gates; over-broad procedures; identity vs capability conflation; auth fail-open; secrets/PII in logs or responses; env names in user errors; cross-tenant leakage; missing input validation; crypto/session/JWT issues.\n";
        s += "Do NOT deep-dive: performance, soft-type hardening (except fail-open auth), test coverage, plan-fit nits.\n";
        return s;
    }
    if name == "silent" {
        let s = "";
        s += "SPECIALTY: Silent failure / soft types (\"just make it work\")\n";
        s += "Prefer hard failures with clear errors over wrong-state continuation unless intentional graceful degradation.\n";
        s += "Flag: empty catch; catch that logs and continues as success; .catch(()=>undefined|null|[]|{}); try/catch returning success defaults; fire-and-forget where failure must surface.\n";
        s += "Flag fallbacks that should hard-fail: critical config defaults; empty arrays/objects when required data missing; || [] / ?? {} papering; optional chains on required paths; mock/stale production fallbacks; parse→silent default; retry that succeeds with empty data.\n";
        s += "Soft types root cause: for every fallback, name the exact hard type + validation boundary. Never suggest any / as any / double cast / blanket ! / @ts-ignore.\n";
        s += "Flag: optional fields that should be required; Partial for loaded entities; unvalidated JSON deep in domain; empty success when absence is error.\n";
        s += "For each finding: (1) what happens on failure today (2) what should happen (3) soft-type root cause + hard type (4) concrete fix without more defaults.\n";
        return s;
    }
    if name == "recurring" {
        let s = "";
        s += "SPECIALTY: Recurring PR failure patterns R1-R10\n";
        s += "Walk checklist; flag production failure modes as blocker/major.\n";
        s += "R1 Soft success (looks ACTIVE/ready while broken). R2 Write-only / incomplete E2E wiring (UI→API→DB→read→export pipelines→import→jobs). R3 App-only invariants/races (need DB unique/transactions). R4 Thin authZ/tenant/secret boundaries. R5 Form hydration/mount wipes. R6 Dual-path inconsistency (CRM vs funnel, twin transformers). R7 Envelope casts / partial updates null omitted fields / type lies. R8 Tests that don't protect failure modes. R9 UX recovery missing. R10 Reinvention / arbitrary design tokens / incomplete a11y.\n";
        s += "For R2/R6 read consumers outside the touched list. In Why, name the production failure mode. Prefer DB constraints, existing auth helpers, hard preflight throws, full consumer wiring — not more ?? defaults.\n";
        return s;
    }
    if name == "testing" {
        let s = "";
        s += "SPECIALTY: Testing gaps\n";
        s += "Review ONLY missing/weak tests. Do not redesign product logic except to name the assertion that would catch a bug.\n";
        s += "Flag: new branches without tests; modified behavior without updated tests; happy-path-only fixtures; tests that no-op green when fixtures missing; missing failure-path assertions; contract changes without e2e/integration updates.\n";
        s += "Prefer at least one test that would FAIL if a silent-success or write-only bug returned. For each: where test lives, what to assert, what bug it catches.\n";
        return s;
    }
    if name == "deadcode" {
        let s = "";
        s += "SPECIALTY: Dead code / unused / stale comments\n";
        s += "Remove refactor leftovers. Prove unused with grep/read — do not guess.\n";
        s += "Flag unused imports (named/default/type-only/unneeded side-effect); unused locals/params/private helpers/types/constants; exports/re-exports with no in-repo consumers (unless intentional public package API); dead/unreachable branches; assigned-never-read vars; leftover feature-flag/env reads.\n";
        s += "Flag stale/useless comments to DELETE: narrating removed behavior (used to/previously/was/no longer/removed X/old path); large commented-out blocks; JSDoc contradicting current signatures; TODOs already done or pointing at deleted code; leftover section banners; obvious narrating comments from this change with no non-obvious intent.\n";
        s += "Do NOT flag: symbols used via types/decorators/DI/reflection; WHY/invariant/security comments that still apply; WIP with active TODO+issue; broad cleanups outside this change's blast radius.\n";
        s += "Severity: unused import=nit; dead private helper/misleading stale comment=minor/major; stale comment contradicting auth/security=major/blocker. Each finding needs proof of zero refs (or quote) + exact delete.\n";
        return s;
    }
    if name == "duplication" {
        let s = "";
        s += "SPECIALTY: Duplication / extract-to-shared\n";
        s += "Flag repeated logic only when ALL hold: (1) >=3 real occurrences after this change (2) would realistically be used more (3) stable enough to name (4) extraction reduces drift risk.\n";
        s += "Scope of shared home from fan-out: 3+ in one file => private helper; 3+ in one feature/module => module utils/helpers; 3+ across one app => app shared module; 3+ across apps/FE+BE domain => existing libs/ package; near-match existing helper => extend/reuse, no parallel utility.\n";
        s += "Always include occurrence count, file:line list, proposed symbol+path, params vs identical core. Search the repo, not only touched files.\n";
        s += "Do NOT flag: only 2 weak lookalikes; intentional test-fixture dup; trivial one-liners; similar control flow with different business meaning; huge unrelated DRY refactors.\n";
        s += "Severity: easy local 3-copy=minor/nit; drifting copies or dual-path same domain rule=major; reinvented existing helper=major. Suggested change = concrete signature + home path, not 'consider DRY'.\n";
        return s;
    }
    "SPECIALTY: general review\n"
}

fn make_review_prompt(specialty, plan_json, files_block, round_label, focus_note) {
    let p = "";
    p += "You are an independent specialist code reviewer for ONE concern only.\n";
    p += "You have no prior context. Review what you see. You do not know about other specialists or other rounds.\n\n";
    p += "ROUND: ";
    p += round_label;
    p += "\n\n";
    p += specialty_body(specialty);
    p += "\n";
    p += shared_review_rules();
    p += "\n## The plan (JSON)\n";
    p += plan_json;
    p += "\n\n## Files implemented / in scope\n";
    p += files_block;
    p += "\n\n";
    if focus_note != "" {
        p += "## Focus for this pass\n";
        p += focus_note;
        p += "\n\n";
    }
    p += "Return structured findings for your specialty only. line may be empty string if unknown.\n";
    p
}

fn make_arch_prompt(plan_json, files_block) {
    let p = "";
    p += "You are performing an ARCHITECTURE SENSE-CHECK only. Advisory. Conservative.\n";
    p += "Question: Does the way this is implemented actually make sense as it is now?\n\n";
    p += "Use read_file / grep to inspect the plan, listed files, and surrounding codebase patterns (similar features, helpers, layering).\n\n";
    p += "STANCE — default to fine:\n";
    p += "- Most working designs that fit local patterns are fine.\n";
    p += "- Only speak when there is a VERY CLEAR better path that fits this codebase, or the approach is CLEARLY poor (wrong layer, fights abstractions, parallel system for something already solved).\n";
    p += "- Style prefs, micro-opts, naming bikesheds are NOT findings. Preferable-but-not-clearly-better is NOT a finding. Silence/fine is correct when acceptable.\n\n";
    p += "CRITICAL:\n";
    p += "- Never demand a rewrite or re-architecture.\n";
    p += "- Never emit severity findings for triage.\n";
    p += "- Keep notes short (half page max). If fine: verdict fine and note empty string.\n\n";
    p += "Verdict enum: fine | clear-better-path | poor-fit\n\n";
    p += "## Plan (JSON)\n";
    p += plan_json;
    p += "\n\n## Files\n";
    p += files_block;
    p += "\n";
    p
}

fn make_verify_prompt(f) {
    let p = "";
    p += "You are an adversarial skeptic. Your job is to REFUTE review findings unless the shipped code independently proves them.\n";
    p += "Default real=false. Set real=true ONLY with concrete evidence you inspected yourself (file:line + what the code does).\n";
    p += "Missing evidence, ambiguity, or 'probably' => real=false.\n";
    p += "Use read_file / grep. Do not trust the finding text alone.\n";
    p += "If the finding is true but severity is inflated, still real=true and note that in reason.\n";
    p += "If the finding misreads out-of-scope, intentional tradeoff in the plan, or already-fixed code, real=false.\n\n";
    p += "FINDING TO VERIFY:\n";
    p += "Title: ";
    p += f.title;
    p += "\nSpecialty: ";
    p += f.specialty;
    p += "\nSeverity: ";
    p += f.severity;
    p += "\nFile: ";
    p += f.file;
    if f.line != () && f.line != "" {
        p += "\nClaimed line: ";
        p += f.line;
    }
    p += "\nObservation: ";
    p += f.observation;
    p += "\nWhy it matters: ";
    p += f.why;
    p += "\nSuggested change: ";
    p += f.suggested_change;
    p += "\n\nReturn: real (bool), reason (short), evidence (file:line quotes or concrete code behavior; empty string if unreal).\n";
    p
}

// ── Phase: Resolve ─────────────────────────────────────────────────────────

phase("Resolve");
log("Resolving task into a bound spec");

let resolve_prompt = "";
resolve_prompt += "Resolve the user's peer-review task into a single clear specification document.\n\n";
resolve_prompt += "INPUT (verbatim):\n";
resolve_prompt += json_encode(task);
resolve_prompt += "\n\nRules:\n";
resolve_prompt += "1. If INPUT is a filesystem path that exists, read the file and treat it as the PRD/spec.\n";
resolve_prompt += "2. If INPUT looks like a GitHub issue (#NNN or github.com/.../issues/NNN), use gh issue view (detect repo from git remote) and use title+body as the spec. If the issue references a PRD path, read that too.\n";
resolve_prompt += "3. Otherwise treat INPUT as a free-form task description.\n";
resolve_prompt += "4. Also run: git branch --show-current, and note base branch preference: ";
resolve_prompt += base_branch;
resolve_prompt += "\n5. Return ONLY the resolved specification as plain markdown text (no code edits).\n";
resolve_prompt += "Include a top heading and enough detail for an implementer to plan.\n";

let resolved = agent(resolve_prompt, #{
    label: "resolve-spec",
    capability_mode: "read-only",
    agent_type: "general-purpose",
});

let spec_text = "";
if resolved != () && resolved.success && type_of(resolved.output) == "string" {
    spec_text = resolved.output;
} else if resolved != () && resolved.success {
    spec_text = json_encode(resolved.output);
} else {
    // Fall back to raw task so the loop can continue.
    if type_of(task) == "string" {
        spec_text = task;
    } else {
        spec_text = json_encode(task);
    }
    log("resolve agent failed or empty — using raw task text");
}

let spec_path = write_scratch_file("spec.md", spec_text);
log("Spec written to " + spec_path);

// ── Phase: Plan ────────────────────────────────────────────────────────────

phase("Plan");
log("Writing structured plan");

let plan_prompt = "";
plan_prompt += "You are the planning engineer for a peer-reviewed implementation. Do NOT implement yet.\n";
plan_prompt += "Explore the codebase with read_file / grep / list_dir as needed so the plan fits local patterns.\n\n";
plan_prompt += "## Spec\n";
plan_prompt += spec_text;
plan_prompt += "\n\n## Required plan fields\n";
plan_prompt += "- goal: one paragraph restating the task\n";
plan_prompt += "- approach: design/architecture choice and main tradeoff accepted\n";
plan_prompt += "- files: explicit list of paths to create or modify\n";
plan_prompt += "- consumer_map: for every new/moved field or abstraction, who must read/honor it (API schema, DB, list/read UI, exporters/transformers for EACH pipeline, importers, jobs). Mark intentional deferrals.\n";
plan_prompt += "- invariants: uniqueness/atomicity; whether DB constraint or transaction enforces it\n";
plan_prompt += "- authz: who can call new procedures; which existing gate (role/assignment/tenant helper) is reused\n";
plan_prompt += "- failure_modes: what hard-fails vs user-visible degradation; no silent ACTIVE/success on failed setup\n";
plan_prompt += "- out_of_scope: deliberate non-goals so reviewers don't churn\n";
plan_prompt += "- open_questions: uncertainties\n";
plan_prompt += "- implementation_steps: ordered concrete steps\n";
plan_prompt += "\nSelf-check while planning: soft success, write-only wiring, races, thin authZ, mount wipes, dual-path drift, envelope casts, tests that assert failure paths.\n";
plan_prompt += "Return the structured plan object only.\n";

let plan_result = agent(plan_prompt, #{
    label: "plan",
    capability_mode: "read-only",
    agent_type: "plan",
    output_schema: plan_schema,
});

if plan_result == () || !plan_result.success || plan_result.output == () {
    complete(#{
        ok: false,
        error: "Plan agent failed — cannot continue peer-review loop",
        spec_path: spec_path,
    });
}

let plan = plan_result.output;
let plan_files = as_array(plan.files);
let plan_steps = as_array(plan.implementation_steps);
let plan_json = json_encode(plan);
let plan_md = "";
plan_md += "# Plan\n\n## Goal\n";
plan_md += as_string(plan.goal);
plan_md += "\n\n## Approach\n";
plan_md += as_string(plan.approach);
plan_md += "\n\n## Files\n";
for f in plan_files {
    plan_md += "- ";
    plan_md += as_string(f);
    plan_md += "\n";
}
plan_md += "\n## Consumer map\n";
plan_md += as_string(plan.consumer_map);
plan_md += "\n\n## Invariants\n";
plan_md += as_string(plan.invariants);
plan_md += "\n\n## AuthZ\n";
plan_md += as_string(plan.authz);
plan_md += "\n\n## Failure modes\n";
plan_md += as_string(plan.failure_modes);
plan_md += "\n\n## Out of scope\n";
plan_md += as_string(plan.out_of_scope);
plan_md += "\n\n## Open questions\n";
plan_md += as_string(plan.open_questions);
plan_md += "\n\n## Steps\n";
for s in plan_steps {
    plan_md += "- ";
    plan_md += as_string(s);
    plan_md += "\n";
}
let plan_path = write_scratch_file("plan.md", plan_md);
log("Plan written to " + plan_path);

// ── Phase: Implement ───────────────────────────────────────────────────────

phase("Implement");
log("Implementing against the plan");

let impl_prompt = "";
impl_prompt += "You are the implementing engineer. Execute the plan fully. Prefer existing helpers, auth gates, and DB patterns in this repo.\n";
impl_prompt += "Use the monorepo conventions (Nx via yarn nx, Prisma when needed). Do not expand out_of_scope.\n\n";
impl_prompt += "While implementing, self-check: soft success, write-only wiring, races, thin authZ, mount wipes, dual-path drift, envelope casts, failure-path tests.\n";
impl_prompt += "When soft-fails appear: harden exact types at the boundary; never paper with any / as any / more optionals.\n";
impl_prompt += "Verify build/typecheck for touched projects before finishing (e.g. yarn nx run <project>:typecheck or equivalent).\n\n";
impl_prompt += "## Spec\n";
impl_prompt += spec_text;
impl_prompt += "\n\n## Plan (JSON)\n";
impl_prompt += plan_json;
impl_prompt += "\n\nReturn: summary, files_touched (every created/modified path), build_ok, notes.\n";
impl_prompt += "files_touched must be accurate — reviewers only examine this list.\n";

let impl_result = agent(impl_prompt, #{
    label: "implement",
    capability_mode: "all",
    agent_type: "general-purpose",
    output_schema: implement_schema,
});

if impl_result == () || !impl_result.success || impl_result.output == () {
    complete(#{
        ok: false,
        error: "Implement agent failed",
        spec_path: spec_path,
        plan_path: plan_path,
    });
}

let impl = impl_result.output;
let files_touched = as_array(impl.files_touched);
if files_touched.len() == 0 {
    files_touched = plan_files;
}

// Prefer plan files unioned with reported touches.
files_touched = merge_files(plan_files, files_touched);

let files_md = "";
for f in files_touched {
    files_md += f;
    files_md += "\n";
}
let files_path = write_scratch_file("files-touched.md", files_md);
log("Implementation done; files_touched=" + files_touched.len().to_string() + " build_ok=" + impl.build_ok.to_string());

// Round tracking for summary
let all_round_stats = [];
let all_deferred = [];
let all_rejected = [];
let all_accepted_applied = [];
let strongest_arch = "fine";
let strongest_arch_note = "";
let files_block = files_prompt_block(files_touched);

// ── Review / Verify / Triage / Fix loop ────────────────────────────────────

let round_n = 1;
while round_n <= max_rounds {
    let round_label = "R" + round_n.to_string();
    let is_delta = round_n > 1;
    let focus_note = "";
    if is_delta {
        focus_note = "This is a DELTA re-review after fixes. Focus on the listed files and regressions introduced by recent fixes. Do not re-litigate already-correct code. Do not pad.";
    }

    // ── Review ────────────────────────────────────────────────────────────
    phase("Review");
    log(round_label + ": spawning parallel specialists");

    let specialties = ["correctness", "security", "silent", "recurring", "testing", "deadcode", "duplication"];
    let specialty_labels = ["Correctness", "Security", "SilentFailure", "RecurringPattern", "Testing", "DeadCode", "Duplication"];
    let specialty_count = specialties.len();
    let review_jobs = [];
    let si = 0;
    for sp in specialties {
        let pr = make_review_prompt(sp, plan_json, files_block, round_label, focus_note);
        let agent_type = "general-purpose";
        if sp == "security" { agent_type = "backend-architect"; }
        if sp == "testing" { agent_type = "test-writer-fixer"; }
        review_jobs.push(#{
            prompt: pr,
            label: round_label + "-" + sp,
            capability_mode: "read-only",
            agent_type: agent_type,
            output_schema: findings_schema,
        });
        si += 1;
    }

    // Architecture only on first full pass (saves 1 agent per extra round).
    let arch_included = !is_delta;
    if arch_included {
        review_jobs.push(#{
            prompt: make_arch_prompt(plan_json, files_block),
            label: round_label + "-architecture",
            capability_mode: "read-only",
            agent_type: "plan",
            output_schema: arch_schema,
        });
    }

    let review_results = parallel(review_jobs);

    // Collect findings from actionable specialists; arch is last if present.
    let merged = [];
    let clean_specialists = [];
    let failed_specialists = [];
    let ri = 0;
    while ri < specialty_count {
        let r = review_results[ri];
        let label = specialty_labels[ri];
        let found = [];
        let ok = false;
        if r != () && r.success && r.output != () {
            found = as_array(r.output.findings);
            ok = true;
        }
        if !ok {
            failed_specialists.push(label);
            log(round_label + ": retrying specialist " + label);
            let retry = agent(
                make_review_prompt(specialties[ri], plan_json, files_block, round_label, focus_note),
                #{
                    label: round_label + "-" + specialties[ri] + "-retry",
                    capability_mode: "read-only",
                    agent_type: "general-purpose",
                    output_schema: findings_schema,
                }
            );
            if retry != () && retry.success && retry.output != () {
                found = as_array(retry.output.findings);
                ok = true;
            }
        }
        if !ok {
            merged.push(#{
                title: "reviewer-failed (" + label + ")",
                severity: "major",
                file: "general",
                line: "",
                observation: "Specialist " + label + " failed twice and produced no usable output.",
                why: "Coverage gap for this specialty in " + round_label,
                suggested_change: "Re-run peer-review for this specialty or manual review.",
                specialty: label,
            });
        } else if found.len() == 0 {
            clean_specialists.push(label);
        } else {
            for f in found {
                merged.push(#{
                    title: as_string(f.title),
                    severity: as_string(f.severity),
                    file: as_string(f.file),
                    line: as_string(f.line),
                    observation: as_string(f.observation),
                    why: as_string(f.why),
                    suggested_change: as_string(f.suggested_change),
                    specialty: label,
                });
            }
        }
        ri += 1;
    }

    // Architecture note
    if arch_included {
        let ar = review_results[specialty_count];
        let arch_verdict = "fine";
        let arch_note = "";
        if ar != () && ar.success && ar.output != () {
            if ar.output.verdict != () { arch_verdict = trimmed(ar.output.verdict); }
            if ar.output.note != () { arch_note = ar.output.note; }
        } else {
            // retry once
            let ar2 = agent(make_arch_prompt(plan_json, files_block), #{
                label: round_label + "-architecture-retry",
                capability_mode: "read-only",
                agent_type: "plan",
                output_schema: arch_schema,
            });
            if ar2 != () && ar2.success && ar2.output != () {
                if ar2.output.verdict != () { arch_verdict = trimmed(ar2.output.verdict); }
                if ar2.output.note != () { arch_note = ar2.output.note; }
            } else {
                arch_verdict = "fine";
                arch_note = "";
            }
        }
        // Rank: poor-fit > clear-better-path > fine
        if arch_verdict == "poor-fit" {
            strongest_arch = "poor-fit";
            strongest_arch_note = arch_note;
        } else if arch_verdict == "clear-better-path" && strongest_arch != "poor-fit" {
            strongest_arch = "clear-better-path";
            strongest_arch_note = arch_note;
        }
        let arch_md = "# Architecture sense-check (" + round_label + ")\n\nVerdict: " + arch_verdict + "\n\n" + arch_note + "\n";
        write_scratch_file("round-" + round_n.to_string() + "-architecture-note.md", arch_md);
        log(round_label + " architecture: " + arch_verdict);
    }

    // Dedup near-identical titles+files (keep higher severity)
    let deduped = [];
    for f in merged {
        let dup_idx = -1;
        let di = 0;
        for d in deduped {
            let same_file = d.file == f.file;
            let same_title = d.title == f.title;
            // crude near-dup: same file and overlapping title prefix
            if same_file && same_title {
                dup_idx = di;
            }
            di += 1;
        }
        if dup_idx < 0 {
            deduped.push(f);
        } else {
            if severity_rank(f.severity) > severity_rank(deduped[dup_idx].severity) {
                // replace with stronger severity; note both specialties
                let kept = deduped[dup_idx];
                let specs = kept.specialty + "+" + f.specialty;
                deduped[dup_idx] = #{
                    title: f.title,
                    severity: f.severity,
                    file: f.file,
                    line: f.line,
                    observation: f.observation,
                    why: f.why,
                    suggested_change: f.suggested_change,
                    specialty: specs,
                };
            }
        }
    }

    let comments_md = "# Review " + round_label + "\n\n## Summary\n";
    comments_md += "Merged ";
    comments_md += deduped.len().to_string();
    comments_md += " findings after specialist fan-out (pre-verification).\n\n## Comments\n";
    let ci = 0;
    for f in deduped {
        comments_md += "\n### C";
        comments_md += (ci + 1).to_string();
        comments_md += " — ";
        comments_md += f.title;
        comments_md += "\n- **Specialty**: ";
        comments_md += f.specialty;
        comments_md += "\n- **Severity**: ";
        comments_md += f.severity;
        comments_md += "\n- **File**: ";
        comments_md += f.file;
        comments_md += "\n- **Observation**: ";
        comments_md += f.observation;
        comments_md += "\n- **Why it matters**: ";
        comments_md += f.why;
        comments_md += "\n- **Suggested change**: ";
        comments_md += f.suggested_change;
        comments_md += "\n";
        ci += 1;
    }
    comments_md += "\n## Clean specialists\n";
    for c in clean_specialists {
        comments_md += "- ";
        comments_md += c;
        comments_md += ": no findings\n";
    }
    write_scratch_file("round-" + round_n.to_string() + "-comments.md", comments_md);
    log(round_label + ": " + deduped.len().to_string() + " findings pre-verify");

    if deduped.len() == 0 {
        all_round_stats.push(#{
            round: round_n,
            raised: 0,
            confirmed: 0,
            accepted: 0,
            rejected: 0,
            deferred: 0,
        });
        log(round_label + ": no findings — early exit remaining rounds");
        break;
    }

    // ── Verify (fail-closed) ──────────────────────────────────────────────
    phase("Verify");
    // Cap what we verify to control budget; prioritize by severity.
    // Simple selection: take first MAX_VERIFY after sorting by severity rank desc.
    let ordered = [];
    // 4 buckets
    for f in deduped {
        if severity_rank(f.severity) == 4 { ordered.push(f); }
    }
    for f in deduped {
        if severity_rank(f.severity) == 3 { ordered.push(f); }
    }
    for f in deduped {
        if severity_rank(f.severity) == 2 { ordered.push(f); }
    }
    for f in deduped {
        if severity_rank(f.severity) == 1 { ordered.push(f); }
    }

    let to_verify = [];
    let vi = 0;
    for f in ordered {
        if vi < MAX_VERIFY {
            to_verify.push(f);
        }
        vi += 1;
    }
    if ordered.len() > MAX_VERIFY {
        log(round_label + ": verifying top " + MAX_VERIFY.to_string() + " of " + ordered.len().to_string() + " by severity; remainder dropped as unverified");
    }

    let vjobs = [];
    for f in to_verify {
        vjobs.push(#{
            prompt: make_verify_prompt(f),
            label: round_label + "-verify-" + f.file,
            capability_mode: "read-only",
            output_schema: verdict_schema,
        });
    }
    let verdicts = parallel(vjobs);

    let confirmed = [];
    let dropped = 0;
    let vj = 0;
    for v in verdicts {
        // Fail closed: missing/failed/unusable => not confirmed
        if v != () && v.success && v.output != () && v.output.real == true
            && v.output.evidence != () && trimmed(v.output.evidence) != "" {
            let base = to_verify[vj];
            confirmed.push(#{
                title: base.title,
                severity: base.severity,
                file: base.file,
                line: base.line,
                observation: base.observation,
                why: base.why,
                suggested_change: base.suggested_change,
                specialty: base.specialty,
                evidence: v.output.evidence,
                verify_reason: v.output.reason,
            });
        } else {
            dropped += 1;
        }
        vj += 1;
    }
    log(round_label + ": " + confirmed.len().to_string() + "/" + to_verify.len().to_string() + " findings survived verification (" + dropped.to_string() + " dropped)");

    let confirmed_md = "# Confirmed findings " + round_label + "\n\n";
    confirmed_md += findings_prompt_block(confirmed);
    write_scratch_file("round-" + round_n.to_string() + "-confirmed.md", confirmed_md);

    if confirmed.len() == 0 {
        all_round_stats.push(#{
            round: round_n,
            raised: deduped.len(),
            confirmed: 0,
            accepted: 0,
            rejected: 0,
            deferred: 0,
        });
        log(round_label + ": nothing confirmed — early exit remaining rounds");
        break;
    }

    // ── Triage (independent judge — NOT the implementer) ──────────────────
    phase("Triage");
    log(round_label + ": independent judge triaging confirmed findings");

    let triage_prompt = "";
    triage_prompt += "You are an independent triage judge. You did NOT implement this code and must not defend it.\n";
    triage_prompt += "Only CONFIRMED findings (already adversarially verified against the code) are listed.\n";
    triage_prompt += "For each finding, decide accept | reject | defer.\n\n";
    triage_prompt += "Rules:\n";
    triage_prompt += "- accept: correct, in scope, and should be implemented now. Include implementation_note with the specific edit.\n";
    triage_prompt += "- reject: wrong, already handled, misread of intentional plan tradeoff, or fix would be harmful. Reasoning mandatory.\n";
    triage_prompt += "- defer: reasonable but out of scope / follow-up. Reasoning + where to track mandatory.\n";
    triage_prompt += "- Severity is informational, not binding. A cheap nit can be accept; a misunderstood blocker can be reject.\n";
    triage_prompt += "- Prefer accept for real blocker/major security, soft-success, write-only wiring, auth fail-open, data-loss soft-fails.\n";
    triage_prompt += "- Soft-fail fixes must harden exact types at boundaries — never accept a fix that adds any/as any/more optionals.\n";
    triage_prompt += "- Read the plan's out_of_scope and the code before deciding. Use tools.\n";
    triage_prompt += "- index is the INDEX number shown on each finding (0-based).\n";
    triage_prompt += "- Every finding must appear exactly once in decisions.\n\n";
    triage_prompt += "## Plan (JSON)\n";
    triage_prompt += plan_json;
    triage_prompt += "\n\n## Confirmed findings\n";
    triage_prompt += findings_prompt_block(confirmed);
    triage_prompt += "\nReturn decisions array covering every index.\n";

    let triage_result = agent(triage_prompt, #{
        label: round_label + "-triage",
        capability_mode: "read-only",
        agent_type: "general-purpose",
        output_schema: triage_schema,
    });

    let decisions = [];
    if triage_result != () && triage_result.success && triage_result.output != () {
        decisions = as_array(triage_result.output.decisions);
    }
    if decisions.len() == 0 {
        // Fail closed for triage failure: defer all confirmed (do not auto-accept)
        log(round_label + ": triage agent failed — deferring all confirmed findings");
        let ti = 0;
        for f in confirmed {
            decisions.push(#{
                index: ti,
                decision: "defer",
                reasoning: "Triage agent failed; deferred automatically for human review.",
                implementation_note: "",
            });
            ti += 1;
        }
    }

    let accepted = [];
    let n_accept = 0;
    let n_reject = 0;
    let n_defer = 0;
    let decisions_md = "# Round " + round_n.to_string() + " decisions (confirmed findings only)\n\n";

    for d in decisions {
        let idx = d.index;
        if type_of(idx) == "f64" { idx = idx; }
        // bounds check
        if idx < 0 || idx >= confirmed.len() {
            continue;
        }
        let f = confirmed[idx];
        let dec = trimmed(d.decision);
        let reasoning = if d.reasoning != () { d.reasoning } else { "" };
        let impl_note = if d.implementation_note != () { d.implementation_note } else { "" };

        decisions_md += "## INDEX ";
        decisions_md += idx.to_string();
        decisions_md += " — ";
        decisions_md += f.title;
        decisions_md += "\n- **Decision**: ";
        decisions_md += dec;
        decisions_md += "\n- **Reasoning**: ";
        decisions_md += reasoning;
        if impl_note != "" {
            decisions_md += "\n- **Implementation note**: ";
            decisions_md += impl_note;
        }
        decisions_md += "\n\n";

        if dec == "accept" {
            n_accept += 1;
            accepted.push(#{
                title: f.title,
                severity: f.severity,
                file: f.file,
                line: f.line,
                observation: f.observation,
                why: f.why,
                suggested_change: f.suggested_change,
                specialty: f.specialty,
                evidence: f.evidence,
                implementation_note: impl_note,
            });
        } else if dec == "reject" {
            n_reject += 1;
            all_rejected.push(#{
                round: round_n,
                title: f.title,
                reason: reasoning,
            });
        } else {
            n_defer += 1;
            all_deferred.push(#{
                round: round_n,
                title: f.title,
                file: f.file,
                reason: reasoning,
                specialty: f.specialty,
            });
        }
    }

    write_scratch_file("round-" + round_n.to_string() + "-decisions.md", decisions_md);
    log(round_label + " triage: accept=" + n_accept.to_string() + " reject=" + n_reject.to_string() + " defer=" + n_defer.to_string());

    all_round_stats.push(#{
        round: round_n,
        raised: deduped.len(),
        confirmed: confirmed.len(),
        accepted: n_accept,
        rejected: n_reject,
        deferred: n_defer,
    });

    if accepted.len() == 0 {
        log(round_label + ": nothing accepted — skipping fix and further rounds");
        break;
    }

    // ── Fix ───────────────────────────────────────────────────────────────
    phase("Fix");
    log(round_label + ": applying " + accepted.len().to_string() + " accepted findings");

    let fix_prompt = "";
    fix_prompt += "You are the implementing engineer applying ACCEPTED review fixes only.\n";
    fix_prompt += "Do not re-architect. Do not expand scope. Implement each accepted item's suggested_change / implementation_note.\n\n";
    fix_prompt += "Soft-fail / soft-type fixes:\n";
    fix_prompt += "1. Determine the exact expected type (domain, API, DB, callers).\n";
    fix_prompt += "2. Tighten that hard type; validate once at the boundary.\n";
    fix_prompt += "3. Remove the silent fallback / empty default / type-papering.\n";
    fix_prompt += "4. NEVER fix with any, as any, as unknown as T, blanket !, or by making more fields optional.\n";
    fix_prompt += "If applying a fix breaks the build/types, put it in rejected_during_apply with reason — do not silently drop.\n";
    fix_prompt += "Verify build/typecheck for touched projects.\n\n";
    fix_prompt += "## Plan (JSON)\n";
    fix_prompt += plan_json;
    fix_prompt += "\n\n## Accepted findings to apply\n";
    fix_prompt += json_encode(accepted);
    fix_prompt += "\n\nReturn summary, files_touched, build_ok, applied (titles), rejected_during_apply.\n";

    let fix_result = agent(fix_prompt, #{
        label: round_label + "-fix",
        capability_mode: "all",
        agent_type: "general-purpose",
        output_schema: fix_schema,
    });

    if fix_result != () && fix_result.success && fix_result.output != () {
        let fx = fix_result.output;
        let fx_files = as_array(fx.files_touched);
        if fx_files.len() > 0 {
            files_touched = merge_files(files_touched, fx_files);
            files_block = files_prompt_block(files_touched);
            let fm = "";
            for f in files_touched {
                fm += as_string(f);
                fm += "\n";
            }
            write_scratch_file("files-touched.md", fm);
        }
        for t in as_array(fx.applied) {
            all_accepted_applied.push(#{ round: round_n, title: as_string(t) });
        }
        for r in as_array(fx.rejected_during_apply) {
            all_rejected.push(#{
                round: round_n,
                title: as_string(r.title),
                reason: "rejected during apply: " + as_string(r.reason),
            });
        }
        let build_ok_str = "unknown";
        if fx.build_ok != () { build_ok_str = fx.build_ok.to_string(); }
        log(round_label + " fix done build_ok=" + build_ok_str);
    } else {
        log(round_label + ": fix agent failed — stopping further rounds");
        break;
    }

    round_n += 1;
}

// ── Summary ────────────────────────────────────────────────────────────────

phase("Summary");
log("Writing final summary");

let summary_md = "";
summary_md += "# Peer review summary\n\n";
summary_md += "**Spec source**: see scratch/spec.md\n";
summary_md += "**Review model**: plan → implement → parallel specialists → adversarial verify (fail-closed) → independent triage → fix";
if max_rounds > 1 {
    summary_md += " → optional delta re-review";
}
summary_md += "\n";
summary_md += "**Max rounds**: ";
summary_md += max_rounds.to_string();
summary_md += "\n**Files touched**: ";
summary_md += files_touched.len().to_string();
summary_md += "\n\n## What was built\n\n";
summary_md += as_string(impl.summary);
summary_md += "\n\n## Review rounds\n";

for st in all_round_stats {
    summary_md += "\n### Round ";
    summary_md += st.round.to_string();
    summary_md += "\n- Raised (pre-verify): ";
    summary_md += st.raised.to_string();
    summary_md += "\n- Confirmed (post-verify): ";
    summary_md += st.confirmed.to_string();
    summary_md += "\n- Accepted: ";
    summary_md += st.accepted.to_string();
    summary_md += " | Rejected: ";
    summary_md += st.rejected.to_string();
    summary_md += " | Deferred: ";
    summary_md += st.deferred.to_string();
    summary_md += "\n";
}

summary_md += "\n## Applied fixes\n";
if all_accepted_applied.len() == 0 {
    summary_md += "\n(none)\n";
} else {
    for a in all_accepted_applied {
        summary_md += "- R";
        summary_md += a.round.to_string();
        summary_md += ": ";
        summary_md += a.title;
        summary_md += "\n";
    }
}

summary_md += "\n## Deferred items\n";
if all_deferred.len() == 0 {
    summary_md += "\n(none)\n";
} else {
    for d in all_deferred {
        summary_md += "- R";
        summary_md += d.round.to_string();
        summary_md += " [";
        summary_md += d.specialty;
        summary_md += "] ";
        summary_md += d.title;
        summary_md += " (";
        summary_md += d.file;
        summary_md += "): ";
        summary_md += d.reason;
        summary_md += "\n";
    }
}

summary_md += "\n## Rejected items\n";
if all_rejected.len() == 0 {
    summary_md += "\n(none)\n";
} else {
    for r in all_rejected {
        summary_md += "- R";
        summary_md += r.round.to_string();
        summary_md += ": ";
        summary_md += r.title;
        summary_md += " — ";
        summary_md += r.reason;
        summary_md += "\n";
    }
}

if strongest_arch != "fine" {
    summary_md += "\n## Architecture sense-check (user advisory)\n\n";
    summary_md += "**Verdict**: ";
    summary_md += strongest_arch;
    summary_md += "\n\nFor your consideration — the architecture sense-check thought:\n\n";
    summary_md += strongest_arch_note;
    summary_md += "\n\nThis is not a rewrite demand and was never triaged as implementable work during the loop.\n";
}

summary_md += "\n## Artifacts\n";
summary_md += "- scratch/spec.md\n- scratch/plan.md\n- scratch/files-touched.md\n";
summary_md += "- scratch/round-*-comments.md / confirmed.md / decisions.md\n";
summary_md += "- scratch/round-1-architecture-note.md (if produced)\n";

let report_path = write_scratch_file("summary.md", summary_md);

// Optional: polish report via agent for readability (cheap single call)
let polish = agent(
    "Polish this peer-review summary for a human reader. Keep all facts, counts, deferred items, and architecture note. Return only markdown in report_markdown. Do not invent findings.\n\n" + summary_md,
    #{
        label: "summary-polish",
        capability_mode: "read-only",
        output_schema: summary_schema,
    }
);
if polish != () && polish.success && polish.output != () && polish.output.report_markdown != () {
    let polished = polish.output.report_markdown;
    if trimmed(polished) != "" {
        report_path = write_scratch_file("summary.md", polished);
        summary_md = polished;
    }
}

log("Peer-review complete → " + report_path);

complete(#{
    ok: true,
    path: report_path,
    report: summary_md,
    files_touched: files_touched,
    rounds: all_round_stats,
    deferred: all_deferred,
    architecture: #{
        verdict: strongest_arch,
        note: strongest_arch_note,
    },
    plan_path: plan_path,
    spec_path: spec_path,
});
