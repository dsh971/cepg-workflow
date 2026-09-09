# Stage 4: DX Review — reference

Adapted from gstack's `plan-devex-review` (developer-persona investigation + 8 DX
passes). Read this section in full when running Stage 4; don't work from memory.

**Input from Stage 2 and Stage 3:** the confirmed architecture and any design
sign-off. This stage evaluates the experience of a *developer* touching this surface
(a consumer of an API/CLI/SDK, or an engineer extending/maintaining the code) — a
different audience from Stage 3's end users.

## Step 4.0 — Applicability gate

Is the plan's deliverable itself developer-facing — a library, API, SDK, CLI tool, or
a Claude Code/Codex skill or plugin? Run the full 8-pass review below.

Is it an internal-only change or a pure end-user product feature with no external
developer surface? Narrow to whichever passes still matter for the engineers who will
maintain or extend this code — typically **Pass 3 (Errors & Debugging)**, **Pass 4
(Documentation)**, and **Pass 6 (Dev Environment & Tooling)**. State explicitly which
passes were narrowed and why; don't run the full startup-tier persona interrogation
(Step 4.1 below) against an audience that doesn't exist.

## Step 4.1 — Investigation before scoring (full-review case only)

Gather evidence before rating anything — scoring from vibes produces generic
findings.

**Developer persona.** Who is the target developer? Read any README/docs/design-doc
language naming an audience. Present 2–3 concrete archetypes (for example: "founder
integrating an MVP — 30-minute tolerance, won't read docs, copies from the README" vs.
"platform engineer evaluating for a Series C team — thorough, cares about security/
SLAs/CI integration") and confirm which applies via AskUserQuestion. Every later
finding should reference this persona by name, not "developers" in the abstract.

**Empathy narrative.** Write a 150–250 word first-person walkthrough of the *actual*
getting-started path this persona would hit today, grounded in real files/commands —
not hypothetical. Confirm it's accurate before treating it as evidence.

**Competitive TTHW (time-to-hello-world) benchmark**, if a comparison is meaningful:
Champion tier <2 min (3–4x adoption lift), Competitive 2–5 min (baseline), Needs Work
5–10 min (real drop-off), Red Flag >10 min (50–70% abandon). Pick a target tier and
carry it into Pass 1.

**Magical moment.** Name the instant this persona goes from "is this worth my time?"
to "oh, this is real" — and pick how it's delivered: an interactive playground/
sandbox (highest conversion, highest build cost), a single copy-paste command that
produces the moment, a passive video/GIF walkthrough (lowest friction, no doing), or a
guided tutorial using the developer's own data (deepest engagement, longest time).

**DX ambition mode**, mirroring Stage 1's scope mode but scoped to DX specifically:
- **DX EXPANSION** — DX could be a competitive edge; propose ambitious improvements
  beyond the plan's current scope, opt-in per item.
- **DX POLISH** — the plan's DX scope is right; make every touchpoint (errors, docs,
  CLI help, getting started) bulletproof, add nothing new. Default for most reviews.
- **DX TRIAGE** — fast, surgical; fix only the gaps that would block adoption. Default
  for an urgent ship.

**Journey trace.** For each stage — Discover, Install, Hello World, Real Usage, Debug,
Upgrade — trace the actual current experience against real files/commands and raise
one AskUserQuestion per concrete friction point found (never batched). DX TRIAGE mode
traces only Install and Hello World; DX POLISH traces all six; DX EXPANSION traces all
six and additionally asks "what would make this stage best-in-class?"

## The 8 review passes

Rate each 0–10. A rating must cite the evidence behind it — not "Getting Started: 4/10"
but "4/10 because [persona] hits [named friction point] at step 3, and a comparable
tool does this in under 2 minutes."

**Pass 1 — Getting Started (zero friction).** One command or one click to install? No
prerequisites? Does the first run produce real, meaningful output? Is there a
sandbox to try before installing? Copy-paste quick start that shows real output? Is
the chosen magical moment actually reachable in the plan as written?

**Pass 2 — API/CLI/SDK Design.** Guessable naming without docs? Every parameter has a
sensible default, so the simplest call is still useful? Consistent patterns across the
whole surface? 100% coverage, or do developers drop to raw HTTP for edge cases?
Discoverable from the CLI/playground without leaving to read docs? Does complexity
reveal itself progressively rather than requiring the full mental model up front?

**Pass 3 — Errors & Debugging.** Trace 3 specific error paths from the plan or code.
For each, evaluate against a three-tier bar:
- *Tier 1*: conversational, first-person, names the exact location, suggests the fix.
- *Tier 2*: an error code linking to an explanation, primary + secondary detail.
- *Tier 3*: structured output with type, code, message, offending param, and a doc
  link.
Show what the developer currently sees vs. what they should see. Also check: is
there a verbose/debug mode, and are stack traces useful or internal framework noise?

**Pass 4 — Documentation & Learning.** Can the target developer find what they need in
under 2 minutes? Do beginners see the simple path while experts can find the advanced
one? Are code examples copy-paste-complete and runnable as-is, not fragments? Do both
tutorials (learn by doing) and reference docs exist?

**Pass 5 — Upgrade & Migration Path.** What breaks on upgrade, and is the blast radius
limited? Are deprecation warnings actionable ("use `newMethod()` instead"), not just a
notice? Is there a step-by-step migration guide for every breaking change? Is
versioning predictable (semver or an equivalent stated policy)?

**Pass 6 — Dev Environment & Tooling.** Editor/language-server support? Works
non-interactively in CI? Type definitions and autocomplete included if relevant? Easy
to mock/test against? Hot reload or fast feedback locally? Cross-platform (including
reproducibility across OS/package-manager/container differences)? Is there a dry-run
or verbose mode for debugging integration issues?

**Pass 7 — Community & Ecosystem.** Is the code open and permissively licensed if
that's the model? Is there a place developers ask questions, with someone actually
answering? Are examples real-world and runnable, not just hello-world? Is pricing (if
any) transparent, with no surprise bills?

**Pass 8 — DX Measurement & Feedback Loops.** Can time-to-hello-world actually be
measured post-ship, not just estimated now? Is there a feedback mechanism (bug
reports, a feedback channel)? Are periodic friction audits planned? Will it be
possible to compare this plan's DX predictions against reality later?

## Asking questions during this stage

One friction point or gap = one AskUserQuestion, never batched. Ground every question
in the persona and evidence gathered in Step 4.1 — "this stage engineer hits [named
friction point] at minute N and abandons" rather than "developers might find this
confusing." If a pass turns up nothing, say so and move on.

## Stage 4 output — DX Sign-Off Record

```
DX SIGN-OFF RECORD
Applicability: <full 8-pass review | narrowed to: <passes run> — reason>
Persona: <name + tolerance + expectations, or n/a if narrowed>
TTHW target: <tier, or n/a>
Magical moment: <chosen delivery vehicle, or n/a>
Resolved friction points: <list>
Unresolved / deferred: <list, or "none — all resolved">
```

This is the final stage. Combine all four stage records into one Scope Sign-Off (see
SKILL.md) before handing off to the Plan skill.
