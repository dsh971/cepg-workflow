---
name: cepg-ship
description: "Ship a completed, review-ready change through to production. Runs a QA pass and gets the branch to green, opens or updates the PR, stays attached to it -- unattended CI-fix and straightforward-comment triage -- until it is mergeable, then performs a gated, health-verified production deploy: config-fingerprint dry-run re-validation on drift, a staged rollout with a named health-check gate at each stage, autonomous-or-human-gated rollback on failure, and mid-rollout interruption detection on resume. Every deploy-affecting action is gated by this plugin's own safety hooks. Use when asked to ship, deploy, release, open a PR and see it through to merge, or take a change to production -- not for the implementation itself (see Build) or formal code review (see Check)."
argument-hint: "[PR ref, branch, or blank to use the branch most recently worked on in this session]"
---

**Platform note.** On Codex or another non-Claude runtime, the Claude tool names and model slugs named below are Claude defaults. Resolve them via [`codex-tools.md`](../../references/codex-tools.md).

# Ship

This skill takes a Build-verified, Check-reviewed change from a local branch through to a health-verified production deploy. It does not implement or review the change -- both of those already happened upstream. Its job is QA and get-to-green, PR mechanics, unattended persistence on the open PR, and a gated production rollout with rollback.

## Outcome

- **Result:** Either a merged PR with a health-verified production deploy, or a clearly reported halt state -- pre-traffic stop-and-report, post-traffic halt-and-rollback, or a surfaced mid-rollout interruption -- with nothing silently abandoned or silently retried.
- **Done:** The PR is merged; the deploy (single-stage or staged, per the project's own configuration) has passed its health-check gate at every stage; no rollout state file is left in `in_progress` when the skill's own turn ends.
- **Not this skill's job:** Implementation lives in `/cepg-build`; formal review lives in `/cepg-check`. This skill assumes both already happened -- it does not re-review the diff, though `babysit` below still triages incoming PR comments as they arrive.

**Lineage.** QA and get-to-green mine gstack's `/qa` and `/ship` skills: the destructive-command-hardened test-fix-reverify loop and version/CHANGELOG/PR-title bookkeeping of `/ship`'s pipeline, and `/qa`'s severity-tiered issue triage for user-facing changes, adapted rather than ported whole -- gstack's Aside-mediated real-browser session and GBrain-backed learning search are this plan's declared out-of-scope browser-automation and indexing infrastructure (see the plan's Scope Boundaries), so the QA phase below uses whatever browser-automation skill is already installed (`agent-browser`, if present) rather than depending on Aside. PR creation and push mechanics are Compound Engineering's `ce-commit-push-pr` -- its branch/PR-state resolution, `--body-file` (never stdin) apply discipline, and existing-PR update-vs-create disambiguation carry forward directly. Unattended persistence on the open PR is pstack's `babysit`, generalized off Cursor-analog framing. Production deploy is adapted from gstack's `land-and-deploy`: its config-fingerprint dry-run gate and canary health-check signal are mined directly (see Phase 4), but gstack's own canary check is a **single-pass** verification with no staged/percentage rollout -- the staged-rollout mechanism below is this plugin's own generalization of that one check into a repeatable per-stage gate, since gstack's actual infrastructure doesn't have one to port (see Phase 4's note on this). Rollback authority (autonomous-with-notify vs. human-confirmed) mirrors Build's Gate 3 reversibility split.

## Phase 0 -- Resolve the target and preconditions

`<input>` is a PR ref, a branch name, or blank (use the branch most recently worked on this session). Resolve the branch and check for an existing open PR the same way `ce-commit-push-pr`'s Context step does: `git branch --show-current`, then `gh pr list --head <branch> --state open --json number,url,title,body,state,mergeable,statusCheckRollup`. A non-zero exit from that check means PR state is **unknown** (auth/connectivity), never "no PR" -- resolve `gh auth status` before treating it as absent.

**Mid-rollout resume check runs here, before anything else.** Before starting any new work, check for an existing rollout state file for this repo (Phase 4 defines its path and shape). If one exists with status `in_progress`, this is a resumed session after an interruption -- go straight to Phase 4's resume handling instead of starting QA over. Do not silently restart the rollout from stage one, and do not silently treat an interrupted rollout as abandoned.

Working tree must be clean before QA starts (matching gstack's `/qa` precondition) -- if not, commit, stash, or stop and ask, per Build's Gate 3 (uncommitted work is reversible to stash, so handle it and proceed; don't block on asking unless it's genuinely ambiguous which changes belong to this ship).

## Phase 1 -- QA and get-to-green

1. **Run the existing verification suite first.** Tests, lint, typecheck, build -- whatever the project's own commands are. Failures here are the common case and are fixed in place: locate source, fix, rerun, confirm green. This is Build's Gate 2 discipline applied one more time at the ship boundary, not a new invention.
2. **User-facing changes get a QA pass beyond unit tests.** If the diff touches UI, an API surface, or CLI behavior a person exercises directly, drive the actual path once: `agent-browser` for a web UI if installed, otherwise whatever the platform run/verify skill exposes. Triage anything found by severity (critical/high fixed now; medium fixed if the fix is contained; low/cosmetic logged rather than block ship) -- mirroring `/qa`'s severity tiers without its Aside/GBrain-specific machinery.
3. **Each fix in this phase is its own atomic commit** with before/after evidence (what you ran, what you observed) -- never a `WIP` commit here, since Phase 2 pushes whatever HEAD looks like at the moment it runs.
4. **Re-verify after any code change.** If anything changed after step 1's run, rerun it before moving on -- trust a fresh result, never a stale one from before the fix. This is `/ship`'s evidence-freshness rule, generalized off its specific `gstack-evidence` tooling: the rule (rerun on any post-verification code change), not the CLI.
5. **Escalation, not indefinite retry.** If the same check is still failing after three fix-rerun rounds, stop and report what's broken rather than attempting a fourth blind fix -- this is the same smart-escalation instinct as Check -- debug's, applied to a stuck green-up instead of a stuck investigation.

Exit this phase only when the verification suite is green and any QA findings above medium severity are resolved.

## Phase 2 -- Commit, push, PR

Follow `ce-commit-push-pr`'s mechanics directly for this step: group changes into 2-3 logical commits at most (never `git add -A`/`git add .`), push with `git push -u origin HEAD` after re-confirming the live branch, and apply the PR body via a temp file and `--body-file` (never `--body "$(cat ...)"` or a stdin pipe -- both can silently produce an empty body while `gh` still exits 0). Re-check for a PR that appeared since Phase 0 immediately before `gh pr create`, and disambiguate multi-fork matches by `headRepositoryOwner`/`headRefName` rather than assuming the first result. If a PR already exists, this phase pushes new commits onto it and updates the description rather than creating a duplicate.

This phase does not merge. Merge happens in Phase 3, once the PR is actually mergeable.

## Phase 3 -- Babysit: stay attached until mergeable

Once a PR is open, this skill does not stop and wait to be re-invoked -- it stays attached, per pstack's `babysit`, until the PR reaches a mergeable state or a genuine blocker is reached.

1. **Fetch PR state:** `gh pr view <number> --json number,title,state,mergeable,reviewDecision,statusCheckRollup,mergeStateStatus,comments,reviews`.
2. **Triage in priority order:**
   - **Merge conflicts** (`mergeStateStatus == DIRTY`): rebase or merge the base branch, resolve, and force-push only if the branch is exclusively yours and not shared -- otherwise stop and ask.
   - **Failing checks:** pull logs (`gh run view <run-id> --log-failed`), root-cause, fix, commit, push. This is Phase 1's fix-rerun loop, re-entered as needed -- it does not require a second manual invocation of this skill.
   - **Review comments:** act on feedback you actually agree with. A mechanical fix (rename, guard clause, formatting) gets applied and the commit message quotes the comment; a judgment call gets a reply explaining the reasoning instead of a guessed edit.
3. **Poll on an interval matched to what's being watched:** an active CI run polls until it resolves; an awaiting-review PR checks on a 20-30 minute heartbeat; an otherwise-idle PR checks hourly for new comments. Implement the wait as a bounded loop over the `gh` calls above (sleep between polls, cap total wall time per round) rather than a single blocking call with no cap.
4. **Stop conditions:** checks green, every comment resolved, and the PR merges cleanly -> proceed to Phase 4. Three rounds of fix-push-recheck without reaching green -> stop, summarize what's still broken, and hand control back rather than grinding a fourth round. A fix would force a genuine design choice -> pause and ask, per Build's Gate 3, rather than guessing.
5. **Merge** once every check above is satisfied. Never bypass a failing check by marking it not required, and never rewrite history on a branch others may have pulled without clearing it first.

**Unattended-loop safety note.** This phase is explicitly designed to run without a human re-prompting it, which changes what an `ask`-tier safety-hook hit means. Interactively, an `ask` decision from this plugin's hooks (see below) surfaces a prompt someone answers; unattended, nobody is watching for it. Treat an `ask`-tier hit during this phase as a hard stop, not something to route around or wait out: pause the loop, report exactly what command or edit triggered it and why, and resume only once a human has responded. Do not construct commands specifically to avoid tripping the pattern match -- that defeats the boundary the hook exists to enforce.

## Phase 4 -- Production deploy: dry-run gate, staged rollout, health verification

Everything in this phase is deploy-affecting and is gated by this plugin's own safety hooks, declared in `hooks/hooks.json` (`check-careful.sh` on the Bash matcher, `check-freeze.sh` on the Edit/Write matcher) -- not gstack's settings-mutation mechanism, which this plugin does not carry forward. Do not attempt to work around a hook decision; a HIGH-tier deny or a MEDIUM-tier ask firing here is the boundary functioning as intended, and the one place it deliberately steps aside (a confirmed rollback's force-push to the default branch) is handled explicitly in the Rollback section below, not by evading the check.

### Config-fingerprint dry-run gate

Adapted from `land-and-deploy`'s first-run-validation: compute a fingerprint from two hashes, concatenated --

1. The project's own `## Deploy Configuration` section (in `CLAUDE.md`/`AGENTS.md`, resolved per U2's CLAUDE.md-vs-AGENTS.md convention) -- platform, production URL, and related settings.
2. The deploy-relevant workflow/config files present in the repo: `.github/workflows/*deploy*` and `*cd*`, or platform-native files (`fly.toml`, `render.yaml`, `vercel.json`, `netlify.toml`, `Procfile`) when GitHub Actions isn't the deploy mechanism.

Store the fingerprint at `${CEP_HOME:-$HOME/.cep}/ship/<repo-slug>/deploy-confirmed` (`<repo-slug>` is the sanitized `origin` remote, owner_repo with `/` replaced by `_`; fall back to the sanitized absolute repo path when there's no remote). Three states:

- **No file present (first run):** stop. Explain the deploy mechanism in full (platform, URL, workflow) before proceeding, get explicit confirmation, then write the fingerprint.
- **Fingerprint matches:** skip straight to the staged rollout below.
- **Fingerprint differs (config changed since last confirmed deploy):** stop and re-run the same first-run validation -- something changed (new platform, different workflow, updated URL) and a silent proceed is exactly the failure mode this gate exists to prevent. Write the new fingerprint only after re-confirmation.

### Staged rollout and the health-check gate

**Named health-check signal, threshold, and timeout** (the concrete gate that advances or halts each stage):

| Signal | Threshold |
|---|---|
| HTTP status at the deployed URL | Must equal `200` (or a project-configured expected code) |
| Page load time | Under `10s` |
| Console errors | Zero new matches against `Error`, `Uncaught`, `Failed to load`, `TypeError`, `ReferenceError` that weren't already present pre-deploy |
| Page content | Not blank, not a generic platform error screen |

Poll every `30s`; timeout the wait for deploy completion at `20min` and for CI at `15min` (matching `land-and-deploy`'s own values). Once the health check first passes, hold for a stabilization window (`5min` default, configurable) with continued 30s re-checks before advancing -- a single instantaneous pass is not enough evidence a stage is actually healthy.

**On the staged-rollout mechanism itself:** gstack's `land-and-deploy` does not actually implement percentage-based canary staging -- its own canary step is a single post-deploy verification pass, not a multi-stage rollout. This is a case the plan flagged explicitly: the health-check signal above is portable (it's just an HTTP+browser check against a URL), but a real percentage-traffic staged rollout depends on infrastructure this plugin has no generic access to (a load balancer, a feature-flag service, a platform-native canary feature). So:

- **Default (no project staging config):** one stage -- "deployed, full traffic" -- gated by the health check above. This matches what gstack's own tooling actually does.
- **Project-configured staging (per-adoption configuration point):** when the project's `## Deploy Configuration` section names an ordered list of stages (e.g., a percentage-traffic split, a canary environment name, a blue/green target), walk them in order, applying the same health-check gate at each stage boundary before advancing to the next. This plugin does not invent a traffic-splitting mechanism -- it drives whatever CLI or API the project's own staging setup exposes, the same way `land-and-deploy` drives whichever of GitHub Actions/Fly.io/Render/Vercel/Netlify/Heroku a project has configured.

**Rollout state file.** Before starting the first stage, write `${CEP_HOME:-$HOME/.cep}/ship/<repo-slug>/rollout-state.json`: PR number, merge commit SHA, ordered stage list, current stage index, stage-start timestamp, last health-check result, status (`in_progress`). Update it at every stage transition and every health-check result. Finalize it (`completed`, or `rolled_back`) only once the outcome is certain -- never leave it `in_progress` across a session boundary if the rollout actually finished or failed within this run.

### Failure handling

- **Failure before any stage has shipped traffic** (deploy itself fails to complete, first stage never goes live): stop and report. No rollback is needed -- nothing is serving traffic yet.
- **Failure after a stage has shipped traffic** (health check fails post-advance, or degrades during the stabilization hold): halt immediately, do not advance further, and move to rollback below. Never advance to the next stage on a failing or ambiguous health check.

### Rollback authority split

Matches Build's Gate 3 reversibility framing exactly:

- **Clear failure** (health check fails unambiguously -- non-200 status, console errors matching the known-bad patterns, a blank/error page): roll back autonomously and notify. Waiting for a human to confirm the obvious wastes the exact window that limits blast radius.
- **Ambiguous failure** (borderline load time, a transient-looking single failed poll that didn't repeat, a signal outside the four named above): pause and require explicit human confirmation before rolling back. Do not guess at ambiguous signals in either direction -- neither auto-rollback nor auto-continue.

### Rollback mechanism

Prefer the deploy platform's own rollback command when the project's configuration names one (e.g., a platform CLI's rollback/redeploy-previous action) -- this never touches git and never needs the hook bypass below.

When no platform rollback exists and the recovery path is a git-level revert:

- **Default: `git revert <merge-commit-sha> --no-edit` then a normal (non-force) push to the base branch**, followed by redeploying. This is a forward commit, not a history rewrite, so it does not trip the HIGH-tier force-push check at all.
- **Only when a force-reset to a known-good ref is genuinely required** (a revert commit can't redeploy fast enough, or the platform demands resetting to a prior SHA): this is a force-push to the default branch, which `check-careful.sh`'s HIGH tier hard-denies by design. Arm the bypass **before** issuing that command: write the current UTC epoch seconds as the first line of `${CEP_HOME:-$HOME/.cep}/rollback-active.txt` (the exact file and TTL, default `1800s` via `CEP_ROLLBACK_TTL_SECS`, that `check-careful.sh`'s `_cep_rollback_bypass_active` check already reads). Issue the force-push. **Clear the flag immediately after** (delete the file, don't just let the TTL expire) -- an armed bypass left standing is a hole in the boundary it exists to make narrow. This bypass only ever applies to the force-push-to-default-branch check; it does not and must not touch any other destructive-pattern match (`rm -rf`, `DROP TABLE`, etc.) -- those stay fully enforced during a rollback.

Only arm the flag once the rollback decision itself is made (autonomous-clear-failure or human-confirmed-ambiguous, per the split above) -- never speculatively, and never for a rollback that turns out not to need a force-push.

### Mid-rollout interruption detection and resume

If this skill's own session ends or crashes with `rollout-state.json` still `in_progress`, the next invocation's Phase 0 resume check catches it. On resume:

1. Read the state file: which stage, how long ago the last health check ran, what it found.
2. Re-run the health check now, fresh -- do not trust a stale result from before the interruption.
3. **Surface the partial state explicitly** before doing anything else: "Rollout for PR #<n> was interrupted at stage <k> of <n>, last health check <time> ago showed <result>." Never silently resume from a stale assumption and never silently discard the in-progress state and start over.
4. Proceed from there using the same stage/health-check/rollback logic above -- a fresh health-check failure at resume time is a failure after traffic has shipped, so it goes through the halt-and-rollback path, with the same authority split.

## Key principles

- **QA and green before PR mechanics.** Don't push a broken branch and hope Phase 3 cleans it up -- Phase 1 exists so Phase 3's babysit loop starts from a green baseline.
- **Stay attached, don't fire-and-forget.** A PR opened and abandoned is not shipped. Babysit until it's actually mergeable.
- **Every deploy-affecting action is hook-gated, by design.** A hook firing here is not an obstacle to route around; it's the safety boundary this plan built specifically to sit in front of this phase.
- **Advance only on a real health-check pass, held, not a single instantaneous check.**
- **Rollback authority follows the same reversibility discipline as Build:** autonomous where the failure is unambiguous, human-gated where it isn't.
- **An interrupted rollout is a fact to report, never a fact to hide.** Silent restart and silent abandonment are both wrong; surfacing the partial state is the only correct resume behavior.

## Common pitfalls

- Skipping Phase 1's re-verify-after-fix step and pushing on a stale test result.
- Using `--body "$(cat ...)"` or a stdin pipe for the PR body instead of `--body-file` -- both can silently produce an empty body.
- Letting Phase 3's babysit loop grind a fourth fix-push-recheck round instead of stopping to report after three.
- Treating an unattended `ask`-tier hook hit as something to wait out or route around instead of a hard stop.
- Advancing a rollout stage on a single passing health check with no stabilization hold.
- Auto-rolling-back on an ambiguous signal, or auto-continuing past one -- both skip the required human confirmation.
- Arming the rollback bypass flag speculatively, or forgetting to clear it after the rollback command runs.
- Silently restarting an interrupted rollout from stage one, or silently treating it as abandoned, instead of surfacing the partial state on resume.
