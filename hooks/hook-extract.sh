#!/usr/bin/env bash
# hook-extract.sh — SHARED JSON + host-detection helpers for cepg PreToolUse hooks.
# Sourced (never executed) by hooks/check-careful.sh and hooks/check-freeze.sh
# via a path relative to each hook script (same directory — this file lives
# in hooks/ alongside both check scripts).
#
# Ported from gstack's careful/bin/hook-extract.sh, which itself exists as
# ONE shared copy on purpose: careful and freeze used to carry separate
# extractor copies, an escaped-quote truncation bug got fixed in one and
# silently stayed broken in the other. Any future parsing fix lands here and
# reaches both hooks by construction. Function names below are renamed from
# gstack_* to cepg_* (cosmetic rebrand only — detection/parsing logic is
# unchanged) and GSTACK_HOME becomes CEPG_HOME.

# cepg_hook_extract_field PAYLOAD FIELD
#   Prints tool_input.FIELD when PAYLOAD is valid JSON and the field is a
#   string ("" when absent or non-string). Returns 1 when no parser is
#   available or the payload is not parseable JSON — the CALLER decides the
#   polarity for that case (careful-equivalent asks, freeze-equivalent denies).
#
#   python3 is tried first because it ships with macOS and most Linux distros
#   and is reliably on PATH in a hook environment; node is the fallback.
cepg_hook_extract_field() {
  _chef_payload="$1"
  _chef_field="$2"
  if command -v python3 >/dev/null 2>&1; then
    printf '%s' "$_chef_payload" | python3 -c 'import sys,json
field = sys.argv[1]
d = json.loads(sys.stdin.read())
c = d.get("tool_input", {}).get(field, "")
sys.stdout.write(c if isinstance(c, str) else "")' "$_chef_field" 2>/dev/null && return 0
  fi
  if command -v node >/dev/null 2>&1; then
    printf '%s' "$_chef_payload" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const j=JSON.parse(s);const c=(j&&j.tool_input&&j.tool_input[process.argv[1]])||"";process.stdout.write(typeof c==="string"?c:"")}catch(e){process.exit(3)}})' "$_chef_field" 2>/dev/null && return 0
  fi
  return 1
}

# cepg_hook_json_string TEXT
#   Prints TEXT as a JSON string literal (surrounding quotes included),
#   encoding quotes, backslashes, control characters and newlines. Never build
#   hook JSON with printf/sed interpolation: a path containing a quote or a
#   newline produces malformed JSON, and Claude Code silently ignores the
#   whole decision — a deny that no-ops exactly when it matters.
cepg_hook_json_string() {
  _chjs_text="$1"
  if command -v python3 >/dev/null 2>&1; then
    printf '%s' "$_chjs_text" | python3 -c 'import sys,json; sys.stdout.write(json.dumps(sys.stdin.read()))' 2>/dev/null && return 0
  fi
  if command -v node >/dev/null 2>&1; then
    printf '%s' "$_chjs_text" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>process.stdout.write(JSON.stringify(s)))' 2>/dev/null && return 0
  fi
  # Last-resort fallback (no parser on PATH): strip to a safe charset so the
  # envelope stays valid JSON even if the message loses characters.
  printf '"%s"' "$(printf '%s' "$_chjs_text" | tr -cd 'a-zA-Z0-9 ._/:@=+-' )"
}

# cepg_is_codex
#   Host detection, matching references/codex-tools.md's "Host detection"
#   convention: default to Claude Code behavior unless a Codex-specific
#   environment signal is present. CODEX_HOME is set in a Codex session and
#   not in a Claude Code one.
cepg_is_codex() {
  [ -n "${CODEX_HOME:-}" ]
}

# cepg_hook_decision DECISION REASON
#   Emits the full PreToolUse hookSpecificOutput envelope with REASON safely
#   JSON-encoded. DECISION is "ask" or "deny". The decision MUST be nested
#   under hookSpecificOutput — Claude Code (and Codex) ignore a top-level
#   permissionDecision, which silently no-ops the block.
cepg_hook_decision() {
  _chd_decision="$1"
  _chd_reason="$2"
  _chd_encoded=$(cepg_hook_json_string "$_chd_reason")
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"%s","permissionDecisionReason":%s}}\n' "$_chd_decision" "$_chd_encoded"
}

# cepg_hook_decision_ask REASON
#   Emits an "ask" decision — EXCEPT on Codex, where PreToolUse hooks accept
#   permissionDecision "ask" but silently ignore it (no prompt, command
#   proceeds as if the hook never ran — confirmed via openai/codex#28437,
#   open as of this writing). Every ask-tier emission in check-careful.sh
#   (both the MEDIUM destructive-pattern matches and the ask-tier fail-safe
#   paths) routes through this helper rather than calling cepg_hook_decision
#   ask directly, so the escalation is uniform: an unenforced "ask" is exactly
#   as dangerous whether it came from a pattern match or a fail-safe path.
#   deny-tier decisions do NOT need this treatment — Codex honors deny
#   correctly, so hooks/check-freeze.sh (always deny-tier) calls
#   cepg_hook_decision directly.
cepg_hook_decision_ask() {
  _chda_reason="$1"
  if cepg_is_codex; then
    cepg_hook_decision deny "$_chda_reason [escalated to deny on Codex: PreToolUse \"ask\" is silently ignored there (openai/codex#28437) — this command is blocked outright rather than passing through unenforced]"
  else
    cepg_hook_decision ask "$_chda_reason"
  fi
}

# cepg_hook_log_fire SKILL PATTERN
#   Append a hook_fire analytics record (pattern name only, never command
#   content). Respects CEPG_HOME so tests never pollute the operator's real
#   analytics file. Best-effort: failures never affect the hook decision.
cepg_hook_log_fire() {
  _chlf_dir="${CEPG_HOME:-$HOME/.cepg}/analytics"
  mkdir -p "$_chlf_dir" 2>/dev/null || true
  # Fields are JSON-encoded (a repo basename can carry quotes/backslashes) —
  # same rule this file states for decisions: never raw-interpolate into JSON.
  _chlf_repo=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "unknown")
  printf '{"event":"hook_fire","skill":%s,"pattern":%s,"ts":"%s","repo":%s}\n' \
    "$(cepg_hook_json_string "$1")" \
    "$(cepg_hook_json_string "$2")" \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    "$(cepg_hook_json_string "$_chlf_repo")" >> "$_chlf_dir/skill-usage.jsonl" 2>/dev/null || true
}
