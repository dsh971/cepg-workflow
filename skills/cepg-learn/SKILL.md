---
name: cepg-learn
description: "Capture a solved problem or new insight as a docs/solutions/ entry and CONCEPTS.md update, then decide whether it reveals a gap an existing skill should have caught -- if so, propose a specific skill-file edit for human confirmation, never applied autonomously. Also runs a scoped refresh pass over existing docs/solutions/ entries on request. Use after finishing a fix, closing out a debugging session, or when asked to refresh stale learnings."
argument-hint: "[optional: brief context, or 'refresh' plus a scope hint]"
---

# Learn

**Platform note.** On Codex or another non-Claude runtime, the Claude tool names and model slugs named below are Claude defaults. Resolve them via [`codex-tools.md`](../../references/codex-tools.md).

Learn turns a solved problem into two durable artifacts -- a `docs/solutions/` entry and, when the problem touches shared vocabulary, a `CONCEPTS.md` update -- then asks one more question this plugin's other five skills don't: does this learning reveal something an existing skill file should already have encoded? If so, it drafts the specific edit and stops for a human to confirm it. It never rewrites a skill file on its own judgment alone.

**Lineage.** The capture workflow -- frontmatter schema, bug/knowledge tracks, category taxonomy, overlap-before-duplicate, CONCEPTS.md discipline -- carries forward Compound Engineering's `ce-compound`. Dropped from `ce-compound`: the scratch-artifact multi-subagent Phase 1 pipeline, the automatic session-history mining probe, and the bundled Python parser-safety/claims validators -- all built for a standalone 32-skill plugin's context budget, not this plugin's six-command surface. A single agent capturing one learning does the work inline; a subagent is worth dispatching only when `docs/solutions/` has grown large enough that searching it is the expensive part (see Phase 2). The refresh capability carries forward a condensed form of `ce-compound-refresh`'s five-way classification (Keep / Update / Consolidate / Replace / Delete) as an explicit secondary mode -- dropped from it: broad-sweep subagent batching, automatic branch-and-PR creation, and the separate `per-action-flows.md` indirection. The significance-decision step is mined from pstack's `reflect`: not its three-parallel-reviewer-lens architecture (this skill already has the finished conversation in context, unlike `reflect`, which re-mines a past transcript) but its central discipline -- a candidate skill edit is drafted, shown, and never applied without explicit approval, because a skill change affects every future agent that reads it.

## Principles

1. **One learning per run.** Capture the problem just solved, not a batch of everything from the session. If several distinct learnings landed, run Learn once per learning.
2. **Ground claims in source, not memory.** Before asserting how code behaves (a value, a limit, a status, a default), Read the defining line at the current tree and cite `file:line`. Cite PR numbers over bare commit SHAs -- SHAs move under rebase.
3. **Update over duplicate.** If an existing doc already covers this problem, refresh it in place rather than create a sibling that will drift.
4. **Skill edits are proposals, never autonomous mutations.** The significance decision (Phase 4) may conclude an existing skill file should change. Draft the exact edit, get explicit confirmation, only then apply it. An unattended run that can't get confirmation records the proposal and stops -- it does not apply it by default-approving.
5. **Small, discoverable artifacts.** The doc and any `CONCEPTS.md` entry must be findable by a future agent who wasn't in this session -- correct frontmatter, no jargon that isn't defined, no dangling references.

## Phase 0: Mode

Two modes, selected from the invocation:

| Mode | Trigger | Does |
|---|---|---|
| **Capture** (default) | No argument, a brief context hint, or nothing recognizable as a refresh request | Phases 1-5 below: document the problem just solved |
| **Refresh** | Argument starts with `refresh`, optionally followed by a scope hint (directory, filename, module, or keyword) | The Refresh Mode section: audit existing `docs/solutions/` entries against the current codebase |

If the mode is ambiguous, default to Capture -- it is the common case and the cheaper mistake to make (a Refresh that should have run can always be invoked explicitly next).

## Phase 1: Identify the Learning

Determine what's being documented from the conversation just completed, or from the context hint if Learn was invoked standalone with one.

**Stop and report instead of writing anything when:**
- The problem isn't actually solved yet, or the fix hasn't been verified working.
- The "problem" is a trivial, obvious one-liner (a typo, an unambiguous off-by-one) with no generalizable lesson.

**Classify the track:**

| Track | When | Required fields beyond the shared set |
|---|---|---|
| **Bug** | Something was broken and got fixed | `symptoms`, `root_cause`, `resolution_type` |
| **Knowledge** | A practice, pattern, tooling choice, or convention worth recording -- nothing was strictly "broken" | `applies_when` |

**Classify the category** (directory under `docs/solutions/`):

- Bug track: `build-errors`, `test-failures`, `runtime-errors`, `performance-issues`, `database-issues`, `security-issues`, `ui-bugs`, `integration-issues`, `logic-errors`
- Knowledge track: `architecture-patterns`, `design-patterns`, `tooling-decisions`, `conventions`, `workflow-issues`, `developer-experience`, `documentation-gaps`, `best-practices` (fallback only, when nothing narrower fits)

## Phase 2: Check Overlap, Then Write

**Search first.** Grep `docs/solutions/<category>/` (and, if the category classification is uncertain, the wider `docs/solutions/` tree) for existing docs on the same problem -- match on frontmatter `title`, `tags`, and `module` before reading full file bodies. For a small tree, do this inline. When `docs/solutions/` is large enough that this search is the expensive part of the run, dispatch a read-only generic subagent (`Task`/`Agent`, `subagent_type: general-purpose`) to do the search and return distilled matches rather than raw file contents.

**Decide update vs. create:**

| Overlap | Action |
|---|---|
| Same problem, same root cause, same solution approach | **Update** the existing doc: preserve its path and frontmatter, refresh the solution/examples/prevention content, add `last_updated: YYYY-MM-DD`. |
| Same area, different angle or root cause | **Create** a new doc; note the related doc as a cross-reference. |
| No meaningful overlap | **Create** a new doc. |

Two docs describing the same problem drift apart over time -- when in doubt between Update and Create, prefer Update.

**Frontmatter schema** (quote any scalar value containing an unquoted ` #` or `: ` -- both silently corrupt YAML parsing):

```yaml
---
title: <short, specific title>
date: YYYY-MM-DD
track: bug | knowledge
category: <one of the category slugs above>
module: <primary module or component this touches>
tags: ["<keyword>", "<keyword>"]
problem_type: <category slug, or a finer-grained value the category maps to>
# bug track only:
symptoms: "<what was observed>"
root_cause: "<one-line technical cause>"
resolution_type: fix | workaround | config-change | dependency-upgrade
# knowledge track only:
applies_when: "<the situations this guidance is relevant to>"
# only when updating an existing doc:
last_updated: YYYY-MM-DD
---
```

**Body sections**, in order:

- **Bug track:** Problem, Symptoms, What Didn't Work, Solution (with before/after code when applicable), Why This Works, Prevention (concrete -- a lint rule, a test assertion, a config, not just prose advice).
- **Knowledge track:** Context (what friction or gap prompted this), Guidance (the practice or pattern, with examples), Why This Matters, When to Apply, Examples (concrete before/after).

Create `docs/solutions/<category>/` if it doesn't exist. Filename: `<sanitized-problem-slug>.md`, no date suffix -- the `date:` field is the canonical timestamp.

## Phase 3: CONCEPTS.md

Scan the new doc and the surrounding conversation for domain terms that qualify: project-specific entities, named processes, or status/state concepts with meaning particular to this project -- not implementation details (a class name, a file path, a config value that will drift). A term qualifies when a future agent reading it out of context would otherwise misuse or misunderstand the word.

- **If `CONCEPTS.md` exists at the repo root:** add missing qualifying terms, refine existing entries the new doc adds precision to.
- **If it doesn't exist and at least one term qualifies:** create it, seeded with the core domain nouns of the area this learning touched (not a repo-wide sweep -- that belongs to a dedicated future bootstrap, out of scope here). Start the file with:

  > Shared domain vocabulary for this project -- entities, named processes, and status concepts with project-specific meaning. Seeded from documented learnings; direct edits are fine. Glossary only, not a spec or catch-all.

- **If nothing qualifies:** proceed without editing it, and say so explicitly in the report (Phase 5) -- a silent skip looks identical to a forgotten check.

Apply `CONCEPTS.md` edits directly, in every mode -- this is a side effect of documenting a learning, not a decision that needs confirmation. It is bounded and additive, unlike Phase 4's skill edits, which change what future agents are told to do.

## Phase 4: Significance Decision

This is the step mined from `reflect`, and the reason Learn is a distinct skill rather than a doc-writer bolted onto another phase. Most learnings are worth a doc entry and nothing more. Some reveal that an existing skill's instructions had a gap that let the problem happen -- those are worth a proposed skill edit.

**Evaluate significance** against these signals -- treat them as evidence to weigh, not a checklist to satisfy in full:

- **Recurrence.** Phase 2's overlap search found a prior doc in the same area describing a related mistake, or this doc is itself an Update to one -- the same class of problem has now happened more than once.
- **A skill should have caught this.** During the session, the agent took a wrong path, produced an incorrect result, or had to be corrected mid-task, and the relevant phase skill's instructions are silent on the distinction that mattered -- not merely a case where the agent had the right instructions and failed to follow them carefully (that is a discipline lapse, not a content gap, and does not warrant an edit).
- **The lesson generalizes to that skill's other invocations.** A future agent following the same skill, on a different task in this repo, would hit the same gap again.

**Skip the edit proposal** (doc entry only) when the problem is one-off, environment-specific, already correctly covered by a skill the agent simply didn't follow, or too narrow to state as a general rule without overfitting to this one instance.

**When significant:**

1. Identify the specific skill file(s) under `skills/*/SKILL.md` whose guidance is implicated -- the phase most likely to encounter this class of problem again. Read it.
2. Draft the smallest concrete edit that would have caught or prevented this -- a bullet added to an existing section, a row in an existing table, a tightened sentence -- matching that file's existing structure, tone, and density. Do not invent a new section unless nothing existing is even remotely related. This is a draft, not yet applied.
3. Present the proposal for confirmation before touching the file: the target skill path, the exact text to add or change, and a one-sentence reason. Use `AskUserQuestion` in Claude Code (call `ToolSearch` with `select:AskUserQuestion` first if its schema isn't loaded); on Codex or another runtime without a blocking-question tool, present the proposal in chat and ask in plain text, then wait for the reply.
4. **On explicit approval:** apply the edit with `Edit`, preserving the rest of the file's structure and frontmatter untouched. Report what changed and where.
5. **On decline, no response, or an unattended/non-interactive run with no one to ask:** do not touch the skill file. Record the proposal in the Phase 5 report as declined or pending -- never silently drop it, and never apply it by treating silence as approval.

One proposal per learning-run. If the significance evaluation surfaces edits to more than one skill file, present them as separate confirmations rather than bundling unrelated changes behind a single yes.

## Phase 5: Report

End every Capture run with a short, structured summary -- no "what's next?" menu, since the doc is already written and any skill edit was already confirmed or declined in Phase 4:

```text
Learn: <captured | updated> docs/solutions/<category>/<filename>.md
Track: <bug | knowledge>
CONCEPTS.md: <not touched | scanned, no qualifying terms | created with N entries | updated -- N added, N refined>
Skill-edit proposal: <none -- not significant | applied: <skill path> | declined | pending confirmation>
```

## Refresh Mode

Triggered by an argument starting with `refresh`, with an optional scope hint (directory, filename, module, or keyword) after it.

**Scope.** With a hint, narrow with the first strategy that produces results: directory name -> frontmatter (`module`/`tags`) -> filename -> content keyword. No hint: process all of `docs/solutions/`. A hint that matches nothing: report the miss and stop -- do not silently widen to everything. An empty `docs/solutions/` reports that and points at Capture mode as the way to start building it.

**Classify each doc in scope:**

| Outcome | Meaning | Action |
|---|---|---|
| **Keep** | Still accurate | No edit -- list it as reviewed |
| **Update** | Solution still correct; references (paths, names, snippets, links) drifted | Fix in place |
| **Consolidate** | Two docs cover the same problem, both correct | Merge unique content into whichever is more current, delete the subsumed one |
| **Replace** | The guidance itself is now misleading, not just its references | Write a successor with current evidence, then delete the old |
| **Delete** | No longer useful, applicable, or distinct from another doc | Remove -- git history is the archive |

**Judgment rules:**
- Match docs to reality, not the reverse -- when code and doc disagree, the doc changes, never the code.
- Age alone is not staleness. A doc that still matches the code is a Keep regardless of how old it is.
- Never edit for typos or wording alone -- no-churn.
- **Replace requires real evidence** from this investigation, not a guess. Without it, mark the doc `status: stale` with a `stale_reason` and move on -- do not invent a rewrite to avoid leaving a doc unresolved.
- **Before any Delete,** confirm the problem domain itself is gone, not just the specific file the doc cites (an implementation detail disappearing doesn't mean the problem stopped existing), and check for inbound links from other docs -- a substantive citation blocks deletion (Replace or narrow Keep instead); a decorative one permits it with the citation cleaned up in the same pass.

**Report** in the same shape as `ce-compound-refresh`'s summary -- counts by outcome, then per-file detail (path, classification, evidence, action taken or recommended):

```text
Refresh Summary
================
Scanned: N
Kept: X   Updated: Y   Consolidated: C   Replaced: Z   Deleted: W   Marked stale: S
```

In a non-interactive or unattended run, apply Keep/Update/Consolidate/auto-qualifying Delete directly and never pause; anything genuinely ambiguous (a borderline Replace, a Delete that fails the inbound-link check) gets stale-marked or recorded as a recommendation instead of applied, following the same never-guess discipline as Phase 4's skill-edit proposals. In an interactive run, apply unambiguous outcomes directly and ask (via the blocking-question tool) only on the genuinely ambiguous ones.

Refresh mode reconciles `CONCEPTS.md` the same way Phase 3 does, scoped to the docs actually touched by this run -- not a repo-wide vocabulary sweep. Refresh mode does not run the Phase 4 significance decision -- that step evaluates a learning as it's captured, not a backlog of existing docs.
