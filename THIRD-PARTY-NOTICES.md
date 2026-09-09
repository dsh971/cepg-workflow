# Third-party notices

cepg is a fork of Compound Engineering, with technique mined from pstack and gstack. All three are MIT-licensed, which permits this, subject to including the notices below — required by MIT's "the above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software" clause, and good practice regardless.

## Compound Engineering

Copyright (c) 2025 Every
https://github.com/EveryInc/compound-engineering-plugin — MIT License

cepg's overall structure (the phase-skill + thin-command-wrapper pattern, `description`-driven routing with no hook-based router, generic-subagent-plus-prompt-file specialist dispatch) and the base content for `skills/cepg-plan/`, `skills/cepg-build/`, `skills/cepg-check-debug/`, `skills/cepg-check-review/` (persona set), and `skills/cepg-learn/` are adapted from Compound Engineering's `ce-plan`, `ce-work`, `ce-debug`, `ce-code-review`, and `ce-compound` skills respectively. The platform-adapter files under `.cursor-plugin/`, `.devin-plugin/`, `.grok-plugin/`, `.kimi-plugin/`, `.agy/`, `plugin.json`, `.opencode/plugins/cepg.js`, and `.cline/scripts/install-skills.sh` are near-verbatim ports of Compound Engineering's own adapter files, renamed and re-described for cepg.

## pstack

Copyright (c) 2026 Lauren Tan
https://github.com/michael-denyer/pstack-claude — MIT License (Claude Code port by Michael Denyer, original pstack for Cursor by Lauren Tan)

`references/codex-tools.md` is adapted from pstack's `skills/poteto-mode/references/codex-tools.md`. The reproduce-first, prove-it-works, and reversibility-based-autonomy disciplines folded into `skills/cepg-build/` are mined from pstack's `tdd`, `principle-prove-it-works`, and `principle-never-block-on-the-human` skills. The type-first planning step in `skills/cepg-plan/` is mined from pstack's `architect` skill. The multi-model escalation tier in `skills/cepg-check-review/` is mined from pstack's `interrogate` skill. The comment-hygiene pass in `skills/cepg-check-review/` is mined from pstack's `no-comments` skill and `comment-sicko` agent. The unattended PR persistence in `skills/cepg-ship/` is mined from pstack's `babysit` skill. The skill-edit significance check in `skills/cepg-learn/` is mined from pstack's `reflect` skill. The deepest code-review tier is mined from pstack's `thermo-nuclear-code-quality-review` skill.

## gstack

Copyright (c) 2026 Garry Tan
https://github.com/garrytan/gstack — MIT License

`skills/cepg-scope/` is adapted from gstack's `office-hours`, `plan-ceo-review`, `plan-eng-review`, `plan-design-review`, and `plan-devex-review` skills. Part of `skills/cepg-check-debug/` is mined from gstack's `investigate` skill. Part of `skills/cepg-check-review/` (including several persona fragments and the `/codex` cross-model escalation path) is mined from gstack's `review` skill and its specialist fragments, and its `codex` skill. `skills/cepg-ship/` is adapted from gstack's `qa`, `ship`, and `land-and-deploy` skills. `hooks/hooks.json`, `hooks/check-careful.sh`, `hooks/check-freeze.sh`, and `hooks/hook-extract.sh` are ported from gstack's `careful` and `freeze` skills' actual check scripts (`careful/bin/check-careful.sh`, `freeze/bin/check-freeze.sh`, `careful/bin/hook-extract.sh`), adapted for plugin-scoped `hooks/hooks.json` registration instead of gstack's global-settings-mutation mechanism, with an added Codex host-conditional escalation.

## What isn't ported

Neither pstack nor gstack is installed as a live dependency of cepg — see `docs/brainstorms/2026-09-02-pstack-ce-plugin-merge-requirements.md` and `docs/plans/2026-09-04-001-feat-unified-ce-pstack-gstack-plugin-plan.md` for why. Everything above is technique and structure mined into cepg's own files, not a runtime dependency on either project.
