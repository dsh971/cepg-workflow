# Skill authoring template

Every skill under `skills/` and its paired command under `commands/` follow this shape. Copy it rather than re-deriving the boilerplate per skill.

## 1. Skill frontmatter (`skills/cepg-<name>/SKILL.md`)

```yaml
---
name: cepg-<name>
description: <what it does and when to invoke it — this is what drives model auto-invocation>
---
```

Every skill and command carries the `cepg-` prefix on its `name:` field (and directory/filename) — this is what keeps `/cepg-scope`, `/cepg-plan`, etc. from colliding with another marketplace plugin's own `/scope` or `/plan`. Several platforms (OpenCode, and the skills-pointing static-manifest platforms) derive their command surface directly from this `name:` field, not from `commands/*.md` — the prefix has to live here, not just on the command wrapper, for the dedupe to hold everywhere.

`argument-hint` is optional — add it only when the skill takes a meaningful argument (see Compound Engineering's convention). Don't add `disable-model-invocation` here — that field belongs on the command wrapper (below), not the skill. A skill without it stays reachable by the model's own judgment; the command wrapper is the explicit, always-available entry point alongside it.

## 2. Platform note (skills that name a Claude-specific tool)

If the skill's body names a Claude Code tool directly (`Read`, `Edit`, `Bash`, `Task`, `AskUserQuestion`, `TodoWrite`), add this paragraph near the top, right after the frontmatter:

```markdown
**Platform note.** On Codex or another non-Claude runtime, the Claude tool names and model slugs named below are Claude defaults. Resolve them via [`codex-tools.md`](../../references/codex-tools.md).
```

Don't restate the mapping table inline — that's Compound Engineering's older, more duplicative pattern. Point at the one shared file (see `references/codex-tools.md`) every time.

## 3. Command wrapper (`commands/cepg-<name>.md`)

```yaml
---
name: cepg-<name>
description: <short imperative, distinct wording from the skill's own description>
disable-model-invocation: true
---

Invoke the `cepg-<name>` skill and follow it.
```

This is the thin-wrapper pattern: the command is only reachable by explicit `/cepg-<name>` invocation (`disable-model-invocation: true` keeps the model from double-triggering off the command file itself), while the skill underneath stays independently reachable via its own `description`. One exception: `commands/cepg-check.md` wraps two skills (`cepg-check-debug`, `cepg-check-review`) and routes between them — see its own file for the routing rule, since it doesn't follow the one-command-one-skill shape.

## 4. Cross-lineage specialist dispatch

When a skill needs to fan out to independent specialist reviewers (not sequential staged sections — see `skills/cepg-scope/SKILL.md` for that shape instead), dispatch generic subagents seeded with a prompt-fragment file, not a named custom agent type:

> Use a generic subagent, with the prompt built from `references/personas/<specialist>.md`.

This is Compound Engineering's pattern (`references/personas/`), independently converged on by gstack's review-army design, and it doesn't depend on a platform's custom-subagent-type feature — keeps skills portable across Claude Code and Codex.
