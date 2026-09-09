# Codex tool mapping

cepg's skills are written in Claude Code tool language (the `Skill` tool, the `Agent` tool, `AskUserQuestion`, model slugs like `claude-opus-4-8`). On Codex the skills are the same files — only the tool names resolve differently. Read this when a skill names a Claude tool, a Claude built-in skill, or a `claude-*` model. Every skill's "Platform note" paragraph points here instead of restating this table inline.

## Tool actions

| cepg / Claude action | Codex equivalent |
|------------------------|------------------|
| Read a file | `shell` (`cat`, `head`, `tail`) |
| Create / edit / delete a file | `apply_patch` |
| Run a shell command | `shell` |
| Search file contents / find files | `shell` (`rg`, `grep`, `find`, `ls`) |
| Fetch a URL | `shell` with `curl` / `wget` |
| Search the web | `web_search` |
| Invoke a skill (the `Skill` tool, `/command`) | Skills load natively. Follow the instructions presented. |
| Dispatch a subagent (the `Agent`/`Task` tool) | `spawn_agent` |
| Dispatch N parallel subagents in one turn | N `spawn_agent` calls in one response |
| Wait for a subagent result | `wait_agent` |
| Free a finished subagent slot | `close_agent` |
| Track tasks (the todolist / `TodoWrite`) | `update_plan` |
| Ask the human a fixed-choice question (`AskUserQuestion`) | Ask in plain text and let the user answer. Codex has no structured-choice tool. |

Subagent dispatch needs `multi_agent` enabled. Add to `~/.codex/config.toml`:

```toml
[features]
multi_agent = true
```

Without it, `spawn_agent` is unavailable and fan-out skills (the code-review skill's specialist dispatch and multi-model escalation) degrade to a single sequential pass.

## Subagent policy

cepg dispatches specialist reviewers as generic subagents seeded with a prompt-fragment file (`references/personas/<specialist>.md`) — not a named custom agent type — precisely so this holds on both platforms without translation. On Codex, dispatch a `spawn_agent` whose instructions embed the persona file's content directly. Pass file pointers not inlined context where possible, review every subagent's diff yourself.

## Model names

Skills name Claude defaults (`claude-opus-4-8` for code/prose/judgment; multiple distinct models for cross-model review escalation). These slugs do not resolve on Codex. Substitute your configured Codex models:

- Single-model roles: your primary Codex model (for example `gpt-5.6-sol`).
- Cross-model escalation (the code-review skill's `interrogate`-derived tier): the signal comes from model diversity, so use the distinct Codex models available to you. If only one model family is reachable, vary reasoning effort and note in the finding that diversity was reduced.

## Host detection

Some behavior branches on which host is running the skill — notably the safety hooks (`hooks/hooks.json`), where Codex's `PreToolUse` hooks support `deny` but silently ignore `ask` (confirmed via openai/codex#28437, open as of this writing). Detect the host the same way skill dispatch already differs: Claude Code invokes skills via the `Skill` tool and exposes `AskUserQuestion`; Codex has neither. When a skill or hook needs to branch on host, check for a Codex-specific environment signal (e.g. `CODEX_HOME`) rather than assuming Claude Code as the default.

## Claude built-in skills cepg references

| Claude built-in | On Codex |
|---|---|
| `run` (drive a CLI/TUI to see a change work) | Run the app yourself via `shell` and observe the real output. |
| `verify` (drive a UI to confirm a fix) | Drive the UI with whatever automation you have, or hand the user a concrete manual check. Do not claim done without observing the artifact. |

## Instructions file

Where a cepg skill says "your instructions file," on Codex that is `AGENTS.md` (project root, plus `~/.codex/AGENTS.md` global). On Claude Code it is `CLAUDE.md`.
