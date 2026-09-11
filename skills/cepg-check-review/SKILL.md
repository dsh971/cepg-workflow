---
name: cepg-check-review
description: Tiered code review — default persona review plus built-in comment hygiene, a blast-radius pass that proves safety by running real code, and two escalation tiers (in-process multi-model interrogation and an external Codex second opinion, collapsing to interrogation-only on a Codex host) for high-risk diffs, topped by a thermo-nuclear structural-quality pass for the deepest tier. Use before creating a PR, after finishing a task, or whenever code-quality or safety feedback on a diff is needed.
argument-hint: "[blank reviews the current branch against its base; or a PR link, branch name, or explicit ref]"
---

**Platform note.** On Codex or another non-Claude runtime, the Claude tool names, `Agent`/`Task` dispatch, and model slugs named below are Claude defaults. Resolve them via [`codex-tools.md`](../../references/codex-tools.md) — this includes the host-detection method the escalation-tier collapse rule (Tier 2) depends on.

**Artifact root note.** Every `docs/...` path below (Protected Artifacts) assumes the default artifact root. A project with a configured `docs_root` relocates it the same way — see [`artifact-root.md`](../../references/artifact-root.md).

# Check — Code Review

## Outcome

- **Result:** A single merged, deduplicated findings report for the reviewed diff, gated by severity (P0-P3) and confidence, covering correctness plus every risk-driven specialist lens the diff actually warrants, a proven (not merely asserted) blast-radius safety fact, comment hygiene, and — for high-risk diffs — independent multi-model escalation.
- **Done:** Every dispatched persona has returned or been recorded as skipped with a reason; the blast-radius pass has produced a proven-or-marked-unproven safety fact; escalation ran on both available paths when the diff was high-risk (or on the Codex-host-collapsed path when running on Codex); no finding appears twice under two different tier labels.
- **Not this skill's job:** root-cause debugging lives in `cepg-check-debug`; applying fixes beyond report-only findings is `/cepg-build`'s job unless the caller explicitly authorized local apply; opening a PR or deploying is `/cepg-ship`'s job.

## Phase 0 — Resolve scope

Determine the diff the same way Build resolves its target: no argument reviews the current branch against its merge-base with the default branch; a PR link/number, branch name, or explicit ref reviews that target instead. Compute the file list and diff (`git diff -U10 <base>`), and list any untracked files separately rather than silently including or blocking on them.

Write a 2-3 line intent summary (what the diff is trying to accomplish, drawn from commit messages, PR description, or conversation context) — every dispatched persona and escalation tier receives this, since it shapes how hard each one looks without changing which ones get selected.

## Phase 1 — Default tier: persona review

Read `references/personas/<name>.md` for each persona you select below before dispatching it. Dispatch every selected persona as a generic subagent seeded with that file's content — per the cross-lineage specialist-dispatch convention (skill-authoring template), never as a named custom agent type. Launch the full selected roster in one batch (foreground, one message, multiple `Agent`/`Task` calls) and collect every return before merging; degrade to serial dispatch if the host caps concurrency.

**Always-on** (dispatch regardless of diff size or domain):

| Persona | Why |
|---|---|
| `correctness-reviewer` | Every diff can carry a logic bug; this is the one lens with no size or domain gate. |
| `testing-reviewer` | For any diff changing test files, test infrastructure, or meaningful runtime behavior. |
| `maintainability-reviewer` | For any diff over ~50 changed executable lines, or any size that's structurally significant (new abstraction, file move, coupling change). |
| `comment-hygiene-reviewer` | Runs on any diff touching source comments — this is pstack's `no-comments`/`comment-sicko` pass folded in here, not shipped as a separate command. |

**Conditional** (dispatch when the diff shows the matching signal — read the persona file's own gate before deciding, don't select on filename alone):

| Persona | Signal |
|---|---|
| `security-reviewer` | Auth, public endpoints, user input handling, permission checks, or backend surface over ~100 lines. |
| `performance-reviewer` | Database queries, loop-heavy transforms, caching, I/O-intensive paths, or frontend rendering/bundling. |
| `api-contract-reviewer` | Routes, request/response types, serialization, versioning, or exported type signatures a consumer relies on. |
| `data-migration-reviewer` | A migration or schema-dump artifact is actually present in the diff — never on inferred data impact alone. |
| `reliability-reviewer` | Error handling, retries, circuit breakers, timeouts, health checks, background jobs, or async handlers. |
| `adversarial-reviewer` | 50+ changed lines, or any size touching auth/payments/persistence writes/event publication/retry-concurrency semantics/external APIs, or a silent-pass verification mechanism. Dispatch this one last among the roster (see the persona file) and pass it a one-line summary of what the others already found. |

**Advisory** (report-only, never gates the verdict):

| Persona | Signal |
|---|---|
| `simplification-reviewer` | Diff over ~100 changed lines. Findings are always `P3`/`advisory` and are excluded from any severity-based gate. |

For an instruction-prose-only diff (Markdown skill files, JSON schemas, config with no runtime behavior), skip the runtime-focused personas (`performance`, `reliability`, `adversarial`) unless the prose itself describes auth/payment/data-mutation behavior or the change is itself a verification mechanism.

Every persona returns the same JSON shape (see any persona file's "Output format"): `reviewer`, `findings[]` (each with `severity` P0-P3, `confidence` 0-100, `file`/`line`, `summary`, `suggested_fix`, `autofix_class`, `owner`), `residual_risks[]`, `testing_gaps[]`. Collect every persona's return before merging, but keep the parent's own visible context to that structured JSON, not each persona's full raw reasoning trace -- mined from pstack's `principle-guard-the-context-window`.

### Protected artifacts

Adapted from Compound Engineering's own `ce-code-review` guard: no reviewer -- `simplification-reviewer` and `maintainability-reviewer` especially -- may flag any file for deletion, removal, or gitignore when it lives under `plans/`, `solutions/`, `scope/`, or the legacy `brainstorms/` **and that directory's own immediate parent is the artifact root** (`docs/`, by default -- see `references/artifact-root.md`). The immediate-parent test qualifies the `plans/`/`solutions/`/`scope/`/`brainstorms/` directory itself, not each individual file underneath it -- so it protects everything nested inside, including category subfolders (e.g. `docs/solutions/<category>/foo.md`), while leaving a same-named directory rooted elsewhere in the repo -- a skill's own `references/personas/` assets, parented by `references`, not by the artifact root -- as ordinary code whose deletion finding stands. These are this plugin's own decision and learning artifacts, not dead weight. Discard any such finding during Phase 5's merge rather than letting it reach the report.

## Phase 2 — Blast-radius pass

Runs after the persona roster returns, before either escalation tier, on every review — this is pstack's `blast-radius` technique, and its point is that a diff can look safe on its own and still break something downstream that grep won't show you.

1. Read the diff and find **the one fact it's safe because of** — most changes that look risky are safe because of a single fact (e.g. "this call only touches already-dead cache entries"). Spend your time finding that fact, not enumerating maybes.
2. Look where grep stops: library source at the pinned version, wire formats, DB columns another service reads, feature flags, code several hops downstream.
3. Get that one fact as far down this ladder as is cheap, and say where it stopped: (1) asserted, (2) pointed at a `file:line`, (3) walked step-by-step to show the bad case can't happen, (4) proven by running a script or test against the real code, (5) reproduced in the running app. Anything short of (4) is reported as **unproven**, not settled.
4. List the risks you found real chances and real costs for, and the risks you checked and cleared, separately.

If this pass proves the safety fact only up to level 2 or 3 (never ran real code) on a diff that also matches the high-risk criteria below, that gap itself is a reason to escalate — an unproven safety-critical fact is exactly what Tier 1 exists to get a second opinion on.

## Phase 3 — Escalation tiers

### Determining high-risk

A diff is high-risk when any of: it touches auth, payments, or data mutation; `security-reviewer` or `adversarial-reviewer` returned a P0/P1 finding; the diff is large (roughly 200+ changed lines) by the same measure `adversarial-reviewer` uses for its Deep tier; or Phase 2's blast-radius safety fact stopped below level 4 (unproven) on a diff that also shows a risk signal. A high-risk diff triggers **both** escalation paths below on a Claude Code host. On a diff that isn't high-risk, stop after Phase 2 and produce the report (Phase 4).

### Tier 1a — interrogate (in-process multi-model dispatch)

Dispatch one reviewer subagent per configured model — same mechanism as pstack's `interrogate` skill: model diversity is the adversarial signal, not assigned personas, so every reviewer gets the same intent summary, diff, and review rubric. State the intent explicitly before dispatch. Collect all reviewers' findings, then apply lead judgment across four buckets — **act on** (would block a real PR), **consider** (legitimate, cost/benefit unclear), **noted** (valid but not actionable now), **dismissed** (wrong or missing context, with a one-line reason). Findings 2+ models raise independently are the highest-signal bucket; note agreement and disagreement explicitly in the report.

### Tier 1b — /codex (external shell-out)

Dispatch an external Codex CLI review scoped to the same base (`codex review --base <base>`, read-only sandbox), per gstack's `codex` skill review mode.

**Data-handling clause (non-negotiable):** this path sends diff content to an external process outside this host's trust boundary. Before shelling out, scrub the diff for secrets and credentials — API keys, tokens, passwords, connection strings, private key material, session tokens — the same categories `security-reviewer` hunts for. Redact matches in place (e.g. `«redacted: looks like an API key»`) rather than skipping the whole hunk, so the rest of the diff still gets reviewed. Never pass raw `.env` contents or credential files through this path even if they appear in the diff.

**Codex-host collapse rule:** shelling out to Codex *from* a Codex-hosted install of this skill isn't an independent second opinion — same model family reviewing itself. Detect the host per `codex-tools.md`'s method; on a Codex host, skip this tier entirely and note explicitly in the report that escalation ran interrogate-only because of the host, not because the diff didn't qualify.

**Gate logic (fails closed):** a run that can't be verified is a FAIL, never a PASS, in this order:
1. Non-zero/timeout exit → FAIL (fail-closed: the review didn't complete).
2. Empty or whitespace-only output → FAIL (fail-closed: nothing was reviewed).
3. Output contains a `P0`/`P1`-equivalent tag → FAIL (N critical findings).
4. Output has no severity tags at all → FAIL (fail-closed: can't mechanically verify "no critical findings" without them — a human reads the verbatim output).
5. Tags present, none above P2 → PASS.

Present Codex's output verbatim (never summarized or truncated) alongside the gate verdict.

### Escalation synthesis

When both Tier 1 paths ran, cross-reference their findings the same way `codex`'s own skill does: what both found (highest confidence), what only interrogate found, what only Codex found, and the agreement rate. A disagreement between the two paths on the same code location is itself worth surfacing to the human, not silently resolved by picking one side.

## Phase 4 — Deepest tier: thermo-nuclear structural review

Invoke only on explicit request for a maximally strict pass, or when Phase 1/3 findings converge on structural concerns severe enough that the ordinary `maintainability-reviewer` bar undersells them (e.g. the persona and both escalation paths all flag the same file for spaghetti growth or a near-1000-line crossing). This tier is pstack's `thermo-nuclear-code-quality-review` content, applied to the diff and the files it touches:

- Push for "code judo": a restructuring that deletes whole branches/helpers/layers rather than rearranging the same complexity.
- Presumptive blockers unless justified: a file crossing 1000 lines because of this diff; ad-hoc branching tangling an existing flow; feature logic scattered into shared paths; an unnecessary wrapper/cast/optionality churn obscuring the real design; a bespoke helper duplicating an existing canonical one.
- The deliverable is layered, not a single report: a short (~200-line) summary — verdict, each finding as a narrative paragraph, a proposed remediation sequence — plus one detail file per subsystem carrying the measurements and worked code-judo proposals. Keep detail files on disk; don't compress them into the summary.
- This tier is demanding but not rude: name the structural problem and the missed dramatic-simplification opportunity plainly, without softening either into a mild suggestion.

## Phase 5 — Merge, dedupe, and report

1. **Fingerprint every finding** across every tier that ran (personas, blast-radius, both escalation paths, thermo-nuclear) as `file:line:category` (or `file:category` when no line applies). Findings sharing a fingerprint are the same issue seen from a different lens, not separate findings.
2. **Merge duplicates**: keep the higher-confidence version, tag it with every tier/persona that raised it, and boost confidence when 2+ independent tiers agree (mirrors gstack's multi-specialist confirmation). This is what makes the "no duplicate findings across tiers" verification criterion hold — a finding both `security-reviewer` and Tier 1b's Codex pass raised is one line in the report with both sources credited, not two.
3. **Apply the severity/confidence gate**: P0/P1 always surface; P2/P3 at low confidence (anchor ≤25 per the persona files) are suppressed; simplification and comment-hygiene findings are always shown separately from the severity-gated set, never folded into a "quality score." Drop any finding that trips the Protected Artifacts guard above before it reaches this gate -- a correctly-scoped deletion finding never needed the guard in the first place.
4. **Render the report**: verdict (Ready to merge / Ready with fixes / Not ready), findings grouped by severity with source tier(s) credited, the blast-radius safety fact and its proof level, the comment-hygiene section, and — when escalation ran — the Tier 1 synthesis and, when Phase 4 ran, a pointer to its detail files.
5. Never push, open a PR, or apply fixes from this skill unless the caller explicitly authorized local apply for this invocation; report-only is the default, matching Build's Gate 3 default-to-reversible/pause-on-irreversible framing (this skill's default output is inherently reversible — a report — so no confirmation is needed to produce it).

## Common pitfalls

- Selecting `data-migration-reviewer` on inferred data impact instead of an actual migration/schema artifact in the diff — its own gate exists precisely to prevent noise here.
- Running the `/codex` shell-out on a Codex host and treating it as a second opinion — collapse to interrogate-only and say so.
- Skipping the secret-scrub step before the `/codex` shell-out because the diff "looks clean" — scrub unconditionally, it's cheap.
- Treating an asserted or `file:line`-pointed blast-radius claim as proof — only a run of real code (level 4+) closes that gap.
- Letting `simplification-reviewer` or `comment-hygiene-reviewer` findings leak into the P0-P3 severity gate that decides the verdict — they're report-only by design.
- Re-listing the same issue once per tier in the final report instead of merging by fingerprint first.
