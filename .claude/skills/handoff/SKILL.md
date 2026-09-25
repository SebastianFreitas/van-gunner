---
name: handoff
description: Write .claude/handoff.md so a fresh context can continue this task. Use when CONTEXT WATCH says the main session is past its line, when a turn must end with work half done (an error you cannot get past, a question only the owner can answer), or when the owner asks for a handoff.
---

# Handoff

Write `.claude/handoff.md` (gitignored). In cloud mode it also goes in the
PR body under `## Handoff`. Under 80 lines, no code, these headings in this
order:

- **Goal:** the owner's words.
- **Task file:** the `docs/tasks/` file being worked, if any, and which of
  its checklist steps are ticked.
- **Done:** commits with hashes.
- **In progress:** files, their state, the last spec sent.
- **Next:** numbered; the first step concrete enough to start cold.
- **Decisions:** each with its why.
- **Gotchas:** found this session and not yet in CLAUDE.md or
  `.claude/rules/` (add the lasting ones there before handing off).
- **Verified:** check, smoke and scene dump runs that passed on the current
  `HEAD`, and which are pending. Screenshots already taken, with paths.
- **Foreign edits:** uncommitted paths that were not yours (shared mode).

Then follow your mode file's "Context full" rule. The SessionStart hook
prints the file into the next context (after compaction, `/clear` or a
fresh start), cut at 6,000 characters (less if the mode rules and dirty
list are long: hook output over 10,000 characters is replaced by a
2,000-character preview), so keep it short. Delete the file once a fresh
context has absorbed it.

## Auto-continue

For a context-full handoff the session keeps working with no owner input:
auto-compaction, not a clear. `.claude/settings.json` sets
`CLAUDE_CODE_AUTO_COMPACT_WINDOW` to 180000, so Claude Code compacts the
conversation a little past the 140k handoff line, mid-turn, and goes on in
the same turn. The SessionStart hook runs again with source `compact` and
prints `.claude/handoff.md` (and the task-file reminder) into the
compacted context. It is the same session, folder, branch and PR, so never
open a new worktree, branch or PR for the same work.

Once the handoff is written and everything is committed, keep going with
Next in the same turn. Do not end the turn because context is full. A
handoff that waits on the owner (a question, a blocker) ends the turn with
the normal report as usual.

Never call `mcp__ccd_session_mgmt__clear_session` on "self" to continue
work. In the desktop app a clear stops the session's Claude process, which
drops every session-only job with it (`CronCreate`, background shells,
monitors), so nothing is left to start the next turn and the session sits
empty until the owner types (seen in the Portfolio repo on 2026-09-25).
