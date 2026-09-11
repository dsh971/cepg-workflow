# Bootstrapping a project-local verification skill

Both `cepg-ship` (Phase 1, QA pass) and `cepg-check-debug` (Phase 1, reproduction)
say to use "whatever the platform run/verify skill exposes" to drive the real app.
When no such skill exists for this project yet, mined from pstack's
`create-verification-skill`, generate one rather than improvising a one-off drive
each time.

## 1. Interview the repo, not the user

Answer these from the codebase; ask the user only what you can't observe:

- **Surface.** What does a user actually touch — web UI, CLI/TUI, desktop app, API,
  mobile app, library? Pick the primary one if there are several, and note the rest.
- **Run.** How does the app start locally? Prefer the repo's own documented dev
  command (package scripts, Makefile, README quickstart). Note ports, env vars, seed
  data, auth.
- **Drive.** How can an agent interact with it programmatically? Existing harnesses
  first (Playwright/Cypress specs, expect scripts, PTY helpers, curl-able endpoints,
  a debug port); only then a generic recipe — browser/CDP for web and Electron, a
  tmux/PTY harness for CLI/TUI, plain HTTP for services.
- **Observe.** What evidence can be captured — screenshots, terminal transcripts,
  response bodies, logs, exit codes, DB state?
- **Isolate.** Can two instances run side by side (ports, data dirs, profiles)? If
  not, say so explicitly in the generated skill — refusing to double-drive a shared
  instance beats corrupting a running session.

If the checkout doesn't build or start as-is, fix that first (or report it
precisely) before generating — a skill written against a broken base teaches wrong
steps.

## 2. Generate the skill

Write `.claude/skills/verify-<app>/SKILL.md` (or the current runtime's equivalent
project-skill location) with real frontmatter and:

- **Launch** — the exact start command and how to tell it's ready (a log line, a
  port answering, a prompt), plus teardown. A short-lived CLI/TUI has no server to
  keep alive: launch means build/install once, then start each drive in its own
  isolated PTY or tmux session.
- **Doctor** — one read-only check answering "is this instance worth driving?"
  (process up, right version, port owned by us, auth valid).
- **Drive** — the harness recipe with real selectors/commands from this repo, not
  placeholders. Prefer stable handles (ARIA labels, data attributes, prompt
  strings, route paths) over coordinates and tab order.
- **Evidence** — what to capture and where it goes. Exercise the real user path, not
  internal setters or test-only endpoints; capture the action and the resulting
  state, not just the final screen; verify side effects (files written, rows
  inserted, messages sent) alongside what's visible.
- **Cleanup** — how to tear down what this run started. Never kill by process name;
  kill what you started. Cleanup removes instances and scratch state, never the
  evidence.

## 3. Seed the feature map

Create `.claude/skills/verify-<app>/features/README.md` plus one file per
user-facing feature (top 3-5 to start, from routes, commands, menus, or docs).
Each feature file answers, from the user's point of view: what the feature is, how
to reach it, how to drive it with the harness, and what observable end state proves
it works.

## 4. Prove the generated skill before handing it over

Run it end to end once: launch, doctor, drive one mapped feature, capture evidence,
clean up — then confirm the evidence still exists at its named location after
cleanup. A generated skill that was never executed is a draft, not a deliverable.

## 5. Maintenance

Point at whatever maintenance pass this project uses to keep the feature map honest
as the app changes (pstack's own equivalent is `/maintain-verification-skill`).
Suggest a cadence only if asked.
