---
name: cepg-check
description: Route to the debugging skill or the code-review skill for the Check phase.
disable-model-invocation: true
---

This is the one command in this plugin that wraps two skills instead of one — `cepg-check-debug` and `cepg-check-review` stay separate skills because debugging and code review are different jobs; only this command surface unifies them, preserving the plugin's six-command surface rather than shipping a seventh command for the Check phase.

Parse `$ARGUMENTS` and route as follows, in order:

1. **Explicit sub-argument.** If the first word of `$ARGUMENTS` is `debug` (case-insensitive), invoke the `cepg-check-debug` skill with the remainder of `$ARGUMENTS` and follow it. If it's `review`, invoke the `cepg-check-review` skill with the remainder and follow it. Strip the matched word before passing the rest along — don't make either skill re-parse its own name.
2. **No sub-argument, but a task description follows or is inferable from context.** Inspect the description (the rest of `$ARGUMENTS`, or, if blank, the work most recently discussed in this session) for bug/error/repro language — phrases like "bug," "error," "broken," "regression," "failing," "stack trace," "reproduce," "used to work," or a pasted stack trace or failing-test output. If that language is present, invoke `cepg-check-debug` with the description and follow it.
3. **No sub-argument and no bug/error/repro signal (including a blank or genuinely ambiguous description).** Default to `cepg-check-review` — invoke it with whatever scope is available (the description, or blank to review the current branch against its base) and follow it. Ambiguous input must resolve to a skill, never to failing or invoking both.

Do not invoke both skills for a single `/cepg-check` call. If the input plausibly fits both (e.g. "review this fix for the login bug"), prefer the explicit signal in step 1 if present; otherwise step 2's bug-language match wins over the default in step 3, since a debugging need is more specific to infer correctly than a review request is.
