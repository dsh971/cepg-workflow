---
name: cepg-scope
description: Runs a staged product-framing, architecture-lock-in, design, and DX sign-off pass over a proposed feature or idea before planning begins. Invoke when a request is vague, ambitious, high-stakes, or touches multiple specialties and needs cross-functional buy-in before /cepg-plan — not for a well-scoped bug fix or a trivial, single-file change.
argument-hint: <feature or idea description, or a path to a doc describing it>
---

**Platform note.** On Codex or another non-Claude runtime, the Claude tool names and
model slugs named below are Claude defaults. Resolve them via
[`codex-tools.md`](../../references/codex-tools.md).

**Artifact root note.** Every `docs/...` path below assumes the default artifact
root. A project with a configured `docs_root` relocates all of them the same way —
see [`artifact-root.md`](../../references/artifact-root.md).

# Scope

Scope is a sign-off pass, not a planning tool. It runs before the Plan skill and
answers "should we build this, and does it hold up under product, architecture,
design, and DX scrutiny" — not "how do we build it." Do not invent implementation
detail, name specific files to change, or describe Build/Check/Ship-level steps here;
that's the Plan skill's job once Scope hands off.

Four staged sections run **in sequence**, in one skill invocation — not as four
separate commands, and not as parallel subagent dispatch. This is deliberate: each
stage's output is a fixed input to the next, so the work is cumulative, not
independent (contrast with the Check skill's specialist review, where the review
dimensions genuinely don't depend on each other and parallel dispatch is correct
there).

```
Product Framing  --->  Architecture Lock-In  --->  Design Review  --->  DX Review
(what & how ambitious)  (concrete shape,           (UI/UX, if any        (developer-facing
                         named types)               UI scope exists)      surface, if any)
```

## Running the four stages

Each stage has its own reference file with the full question set / review criteria —
read a stage's reference file in full immediately before running that stage, not from
memory, and not all four at once at the start (this keeps each stage's context
focused on what it actually needs).

| Stage | When | Read this section |
|---|---|---|
| 1. Product Framing | always | [`references/product-framing.md`](references/product-framing.md) |
| 2. Architecture Lock-In | always | [`references/architecture-lock-in.md`](references/architecture-lock-in.md) |
| 3. Design Review | only if the confirmed scope has UI/UX surface (Stage 3's own gate decides this) | [`references/design-review.md`](references/design-review.md) |
| 4. DX Review | always, but narrows sharply if there's no developer-facing surface (Stage 4's own gate decides this) | [`references/dx-review.md`](references/dx-review.md) |

Run the stages strictly in order. Don't start Stage 2 until Stage 1's Product Framing
Record is written; don't start Stage 3 until Stage 2's Architecture Lock-In Record is
written; and so on. A later stage that finds a problem with an earlier stage's
decision doesn't silently reopen it — surface the tension via AskUserQuestion, let the
requester decide whether to revise the earlier record or accept the new stage's
finding as a known tradeoff.

## Question protocol (all four stages)

- Ask via `AskUserQuestion`, one issue per call — never batch multiple findings into a
  single question.
- Every question states: the concrete finding (with a file/line or a named piece of
  evidence where one exists), 2–3 options, and a recommendation with a one-line
  reason.
- If a step in a stage turns up nothing, say so ("No issues, moving on") and continue
  — don't manufacture a finding to make a step look thorough. This is the mechanism
  that keeps a well-specified request from getting padded with unnecessary questions.
- Don't proceed past a stage, and don't write that stage's output record, until every
  question it raised has been answered. An "obvious fix" is still a finding and still
  needs an explicit answer before it's treated as settled.
- If `AskUserQuestion` is unavailable on the current runtime, ask in plain text — one
  question, wait for the reply, then continue — per `codex-tools.md`.

## Handing off to Plan

After Stage 4, assemble the four stage records into one Scope Sign-Off:

```
## Scope Sign-Off: <feature/idea name>

<Product Framing Record>
<Architecture Lock-In Record>
<Design Sign-Off Record>
<DX Sign-Off Record>
```

**Always write this to disk before ending the skill** — do not rely on the user to
copy it out of chat. Save it to `docs/scope/YYYY-MM-DD-<descriptive-name>-sign-off.md`
(create `docs/scope/` if it doesn't exist; kebab-case the descriptive name, 3-5 words),
mirroring `docs/brainstorms/`'s convention for legacy requirements docs. This is what
makes the handoff to Plan automatic rather than manual: the Plan skill's Phase 0
already looks under `docs/scope/` for a recent, topically-matching sign-off before
falling back to a bootstrap conversation — that lookup only finds anything if this
step actually wrote the file.

Confirm with the absolute path so it's clickable, then present the same block as the
closing message of this skill:

```text
Scope sign-off written to <absolute path>
```

The user can still paste the block directly into `/plan` for an immediate handoff in
the same session — the file write and the chat presentation are not exclusive — but
the file is what makes the record durable across a session boundary.

## Edge cases

- **Already well-specified request** (clear actors, clear architecture already
  agreed): stages still run, but most steps resolve to "No issues, moving on" quickly.
  Don't skip a stage just because it looks unnecessary going in — Stage 3 and Stage 4
  each have their own explicit applicability gate for that; use those, not judgment
  calls made before a stage has actually run.
- **No UI scope at all:** Stage 3 skips itself per its own gate and records why.
- **No developer-facing surface:** Stage 4 narrows itself per its own gate rather than
  running the full persona interrogation against an audience that doesn't exist.
