# Artifact root

By default every cepg-written artifact folder lives under `docs/` — `docs/plans/`,
`docs/solutions/`, `docs/scope/`, legacy `docs/brainstorms/`. Mined from Compound
Engineering's `docs_root` mechanism: `docs_root` relocates that root to any
repo-relative folder, for projects where `docs/` is already tracked content owned by
something else (an Obsidian vault, a docs site). Unset, behavior is byte-identical to
today. `CONCEPTS.md` always stays at the repo root regardless — it isn't one of the
relocatable artifact kinds.

Every skill that writes or looks up an artifact under `docs/` resolves the root this
way instead of hardcoding `docs/`.

## Resolution

Read `docs_root` from two layers, first non-empty wins:

1. Checkout-local `.cepg/config.local.yaml` (gitignored, per-checkout).
2. Tracked `.cepg/config.yaml` (committed, reaches every clone and worktree).

Prefer the tracked file for a team-wide setting — the local file is per-checkout and
has to be re-set in each new worktree.

## Validation

Two things make `docs_root` unlike an ordinary setting:

- **It is repo-relative and validated.** The value must resolve to a directory
  inside the repository — not absolute, not escaping via `../` or a symlink, not the
  repo root itself, not under `.git/`. A missing directory is created on first write.
- **It fails closed.** An invalid value stops the current skill with an error rather
  than silently falling back to `docs/` — silently writing to the default would land
  artifacts in the exact location the project configured away from. Report the
  resolved root and which layer supplied it when a skill first reads it in a run.

## Setup

cepg has no dedicated setup skill (the README's own stance: "a seventh command was
deliberately left out to preserve the six-phase command surface"), so there's no
interactive bootstrap for this file. A project that wants `docs_root` copies
`.cepg/config.local.example.yaml` to `.cepg/config.local.yaml` (or writes the key
directly into a tracked `.cepg/config.yaml`) by hand, the same way cepg's other
Prerequisites are confirmed manually rather than checked for the user ahead of time.
