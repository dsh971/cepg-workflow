# Installing cep for Cline

Cline loads cep through native **skills** discovery — the same `SKILL.md` directories shipped in this repository's `skills/` folder. No build or generated-copy step is required.

## Extension (VS Code, Cursor, JetBrains)

1. Install the [Cline extension](https://docs.cline.bot/getting-started/installing-cline) in your editor.
2. Enable **Settings -> Features -> Enable Skills**.
3. Link cep's skills globally or into your project (see below).
4. Start a new Cline task. Skills such as `cepg-scope` and `cepg-plan` appear when their descriptions match your request.

## Install skills

From a clone of this repository:

```bash
# Global (~/.cline/skills/) — available in every project
./cep/.cline/scripts/install-skills.sh --global

# Project (.cline/skills/ in the current directory)
./cep/.cline/scripts/install-skills.sh --project
```

The script creates symlinks so Cline reads the live skill directories from your checkout. Re-run it after `git pull` to refresh links when skill folder names change. It only ever creates or replaces cep-owned symlinks; an existing `~/.cline/skills/<name>` pointing at your own skill, a fork, or another checkout is left untouched.

## No slash-command equivalent

cep's `commands/*.md` wrappers (the `/cepg-scope`, `/cepg-plan`, `/cepg-build`, `/cepg-check`, `/cepg-ship`, `/cepg-learn` slash commands available on Claude Code and Codex) are not read by Cline — it only discovers `skills/`. All six skills activate by description-matching instead; there's no manual invocation path on this platform. None of the six currently set `disable-model-invocation` on the skill file itself, so this script links all of them without exclusions.

## Uninstall

```bash
rm -rf ~/.cline/skills/cepg-scope ~/.cline/skills/cepg-plan ~/.cline/skills/cepg-build \
       ~/.cline/skills/cepg-check-debug ~/.cline/skills/cepg-check-review \
       ~/.cline/skills/cepg-ship ~/.cline/skills/cepg-learn
```
