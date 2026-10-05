---
name: handoff
description: Write .claude/handoff.md so a fresh context can continue this task. Use when CONTEXT WATCH says the main session is past its line, when a turn must end with work half done (an error you cannot get past, a question only the owner can answer), or when the owner asks for a handoff.
---

# Handoff

Write `.claude/handoff.md` (gitignored). In cloud mode it also goes in the
PR body under `## Handoff`. At most 80 lines and 6 KB, no code
(`file-guard.py` refuses a bigger write: the handoff is a pointer, so
detail goes in the plan or state file, a spec or a report file it
names). These headings in this order:

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

**Prepared run** (`.claude/rules/workflow.md` "Prepare", step 2): the
first line is `Run: prepared`, and Next lists the spec files in
`.claude/specs/` in order (which run in parallel), the Verify commands,
a `Review:` line with the number of distinct target files across the
specs (over three, or over about 150 lines expected: due; the commit
guard counts the real diff anyway), and the screenshots the report
needs. It ends the turn with the go prompt (`workflow.md` "The go
prompt"), not a "Context full" report, and stays until the run's commit.
A run window that reaches its context line keeps `Run: prepared`, lists
in Next only the spec files still to send, and its go prompt's what is
"build the prepared specs", so the fresh window carries on managing.

Then end the turn as your mode file's "Context full" rule says. The
SessionStart hook prints the file's first lines (title, `Run:` line,
Goal) into the next context (also after `/clear`) and tells it to read
the file, which it reads once. Delete the file once a fresh context has
absorbed it.

## Then stop

Auto-compact is off (owner's rule, 2026-09-29): a handoff always ends
the turn. The turn's last thing is the go prompt (`workflow.md` "The go
prompt": what to do, checkout, branch, file), never "say `go`". The
owner runs `/clear` (or opens a new chat) and pastes it; the
SessionStart hook points the fresh context at the handoff. It is the
same folder, branch and PR, so never open a new worktree, branch or PR
for the same work. Never compact and never call
`mcp__ccd_session_mgmt__clear_session` on yourself.
