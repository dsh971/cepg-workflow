#!/usr/bin/env bash
# check-careful.sh — cep PreToolUse hook, Bash matcher.
# Reads JSON from stdin, checks Bash command for destructive patterns.
# Ported from gstack's careful/bin/check-careful.sh (function names renamed
# gstack_* -> cep_*, GSTACK_HOME -> CEP_HOME — cosmetic only; detection logic,
# tiering, and fail-safe polarity are unchanged). Unlike gstack, where this
# check is only registered while a /careful session is active, this hook is
# a standing plugin-scoped PreToolUse entry (hooks/hooks.json) — always on.
#
# Two tiers:
#   HIGH   — a tiny set of catastrophic SIMPLE commands returns "deny"
#            (best-effort advisory hard-stop, not a policy boundary).
#   MEDIUM — the destructive families below return "ask" (always overridable
#            on Claude Code; escalated to "deny" on Codex — see
#            cep_hook_decision_ask in hook-extract.sh).
# The decision MUST be nested under hookSpecificOutput — Claude Code ignores a
# top-level permissionDecision, which silently no-ops the warning.
set -euo pipefail

# Read stdin (JSON with tool_input)
INPUT=$(cat)

# Shared JSON + host-detection helpers (extractor + encoder) — one copy for
# check-careful.sh AND check-freeze.sh. See hook-extract.sh for the drift
# history that motivated the shared file.
_HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=hooks/hook-extract.sh
# bash treats `.` on a MISSING file as fatal non-interactively; a partial
# install must degrade to an ASK (this is the ask-tier hook), never silence.
_HOOK_HELPER="$_HOOK_DIR/hook-extract.sh"
if [ ! -f "$_HOOK_HELPER" ] || ! . "$_HOOK_HELPER" 2>/dev/null; then
  # cep_hook_decision_ask isn't available yet (that's the problem), so this
  # one envelope is hand-built rather than routed through the missing helper.
  # Codex escalation cannot apply here either (cep_is_codex isn't loaded) —
  # a broken install already fails toward the safer state on Claude Code
  # (a prompt); on Codex it fails open, same as gstack's original. Flagged as
  # a known gap rather than silently accepted.
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"[cep] Hook helpers unavailable (broken install?) - cannot safety-check this command. Approve only if you know what it does."}}\n'
  exit 0
fi

# Extract the "command" field value from tool_input with a real JSON parser.
#
# A naive extractor such as
#   grep -o '"command"[[:space:]]*:[[:space:]]*"[^"]*"'
# has its [^"]* stop at the first escaped quote in the JSON string value. Any
# destructive command preceded by a quoted argument would then be truncated
# away before the pattern checks ever ran:
#
#   git commit -m "wip" && rm -rf /   ->  CMD='git commit -m \'   -> allowed
#   bash -c "rm -rf /"                ->  CMD='bash -c \'         -> allowed
#   echo "x"; rm -rf ~                ->  CMD='echo \'            -> allowed
#
# Parse the payload properly instead, and fail CLOSED (toward "ask" — this is
# the ask-tier hook) when it cannot be parsed at all — a hook that gates
# destructive commands must not allow-by-default on unreadable input.
set +e
CMD=$(cep_hook_extract_field "$INPUT" command)
EXTRACT_RC=$?
set -e

# No parser available, or the payload is not parseable JSON. Fail toward ask
# (escalates to deny on Codex via cep_hook_decision_ask).
if [ "$EXTRACT_RC" -ne 0 ] && [ -n "$INPUT" ]; then
  cep_hook_decision_ask "[cep] Could not parse the tool payload to safety-check this command. Approve only if you know what it does."
  exit 0
fi

# Parsed fine, but there is genuinely no command field (non-Bash payload) — allow.
if [ -z "$CMD" ]; then
  echo '{}'
  exit 0
fi

# Log a hook fire event (pattern name only, never command content).
# Shared helper respects CEP_HOME, so tests never write real analytics.
_careful_log_fire() { cep_hook_log_fire destructive-command "$1"; }

# Normalize: lowercase for case-insensitive SQL matching
CMD_LOWER=$(printf '%s' "$CMD" | tr '[:upper:]' '[:lower:]')

# --- Shell-obfuscation tripwire ---
# Every check below inspects the command as a STRING, but bash executes what the
# string MEANS after expansion. ${IFS} holds the default field separator and
# contains no literal whitespace, so
#
#   rm${IFS}-rf${IFS}/
#
# matches none of the `rm\s+` patterns while executing as a full recursive
# delete. The same holds for a command assembled by a base64 decode piped to a
# shell. Rather than try to out-parse bash, treat these splitting/decoding
# primitives as a reason to ask: they are vanishingly rare in commands a human
# actually means to run unattended.
if printf '%s' "$CMD" | grep -qE '\$\{IFS\}|\$IFS|\$\(echo[^)]*base64[^)]*\)|base64[[:space:]]+(-d|--decode)[^|]*\|[[:space:]]*(sh|bash)' 2>/dev/null; then
  cep_hook_decision_ask "[cep] Shell obfuscation detected (IFS word-splitting or base64-to-shell). Read the command carefully before approving."
  exit 0
fi

# --- Rollback bypass (HIGH tier only) ---
# The HIGH-tier force-push-to-default-branch deny below exists to stop an
# ACCIDENTAL force-push to production, not to block the one legitimate reason
# to do it under fire: restoring a known-good ref during a confirmed, active
# incident (see U8's ship skill). Pattern-matching "looks like a rollback" is
# spoofable by construction — any command can be dressed up to look like one
# — so the bypass instead requires an explicit, out-of-band context flag: a
# state file the rollback-issuing skill writes ONLY after a clear-failure
# autonomous decision or a human confirmation (matching U8's Approach), read
# here, and always time-bounded so a flag left behind by a crashed process
# cannot arm the bypass indefinitely. Scoped to the force-push-to-default-
# branch check only — rm -rf / is never a legitimate rollback action, so it
# is deliberately NOT covered by this bypass.
_cep_rollback_bypass_active() {
  _crba_file="${CEP_HOME:-$HOME/.cep}/rollback-active.txt"
  [ -f "$_crba_file" ] || return 1
  _crba_armed_at=$(head -n 1 "$_crba_file" 2>/dev/null | tr -cd '0-9')
  [ -n "$_crba_armed_at" ] || return 1
  _crba_now=$(date -u +%s)
  _crba_ttl="${CEP_ROLLBACK_TTL_SECS:-1800}"
  [ $(( _crba_now - _crba_armed_at )) -le "$_crba_ttl" ] 2>/dev/null
}

# --- HIGH tier: hard deny (best-effort advisory hard-stop, NOT a policy boundary) ---
# Only SIMPLE commands are eligible: string matching cannot resolve what a
# compound command does (`cd X && git push --force` — whose cwd? which repo?),
# so anything containing ; && || | or a newline falls through to the MEDIUM ask
# families below — conservative failure = ask, never guess.
# --force-with-lease is deliberately NOT matched here (it is the safe variant).
# curl|sh stays MEDIUM/allow territory: hard-denying it would block legitimate
# installer flows.
_IS_SIMPLE=1
case "$CMD" in
  *';'*|*'&&'*|*'||'*|*'|'*|*$'\n'*) _IS_SIMPLE=0 ;;
esac
if [ "$_IS_SIMPLE" -eq 1 ]; then
  # Recursive delete aimed at the filesystem root or the whole home directory.
  # Tokenized: options (long or short, any position — --no-preserve-root may
  # trail the target) are skipped; EVERY non-option token must be a root-class
  # target (/, ~, $HOME, /*), and a recursive flag must be present. noglob is
  # forced around word-splitting so a literal /* token never expands.
  if printf '%s' "$CMD" | grep -qE '^[[:space:]]*(sudo[[:space:]]+)?rm[[:space:]]' 2>/dev/null \
    && printf '%s' "$CMD" | grep -qE '(^|[[:space:]])(-[a-zA-Z]*[rR][a-zA-Z]*|--recursive)([[:space:]]|$)' 2>/dev/null; then
    _ROOT_TARGETS=0
    _SAFE_TARGETS=0
    set -f
    for _TOK in $CMD; do
      # Strip one layer of surrounding quotes: rm -rf "/" is still rm -rf /.
      _TOK="${_TOK#\"}"; _TOK="${_TOK%\"}"; _TOK="${_TOK#\'}"; _TOK="${_TOK%\'}"
      case "$_TOK" in
        # Skip non-target decoration: options, `--`, redirections (2>/dev/null
        # is the most common suffix on agent-generated commands), backgrounding.
        sudo|rm|-*|--|[0-9]'>'*|'>'*|'<'*|'&') continue ;;
        '/'|'~'|'~/'|'$HOME'|'$HOME/'|'${HOME}'|'${HOME}/'|'/*'|'//') _ROOT_TARGETS=1 ;;
        *) _SAFE_TARGETS=1 ;;
      esac
    done
    set +f
    if [ "$_ROOT_TARGETS" -eq 1 ] && [ "$_SAFE_TARGETS" -eq 0 ]; then
      _careful_log_fire "high_rm_root"
      cep_hook_decision deny "[cep][HIGH] Recursive delete of / or the home directory is blocked. If you truly mean it, run it outside an agent session."
      exit 0
    fi
  fi
  # Force-push to the repo's default branch (the shared history everyone pulls).
  # Force is carried by -f/--force OR by git's plus-refspec syntax (+main,
  # +HEAD:main) which needs no flag at all. --force-with-lease never matches.
  if printf '%s' "$CMD" | grep -qE '^[[:space:]]*git[[:space:]]+push([[:space:]]|$)' 2>/dev/null; then
    _HAS_FORCE=0
    if printf '%s' "$CMD" | grep -qE '(^|[[:space:]])(-f|--force)($|[[:space:]])' 2>/dev/null; then
      _HAS_FORCE=1
    elif printf '%s' "$CMD" | grep -qE '(^|[[:space:]])\+[^[:space:]]' 2>/dev/null; then
      _HAS_FORCE=1
    fi
    if [ "$_HAS_FORCE" -eq 1 ]; then
      # Full branch path (slashed defaults like release/2.0 stay intact) and
      # FIXED-STRING token comparison — never interpolate a branch name into
      # an ERE (metacharacters would over/under-match).
      _DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|^refs/remotes/origin/||' || true)
      # Some worktree setups lack the origin/HEAD symbolic ref — without a
      # fallback the HIGH tier would be silently inert in exactly the
      # environment a deploy is most likely to run from. Probe the two
      # conventional defaults.
      if [ -z "$_DEFAULT_BRANCH" ]; then
        if git show-ref --verify -q refs/remotes/origin/main 2>/dev/null; then
          _DEFAULT_BRANCH="main"
        elif git show-ref --verify -q refs/remotes/origin/master 2>/dev/null; then
          _DEFAULT_BRANCH="master"
        fi
      fi
      if [ -n "$_DEFAULT_BRANCH" ]; then
        _TARGETS_DEFAULT=0
        set -f
        for _TOK in $CMD; do
          # Strip one layer of surrounding quotes: `git push -f origin "main"`
          # must not dodge the deny just because the ref is quoted.
          _TOK="${_TOK#\"}"; _TOK="${_TOK%\"}"; _TOK="${_TOK#\'}"; _TOK="${_TOK%\'}"
          case "$_TOK" in git|push|sudo|-*) continue ;; esac
          _REF="${_TOK#+}"          # +main -> main
          _REF="${_REF##*:}"        # HEAD:main / src:main -> main
          if [ "$_REF" = "$_DEFAULT_BRANCH" ]; then
            _TARGETS_DEFAULT=1
            break
          fi
        done
        set +f
        if [ "$_TARGETS_DEFAULT" -eq 0 ] && printf '%s' "$CMD" | grep -qE '^[[:space:]]*git[[:space:]]+push([[:space:]]+(-f|--force))*[[:space:]]*$' 2>/dev/null; then
          # Bare `git push --force` (force flags only, no remote/ref): targets
          # the current branch's upstream — the default branch only when ON it.
          _CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || true)
          [ -n "$_CURRENT_BRANCH" ] && [ "$_CURRENT_BRANCH" = "$_DEFAULT_BRANCH" ] && _TARGETS_DEFAULT=1
        fi
        if [ "$_TARGETS_DEFAULT" -eq 1 ]; then
          if _cep_rollback_bypass_active; then
            # Confirmed, active-incident rollback in progress (state file
            # armed by the rollback-issuing skill, within TTL): do not hard
            # deny. Falls through to the MEDIUM tier below, which still
            # surfaces as an ask (or deny-on-Codex) rather than a silent
            # pass — the safety boundary steps aside for the one action it
            # exists to permit, without going fully dark.
            _careful_log_fire "high_force_push_default_rollback_bypass"
          else
            _careful_log_fire "high_force_push_default"
            cep_hook_decision deny "[cep][HIGH] Force-push to the default branch ($_DEFAULT_BRANCH) is blocked. Use --force-with-lease on a feature branch, or arm the rollback bypass via a confirmed incident rollback if this is a deliberate recovery action."
            exit 0
          fi
        fi
      fi
    fi
  fi
fi

# --- Check for safe exceptions (one standalone rm of build artifacts) ---
# Match the complete command. Parsing only the last rm is unsafe because shell
# syntax or comments can hide an earlier destructive command, for example:
#   rm -rf / # rm -rf node_modules
# Unknown syntax fails closed and falls through to the destructive checks.
# Two hardenings on top of the anchored shape:
#   - flag cluster accepts capital -R (BSD/macOS recursive), so a single
#     `rm -Rf node_modules` stays allowed instead of prompting;
#   - target tokens exclude `(` and backtick, so command substitution that
#     ENDS in a whitelisted suffix (`rm -rf $(./wipe-all)/node_modules`)
#     cannot ride the whitelist. Plain $VAR expansion (no parenthesis) is
#     still allowed.
#   - multi-line commands never ride the whitelist: grep matches the anchored
#     shape against EACH line, so `rm -rf /\nrm -rf node_modules` would be
#     allowed by its second line. With the JSON-parser extraction the \n in
#     the payload is a real newline (a naive grep extractor keeps it as two
#     literal characters, which would break the anchored match by accident).
case "$CMD" in
  *$'\n'*) : ;; # multi-line: fall through to the destructive checks
  *)
    if printf '%s' "$CMD" | grep -qE '^[[:space:]]*rm[[:space:]]+(-[a-zA-Z]*[rR][a-zA-Z]*[[:space:]]+|--recursive[[:space:]]+)(([^[:space:];&|#(`]*/)?(node_modules|\.next|dist|__pycache__|\.cache|build|\.turbo|coverage)[[:space:]]*)+$' 2>/dev/null; then
      echo '{}'
      exit 0
    fi
    ;;
esac

# --- Destructive pattern checks (MEDIUM tier — always overridable) ---
WARN=""
PATTERN=""

# rm -rf / rm -r / rm -R / rm --recursive (capital -R is BSD/macOS recursive)
if printf '%s' "$CMD" | grep -qE 'rm\s+(-[a-zA-Z]*[rR]|--recursive)' 2>/dev/null; then
  WARN="Destructive: recursive delete (rm -r). This permanently removes files."
  PATTERN="rm_recursive"
fi

# DROP TABLE / DROP DATABASE
if [ -z "$WARN" ] && printf '%s' "$CMD_LOWER" | grep -qE 'drop\s+(table|database)' 2>/dev/null; then
  WARN="Destructive: SQL DROP detected. This permanently deletes database objects."
  PATTERN="drop_table"
fi

# TRUNCATE
if [ -z "$WARN" ] && printf '%s' "$CMD_LOWER" | grep -qE '\btruncate\b' 2>/dev/null; then
  WARN="Destructive: SQL TRUNCATE detected. This deletes all rows from a table."
  PATTERN="truncate"
fi

# git push --force / git push -f / plus-refspec force (git push origin +ref)
if [ -z "$WARN" ] && printf '%s' "$CMD" | grep -qE 'git\s+push\s' 2>/dev/null \
  && printf '%s' "$CMD" | grep -qE '(-f\b|--force|(^|[[:space:]])\+[^[:space:]])' 2>/dev/null; then
  WARN="Destructive: git force-push rewrites remote history. Other contributors may lose work."
  PATTERN="git_force_push"
fi

# git reset --hard
if [ -z "$WARN" ] && printf '%s' "$CMD" | grep -qE 'git\s+reset\s+--hard' 2>/dev/null; then
  WARN="Destructive: git reset --hard discards all uncommitted changes."
  PATTERN="git_reset_hard"
fi

# git checkout . / git restore .
if [ -z "$WARN" ] && printf '%s' "$CMD" | grep -qE 'git\s+(checkout|restore)\s+\.' 2>/dev/null; then
  WARN="Destructive: discards all uncommitted changes in the working tree."
  PATTERN="git_discard"
fi

# kubectl delete
if [ -z "$WARN" ] && printf '%s' "$CMD" | grep -qE 'kubectl\s+delete' 2>/dev/null; then
  WARN="Destructive: kubectl delete removes Kubernetes resources. May impact production."
  PATTERN="kubectl_delete"
fi

# docker rm -f / docker system prune
if [ -z "$WARN" ] && printf '%s' "$CMD" | grep -qE 'docker\s+(rm\s+-f|system\s+prune)' 2>/dev/null; then
  WARN="Destructive: Docker force-remove or prune. May delete running containers or cached images."
  PATTERN="docker_destructive"
fi

# --- Additive project patterns ---
# Config can only ADD warn rules, never remove or weaken a baseline family:
# these files are consulted AFTER the hardcoded checks and only when none of
# them matched, so no file content can suppress a baseline warning. One POSIX
# ERE per line; blank lines and #-comments skipped; an invalid regex is
# skipped (never fatal — the hook must not break on a typo in config).
#
# Deviation from gstack: gstack resolves a per-project overlay file via an
# external `gstack-slug` binary and a project registry under
# $GSTACK_HOME/projects/<slug>/careful-patterns.txt — that binary and
# registry are part of gstack's install/project-tracking infrastructure,
# which this plan does not port (not named among U9's five load-bearing
# behaviors). The per-project overlay capability is kept, but computed
# self-containedly: a file at the current git repo's own top level, so no
# external slug lookup or registry is needed.
if [ -z "$WARN" ]; then
  _CEP_HOME_DIR="${CEP_HOME:-$HOME/.cep}"
  _PATTERN_FILES="$_CEP_HOME_DIR/destructive-patterns.txt"
  _GIT_TOPLEVEL=$(git rev-parse --show-toplevel 2>/dev/null || true)
  if [ -n "$_GIT_TOPLEVEL" ]; then
    _PATTERN_FILES="$_PATTERN_FILES
$_GIT_TOPLEVEL/.cep/destructive-patterns.txt"
  fi
  while IFS= read -r _PF; do
    [ -f "$_PF" ] || continue
    while IFS= read -r _PAT || [ -n "$_PAT" ]; do
      case "$_PAT" in ''|'#'*) continue ;; esac
      _PAT_RC=0
      printf '' | grep -qE -- "$_PAT" 2>/dev/null || _PAT_RC=$?
      [ "$_PAT_RC" -eq 2 ] && continue # invalid ERE — skip the line
      if printf '%s' "$CMD" | grep -qE -- "$_PAT" 2>/dev/null; then
        WARN="Project rule matched: $_PAT"
        PATTERN="project_rule"
        break
      fi
    done < "$_PF"
    [ -n "$WARN" ] && break
  done <<EOF_PATTERN_FILES
$_PATTERN_FILES
EOF_PATTERN_FILES
fi

# --- Output ---
if [ -n "$WARN" ]; then
  _careful_log_fire "$PATTERN"
  cep_hook_decision_ask "[cep] $WARN"
else
  echo '{}'
fi
