"""Session start: prints what a new context must know before its first move.

1. The mode (cloud / worktree / shared) and that mode's rules from
   .claude/modes/<mode>.md. CLAUDE.md keeps only the rules every mode
   shares, so each session loads one mode's rules instead of all three.
2. On a fresh start or /clear: the branch, and the paths already
   uncommitted (made by another session, never by this one).
3. On a fresh start, /clear or compaction: the handoff left by the
   previous context (.claude/handoff.md), if any.
4. In shared mode on a fresh start or /clear: the uncommitted paths are
   also written to `<session dir>/foreign-paths.json`, which git-guard
   reads to refuse staging them.
5. Every time: the active plans (Stage planning/ready/running in
   .claude/plans/*.md). The one bound to this checkout
   (.claude/plans/HERE, or the only active plan) prints as
   `PLAN: <name> · <stage>`, with its state file's Status while running;
   the others are listed, or `PLANS:` when none is bound.
6. No Godot found: a warning line, since the check and smoke test cannot
   run.
7. After compaction: a reminder to re-read the active `docs/tasks/` file,
   if any exist.

SessionStart also fires after compaction ("compact") and on resume; the
mode rules and the handoff are printed again then (compaction drops
them), but not the dirty-path list, which by then holds this session's
own edits.

Plain stdout on SessionStart is added to the session's context.
Never fails the hook: any error exits 0.
"""
import glob
import json
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))

LIMIT = 9500          # hook output over 10,000 chars becomes a 2,000-char preview
HANDOFF_MAX = 6000
DIRTY_MAX = 40
CUT = ("\n[handoff cut to fit the hook output limit; read "
       ".claude/handoff.md for the rest]")


def git(*args):
    try:
        out = subprocess.run(["git", *args], capture_output=True, text=True,
                             timeout=10)
        return out.stdout.rstrip()  # a leading space is part of `git status --short`
    except Exception:
        return ""


def same(a, b):
    return os.path.normcase(os.path.abspath(a)) == os.path.normcase(os.path.abspath(b))


def session_dir(transcript_path: str) -> str:
    p = os.path.normpath(transcript_path)
    if os.path.basename(os.path.dirname(p)) == "subagents":
        return os.path.dirname(os.path.dirname(p))
    return os.path.splitext(p)[0]


def detect(root):
    if os.environ.get("CLAUDE_CODE_REMOTE") == "true":
        return "cloud", ""
    common = git("rev-parse", "--path-format=absolute", "--git-common-dir")
    main_root = os.path.dirname(common) if common else ""
    top = git("rev-parse", "--show-toplevel") or root
    if main_root and not same(main_root, top):
        return "worktree", main_root
    return "shared", main_root


def mode_rules(root, mode):
    for base in (os.path.join(root, ".claude", "modes"),
                 os.path.join(HERE, "..", "modes")):
        p = os.path.join(base, mode + ".md")
        if os.path.exists(p):
            with open(p, encoding="utf-8", errors="ignore") as f:
                return f.read().strip()
    return (f"(.claude/modes/{mode}.md not found: follow CLAUDE.md and say "
            "in the report that the mode file is missing.)")


def godot_missing(root: str) -> bool:
    try:
        sys.path.insert(0, os.path.join(root, "tools"))
        import godot_env
        return godot_env.find_godot() is None
    except Exception:
        return False


def plan_lines(root):
    """Active plans in .claude/plans/*.md, and the one bound to this checkout."""
    try:
        plans = os.path.join(root, ".claude", "plans")
        if not os.path.isdir(plans):
            return []

        active = []
        for fname in os.listdir(plans):
            if (not fname.endswith(".md") or fname == "TEMPLATE.md"
                    or fname.endswith(".state.md")):
                continue
            path = os.path.join(plans, fname)
            try:
                with open(path, "r", encoding="utf-8", errors="ignore") as f:
                    text = f.read()
            except OSError:
                continue
            m = re.search(r"^Stage:\s*(planning|ready|running)", text, re.M)
            if m:
                active.append((fname[:-3], m.group(1)))
        active.sort()

        here_path = os.path.join(plans, "HERE")
        here = ""
        try:
            with open(here_path, "r", encoding="utf-8", errors="ignore") as f:
                here_text = f.read()
        except OSError:
            here_text = ""
        for here_line in here_text.splitlines():
            if here_line.strip():
                here = here_line.strip()
                break

        active_names = [n for n, _ in active]
        if here and here in active_names:
            bound = here
        elif len(active) == 1:
            bound = active[0][0]
        else:
            bound = None

        if not active:
            if here:
                return [f"(.claude/plans/HERE names '{here}', which is not "
                         "an active plan: delete HERE.)"]
            return []

        here_note = None
        if here and here != bound:
            here_note = (f"(.claude/plans/HERE names '{here}', which is not "
                          "active: rewrite HERE.)")

        if bound:
            stage = dict(active)[bound]
            head = f"PLAN: {bound} · {stage}"
            if stage == "running":
                state_path = os.path.join(plans, bound + ".state.md")
                if os.path.isfile(state_path):
                    with open(state_path, "r", encoding="utf-8",
                               errors="ignore") as f:
                        state_line = f.readline().strip()
                    status = None
                    if state_line.startswith("Status:"):
                        status = state_line[len("Status:"):].strip()
                        head += f" · {status}"
                    if status == "blocked":
                        second = (f"Read .claude/skills/plan/SKILL.md, then "
                                   f".claude/plans/{bound}.state.md (its Next "
                                   f"phase) and .claude/plans/{bound}.md. A "
                                   "bare 'go' continues it. Status blocked: "
                                   "do the skill's Unblock, never the phase.")
                    else:
                        second = (f"Read .claude/skills/plan/SKILL.md, then "
                                   f".claude/plans/{bound}.state.md (its Next "
                                   f"phase) and .claude/plans/{bound}.md. A "
                                   "bare 'go' continues it.")
                else:
                    head += " · no state file"
                    second = (f"Read .claude/skills/plan/SKILL.md, then "
                               f".claude/plans/{bound}.md (no state file: "
                               "take the first todo row in Progress). A "
                               "bare 'go' continues it.")
            else:
                second = (f"Read .claude/skills/plan/SKILL.md, then "
                           f".claude/plans/{bound}.md: Interview, Brief, "
                           "Decisions, Open items, Progress. A bare 'go' "
                           "continues it.")
            lines = [head, second]
            others = [(n, s) for n, s in active if n != bound]
            if others:
                lines.append("Other active plans (run in their own "
                              "checkouts, do not touch their files): " +
                              ", ".join(f"{n} · {s}" for n, s in others))
            if here_note:
                lines.append(here_note)
            return lines

        lines = ["PLANS: " + ", ".join(f"{n} · {s}" for n, s in active),
                 "No plan is bound to this checkout. 'go <name>' binds one "
                 "(write the name to .claude/plans/HERE) and continues it; a "
                 "bare 'go' asks which. See .claude/skills/plan/SKILL.md."]
        if here_note:
            lines.append(here_note)
        return lines
    except Exception:
        return []


def dirty_paths(dirty):
    paths = []
    for line in dirty.splitlines():
        if not line.strip():
            continue
        p = line[3:]
        if " -> " in p:
            old, new = p.split(" -> ", 1)
            paths.append(old.strip('"'))
            paths.append(new.strip('"'))
        else:
            paths.append(p.strip('"'))
    return paths


def write_foreign_paths(transcript_path, paths):
    if not transcript_path:
        return
    fp = os.path.join(session_dir(transcript_path), "foreign-paths.json")
    try:
        os.makedirs(os.path.dirname(fp), exist_ok=True)
        with open(fp, "w", encoding="utf-8") as f:
            json.dump(paths, f)
    except OSError:
        pass


def main():
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass
    d = json.load(sys.stdin)
    source = d.get("source") or "startup"
    root = d.get("cwd") or os.getcwd()
    os.chdir(root)
    mode, main_root = detect(root)
    branch = git("branch", "--show-current") or "(detached)"
    lines = []

    def add_dirty(dirty):
        rows = dirty.splitlines()
        lines.extend("  " + l for l in rows[:DIRTY_MAX])
        if len(rows) > DIRTY_MAX:
            lines.append(f"  ... and {len(rows) - DIRTY_MAX} more "
                         "(git status --short)")

    head = git("status", "-sb").splitlines()
    where = f"branch {branch} at {root}"
    if mode == "worktree":
        where += f"; main checkout {main_root}"
    lines.append(f"MODE: {mode} ({where}). "
                 + (head[0] if head else ""))
    lines.append(mode_rules(root, mode))
    if godot_missing(root):
        lines.append(
            "NO GODOT: tools/godot_env.py found no Godot executable (GODOT "
            "unset, no godot on PATH). tools/check.py and tools/smoke.py "
            "cannot run: say so in the report. Cloud: the environment's "
            "setup script must run `bash tools/cloud_setup.sh`.")
    lines.extend(plan_lines(root))
    lines.append("")

    hand_at = None
    raw = ""
    if source in ("startup", "clear"):
        dirty = git("status", "--short")
        if dirty and mode == "shared":
            lines.append("Edits already in the tree at session start. "
                         "Another session made them, not you: never stage, "
                         "revert, stash or 'clean up' these paths. Stage "
                         "your own files by path.")
            add_dirty(dirty)
            write_foreign_paths(d.get("transcript_path"), dirty_paths(dirty))
        elif dirty:
            lines.append("Uncommitted edits in this checkout at session "
                         "start (left by the previous context on this "
                         "branch; check the handoff before touching them):")
            add_dirty(dirty)
        else:
            lines.append("Tree clean at session start.")
            if mode == "shared":
                write_foreign_paths(d.get("transcript_path"), [])

    if source in ("startup", "clear", "compact"):
        hand = os.path.join(root, ".claude", "handoff.md")
        if os.path.exists(hand):
            with open(hand, encoding="utf-8", errors="ignore") as f:
                body = f.read().strip()
            raw = body[:HANDOFF_MAX]
            if len(body) > HANDOFF_MAX:
                body = raw + CUT
            lines.append("")
            lines.append("HANDOFF from the previous context "
                         "(.claude/handoff.md). Restate the plan in two "
                         "lines, continue from 'Next', never redo 'Done', "
                         "and delete the file once absorbed:")
            hand_at = len(lines)
            lines.append(body)

    if source == "compact":
        names = sorted(
            os.path.relpath(p, root).replace(os.sep, "/")
            for p in glob.glob(os.path.join(root, "docs", "tasks", "*.md")))
        if names:
            lines.append("If you are working a task file, re-read it now "
                         "(CLAUDE.md Active task): " + ", ".join(names))

    out = "\n".join(lines)
    if len(out) > LIMIT and hand_at is not None:
        excess = len(out) - LIMIT
        keep = max(0, len(raw) - excess - len(CUT))
        lines[hand_at] = raw[:keep] + CUT
        out = "\n".join(lines)
    if len(out) > LIMIT:
        out = out[:LIMIT]
    print(out)


try:
    main()
except Exception:
    pass
