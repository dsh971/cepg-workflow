---
name: cepg-build
description: Execute a plan, work item, or bug report end-to-end — triage the work, set up to execute, run the implementation loop with continuous testing and incremental commits, and verify the result against the real artifact before calling it done. Use when implementing from a plan or spec path, a clear work description, or a bug report; hands off to the Check skills for review and to Ship for delivery rather than doing either itself.
argument-hint: "[plan path, work description, or bug report; blank uses the plan or work most recently discussed in this session]"
---

**Platform note.** On Codex or another non-Claude runtime, the Claude tool names and model slugs named below are Claude defaults. Resolve them via [`codex-tools.md`](../../references/codex-tools.md).

# Build

## Outcome

- **Result:** A fully implemented, locally verified change set from a plan, spec, work description, or bug report.
- **Done:** Every in-scope task is complete, each one is backed by evidence checked against the real artifact (Gate 2), bug-shaped work carries a reproduction that failed before the fix and passes after (Gate 1), and the loop never stalled on a question it could have answered itself (Gate 3).
- **Not this skill's job:** Formal code review lives in `/cepg-check`; PR creation, CI babysitting, and production deploy live in `/cepg-ship`. Build stops at a verified, committed, review-ready change.

## Phase 0 — Triage the input

Classify `<input>` before doing anything else:

- **Plan or spec path.** Read its metadata/frontmatter first, then size your read to the plan's length — a short plan can be read in full; for a long one, build a heading map (`rg -n '^#{1,3} '`) and read only the active unit's section plus whatever it cites. Treat the plan as a decision artifact: its Implementation Units, Files, Patterns to follow, and Verification fields are your primary source material, not something to renegotiate.
- **Bare work description.** Scan the likely work area: files that would change, existing tests that already cover that path, local conventions to match. Then route by complexity:

  | Complexity | Signals | Action |
  |---|---|---|
  | Trivial | 1-2 files, no behavioral change | Skip the task list, implement directly, still apply Gate 2 if behavior-bearing |
  | Small/Medium | Clear scope, under ~10 files | Build a short task list, proceed normally |
  | Large | Cross-cutting, architectural, 10+ files, touches auth/payments/migrations | Recommend `/cepg-scope` or `/cepg-plan` before implementing (Gate 3: this is a recommendation, not a block — if the request is already unambiguous and the user wants it done now, proceed) |

- **Bug report or bug-shaped work.** Any explicit bug report, stack trace, "X is broken," "this used to work," or a failing check handed to you. Do not start on a fix. Go to **Gate 1** first — it runs before task-list creation and before any production-code edit.

If the plan or prompt is genuinely ambiguous — you cannot infer intent from what's in front of you — ask one specific question now, before building the task list. This is the ambiguity half of Gate 3 (below); don't confuse it with routine judgment calls, which you make and note rather than ask about.

**Resuming prior work.** When the input references picking up earlier work ("continue where we left off," "catch me up," or a vague/absent input inside an ongoing conversation about existing work), reconstruct a tight capsule before triaging further — mined from pstack's `recall`. Fan out to parallel subagents over recent chat transcripts (never the current chat) rather than reading them inline; verify anything they surface (a branch, a PR, a ticket) against live `git`/`gh` state before trusting it, since a transcript is history, not current truth. Keep the capsule short — what the work is, one line per thread with a status, the open problems, a single next move — and let the main thread hold only that, not the raw transcript content.

## Phase 1 — Set up to execute

**Workspace.** Already on a feature branch: keep working on it (rename first if the branch name is opaque, e.g. an auto-generated worktree name — do this without asking, it's reversible). On the default branch: create isolation by default, named for the work — this is reversible, so it does not need a question. Mined from pstack's `ce-worktree`-adjacent discipline: detect existing isolation first, rather than assuming the default branch means none exists — compare the **resolved absolute** git dir against the resolved absolute common git dir (`git rev-parse --absolute-git-dir` vs. resolving `git rev-parse --git-common-dir` to an absolute path); a raw string compare gives a false negative from a subdirectory checkout, where one of the two comes back relative. If they differ and `git rev-parse --show-superproject-working-tree` is empty, you're already in a linked worktree — work in place, don't nest another one. Otherwise, prefer the harness's native worktree primitive when one exists; only fall back to plain `git worktree add` when it doesn't, and then: run from the repo root (`cd "$(git rev-parse --show-toplevel)"` first, since the skill may start from a subdirectory), gitignore `.worktrees/` before creating anything (`git check-ignore -q .worktrees/` **with the trailing slash**, so an existing directory-only rule is honored before the directory exists), and name the branch for the work rather than accepting an opaque auto-generated name. A branch can be checked out in only one worktree at a time — if the target ref is already checked out elsewhere, report that path and work there rather than forcing a second worktree. The one exception to all of the above is committing directly to the shared default/main branch: that is the closest thing to irreversible in this step, since a push is instantly visible to and pulled by every collaborator, so it always requires an explicit "yes, commit to `<default>`" before you do it (Gate 3's irreversible bucket).

**Task list.** Build it from the plan's units (or the discovery scan above) using the platform's task tracker (`TodoWrite` on Claude Code, `update_plan` on Codex — see the platform note). Carry forward each unit's dependencies, files, and verification criteria; don't invent scope the plan or prompt didn't ask for.

## Gate 1 — Reproduce before you fix

Applies to any bug-shaped work identified in Phase 0, before the task list is finalized and before any production-code edit.

1. **Understand the bug.** Intended behavior, current behavior, affected path, smallest observable reproduction.
2. **Choose the narrowest executable check.** Prefer the closest unit/component/integration/regression test already covering that codepath.
3. **Write the failing test first.** Smallest focused test that would have caught the bug, encoding intended behavior — not a mirror of the current (broken) implementation.
4. **Run it before touching the fix.** Confirm it fails, and fails for the reason you expect. If it passes or fails for an unrelated reason, fix the test or your understanding of the repro before editing anything else.
5. **Only now write the fix** — the smallest production change that satisfies the intended behavior without breaking nearby contracts.
6. **Rerun the test.** Confirm it now passes; this observation feeds Gate 2 below.

**When a failing test is genuinely impractical** (broad harness setup, brittle mocks, slow end-to-end infra, production-only state, vague repro, large unrelated fixture churn): don't force one, and don't silently skip the step either. State plainly why a test isn't practical, then use the closest executable substitute — a targeted script, manual repro command, browser automation, snapshot comparison, or log assertion — and carry that forward as the "before" evidence Gate 2 needs. Prefer no new test over a bad one (one that mostly tests mocks, encodes current-implementation details, depends on timing, or would be deleted right after the fix).

Guardrails: never change a test just to match a wrong implementation; never weaken an existing assertion without a genuine behavior change and a clear reason; keep the regression test focused, not a vehicle for unrelated coverage.

## Phase 2 — Execute the loop

For each task, in dependency order:

1. **Follow existing patterns.** The plan (or the surrounding code, for bare-prompt work) has similar code — read it first. Match naming conventions, reuse existing components, grep for similar implementations before writing new ones.
2. **Model the domain, don't branch around it.** When a task adds stateful logic, or you notice yourself growing an existing if/else chain by one more branch, or adding a second boolean that has to stay in sync with the first — stop and encode the domain in a structure instead: a state machine instead of scattered lifecycle booleans, a typed model instead of loose parameters, a discriminated union or lookup table instead of branching spread across files, a reducer instead of ad hoc mutations. A module organized around one body of domain knowledge beats one organized around a sequence like load/validate/transform/save — execution order is not ownership. Don't force this onto code that's already clear, local, and unlikely to grow; be skeptical of an abstraction that adds indirection without actually removing branches, duplicated rules, or invalid states. Mined from pstack's `principle-model-the-domain` — a write-time discipline, not a gate with a pass/fail exit, so apply it by judgment at the point you're about to write the branch, not as a checklist item after the fact.
3. **Implement the smallest coherent slice** that completes the task.
4. **When a unit replaces an existing internal API with a new one, migrate every caller and delete the old API in the same unit** — mined from pstack's `principle-migrate-callers-then-delete-legacy-apis`. Inventory callers before starting; treat a compatibility shim as exceptional and time-boxed, never default architecture; delete tests that only protected the old implementation's details rather than the new contract. Applies only when nothing external depends on the old API's compatibility and the project can absorb a coordinated breaking change — otherwise the old path is a real constraint, not scope to clean up.
5. **Test continuously**, not at the end. Run relevant tests after each significant change and fix failures immediately. Add tests for new behavior, update tests for changed behavior, remove tests for deleted behavior. Unit tests with mocks prove logic in isolation; integration tests with real objects prove the layers work together — changes touching callbacks, middleware, or error handling need both.
6. **Commit incrementally.**

   | Commit when… | Don't commit when… |
   |---|---|
   | A logical unit is complete (model, service, component) | It's a small part of a larger unit |
   | Tests pass and progress is meaningful | Tests are failing |
   | About to switch contexts (backend → frontend) | It's scaffolding with no behavior yet |
   | About to attempt something risky or uncertain | The message would have to say "WIP" |

   Heuristic: if you can write a commit message describing a complete, valuable change, commit. If the message would be "WIP" or "partial X," keep going. Stage only files that belong to this logical unit — never a blanket add-everything. Use conventional commit messages.

7. **Simplify at natural boundaries**, not after every task. After a cluster of related work (or every 2-3 units), review the files you just touched for duplicated patterns, extractable helpers, or dead paths — this matters more with subagent-dispatched work, since each worker's context is isolated and can't see cross-unit patterns forming. If this plugin host exposes a dedicated simplification skill, invoke it here; otherwise do the pass yourself.
8. **Track progress.** Keep the task list current, note blockers and unexpected discoveries as they happen, and create new tasks rather than silently absorbing scope creep.

Apply **Gate 3** at every decision point inside this loop: don't pause to ask "should I refactor this helper" or "should I add this test" — those are reversible, so do them and explain the choice in the commit message or your summary. Pause only for genuine ambiguity or an irreversible action (see below).

### Delegating a task to a subagent worker

Give the worker a bounded packet — the task's goal, files, patterns to follow, and verification criteria — not "read the whole plan." Require it to report both the files it changed and its verification evidence (what it ran, what it observed) in its final message. Then apply Gate 2 yourself: inspect the actual diff, don't take the worker's summary as the check.

### Fanning out: many workers at once, or many attempts at one unit

Two situations call for more than one delegated worker, mined from pstack's `swarm` and `arena`. Guard the parent's context window differently for each, per pstack's `principle-guard-the-context-window` -- swarm's own aggregation step already keeps the parent to summaries, never raw worker output; arena's pick genuinely requires reading every candidate end to end, so there's no summarizing that away -- bound the cost instead by capping N to what the task actually needs and closing out each candidate's context once its rationale is extracted, rather than holding every candidate's full output live at once.

**Coverage or exploration across independent slices (swarm).** When a task decomposes into genuinely independent pieces, or into races on the same brief worth trying in parallel: state the done predicate and what each worker must report before dispatching anything; decide the shape up front — partition into slices, race N workers on identical briefs, or mix both — and the selection rule (first pass / rank all / best-of) if racing; give every worker its own writable output (a worktree, a branch, or a scratch directory — never a shared path, that's shared mutable state); dispatch all workers in one batch; and aggregate into one compact report — a result table, one-line evidenced issues, explicit gaps or dropouts — never raw worker output pasted in. This is the same "bounded packet, verify the diff yourself" discipline above, generalized from one worker to N.

**One hard, ambiguous unit where a single attempt risks locking in the wrong shape (arena).** Derive a concrete, gradeable rubric (3-6 criteria — "adds a `--dry-run` flag that skips writes," not "code is correct") before spawning anything. Spawn N candidates, each to its own output path, each required to return a short rationale naming what it considered and rejected — without the rationale you can't tell whether a candidate's structure is principled or accidental. Read every candidate end to end and score against the rubric, not on holistic feel. Pick a base, then graft only the one or two ideas from the losers actually worth porting — fold each in by hand, don't paste mechanically, and record what was grafted, from where, and what was rejected and why; the rejection notes are the highest-signal part of the record. When candidates converge on the same shape, that's a strong signal on its own — ship the consensus, no graft needed. The synthesized result still goes through Gate 2 like anything else — arena doesn't earn it a pass.

## Gate 3 — Proceed on reversible work, pause on irreversible work

This is the standing rule behind every "should I ask?" moment in Phases 0-3, not a one-time step.

- **Default: proceed, then present.** Do the work, show the result, explain why. Don't ask permission for something you can just do and let the human course-correct afterward — a wrong reversible decision costs minutes to fix; a blocked agent costs the human's attention.
- **Ask only for genuine ambiguity** — when you truly cannot infer intent from the plan, the prompt, or the surrounding code. Ask one specific question, not a general check-in.
- **Always pause for irreversible actions**, regardless of how confident you are: force-push, deleting or truncating data (especially anything production), sending an external message or notification, committing directly to the shared default branch, spending money, or calling a paid external API with a real side effect. Confirmation is not optional here even when the reversible-work default would say "just proceed."
- **Everything else is reversible by default**: writing or editing code, adding/removing/adjusting tests, splitting or reprioritizing tasks, creating a branch or worktree, local commits, running read-only commands. Proceed on these without asking.
- **Residual findings at the finishing line** (Phase 3) get the same test: a low-severity, easy-to-fix-later finding gets recorded and you proceed; a finding that gates correctness or safety pauses for confirmation.

## Gate 2 — Prove it works before marking anything done

Applies at every "mark complete" point: a single task, an implementation unit, and the build as a whole. Verify against the real artifact — never a proxy.

- **Not proof:** it compiles, the build succeeded, a subagent said it's done, a cached screenshot, a file's mtime changed.
- **Proof:** you ran the feature and exercised the actual path; you read the actual value, not a derived or cached representation; you inspected the actual diff.

Checklist:
1. Build it — necessary, not sufficient.
2. Run it and exercise the actual feature path.
3. Check the full chain: does data actually flow from input to output, not just typecheck?
4. For integrations, exercise the full communication path end-to-end, not one side of it mocked.
5. For bug-shaped work: rerun Gate 1's regression test and confirm it now passes — this closes the loop Gate 1 opened.
6. For delegated work: inspect the worker's actual output artifact (diff, file contents, runtime behavior) yourself. Workers report what they intended, not always what happened.

When verification fails, suspect your observation method before you suspect the system — but always trust the real artifact over any report, including your own summary so far.

**Script the check when you can.** A deterministic script that re-runs the same comparison is stronger proof than a one-time eyeball, and it's an artifact a reviewer can rerun instead of taking your word for it. Keep it visible for the human; commit it only when the work is large or complex enough that the trail needs to be auditable later (a big port or migration) — most work just needs the check visible, not committed.

## Phase 3 — Finish and hand off

1. **Final validation.** Run the full relevant test suite, lint, and typecheck — not just the tests touched by the last task.
2. **Residual gate** (Gate 3 applies): anything left unresolved gets triaged by severity, not silently dropped — low-severity/reversible items get recorded and the build proceeds; anything gating correctness or safety pauses for confirmation.
3. **Update the task list** to reflect final state. Progress lives in commits and the tracker, not in edits to the plan body — never mutate the plan document itself.
4. **Hand off, don't extend scope.** Build's job ends at a verified, committed change. Route it to `/cepg-check` (debugging or code review, as appropriate) before `/cepg-ship` takes it to delivery. Do not open a PR, invoke a deploy, or run production-facing actions from inside this skill — those live behind Ship's own gates.

## Key principles

- **Start fast, execute faster.** Resolve genuine ambiguity once, up front, then execute — don't wait for perfect understanding.
- **The plan (or the existing code) is your guide.** Load its references and match them; don't reinvent what already exists.
- **Reproduce before you fix.** Gate 1 is not optional for bug-shaped work, even under time pressure.
- **Test as you go**, not at the end — continuous testing prevents late surprises.
- **Prove it works before calling it done.** Gate 2 applies to every task, not just the final handoff.
- **Never block on the human** for reversible work. Gate 3 exists so autonomy and safety aren't in tension — pause only where pausing actually matters.
- **Model the domain, not the conditionals.** A growing if/else chain or a second boolean that has to stay in sync with the first is the tell that a structure is missing, not a permanent feature of the code.
- **Ship complete features.** Finish what you started; an 80%-done feature is not a finished task.

## Common pitfalls

- Fixing a bug before reproducing it (skips Gate 1).
- Declaring a task done because it compiled or a subagent said so (skips Gate 2).
- Asking "should I do X?" for a reversible action nobody needed to gate (violates Gate 3).
- Proceeding without confirmation on a force-push, data deletion, external message, or direct commit to the shared default branch (also violates Gate 3, in the other direction).
- Testing only at the end instead of continuously.
- Growing an if/else chain or syncing a second boolean by hand instead of reaching for the structure that would delete the branch.
- Editing the plan document to record progress instead of using commits and the task tracker.
- Reaching into Check's or Ship's territory — running a full review pass or opening a PR from inside Build.
