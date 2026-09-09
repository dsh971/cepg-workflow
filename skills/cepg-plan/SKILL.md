---
name: cepg-plan
description: "Create an implementation-ready technical plan for a feature, fix, or refactor -- research, decisions, and dependency-ordered Implementation Units, each naming its core data/type shapes before behavior. Use when asked to plan, break down implementation, plan from a Scope-skill output or requirements doc, or deepen an existing plan."
argument-hint: "[feature description, or path to a Scope-skill output / plan to deepen]"
---

# Plan

**Platform note.** On Codex or another non-Claude runtime, the Claude tool names and model slugs named below are Claude defaults. Resolve them via [`codex-tools.md`](../../references/codex-tools.md).

Plan answers **HOW** to build something whose **WHAT** the Scope skill (or the user) has already framed. It produces decisions, not code: approach, boundaries, files, dependencies, risks, and test scenarios, dependency-ordered into Implementation Units an implementer can start from without inventing the plan themselves.

This skill does not implement code, run tests, or probe runtime behavior. If the answer depends on changing code and seeing what happens, that belongs to the Build skill, not here.

Lineage: this skill carries forward Compound Engineering's `ce-plan` phase structure -- source-document use, research, question resolution, Implementation Unit structuring, writing, confidence check -- compressed to fit this plugin's smaller command surface. It adds one thing `ce-plan` leaves to the implementer's discretion: a dedicated step, before any Implementation Unit is drafted, that names the core data and type shapes any unit crossing a function boundary will touch. That step is mined from pstack's `architect` skill, which sketches types and signatures before code so the shape gets designed on purpose instead of accreting one function at a time. See "Phase 3: Name the Core Data/Type Shapes" below for how that framing is applied here -- this skill does not reproduce `architect`'s multi-model arena or its scrap/redesign loop, both of which belong to live implementation, not a planning document.

## Core Principles

1. **Decisions, not code.** Capture approach, boundaries, dependencies, risks, and test scenarios. Pseudo-code or a type sketch is fine when it communicates direction, but it is never implementation-ready syntax.
2. **The upstream source is authoritative.** If a Scope-skill output or requirements doc exists, enrich it -- don't re-litigate WHAT to build.
3. **Research before structuring.** Ground the plan in the repo's actual patterns before writing units.
4. **Shape before behavior.** Before drafting Implementation Units, name the data/type shapes that will cross a function boundary. Behavior gets designed against a shape, not the other way around.
5. **Right-size the plan.** A small fix gets a compact plan; cross-cutting or high-risk work gets more structure. The discipline is the same at every size.
6. **Separate planning-time from execution-time unknowns.** Resolve what's knowable now; defer what depends on seeing real code run, explicitly, rather than faking certainty.
7. **Repo-relative paths, always.** Never write an absolute path into a plan -- it breaks portability across machines and teammates.

## Workflow

### Phase 0: Source and Scope

**Resume check.** If the user references an existing plan file, or a clearly matching plan exists under `docs/plans/`, read it and confirm whether to update it in place or start a new one. Plans don't carry per-unit progress state -- that's derived from git during Build -- so resuming means revising still-relevant sections, not restoring a checklist.

**Find the upstream source.** Before asking planning questions, look for:
1. An explicit path the user gave (a Scope-skill sign-off doc, a prior plan, a bug report).
2. A recent, topically-matching Scope-skill output (product framing, architecture lock-in, design/DX sign-off) -- conventionally under `docs/scope/`, paralleling `docs/brainstorms/`'s convention for legacy requirements docs.
3. A legacy requirements or brainstorm doc under `docs/brainstorms/`.

If one is relevant (same problem, not stale), read it fully and treat it as the primary input: carry forward its problem frame, scope boundaries, key decisions, and any unresolved-but-not-blocking questions. Reference carried-forward decisions in the plan as `(see origin: <path>)`. Do not silently drop anything it covered -- if a section is out of scope for this plan, say so explicitly rather than omitting it.

If no upstream source exists, run a brief planning bootstrap directly with the user: problem frame, intended behavior, scope boundaries, success criteria, blocking questions or assumptions. Keep it tight -- this is not a substitute for the Scope skill, just enough to plan responsibly when the user wants to skip straight to Plan.

**Classify remaining blockers.** If the source (or the bootstrap) leaves true product blockers -- something that would change scope or success criteria, not just implementation detail -- surface them and ask the user, via the platform's blocking-question tool (`AskUserQuestion` in Claude Code; call `ToolSearch` with `select:AskUserQuestion` first if its schema isn't loaded), whether to resolve them now as explicit assumptions or send the work back to Scope. Do not plan past an unresolved product blocker.

**Assess depth.** Classify the work as **Lightweight** (small, bounded, 2-4 units), **Standard** (normal feature or bounded refactor, 3-6 units), or **Deep** (cross-cutting, high-risk, or highly ambiguous, 4-8 units, possibly phased). If unclear, ask one targeted question.

**Confirm scope before research.** Research and plan-writing are the expensive steps -- a scope misread caught here costs one exchange; caught after the plan is written, it costs the whole plan. Before starting Phase 1, state back a short scope claim: what this plan will target, what it explicitly won't, in the source's own vocabulary -- not an Implementation Unit list, not a file inventory, since neither exists yet. If anything about the source or bootstrap left a genuine fork where the user's answer would change direction (narrower vs. broader coverage, whether an adjacent cleanup is in or out, which of two viable approaches to take), name it as a one-line call-out.

- **Standard or Deep**, or **any tier with at least one call-out**: present the scope claim and call-outs, then wait for confirmation via the blocking-question tool before proceeding to Phase 1.
- **Lightweight with no call-out**: state the one-line scope claim and proceed to Phase 1 without waiting -- e.g. "Planning: <one-line scope> -- proceeding to research." The user can still redirect if the scope is wrong.

This is a checkpoint, not a second bootstrap -- don't re-ask questions the source or Phase 0 bootstrap already resolved, and don't speculate about Implementation Units, file paths, or unit counts here; Phase 4 hasn't happened yet.

### Phase 1: Research

**Local research (always).** Look at the actual code this plan will touch: existing patterns, the files and modules that own the relevant behavior, and any project conventions in the active instructions file (`CLAUDE.md` / `AGENTS.md`). If a learnings doc directory (e.g. `docs/solutions/`) exists, check it for institutional context relevant to this feature. Use `Task`/`Agent` dispatch for this when the scope is broad enough to warrant a focused subagent; for a small plan, do it inline.

**External research (conditional).** Reach for external documentation, prior art, or best practices when:
- The user or the origin document explicitly asks for it (competitor comparison, "what should we borrow," official docs).
- The topic is high-risk (auth, payments, migrations, external APIs, compliance).
- The codebase has fewer than a handful of direct local examples of the pattern this plan needs.

Skip it when local patterns are strong and recent, and the user already knows the intended shape. Announce the decision briefly either way.

**Consolidate.** Summarize the patterns, files, constraints, and any external findings that will materially shape the plan. A finding that doesn't change a decision doesn't belong in the plan -- land it in a Key Decision's rationale or drop it, don't pad an appendix.

### Phase 2: Resolve Planning Questions

Build a short list of open questions from the origin document's deferred items, gaps research surfaced, and technical decisions the plan needs to be useful. For each, decide:
- **Resolvable now** -- the answer is knowable from repo context, docs, or a quick user choice. Resolve it and record the decision with a one-line rationale.
- **Deferred to implementation** -- the answer depends on runtime behavior or code that doesn't exist yet. Say so explicitly in the plan rather than guessing.

Ask the user only when the answer materially changes architecture, scope, sequencing, or risk, and can't be responsibly inferred. Use the blocking-question tool; ask one question at a time.

Do not run tests, build the app, or probe runtime behavior in this phase -- that's execution, not planning.

### Phase 3: Name the Core Data/Type Shapes

**Before drafting a single Implementation Unit**, identify the data and type shapes the plan's work will introduce or change -- specifically, any shape that will cross a function, module, or service boundary that more than one Implementation Unit will touch. This is the plan's type-first checkpoint, adapted from pstack's `architect` skill, which holds that sketching the shape before the behavior keeps the design from accreting one function at a time and locking in the wrong contract.

For each such shape, name (in prose or a short pseudo-code sketch -- never real, compilable syntax):
- What it represents and the fields or variants it carries.
- Which units create it, which units consume it, and at which boundary it crosses (function signature, API payload, persisted record, message/event shape).
- Any invariant a caller can rely on (e.g., "never null once constructed," "IDs are stable across retries").

Skip this step only when every unit is genuinely self-contained -- no unit's output is another unit's input, and nothing new crosses a boundary. For anything Lightweight-and-trivial (a config toggle, a copy change), say so in one line and move on rather than inventing a shape that doesn't exist.

This is directional, not implementation-ready: it fixes the shape a reviewer can validate and an implementer can build against, not the exact language syntax. If implementation later proves a shape wrong, that's a signal for the Build skill to raise back to this plan, not a reason to have specified the shape in code form here.

Carry the result forward as a short **Data/Type Shapes** section (see Phase 4) and cite it from any Implementation Unit that touches one of the named shapes.

### Phase 4: Structure the Plan

**Break the work into Implementation Units.** Each unit is one meaningful, atomically-committable change: focused on one component or integration seam, touching a small cluster of related files, ordered by dependency. Avoid micro-steps and avoid units so vague an implementer has to invent the plan.

Assign each unit a stable `U<N>` ID at creation. IDs are never renumbered once assigned -- reordering, splitting, or deleting a unit leaves gaps or keeps the original ID on the original concept; a new unit takes the next unused number.

For each unit, include:
- **Goal** -- what this unit accomplishes.
- **Requirements** -- which requirement, decision, or acceptance criterion from the origin source it advances.
- **Dependencies** -- prior U-IDs that must land first.
- **Files** -- repo-relative paths to create, modify, or test.
- **Data/Type Shapes** -- for any unit that creates, consumes, or crosses a boundary with a shape named in Phase 3, cite it here rather than re-describing it. Omit this field entirely for units that touch no such shape.
- **Approach** -- key decisions, data flow, integration notes. Cite governing decisions by ID rather than restating them.
- **Patterns to follow** -- existing code or conventions to mirror.
- **Test scenarios** -- specific, enumerated cases (happy path, edge cases, error paths, integration seams as applicable) naming input, action, and expected outcome. For units with no behavioral change, use `Test expectation: none -- <reason>` instead of leaving this blank.
- **Verification** -- how an implementer knows the unit is done, as an outcome, not a shell script.

**Keep planning-time and implementation-time unknowns separate.** If something matters but isn't knowable yet (exact helper names, final query shape, runtime-dependent behavior), record it explicitly as a deferred implementation note rather than pretending to resolve it.

**Route tangential findings to Deferred, not into units.** Anything research surfaces that's adjacent but outside confirmed scope -- a nice-to-have, a "while we're here" cleanup -- goes in a `Deferred to Follow-Up Work` note, not into an active unit, unless the user explicitly asked for it.

### Phase 5: Write the Plan

Never write implementation code, exact method signatures, or framework-specific syntax into the plan -- pseudo-code and type sketches are for direction only, framed as such. Never write git commands, commit messages, or exact test-command recipes.

**File naming.** `docs/plans/YYYY-MM-DD-NNN-<type>-<descriptive-name>-plan.md`, where `<type>` is `feat`, `fix`, or `refactor`, sequence number is the next unused 3-digit number for today's date, and the descriptive name is 3-5 words, kebab-cased. Create `docs/plans/` if it doesn't exist.

**Sections**, in order, omitting any that carry no information for this specific plan:
- Title and one-paragraph summary
- Problem frame and scope boundary (including what's explicitly out of scope)
- Requirements / success criteria, with a trace back to the origin source
- Key decisions, each with a one-line rationale and, when relevant, the alternative it was chosen over
- **Data/Type Shapes** (Phase 3's output) -- omit only when Phase 3 found nothing to name
- Implementation Units (Phase 4), in dependency order
- Risks and open questions genuinely deferred to implementation
- Sources (origin doc, research inputs) when they exist

All file paths in the plan are repo-relative. All prose is written tight -- lead with the decision, one idea per sentence, no padding a section just because the template lists it.

**Write the file to disk before presenting any next-step options.** Confirm with the absolute path so it's clickable:

```text
Plan written to <absolute path to plan>
```

### Phase 6: Confidence Check and Handoff

Before treating the plan as done, self-review against this checklist:
- Every major decision is grounded in the origin source or Phase 1 research, not invented.
- Every Implementation Unit is concrete, dependency-ordered, and buildable without further invention.
- Every unit that creates, consumes, or crosses a boundary with a named shape cites it under Data/Type Shapes -- no unit silently reinvents a shape Phase 3 already named.
- Every feature-bearing unit has real test scenarios (or an explicit `Test expectation: none` with a reason) -- not blank, not padded.
- Deferred items are explicit, not hidden as false certainty.
- U-IDs are unique and stable; no accidental renumbering.

For a **Standard** or **Deep** plan, or when a section still feels thin after the self-review, do one targeted strengthening pass: re-check the weakest section (usually Risks, a Key Decision's rationale, or a unit's test scenarios) against the research already gathered, and tighten it. Don't re-run full Phase 1 research to do this -- use what's already known.

**Hand off.** Present the plan's location and ask what the user wants next -- start the Build skill, review the open items, or make further edits. Use the blocking-question tool when available; otherwise render numbered options in chat. Don't end the turn on "created the plan" alone -- the plan isn't handed off until the user has been asked what's next and, if they answered, that routing has been carried out.
