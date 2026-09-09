---
date: 2026-09-02
topic: pstack-ce-plugin-merge
---

# Unify Compound Engineering, gstack, and pstack into one command surface

## Summary

Combine three Claude Code plugins into one publishable plugin with a single small set of unified phase commands, instead of three separate command surfaces: gstack supplies outer-loop bookends (scope sign-off, specialist review, QA, security, shipping), Compound Engineering is the inner-loop brain (plan, work, review, compound), and pstack is mined for specific execution disciplines folded into CE's and gstack's steps rather than run as a live fourth plugin.

## Problem Frame

pstack alone collides with CE because both compete for the same inner-loop job — this session hit that collision directly (Problem Frame carried over from the original two-plugin brainstorm). gstack does not have this problem: it owns a genuinely different outer-loop layer (product framing, specialist sign-off, QA, security, shipping), and public prior art already documents exactly this split — "gstack handles the outer loop: what gets built, how it ships. Compound Engineering handles the inner loop: making each cycle through the outer loop better than the last." No equivalent public prior art exists for combining pstack with either plugin. Meanwhile, running all three as separately-installed plugins means switching command surfaces mid-task — `/ce-plan` for one phase, a gstack role-command for another, a pstack skill for a third — which is the exact friction driving this brainstorm now.

## Key Decisions

- **CE is the brains; pstack is mined, not installed live.** pstack's SessionStart hook and skill routing are not shipped as a fourth plugin. Specific pstack disciplines (`architect`'s type-first design, reproduce-before-fix, prove-it-works verification, reversibility-based autonomy, `interrogate`'s cross-model review, `blast-radius`, `babysit`, `reflect`) are folded directly into CE's and gstack's own steps.
- **gstack owns the outer-loop bookends.** Scope validation and specialist sign-off (product, architecture, design, DX) run before CE's plan; QA, security, and shipping run after CE's review. This mirrors the documented public gstack+CE pattern and avoids the collision pstack has with CE.
- **A small set of unified phase commands replaces the combined ~100+ source commands.** The combined surface across CE (32 skills), gstack (43 commands + 11 binaries), and pstack (52 skills) is too large to consolidate 1:1. Instead, one phase command per stage — Scope, Plan, Build, Check, Ship, Learn — dispatches internally to whichever underlying skill(s), from any lineage, fit the task. Skill-level merges within a phase follow the same "combine only if actually the same job" review used for the original CE+pstack pass.
- **Knowledge compounding layers three systems rather than picking one.** gstack's GBrain (indexed repo/code knowledge), CE's `docs/solutions/` + `CONCEPTS.md` (narrative learnings), and pstack's `reflect` (self-editing skill instructions) capture different things and stack: GBrain indexes the codebase, `docs/solutions/` captures what was learned, `reflect` decides when a learning is significant enough to become a skill-level rule change rather than a doc entry.
- **Fork once, diverge freely — now against three moving targets.** No live sync against any of the three source projects. gstack ships its own self-updater (`/gstack-upgrade`) and SessionStart/Stop hooks, so it is also an actively-evolving project the same way pstack is; the same divergence risk applies to both.

## Requirements

**Packaging & command surface**
- R1. The merged plugin ships as a single installable package covering, at minimum, the platforms all three source projects support in common — Claude Code and Codex.
- R2. A small set of unified phase commands (Scope, Plan, Build, Check, Ship, Learn) is the primary way to invoke the system; each dispatches internally to whichever underlying skill fits, so the user never has to know or choose which source plugin a capability came from.
- R3. pstack is not installed as a live plugin. Its SessionStart hook is not shipped; its disciplines are folded into CE's and gstack's own skills at build time.
- R4. The merged plugin is a one-time fork/adaptation of all three source projects' current state, with no live sync or rebase mechanism against any of them.

**Phase: Scope & Sign-off** (gstack-led)
- R5. Before planning starts, the unified surface offers gstack-derived scope validation and specialist sign-off — product framing, architecture lock-in, design and DX review — as one phase command rather than four separate ones.

**Phase: Plan** (CE-led, sharpened by pstack)
- R6. Planning runs on CE's `ce-plan`, sharpened by pstack's type/module-shape-first discipline before any implementation detail is written.

**Phase: Build** (CE-led, sharpened by pstack)
- R7. Execution runs on CE's `ce-work`, gaining pstack's reproduce-before-fix discipline for bugs, a prove-it-works verification gate before declaring work done, and reversibility-based autonomy so the phase doesn't ask more than it needs to.

**Phase: Check** (new — blends all three)
- R8. A distinct check phase sits between build and ship: CE's tiered persona review, a blast-radius pass that proves safety by running real code rather than just reading the diff, and a cross-model adversarial review escalation tier (merging gstack's `/codex` and pstack's `interrogate`, which are the same idea from two lineages).

**Phase: Ship** (gstack-led, gains pstack persistence)
- R9. Shipping runs on gstack's QA and release commands through production deploy and health verification, with pstack's `babysit` folded in so the phase stays attached to a PR unattended — fixing CI failures and handling straightforward comments — rather than being a one-shot pass. Production deploy stays gated behind gstack's existing `/careful`/`/freeze`/`/guard` safety primitives rather than firing unattended by default.

**Phase: Learn** (CE-led, gains pstack + gstack)
- R10. Compounding produces three coordinated outputs, not three competing ones: CE's `docs/solutions/`/`CONCEPTS.md` entries, a GBrain re-index, and a `reflect`-style decision on whether the learning warrants a skill-level edit.

## Skill Consolidation Map

Extends the original CE+pstack review with gstack. Rows unchanged from the prior pass are marked "same call as before"; new three-way overlaps and gstack-only additions are new. Cluster names and calls are a starting point for planning, not final skill boundaries.

| Cluster | CE skill(s) | gstack skill(s) | pstack skill(s) | Call | Why |
|---|---|---|---|---|---|
| Debugging | `ce-debug` | `/investigate` | `tdd` | Merge | Three sources doing root-cause debugging; reproduce-first (pstack) and CE's investigation structure combine. `/investigate` needs a closer read at planning time to see what it adds beyond the other two. |
| Code review | `ce-code-review` | `/review`, `/codex` | `interrogate`, `thermo-nuclear-code-quality-review`, `no-comments`/`comment-sicko` | Merge, as tiers | Persona review (CE) as default, cross-model second opinion (`/codex` + `interrogate` — the same idea from two lineages) as escalation, thermo-nuclear as the deepest tier, comment hygiene as a built-in pass. |
| Code cleanup | `ce-simplify-code` | — | `deslop` | Merge | Same call as before; no gstack equivalent. |
| PR shipping & release | `ce-commit-push-pr`, `ce-resolve-pr-feedback` | `/ship`, `/land-and-deploy` | `fix-ci`, `fix-merge-conflicts`, `get-pr-comments`, `make-pr-easy-to-review`, `babysit` | Merge; gstack adds a new stage | Collectively "get this PR to green, merged, deployed, and health-checked" (R9). `/land-and-deploy`'s production-deploy step is a capability neither CE nor pstack has at all; included, gated behind gstack's existing safety primitives. |
| Planning & architecture | `ce-plan` | `/plan-eng-review`, `/autoplan` | `architect` | Keep separate, chained | Same CE+pstack call as before; gstack's review/autoplan commands become the Scope & Sign-off phase ahead of `ce-plan`, not merged into it. |
| Requirements discovery / scoping | `ce-brainstorm` | `/office-hours`, `/plan-ceo-review`, `/spec` | `figure-it-out`, `how` | Not combined; review `/spec` at planning time | pstack call stands (different jobs). gstack's office-hours/CEO-review commands become the Scope & Sign-off phase rather than merging with `ce-brainstorm`. `/spec`'s mechanics weren't read in enough depth here to call a merge — flagged for planning. |
| Knowledge capture | `ce-compound`, `ce-compound-refresh` | GBrain (`setup-gbrain`, `sync-gbrain`) | `recall`, `reflect`, `what-did-i-get-done` | Layer, not merge | Three different jobs that stack (see Key Decisions). `recall` and `what-did-i-get-done` stay pstack-only, no counterpart. |
| Parallel execution | `ce-optimize` | — | `arena`, `swarm` | Not combined | Same call as before. |
| Design & DX review | — | `/plan-design-review`, `/plan-devex-review`, `/design-review` | — | New, gstack-only | No CE or pstack counterpart; folds into Scope & Sign-off as-is. |
| QA & security | — | `/qa`, `/qa-only`, `/cso`, `/benchmark`, `/canary` | — | New, gstack-only | No CE or pstack counterpart; becomes the Check/Ship phases' QA and security coverage. |
| Principle discipline | — | — | 18 `principle-*` skills | Not combined; stay standalone | Same call as before; embedded inside consolidated execution skills. |
| gstack infrastructure (browser automation, iOS tooling, safety locks, diagramming, PDF publishing) | — | `/browse`, `ios-*`, `/careful`/`/freeze`/`/guard`, `/diagram`, `/make-pdf`, `gstack-*` binaries | — | Not touched | Utility layer with no CE or pstack counterpart; carried over as-is, outside the phase-command consolidation. |

## Scope Boundaries

**Deferred for later**
- A live-sync or rebase mechanism to pull future upstream changes from any of the three source projects.
- New platform adapters beyond what the three source projects already cover natively.
- Full integration of gstack's iOS-specific tooling beyond carrying it over unchanged.

**Outside this product's identity**
- A superset exposing every command from all three plugins — the goal is the six unified phase commands (R2), not the union of ~100+ source commands.
- Rebuilding gstack's browser-automation, iOS, or GBrain-indexing infrastructure — these are carried over as gstack-sourced utilities, not redesigned.
- Consolidating pstack's `principle-*` skills or CE/gstack skills with no counterpart elsewhere (`ce-strategy`, `ce-promote`, `ce-product-pulse`, gstack's safety locks, diagramming, PDF publishing) — these stay as-is.

## Dependencies / Assumptions

- Assumes all three source projects' skill/command inventories (as inspected during this brainstorm) are stable enough to fork from. All three are actively versioned — CE has at least two recent version bumps cached locally, gstack ships its own self-updater and SessionStart/Stop hooks, pstack is pre-1.0 (v0.9.12) — so exact inventories should be re-verified at planning time.
- Verified directly from gstack's README: its SessionStart hook only performs a throttled, silent update check (not task routing) and its Stop hook only closes dangling timeline entries — it does not recreate the routing collision pstack's hook caused.
- Platform overlap across all three source projects is limited to Claude Code and Codex; CE and gstack additionally share Cursor and OpenCode, but neither of those two is covered by pstack.

## Outstanding Questions

**Deferred to Planning**
- Final command/skill names for each phase and cluster — this doc names phases and clusters, not final names.
- The merged plugin's own name and branding.
- Router classification rules for edge cases between phases (e.g., a debugging session that surfaces a scope question).
- Whether gstack's `/spec` overlaps enough with `ce-brainstorm`/`ce-plan` to consolidate.
- Whether gstack's `/investigate` adds anything to the CE+pstack debugging merge beyond what's already covered.
