---
paths:
  - ".claude/hooks/**"
  - ".claude/settings.json"
  - ".claude/project/**"
  - "tools/autoplan.py"
  - "tools/cleanup.py"
---

# Hooks, autoplan and plan files

## Autoplan

- **Autoplan: one fresh headless session per phase.** `autoplan.py` starts `claude -p` for each phase with `AUTOPLAN=1` and a prompt beginning `[autoplan | ...]`, so the session reads `.claude/skills/plan/unattended.md` instead of `run.md`. It runs on the Max subscription only: `child_env` strips the API-key and billing variables, and a usage-limit reply stops the chain with exit 3 instead of retrying. From the main checkout it makes or reuses `.claude/worktrees/plan-<name>` on `claude/plan-<name>` and writes that worktree's HERE. After each session it reads `<name>.state.md`: `phase-done` or `partial` starts the next session, `questions` (deferred phases waiting for answers), `blocked` or `plan-done` stops, it never starts while questions or a blocker wait (exit 4), and so does a session that made no commit or the same phase coming back `partial` three times (split it in the plan). Each session's context line is `AUTOPLAN_LINE` (`--line`, 160k, which `context-watch.py` honours) and the runner kills it at `--kill` (185k). Logs and the run lock live in `.claude/autoplan/` (gitignored). It never lands phases itself: each session runs Commit per the worktree mode (D27), and the end message names the command for anything unlanded. `--dry-run` prints the command, phase and worktree and creates nothing, skipping the dirty-tree gate.

## Plans: HERE and state files

- Every plan with `Stage:` planning, ready or running is active; several can be at once, one per checkout. The gitignored `.claude/plans/HERE` holds the name of the plan this checkout works on. With no HERE and exactly one active plan, that plan is bound; with several, `session-start.py` prints `PLANS: ...` and nothing is bound until `go <name>` (or a state-file prompt) writes HERE. A fresh worktree never has one.
- `.claude/plans/<name>.state.md` exists only while a plan runs, is committed (a cloud session is a fresh clone), stays under 80 lines, and replaces `.claude/handoff.md` at a phase boundary. Its first line `Status: phase-done|partial|questions|blocked|plan-done` is machine-read by `session-start.py` and `autoplan.py`, so never put anything above it. The format is in `.claude/skills/plan/run.md` ("The state file").
- Stage done deletes the state file and the checkout's HERE; the plan file stays as the record. Saved specs `.claude/plans/<name>.spec-<phase>-<k>.md` are deleted in the commit that lands their work.

## Hooks

`.claude/settings.json` runs every hook through `.claude/hooks/run.sh` (the `py` launcher on Windows, where `python3` is often the Store stub). Hooks never fail on their own errors (any exception exits 0).

- Shared (synced from the master, identical in every project): `session-start.py` (the mode file plus `.claude/project/modes/<mode>.md`, the active plans with their state file's Status, the dirty paths, the handoff, `WORKFLOW SYNC:` drift; in shared mode it writes the dirty paths to `<session dir>/foreign-paths.json`), `git-guard.py` (blanket git, pushes, merges into main, branch and worktree removal, checkout or switch in the main checkout, staging a foreign path; rules match with quoted text masked, so commit messages and search strings never trip them), `file-guard.py` (whole reads over 300 lines, binaries and caches, edits of generated files, main-session multi-line source edits and shell writes to source, `.claude/handoff.md` over 80 lines or 6 KB or written from a shell, reviewer and plan-reviewer writes outside `.claude/specs/reports/`; van-gunner's lists are in `.claude/project/file-guard.json`), `context-watch.py` (context lines per agent type; subagents past 1.25 times their line get every tool call denied; a plan run's supervisor, found by its go prompt or its `autoplan.py` launch, gets the 160k line), `stop-guard.py` (uncommitted files, unpushed cloud commits).
- Van-gunner's own, switched on by `.claude/project/settings.json` (merged into `settings.json` by `sync.py push`): `godot-session.py` (SessionStart: a `NO GODOT` line, the `docs/tasks/` reminder after a `/clear` or compaction), `tscn-guard.py` (refuses renumbered header ids in `.tscn`/`.tres`), `gd-lint.py` (lints the lines an edit wrote, plus whole-file checks; `py -3 .claude/hooks/gd-lint.py --scan` lints the tree), `verify-guard.py` (Stop: Godot changes newer than the last clean check, smoke or scene dump; a deleted file counts from its folder's mtime).

Auto-compact is off (`DISABLE_AUTO_COMPACT`, the owner's rule of 2026-09-29): a session past its line stops, writes the handoff and the owner clears. `context-watch.py` still stops at a `compact_boundary` line (a manual `/compact`): the first tool call after one runs before its assistant line reaches the transcript. A subagent is only ever measured from its own transcript.

Hook input carries `agent_id` and `agent_type` inside subagents; `cwd` follows the session into a worktree while `${CLAUDE_PROJECT_DIR}` stays where the session started.
