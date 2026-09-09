# Stage 2: Architecture Lock-In — reference

Adapted from gstack's `plan-eng-review` (Step 0 scope challenge, Architecture, Code
Quality, Test, and Performance passes). Read this section in full when running Stage
2; don't work from memory.

**Input from Stage 1:** the confirmed approach and accepted scope from the Product
Framing Record. Treat both as settled — this stage locks in the concrete shape of
that approach, it does not re-open whether to build it or how ambitious to be.

## Step 2.0 — Scope sanity re-check

Before reviewing architecture, re-run a narrower version of Stage 1's complexity
check against the *concrete* file/component list now visible:

- **Complexity smell:** still >8 files or >2 new classes/services? If Stage 1 already
  accepted that under EXPANSION, don't re-litigate — just confirm it's still true and
  move on. If it emerged only now that architecture is concrete, flag it.
- **Search-before-building check:** for each new architectural pattern, infra
  component, or concurrency approach — does the framework/runtime already have a
  built-in for this? Is the chosen approach current best practice, and are there known
  footguns? If a custom solution is being rolled where a built-in exists, flag it as a
  scope-reduction opportunity.
- **Distribution check:** if this introduces a new artifact type (CLI binary, library
  package, container image, mobile app) — is the build/publish pipeline part of this
  plan, or explicitly deferred? Code without a way to reach users is dead weight; never
  let this drop silently.
- **Backlog cross-reference:** if the project tracks deferred work (a TODOS file, issue
  tracker, etc.), check whether anything there blocks, bundles with, or is unlocked by
  this plan.

If the complexity smell newly triggers, stop and ask via AskUserQuestion before
continuing to Architecture Review.

## Step 2.1 — Architecture Review

Evaluate and, where a flow is non-trivial, sketch as ASCII:

- **System design and component boundaries.** Draw the dependency graph — what's
  newly coupled that wasn't before, and is that coupling justified?
- **Data flow shadow paths.** For every new data flow, trace all four paths: happy,
  nil/missing input, empty/zero-length input, upstream error. What happens on each?
- **State machines.** For every new stateful object, diagram states and transitions,
  including invalid transitions and what prevents them.
- **Security architecture.** Auth boundaries, data-access patterns, API surfaces. For
  every new endpoint or mutation: who can call it, what do they get, what can they
  change?
- **Production failure scenarios.** For each new integration point, name one realistic
  failure (timeout, cascade, data corruption, auth failure) and whether the plan
  accounts for it.
- **Rollback posture.** If this ships and immediately breaks, what's the rollback
  procedure — revert, feature flag, migration rollback — and how long does it take?
- **Distribution architecture**, if Step 2.0 flagged a new artifact type.

**Named data/type shapes.** Before moving to Code Quality, name the concrete shape of
any type or data structure that will cross a function/module boundary — this is the
one piece of architecture lock-in that must not be left implicit. A plan that says
"a validation layer" without naming the request/response/error shapes hasn't locked
architecture in yet, it's still deferring the decision to whoever implements it.

## Step 2.2 — Code Quality Review

- Does new code fit existing organization/module patterns? If it deviates, is there a
  stated reason?
- DRY violations — be aggressive; if the same logic exists elsewhere, cite file and
  line.
- Naming: do new types/methods/variables name what they do, not how they do it?
- Over-engineering check: any new abstraction solving a problem that doesn't exist
  yet?
- Under-engineering check: anything fragile, happy-path-only, or missing obvious
  defensive checks?
- Cyclomatic complexity: flag any new method branching more than 5 times and propose
  a decomposition.

## Step 2.3 — Test Coverage Review

Goal: the plan should specify tests for every new codepath and user flow, not defer
that to implementation.

1. **Trace every codepath.** For each new component, follow data from entry point
   (route/handler/exported function/event) through every branch: where input comes
   from, what transforms it, where it goes, what can go wrong at each step.
2. **Map user flows and interaction edge cases** alongside code paths: double-click,
   navigate-away mid-action, stale/expired state, slow connection, concurrent tabs.
   Zero-results, boundary-length, and maximum-size states are edge cases too.
3. **Check each branch against existing/planned tests.** For every branch — code path
   or user flow — is there a test that exercises it? Both the true and false side of
   every conditional.
4. **Decide unit vs. integration/E2E vs. eval:**
   - Recommend E2E/integration for: a flow spanning 3+ components/services, an
     integration point where mocking would hide real failures, or an auth/payment/
     data-destruction flow.
   - Recommend an eval for: a prompt template, system instruction, or tool-definition
     change whose output quality needs a baseline comparison, not a pass/fail unit
     test.
   - Stick with a unit test for: a pure function, an internal side-effect-free helper,
     or a single function's edge case.
5. **Regression rule (mandatory, no exceptions):** if the diff modifies *existing*
   behavior and the current test suite doesn't cover the changed path, a regression
   test is a required part of the plan — not a nice-to-have, not something an
   AskUserQuestion can talk you out of. When uncertain whether a change is a
   regression, write the test.

Output a coverage diagram (code paths + user flows in one view) noting gaps, and for
each gap specify: the test file, what it asserts, and whether it's unit/E2E/eval.

## Step 2.4 — Performance Review

- N+1 query risk on every new relation traversal.
- Memory usage: worst-case size of any new in-memory data structure in production.
- Missing indexes for new queries.
- Caching opportunities for expensive computation or external calls.
- The 2–3 slowest new codepaths and a rough p99 estimate.

## Asking questions during this stage

One issue = one AskUserQuestion call, never batched. State the concrete problem
(file/line where possible), 2–3 options with effort/risk, and a recommendation with a
one-line reason. If a section turns up nothing, say so and move on — don't manufacture
findings to fill the section.

## Stage 2 output — Architecture Lock-In Record

```
ARCHITECTURE LOCK-IN RECORD
Confirmed architecture: <component boundaries + dependency graph summary>
Named data/type shapes: <list — the concrete shapes crossing module boundaries>
Error/rescue map: <method or codepath -> failure mode -> handling -> user-visible result>
Test coverage plan: <gaps closed, gaps deferred with reason, any mandatory regression tests>
Performance risks: <flagged items, or "none found">
```

Stage 3 reads the confirmed architecture and named shapes as the settled foundation
for any UI screens/flows it evaluates.
