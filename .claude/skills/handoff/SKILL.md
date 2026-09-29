---
name: handoff
description: Write .claude/handoff.md so a fresh context can continue this task. Use when CONTEXT WATCH says the main session is past its line, when a turn must end with work half done (an error you cannot get past, a question only the owner can answer), or when the owner asks for a handoff.
---

# Handoff

Write `.claude/handoff.md` (gitignored). In cloud mode it also goes in the
PR body under `## Handoff`. Under 80 lines, no code, these headings
in this order:

- **Goal:** the owner's words.
- **Done:** commits with hashes.
- **In progress:** files, their state, the last spec sent.
- **Next:** numbered; the first step concrete enough to start cold.
- **Decisions:** each with its why.
- **Task file:** the task or checklist file being worked, if any, and
  which of its steps are ticked.
- **Gotchas:** found this session and not yet in `CLAUDE.md`,
  `.claude/rules/` or `.claude/MAP.md` (add the lasting ones there
  before handing off).
- **Verified:** checks that passed on the current `HEAD` and which are
  pending; screenshots already taken, with paths.
- **Foreign edits:** uncommitted paths that were not yours (shared mode).

Then end the turn as your mode file's "Context full" rule says. The
SessionStart hook prints the file into the next context (also after
`/clear`), cut at 6,000 characters (less if the mode rules and dirty
list are long: hook output over 10,000 characters is replaced by a
2,000-character preview), so keep it short. Delete the file once a fresh
context has absorbed it.

## Then stop

Auto-compact is off (owner's rule, 2026-09-29): a handoff always ends
the turn. The owner runs `/clear` (or opens a new chat) and says `go`;
the SessionStart hook prints the handoff into the fresh context. It is
the same folder, branch and PR, so never open a new worktree, branch or
PR for the same work. Never compact and never call
`mcp__ccd_session_mgmt__clear_session` on yourself.
