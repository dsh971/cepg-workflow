# Stage 1: Product Framing — reference

Adapted from gstack's `office-hours` (demand diagnostic, premise challenge) and
`plan-ceo-review` (scope-ambition modes). Read this section in full when running
Stage 1; don't work from memory.

## Step 1.0 — Posture check (decide before asking anything else)

Is this ask **startup/new-surface shaped** (speculative, no confirmed users yet,
"should this exist at all" is genuinely open) or **feature/iteration shaped** (an
established product or codebase, a concrete internal ask, an incremental change)?

- Startup/new-surface shaped → run the Six Forcing Questions (1.1) before anything else.
- Feature/iteration shaped → skip 1.1 entirely. Note in the sign-off record: "Demand
  questions skipped — iteration on an existing, already-adopted surface." Go straight
  to the Premise Challenge (1.2).

This is the mechanism that keeps Scope from padding an already-well-specified request
with questions it doesn't need.

## Step 1.1 — The Six Forcing Questions (startup/new-surface shaped only)

Ask one at a time via AskUserQuestion (see SKILL.md for the question protocol). Push
once on a vague first answer, then move on — this is a sign-off pass, not office hours
in full; don't run more than two follow-up pushes per question.

Route by what's already known about the work (skip questions whose answers are already
clear from context):
- Pre-product idea → Q1, Q2, Q3
- Has users, no revenue → Q2, Q4, Q5
- Has paying customers → Q4, Q5, Q6
- Pure engineering/infra play → Q2, Q4 only

**Q1 — Demand reality.** What's the strongest evidence someone actually wants this —
not "is interested," not "signed up," but would be upset if it disappeared tomorrow?
Red flags: waitlist counts, "people say it's interesting," VC enthusiasm. None of that
is demand — paying, expanding usage, or scrambling when it breaks is.

**Q2 — Status quo.** What are users doing right now to solve this, even badly? What
does that workaround cost them? "Nothing — no solution exists" is itself a red flag:
it usually means the problem isn't painful enough to act on yet.

**Q3 — Desperate specificity.** Name the actual human who needs this most. Title, what
gets them promoted, what gets them fired. "Enterprises in healthcare" or "product
managers" are filters, not people — push past category-level answers.

**Q4 — Narrowest wedge.** What's the smallest version of this someone would pay real
money for *this week*, not after the full platform ships? "We need the full platform
before anyone can use it" is a sign of attachment to architecture, not value.

**Q5 — Observation & surprise.** Has anyone actually watched a real user attempt this,
unassisted? What surprised them? Surveys and demo calls don't count — they're theater.

**Q6 — Future-fit.** If the world looks meaningfully different in 3 years, does this
become more essential or less? "The market is growing" is not a thesis — every
competitor can say that.

**Escape hatch:** if the user pushes back on the questions once, ask only the 2 most
critical remaining questions for the routed stage, then proceed. If they push back a
second time, stop asking and proceed immediately — don't ask a third time. A fully
formed plan with real evidence (existing users, revenue, named customers) skips 1.1
outright, but Premise Challenge and Implementation Alternatives still run.

## Step 1.2 — Premise Challenge (always runs)

State each as a claim the requester must agree or disagree with, via AskUserQuestion:

1. Is this the right problem? Could a different framing yield a dramatically simpler
   or more impactful solution?
2. What existing code, product surface, or workflow already partially solves this?
   Could the plan capture outputs from something that already exists instead of
   building a parallel path?
3. What happens if nothing is built? Is the pain real or hypothetical?

If the requester disagrees with a premise, revise the framing and re-state it before
moving on — don't proceed on an unresolved premise.

## Step 1.3 — Implementation Alternatives (mandatory, always runs)

Produce 2–3 distinct approaches before any scope-ambition decision. This is not
optional even when one approach seems obviously right — state explicitly why
alternatives were eliminated if only one survives.

For each approach: name, 1–2 sentence summary, effort (S/M/L/XL), risk (Low/Med/High),
2–3 pros, 2–3 cons, what existing code/patterns it reuses.

Rules:
- At least one approach must be the minimal-viable path (fewest files, smallest diff).
- At least one must be the ideal-architecture path (best long-term trajectory). These
  two carry **equal weight** — don't default to minimal just because it's smaller.
- Recommend one, with a one-line reason, via AskUserQuestion. Don't proceed to scope
  mode selection until the requester confirms the approach.

The confirmed approach is a Stage 1 output — Stage 2 (Architecture lock-in) takes it
as a starting point and turns it into concrete data shapes and component boundaries,
not a fresh open question.

## Step 1.4 — Scope Ambition Mode

Present four postures via AskUserQuestion. These differ in kind, not coverage — no
completeness score, just state the tradeoff plainly.

1. **EXPANSION** — the plan is good but could be great; push scope up. Run:
   - *10x check*: what's the version that's 10x more ambitious for ~2x the effort?
   - *Platonic ideal*: if the best engineer alive had unlimited time and perfect
     taste, what would this feel like to use? Start from the experience, not the
     architecture.
   - *Delight opportunities*: list at least 5 adjacent, small (≈30-minute) touches
     that would make a user think "oh nice, they thought of that."
   - Present each resulting scope proposal individually via AskUserQuestion — opt-in,
     never batched. Accepted items become scope; rejected items go to "NOT in scope."
2. **SELECTIVE EXPANSION** — hold current scope as the baseline, but surface
   expansion opportunities neutrally (no enthusiastic push) for the requester to
   cherry-pick. Run the same 10x/delight scan as EXPANSION but present it as
   candidates, not a pitch.
3. **HOLD SCOPE** — the plan's scope is right; make it bulletproof, add and remove
   nothing. Still run the complexity check below.
4. **REDUCTION** — the plan is overbuilt; find the ruthless minimum that ships real
   value. Everything else becomes a follow-up.

**Complexity check** (run under HOLD SCOPE and SELECTIVE EXPANSION): if the approach
touches more than ~8 files or introduces more than 2 new classes/services, treat that
as a smell — ask whether the same goal is reachable with fewer moving parts before
locking in scope.

Context-dependent defaults (state the default, let the requester override):
- Greenfield feature → EXPANSION
- Enhancement to an existing surface → SELECTIVE EXPANSION
- Bug fix, hotfix, or refactor → HOLD SCOPE
- Approach touching 15+ files → suggest REDUCTION

Once a mode is selected, commit to it for the rest of the Scope pass — don't silently
drift toward more or less scope in later stages.

## Step 1.5 — Dream-state note (optional, EXPANSION/SELECTIVE EXPANSION only)

One short paragraph: where does this plan leave the system relative to a 12-month
ideal? Carried into the sign-off record as context, not a gate.

## Stage 1 output — Product Framing Record

Write this record before moving to Stage 2:

```
PRODUCT FRAMING RECORD
Demand evidence: <Q1–Q6 answers, or "skipped — iteration on existing surface">
Premises agreed: <list>
Confirmed approach: <name + 1-line summary from Step 1.3>
Scope mode: <EXPANSION | SELECTIVE EXPANSION | HOLD SCOPE | REDUCTION>
Accepted scope: <bullets>
Deferred / cut: <bullets, with one-line reason each>
```

Stage 2 reads the confirmed approach and accepted scope as fixed inputs — it does not
re-litigate them.
