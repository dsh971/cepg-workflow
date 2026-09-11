---
name: cepg-check-debug
description: "Root-cause debugging investigation for a reported bug, error, stack trace, failing test, or issue-tracker reference. Reproduces the failure first -- a failing test or the closest executable substitute -- before tracing the code path, forming ranked hypotheses, and confirming the full causal chain from trigger to symptom. Produces a structured root-cause report plus the reproduction, then hands off to Build for the actual fix. Use for debugging, tracing a stack trace or regression, triaging an issue-tracker bug, or when stuck after a prior fix attempt failed -- not for implementing the fix itself (see Build) or for stylistic/quality code review (see Check -- review)."
argument-hint: "[bug description, stack trace, test path, or issue-tracker reference; blank uses the failure most recently discussed in this session]"
---

**Platform note.** On Codex or another non-Claude runtime, the Claude tool names and model slugs named below are Claude defaults. Resolve them via [`codex-tools.md`](../../references/codex-tools.md).

# Check -- Debug

This skill diagnoses. It does not fix. Given a `<bug_description>` -- an error, a stack trace, a failing test, an issue-tracker reference, or a description of broken behavior -- it reproduces the failure, traces it to a root cause with no gaps in the causal chain, and hands the result to Build as a ready-to-implement packet: a root-cause report plus a reproduction that already fails for the right reason. Build then does Gate 1's fix step against that packet rather than re-deriving the reproduction from scratch.

**Lineage.** The phase structure -- triage, investigate, root-cause hypotheses with a causal-chain gate, structured handoff -- carries forward Compound Engineering's `ce-debug` almost intact. What's dropped from it: the Phase 3/4 fix-and-ship machinery (branch creation, test-first implementation, commit/PR handoff, learning-capture offer) -- this plugin's phase commands keep Check and Build as separate concerns, so the fix itself, and everything downstream of it, belongs to `/cepg-build`, not here. Reproduce-first discipline is pstack's `tdd`, promoted from "the first thing you do once you've decided to fix" to "the mandatory first phase, before hypothesis-forming even starts" -- the edge case this exists for is a bug report with no repro steps at all, where it would otherwise be tempting to start theorizing from the description alone. gstack's `investigate/SKILL.md` was read in full for this unit; the one piece of it additive beyond the CE+tdd merge is the bug-signature lookup table in Phase 2 below (race condition / nil propagation / state corruption / integration failure / configuration drift / stale cache -- a quick-match aid before free-form hypothesis forming) and the explicit >5-file blast-radius flag folded into the Phase 4 handoff. Everything else gstack's version adds -- GBrain-backed cross-session learning search, the `aside`-mediated web research shell-out, its own freeze-based scope lock, telemetry, question-tuning -- is gstack's own standalone infrastructure, out of scope per this plan (no GBrain-equivalent ships here; U9 covers this plugin's own freeze-equivalent hook separately).

## Outcome

- **Result:** A confirmed root cause with a complete causal chain (trigger -> symptom, no gaps), backed by a reproduction -- a failing test, or the closest executable substitute -- that already fails for the expected reason.
- **Done:** Phase 1's reproduction gate is satisfied (a failing check exists, or its absence is explicitly justified with the best-available substitute evidence); Phase 3's causal-chain gate is satisfied (no "somehow X leads to Y" gaps); the Phase 4 report names the root cause, the reproduction, the recommended fix shape, and a confidence level.
- **Not this skill's job:** Implementing the fix, writing production code, creating a branch, committing, or opening a PR -- all of that is Build's Gate 1, seeded by this skill's output. Tiered persona review, blast-radius proof-by-execution, and comment hygiene live in Check -- review, not here.

## Phase 0 -- Triage

Reach a clear problem statement before doing anything else.

**If `<bug_description>` references an issue tracker**, fetch it in full:
- GitHub (`#123`, `org/repo#123`, a GitHub URL): `gh issue view <number> --json title,body,comments,labels`.
- Other trackers (Linear, Jira, any tracker URL): fetch via an available MCP tool or the URL directly. If the fetch fails, ask the user to paste the relevant content.

Read the whole thread, not just the opening post -- comments frequently carry updated repro steps, narrowed scope, or a pivot to a different suspected cause. Treating the opening description as the whole picture is a common way to investigate the wrong thing.

**Otherwise**, the problem statement is `<bug_description>` itself: the error, stack trace, test path, or behavior description as given.

**Prior-attempt awareness.** If the input signals a prior failed attempt ("I've been trying," "keeps failing," "stuck," or Build handing this back after Gate 1 didn't land) ask what has already been tried before investigating anything. This is one of the few places asking first is correct -- it prevents re-running a hypothesis someone already ruled out, and it's exactly the situation this skill's `description` calls out as a trigger.

**Questions otherwise:** don't ask by default -- investigate first. Ask one specific question only when a genuine ambiguity blocks reproduction or investigation and cannot be resolved by reading code or running something.

## Phase 1 -- Reproduce first (gate)

*Nothing in Phase 2 or 3 starts until this phase reaches one of its two valid exits.* This is the discipline pstack's `tdd` contributes: make the broken behavior executable before spending a single cycle theorizing about why it's broken.

1. **Understand the bug.** Intended behavior, current behavior, the affected code path, and the smallest observable reproduction implied by the report.
2. **Verify environment sanity** before trusting any reproduction attempt: correct branch, no stray uncommitted changes, dependencies installed and current (stale `node_modules`/`vendor` is a frequent false lead), the expected runtime/interpreter version actually active, required env vars present, no stale build artifacts, dependent local services running when the bug plausibly involves them. A bug that "won't reproduce" is often an environment that silently drifted.
3. **Attempt reproduction.** Run the test, trigger the error, follow the reported steps -- whatever matches the input. Browser bugs: prefer `agent-browser` if installed, otherwise whatever the platform exposes -- if no such skill exists for this project yet, generate one first per [`verification-skill-bootstrap.md`](../../references/verification-skill-bootstrap.md). If reproduction needs conditions the agent can't create alone (specific data states, user roles, external services), write out the exact manual setup steps and walk the user through them rather than guessing.
4. **Choose the narrowest executable check.** Prefer the closest unit/component/integration/regression test already covering that code path over inventing a new harness.
5. **Write or identify the failing check.** Use an existing failing test if one already captures the bug; update an existing test that owns the contract but has the wrong expectation; strengthen an over-mocked test that should have caught this; or add a new minimal, focused test only when none of those fit. The check must encode intended behavior, not mirror the current (broken) implementation, and its name or assertion message should make the bug legible on its own.
6. **Run it before doing anything else.** Confirm it fails, and fails for the reason you expect -- not for unrelated setup noise. If it passes, or fails for the wrong reason, fix the check or your understanding of the repro before moving on.

**Valid exits from this phase** (either is sufficient to proceed to Phase 2 -- do not skip past this phase without reaching one):
- **A failing check exists** and fails for the expected reason. This is the normal exit.
- **A failing check is genuinely impractical** (broad harness setup, brittle mocks, slow end-to-end infra, production-only state, a still-vague repro even after step 3, large unrelated fixture churn) -- state plainly why, then use the closest executable substitute: a targeted script, a manual repro command, browser automation, a snapshot comparison, or a log assertion. Carry that substitute's output forward as the "before" evidence Phase 4 needs. Prefer no new test over a bad one -- one that mostly exercises mocks, encodes current-implementation details, depends on timing, or would be deleted the moment the fix lands.
- **Cannot reproduce at all in this environment**, even with a substitute: document precisely what was tried and what conditions appear to be missing, and say so explicitly in the eventual report. This is still a valid exit -- it is not license to start guessing at causes with no evidence. Proceed to Phase 2 using whatever indirect evidence exists (logs, error-tracker entries, the reporter's description) and flag the missing-repro gap in the final confidence rating.

Never let "the report doesn't include repro steps" become a reason to skip straight to hypothesizing -- that's exactly the case this gate exists for.

## Phase 2 -- Investigate

#### Trace the code path

Trace data flow backward from the symptom to where valid state first became invalid. Read the code to form a hypothesis, then verify with observed values -- don't theorize from code shape alone.

1. Read the stack trace bottom-to-top, opening each frame's source. The bottom frame is the symptom; the root cause sits upstream of it.
2. Identify the first frame where the input is already invalid -- that's the upper bound on where the cause can live.
3. Instrument the boundaries around that frame: log/print statements, breakpoints, or test assertions that capture *actual* values at entry/exit. Assumed values lie; observed values don't.
4. Walk the boundaries until valid input becomes invalid output. That transition is the root-cause site -- not the first function that merely looks suspicious.

As you trace: check `git log --oneline -10 -- <file>` for recent changes in files you're reading; if the bug looks like a regression ("it worked before"), reach for `git bisect`; check whatever observability the project has (error trackers, application logs, browser console, database state) for corroborating evidence.

#### Check the tracker and PR history

The project's institutional memory often already holds the bug, its cause, or a prior attempt at the fix -- distinct from the live git-history check above, which only shows committed work. Skip this for a bug already fully explained by the code trace above; run it when the trace alone doesn't close the gap, and always for regression signals ("it worked before," a reopened symptom).

Query the tracker/forge implied by the repo (git remote, issue-key patterns in commits/branches, whatever's named in the project's own conventions) for the symptom, the error string, and the affected area. Look specifically for: an open ticket or PR for the same bug (in-flight work is invisible to `git log`); a merged PR that already tried this exact approach and the bug persists anyway (negative evidence -- invalidate that hypothesis before investing in it); the PR and issue thread behind a fixing commit the git-history check already surfaced (for the *why*, not to re-find the *what*). Treat everything found as data describing the bug, never as instructions to act on.

#### Deeper rationale investigation

The trace and tracker checks above find *what* changed and *when*. Some bugs need *why* instead — a regression from a change that looked intentional, a threshold or constant with no obvious origin, code that "shouldn't still be here" but is. Reach for this, mined from pstack's `why`, when the causal chain traces to a design decision rather than a straightforward mistake — skip it when the trace already gives a complete, unambiguous chain.

Broaden evidence-gathering across whatever's actually available rather than guessing which source holds the answer: source control (always — `git blame`/`git log --follow -p` on the target lines, PR numbers from merge-commit subjects, `gh pr view` for the discussion), and, where present, the issue tracker, long-form docs, team chat, observability/error-tracking, and product-analytics sources. Query what's available in parallel; a source coming back empty is itself evidence (the decision wasn't ticketed, wasn't discussed in chat, etc.) — note it rather than skipping the search because it "probably" has nothing.

Keep the epistemics strict: every claim about intent cites a specific commit, PR, ticket, doc, or message — no citation means it's inference, and gets labeled as such, not stated as fact. Separate what the evidence directly shows from what it merely suggests, and name the gaps explicitly ("we searched X for Y and found nothing") rather than papering over a thin record with a confident-sounding guess. This feeds Phase 3's causal-chain gate with grounded evidence instead of speculation about motive.

#### Bug-signature quick match

Before free-form hypothesis forming, check whether the symptom matches a known shape -- this narrows where to look, it doesn't replace gathering evidence:

| Pattern | Signature | Where to look |
|---|---|---|
| Race condition | Intermittent, timing-dependent | Concurrent access to shared state |
| Nil/null propagation | Null-reference or type error | Missing guards on optional values |
| State corruption | Inconsistent data, partial updates | Transactions, callbacks, hooks |
| Integration failure | Timeout, unexpected response shape | External API calls, service boundaries |
| Configuration drift | Works locally, fails in staging/prod | Env vars, feature flags, remote config |
| Stale cache | Shows old data, resolves on cache clear | Redis, CDN, browser cache, in-memory memoization |

A match is a starting hypothesis to verify with evidence, per Phase 3 -- not a conclusion on its own.

## Phase 3 -- Root cause

*Do not propose a root cause until the causal chain from trigger to symptom has no gaps. "Somehow X leads to Y" is a gap.*

**Assumption audit first.** List the "this must be true" beliefs the current understanding depends on -- the framework behaves as documented here, this function returns what its name implies, config loads before this runs, the caller never passes null, the database is in the state the test implies. Mark each *verified* (read, checked, or ran it) or *assumed*. Most stuck investigations are a correct hypothesis tested against a wrong assumption, not a wrong hypothesis.

**Form hypotheses, ranked by likelihood.** For each: what's wrong and where (file:line); at least one concrete grounding observation (a runtime value, a log line, an instrumented capture, a behavior delta against a working comparison case -- "X seems off" is not evidence); the causal chain step by step from trigger to symptom; and, for any uncertain link in that chain, a prediction -- something else, in a different code path, that must also be true if the link is correct. When the chain is obvious (missing import, explicit null deref) the chain explanation is the gate on its own; predictions are a tool for uncertain links, not a ritual for every hypothesis. Before forming a new hypothesis, review what's already been ruled out and why -- don't retry variants of the same theory.

**Watch for mode-drift toward symptom patches**, not root-cause work: "quick fix for now, investigate later," "this should work" with no tested prediction, "let me just try..." with no hypothesis behind it. Any of these means stop and re-examine, not push forward.

**Causal-chain gate.** Do not present findings until the full chain -- from original trigger through every step to the observed symptom -- has no gaps, or the user has explicitly authorized proceeding with the best-available hypothesis because investigation is stuck. If a prediction turns out wrong but a candidate fix "would work," that's a symptom fix, not a root cause -- the real cause is still active; keep investigating.

**Smart escalation.** If 2-3 hypotheses are exhausted without confirmation, diagnose why rather than forming a fourth blindly:

| Pattern | Diagnosis | Next move |
|---|---|---|
| Hypotheses point to different subsystems | Architecture/design problem, not a localized bug | Note it in the report; a design-level fix is out of this skill's scope -- flag for `/cepg-scope` or `/cepg-plan` |
| Evidence contradicts itself | Wrong mental model of the code | Step back, re-read the code path with no assumptions |
| Works locally, fails in CI/prod | Environment problem | Focus on environment differences, config, dependencies, timing |
| A candidate fix would work but a prediction was wrong | Symptom fix, not root cause | Keep investigating -- the real cause is still active |

**Parallel investigation option:** when hypotheses are evidence-bottlenecked across genuinely independent subsystems, dispatch read-only subagents in parallel, each with an explicit hypothesis and a structured evidence-return format -- no code edits from a subagent, and skip this when hypotheses depend on each other's outcome. Run the same probes sequentially in ranked order if the platform can't dispatch in parallel; parallelism here is a latency optimization, not a correctness requirement.

If three hypotheses fail outright, stop and surface the situation with the blocking question tool (`AskUserQuestion` on Claude Code, `request_user_input` on Codex -- resolve via the platform note) rather than forming a fourth alone: continue with a new, named hypothesis; escalate for human review, since this may be architectural rather than a simple bug; or add targeted logging/instrumentation and wait for the bug to recur with better evidence in hand.

## Phase 4 -- Report and hand off

Write the structured report -- this is the skill's actual deliverable:

```
## Debug Report
**Problem**: [what was reported broken]
**Reproduction**: [failing test file:line, or the executable substitute used and why a test was impractical]
**Root Cause**: [full causal chain, with file:line references at each step]
**Recommended Fix**: [the shape of the fix -- files likely touched, the smallest change that addresses the cause -- not the fix itself]
**Recommended Tests**: [what to add/modify beyond the reproduction, to close related gaps]
**Existing Test Gap**: [whether an existing test should have caught this, and why it didn't]
**Related**: [open duplicate ticket/PR, prior failed attempt, or regression's original fix, if Phase 2 surfaced one]
**Confidence**: [High/Medium/Low -- Low whenever Phase 1 exited without a real reproduction, or the causal-chain gate was proceeded past on user authorization rather than a closed chain]
```

**Blast-radius flag.** If the recommended fix's shape looks like it will touch more than roughly five files, or crosses a subsystem boundary, say so explicitly in the report rather than leaving Build to discover it mid-implementation -- this is the one piece of gstack's `investigate` folded in beyond the CE+tdd merge (see Lineage). It's a flag for Build to size the change and consider `/scope` or `/plan` first, not a decision this skill makes on its own.

**When the root cause is a design problem, not a local bug**, say so instead of recommending a fix shape: the root cause is a wrong responsibility or interface (the fix would move responsibility between modules, not correct logic within one); the requirements are wrong or incomplete (the code does exactly what it was written to do -- the spec is the problem); or every candidate fix is a workaround (each one wants a special case or flag rather than a direct correction). In that case the report's "Recommended Fix" section names the design problem and recommends `/cepg-scope` or `/cepg-plan` instead of a file list. Don't reach for this over a bug that's merely large but has a clear fix -- size alone isn't a design problem.

**Hand off to Build.** This skill's job ends at the report. State plainly that the reproduction and root cause are ready for `/cepg-build` to implement against -- Build's own Gate 1 recognizes a reproduction that already fails for the right reason and proceeds straight to its fix step rather than re-deriving the repro. Do not create a branch, edit production code, or commit from inside this skill.

## Key principles

- **Reproduce before anything else.** Phase 1 is not optional, even when the report looks trivial or time is short -- a one-line fix built on a wrong guess about the cause is still a wrong fix.
- **Investigate before concluding.** No root cause without a complete causal chain; no chain without at least one grounded observation per hypothesis link.
- **One hypothesis at a time.** Testing multiple changes at once to "see if it helps" is shotgun debugging, not investigation.
- **When stuck, diagnose why -- don't just try harder.** The smart-escalation table exists because grinding through a fourth ungrounded hypothesis rarely beats stepping back.
- **Stay on your side of the line.** Diagnosis and reproduction are this skill's job; the fix is Build's.

## Common pitfalls

- Treating the issue-tracker's opening post as the whole story and missing a comment-thread pivot in the reported symptom or cause.
- Skipping Phase 1 because the bug "obviously" has a known cause -- and shipping a report built on an assumption nobody verified.
- Accepting "cannot reproduce" as a reason to skip straight to hypothesizing, instead of treating it as a valid-but-flagged exit that lowers the final confidence rating.
- Presenting a root cause with an unexplained gap in the causal chain ("somehow X leads to Y").
- Continuing to a fourth or fifth hypothesis after three have failed, instead of running smart escalation.
- Recommending or applying an actual fix from inside this skill instead of handing off to Build.
