# cepg

One command surface across six phases of engineering work — scope, plan, build, check, ship, learn — native on Claude Code, Codex, Cursor, Devin, Grok, Kimi, Antigravity, OpenCode, and Cline (see Platform support below).

## Why

Three projects each do part of this well and none do all of it:

- **[Compound Engineering](https://github.com/EveryInc/compound-engineering-plugin)** — brainstorm, plan, work, review, compound. The inner-loop brain.
- **[pstack](https://github.com/michael-denyer/pstack-claude)** — type-first design, reproduce-first debugging, prove-it-works verification, adversarial review. Execution discipline.
- **[gstack](https://github.com/garrytan/gstack)** — product/architecture/design sign-off, QA, security review, staged production deploys. Outer-loop bookends.

cepg forks Compound Engineering as its spine and mines specific techniques from pstack and gstack into native skills and hooks. Neither pstack nor gstack is installed as a live dependency — see `docs/plans/2026-09-04-001-feat-unified-ce-pstack-gstack-plugin-plan.md` for why, and `docs/brainstorms/2026-09-02-pstack-ce-plugin-merge-requirements.md` for the original scope.

## Commands

Every command and skill carries a `cepg-` prefix (Compound Engineering + pstack + gstack) — the four-source merge this plugin represents — specifically to avoid colliding with another marketplace plugin's own `/scope`, `/plan`, or similar generically-named command.

| Command | Phase | What it does |
|---|---|---|
| `/cepg-scope` | Scope & Sign-off | Product framing, architecture lock-in, design and DX review — before planning starts. |
| `/cepg-plan` | Plan | Implementation planning with type/module-shape-first discipline. |
| `/cepg-build` | Build | Execution with reproduce-before-fix, prove-it-works, and reversibility-based autonomy. |
| `/cepg-check debug` / `/cepg-check review` | Check | Root-cause debugging, or tiered code review (persona review, blast-radius, multi-model escalation, comment hygiene). |
| `/cepg-ship` | Ship | QA through production deploy and health verification, gated behind safety hooks. |
| `/cepg-learn` | Learn | Writes learnings to `docs/solutions/`/`CONCEPTS.md`, proposes skill-level edits for significant patterns. |

Each command is a thin wrapper (`disable-model-invocation: true`) around the skill(s) under `skills/`; the skills themselves also auto-invoke via their own `description` frontmatter — there's no separate hook-based router.

## Example workflows

**Standard feature loop**

```
/cepg-scope   Add CSV export to the reports page
/cepg-plan
/cepg-build
/cepg-check review
/cepg-ship
```

`/cepg-scope` writes its sign-off to `docs/scope/`; `/cepg-plan` finds it there automatically, so you don't repeat the description at each step.

**Fixing a bug**

```
/cepg-check debug   Users report the export button hangs on large reports
/cepg-build
/cepg-check review
/cepg-ship
```

`/cepg-check debug` hands a reproduction and root-cause report straight to `/cepg-build`'s Gate 1 — no separate repro step needed once `/cepg-build` picks it up.

**Small, well-scoped change**

```
/cepg-build   Rename `reportId` to `reportUuid` across the exports module
/cepg-check review
```

No architectural decisions, no sign-off needed for a change this bounded — `/cepg-build` triages it as Trivial/Small on its own and skips straight to implementation. `/cepg-scope` and `/cepg-plan` are for when a request is ambitious, vague, or crosses multiple specialties, not every change.

## Prerequisites

cepg has no dedicated setup/preflight skill — a seventh command was deliberately left out to preserve the six-phase command surface (see the plan's Scope Boundaries). Before your first `/cepg-ship` run, confirm manually:

- `gh` is installed and authenticated (`gh auth status`) — `/cepg-ship` uses it for PR creation and CI status.
- The hook scripts are executable (`chmod +x hooks/*.sh`) if your platform's install step didn't preserve the bit.
- `${CLAUDE_PLUGIN_DATA:-~/.cepg}` is writable — this is where the safety hooks keep their state (e.g. the freeze boundary).
- (Optional) If `docs/` is already tracked content owned by something else, set `docs_root` in `.cepg/config.yaml` or `.cepg/config.local.yaml` to relocate every cepg-written artifact folder — see [`references/artifact-root.md`](references/artifact-root.md). Unset, nothing changes.

Nothing in cepg checks these for you ahead of time; a missing prerequisite surfaces as a failure mid-run rather than upfront.

## Platform support

Native on every platform Compound Engineering supports:

| Platform | Mechanism |
|---|---|
| Claude Code | Native, auto-discovers `skills/` |
| Codex | Native, `.codex-plugin/plugin.json` points at `skills/` |
| Cursor, Devin, Grok, Kimi | Static manifest (`.cursor-plugin/`, `.devin-plugin/`, `.grok-plugin/`, `.kimi-plugin/`) pointing at `skills/` |
| Antigravity | Root `plugin.json`; `.agy/plugin.json` and `.agy/skills` are symlinks to it |
| OpenCode | `.opencode/plugins/cepg.js` generates one command per skill from its frontmatter |
| Cline | `.cline/scripts/install-skills.sh` symlinks skill directories into Cline's discovery path |

No build step for any of these — they all read the same `skills/` directory. Codex-specific tool-name resolution lives in `references/codex-tools.md`; every skill's "Platform note" points there instead of restating the mapping inline.

**Two platform-specific limitations, not bugs:**
- **Safety hooks (destructive-command and deploy gating) are Claude Code + Codex only.** `PreToolUse` hooks are a Claude-Code-specific mechanism the other platforms don't have — confirmed from gstack's own source, which doesn't attempt to port its equivalent hooks anywhere else either.
- **OpenCode's generated commands don't replicate `/cepg-check`'s routing.** Its shim generates one command per skill file; `cepg-check-debug` and `cepg-check-review` surface as two separate commands there instead of one routed `/cepg-check`.

## Status

Early scaffold — see the plan doc above for what's built vs. open. `cepg` is a placeholder name.
