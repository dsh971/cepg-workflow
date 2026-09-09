# Stage 3: Design Review — reference

Adapted from gstack's `plan-design-review` (7 design passes). Read this section in
full when running Stage 3; don't work from memory.

**Input from Stage 2:** the confirmed architecture and named data shapes. This stage
evaluates the UI/UX surface built on top of that architecture — it does not revisit
component boundaries or data shapes.

## Step 3.0 — Applicability gate

Does this plan have any UI/UX scope: new screens or pages, changes to existing UI
components, user-facing interaction flows, frontend framework changes, mobile/
responsive behavior, or design-system changes?

- **No** → skip this stage. Record `"No UI scope — design review skipped"` in the sign-off
  record and move to Stage 4.
- **Yes** → run all 7 passes below. Don't condense or skip a pass because the plan
  "seems mostly backend" — design gaps are exactly where implementation breaks down
  even in mixed plans.

## The 7 passes

Run one at a time. For each: rate 0–10, and if it's not a 10, state concretely what a
10 looks like for *this* plan and add that to the plan before moving on. Use
AskUserQuestion per finding — one issue per call, never batched.

**Pass 1 — Information Architecture.** Does the plan define what the user sees first,
second, third? Add an ASCII screen/navigation diagram. Apply constraint worship: if
only 3 things could be shown, which 3?

**Pass 2 — Interaction State Coverage.** Does the plan specify loading, empty, error,
success, and partial states for every UI feature? Build the table:

```
FEATURE            | LOADING | EMPTY | ERROR | SUCCESS | PARTIAL
[each UI feature]  | [spec]  | [spec]| [spec]| [spec]  | [spec]
```

Describe what the user *sees*, not backend behavior. Empty states are features — give
them warmth, a primary action, and context, not just "No items found."

**Pass 3 — User Journey & Emotional Arc.** Does the plan consider the user's felt
experience, not just the mechanics? Storyboard it:

```
STEP | USER DOES        | USER FEELS      | PLAN SPECIFIES?
1    | Lands on page     | [emotion]       | [what supports it?]
```

Apply the three time horizons: 5-second visceral reaction, 5-minute behavioral
experience, 5-year reflective view.

**Pass 4 — AI Slop Risk.** Does the plan describe *specific, intentional* UI, or
generic patterns? First classify the surface:
- **Marketing/landing** (hero-driven, brand-forward, conversion-focused)
- **App UI** (workspace-driven, data-dense, task-focused: dashboards, admin, settings)
- **Hybrid** — apply landing rules to the marketing shell, app rules to functional
  sections.

Hard-rejection patterns (flag if any apply): a generic SaaS card grid as the first
impression; a beautiful hero image carrying a weak brand; a strong headline with no
clear action; busy imagery behind text; sections that repeat the same mood statement;
a carousel with no narrative purpose; app UI built from stacked cards instead of a
real layout.

Universal rules regardless of surface type: define real CSS color variables, not
inline hex; no default font stacks (Inter/Roboto/Arial/system-ui as the *only*
typeface signals nobody made a typography decision); one job per section; "if
deleting 30% of the copy improves it, keep deleting"; cards earn their existence, not
decoration by default; body text stays ≥16px and ≥4.5:1 contrast; labels stay visible
when a field has content (never placeholder-as-only-label); visited/unvisited link
color stays distinct; headings sit visually closer to the section they introduce than
to the one before it.

AI-slop blacklist — the patterns that read as generated rather than designed: purple/
violet gradient backgrounds or blue-to-purple schemes; the 3-column icon-in-circle
feature grid repeated symmetrically; icons in colored circles as pure decoration;
centered-everything layouts; uniform bubbly border-radius on every element; decorative
blobs/floating shapes/wavy dividers filling an empty-feeling section instead of better
content; emoji as design elements; a colored left-border on cards as the only accent;
generic hero copy ("Welcome to X," "Unlock the power of..."); cookie-cutter section
rhythm (hero → 3 features → testimonials → pricing → CTA, every section the same
height); `system-ui`/`-apple-system` as the primary display font.

For each slop pattern flagged: name what makes it generic and what would make it
specific to *this* product instead.

**Pass 5 — Design System Alignment.** Does the plan align with the project's existing
design system/tokens, if one exists? Does every new component fit the existing visual
vocabulary? If no design system doc exists, flag the gap rather than inventing one
inline.

**Pass 6 — Responsive & Accessibility.** Does the plan specify intentional layout
changes per viewport — not "stacked on mobile" but an actual mobile-specific layout
decision? Does it name keyboard-navigation patterns, ARIA landmarks, minimum touch
target size (44px), and color-contrast requirements?

**Pass 7 — Unresolved Design Decisions.** Surface every ambiguity that would otherwise
get silently resolved by whoever implements it:

```
DECISION NEEDED                  | IF DEFERRED, WHAT HAPPENS
What does the empty state look like? | Engineer ships "No items found."
Mobile nav pattern?                  | Desktop nav hides behind a hamburger by default
```

Each row becomes its own AskUserQuestion with a recommendation, reasoning, and
alternatives. Resolve or explicitly defer each one — never leave a row un-triaged.

## Stage 3 output — Design Sign-Off Record

```
DESIGN SIGN-OFF RECORD
Applicability: <UI scope found | "No UI scope — skipped">
Information architecture: <summary, or n/a>
Interaction-state coverage: <resolved | gaps deferred with reason>
Journey notes: <key emotional-arc findings, or n/a>
Slop-risk findings: <flagged patterns + fixes, or "none found">
Design-system alignment: <notes, or "no design system to align to">
Responsive/accessibility specs: <resolved | gaps deferred with reason>
Unresolved decisions: <list, or "none — all resolved">
```

Stage 4 references any screens, error states, or copy decisions locked in here when
evaluating the developer-facing (not end-user-facing) surface.
