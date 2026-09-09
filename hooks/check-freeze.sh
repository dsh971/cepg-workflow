#!/usr/bin/env bash
# check-freeze.sh — cepg PreToolUse hook, Edit|Write matcher.
# Reads JSON from stdin, checks if file_path is within the freeze boundary.
# Returns a PreToolUse hookSpecificOutput with permissionDecision "deny" to
# block, or {} to allow. Ported from gstack's freeze/bin/check-freeze.sh
# (function names renamed gstack_* -> cepg_*, GSTACK_HOME -> CEPG_HOME —
# cosmetic only; boundary logic, symlink resolution, and fail-safe polarity
# are unchanged). Unlike gstack, where this check is only registered while a
# /freeze session is active, this hook is a standing plugin-scoped
# PreToolUse entry (hooks/hooks.json) — always on. It stays a no-op (allow
# everything) until something writes a boundary to the state file below, so
# "always on" does not mean "always restricting."
#
# The decision MUST be nested under hookSpecificOutput — Claude Code ignores
# a top-level permissionDecision, which silently no-ops the block.
#
# Polarity: this is a DENY-tier hook, so an unreadable payload DENIES (fail
# closed). A payload that parses but has no file_path is a non-file tool —
# allow. This is the opposite edge-handling from check-careful.sh's ask-tier,
# and intentionally so: a boundary that fails open is not a boundary. Unlike
# check-careful.sh's ask-tier, deny does not need Codex-host branching —
# Codex's PreToolUse hooks honor "deny" correctly (only "ask" is silently
# ignored there, per openai/codex#28437), so this hook's decisions are
# host-independent.
set -euo pipefail

# Deny-tier backstop: any unexpected non-zero death (a failing pipeline under
# set -e, a deleted cwd, EACCES) would otherwise exit with no decision JSON,
# which Claude Code treats as non-blocking — the edit proceeds. Every
# deliberate output below sets _CEPG_FREEZE_DECIDED first so a late failure
# after a decision never prints a second JSON object. Ported from gstack's
# freeze/bin/check-freeze.sh — cepg previously dropped this trap entirely,
# which meant an unexpected crash silently allowed the edit through despite
# this being a deny-tier boundary.
_CEPG_FREEZE_DECIDED=""
_cepg_freeze_backstop() {
  local rc=$?
  if [ "$rc" -ne 0 ] && [ -z "$_CEPG_FREEZE_DECIDED" ]; then
    _CEPG_FREEZE_DECIDED=1
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"[cepg] Hook failed unexpectedly (exit %s) - blocked, fail closed. Reinstall the plugin or clear the freeze boundary state file."}}\n' "$rc"
    exit 0
  fi
}
trap _cepg_freeze_backstop EXIT

# Read stdin
INPUT=$(cat)

# Shared JSON helpers (extractor + encoder) — one copy for check-careful.sh
# AND check-freeze.sh, both in this same hooks/ directory.
# check-freeze.sh previously (in gstack) carried its own grep-first extractor
# in a different tier which truncated at escaped quotes and failed OPEN; the
# shared file kills that drift class.
_HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=hooks/hook-extract.sh
# This hook is deny-tier: if its own helpers are missing/broken (partial
# install, mid-upgrade state), the boundary must fail CLOSED — inline JSON,
# since the encoder we would normally use lives in the file that just failed
# to load.
# NOTE: bash treats `.` on a MISSING file as fatal in non-interactive shells
# (an if-guard cannot catch it) — the existence check must come first.
_HOOK_HELPER="$_HOOK_DIR/hook-extract.sh"
if [ ! -f "$_HOOK_HELPER" ] || ! . "$_HOOK_HELPER" 2>/dev/null; then
  _CEPG_FREEZE_DECIDED=1
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"[cepg] Hook helpers unavailable (broken install?) - blocked, fail closed. Reinstall the plugin or clear the freeze boundary state file."}}\n'
  exit 0
fi

# Locate the freeze boundary state file
STATE_DIR="${CLAUDE_PLUGIN_DATA:-$HOME/.cepg}"
FREEZE_FILE="$STATE_DIR/freeze-dir.txt"

# If no freeze file exists, allow everything (no boundary configured)
if [ ! -f "$FREEZE_FILE" ]; then
  _CEPG_FREEZE_DECIDED=1
  echo '{}'
  exit 0
fi

# First line, trimmed of LEADING/TRAILING whitespace only. A blunter trim
# (deleting ALL whitespace) would mangle a boundary like "~/My Project/src"
# into something that never matches anything — every edit denied (or worse,
# the mangled path accidentally allowing the wrong tree).
FREEZE_DIR=$(head -n 1 "$FREEZE_FILE" 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
# A literal leading ~ in the state file never matches absolute tool paths
# (tilde is not expanded from variables) — expand it here.
case "$FREEZE_DIR" in
  "~/"*) FREEZE_DIR="$HOME/${FREEZE_DIR#\~/}" ;;
  "~") FREEZE_DIR="$HOME" ;;
esac

# If freeze dir is empty, allow
if [ -z "$FREEZE_DIR" ]; then
  _CEPG_FREEZE_DECIDED=1
  echo '{}'
  exit 0
fi

# Extract file_path from tool_input with the shared real-JSON parser.
set +e
FILE_PATH=$(cepg_hook_extract_field "$INPUT" file_path)
EXTRACT_RC=$?
set -e

# Unparseable payload (or no parser available): DENY. A boundary hook that
# allows what it cannot read is not a boundary.
if [ "$EXTRACT_RC" -ne 0 ] && [ -n "$INPUT" ]; then
  cepg_hook_decision deny "[cepg] Could not parse the tool payload to check the freeze boundary. Blocked (fail closed). Freeze boundary: $FREEZE_DIR"
  _CEPG_FREEZE_DECIDED=1
  exit 0
fi

# Parsed fine but no file_path field: a non-file tool payload — allow.
if [ -z "$FILE_PATH" ]; then
  _CEPG_FREEZE_DECIDED=1
  echo '{}'
  exit 0
fi

# Resolve file_path to absolute if it isn't already
case "$FILE_PATH" in
  /*) ;; # already absolute
  *)
    FILE_PATH="$(pwd)/$FILE_PATH"
    ;;
esac

# Normalize: remove double slashes and trailing slash
FILE_PATH=$(printf '%s' "$FILE_PATH" | sed 's|/\+|/|g;s|/$||')

# Resolve symlinks and .. sequences (POSIX-portable, works on macOS).
# The FULL canonical path is resolved, EVERY component — not only the final
# one: resolving only the parent directory would let an in-boundary symlink
# pointing at an out-of-boundary target sail through the check while the
# actual write lands outside the boundary. This happens in two stages:
#   1. A bounded, cycle-safe readlink loop follows the FINAL path component
#      if it is itself a symlink (a final component that does not exist yet
#      — a new file — has nothing to follow, and parent resolution below is
#      the correct behavior for that case).
#   2. `cd "$_dir" && pwd -P` resolves the PARENT chain: pwd -P reports the
#      physical location with every symlink in the directory chain followed,
#      because path traversal to get there necessarily walks through and
#      resolves each intermediate component — not just the last one.
# Both FREEZE_DIR and FILE_PATH are run through this so the comparison below
# is canonical-path-to-canonical-path, not raw-string-to-canonical-path.
_resolve_path() {
  local _p="$1" _dir _base _tgt _i=0
  while [ -L "$_p" ] && [ "$_i" -lt 40 ]; do
    _tgt=$(readlink "$_p" 2>/dev/null) || break
    case "$_tgt" in
      /*) _p="$_tgt" ;;
      *) _p="$(dirname "$_p")/$_tgt" ;;
    esac
    _i=$((_i + 1))
  done
  _dir="$(dirname "$_p")"
  _base="$(basename "$_p")"
  _dir="$(cd "$_dir" 2>/dev/null && pwd -P || printf '%s' "$_dir")"
  printf '%s/%s' "$_dir" "$_base"
}
FILE_PATH=$(_resolve_path "$FILE_PATH")
FREEZE_DIR=$(_resolve_path "$FREEZE_DIR")

# Check: does the file path start with the freeze directory?
case "$FILE_PATH" in
  "${FREEZE_DIR}/"*|"${FREEZE_DIR}")
    # Inside freeze boundary — allow
    _CEPG_FREEZE_DECIDED=1
    echo '{}'
    ;;
  *)
    # Outside freeze boundary — deny
    # Log hook fire event (shared helper respects CEPG_HOME)
    cepg_hook_log_fire freeze-boundary boundary_deny

    # The reason is JSON-encoded by the shared helper. Never interpolate
    # paths into hand-built JSON: a path containing a quote or newline
    # produces malformed JSON, and the deny silently no-ops.
    cepg_hook_decision deny "[cepg] Blocked: $FILE_PATH is outside the freeze boundary ($FREEZE_DIR). Only edits within the boundary are allowed."
    _CEPG_FREEZE_DECIDED=1
    ;;
esac
