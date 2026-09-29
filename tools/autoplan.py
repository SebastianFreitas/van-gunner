"""Run a multi-phase plan (.claude/plans/<name>.md) unattended.

    py -3 tools/autoplan.py heavylight-page  (from main: makes the plan worktree)
    py -3 tools/autoplan.py --dry-run
    py -3 tools/autoplan.py heavylight-page --here  (run in this checkout)
    py -3 tools/autoplan.py heavylight-page --force  (kill a leftover session)

Each loop iteration launches a FRESH headless Claude Code process
(`claude -p ... --output-format stream-json`), which executes exactly one
plan phase and exits. The runner watches that process's context size
live, kills it if it overflows, commits anything left uncommitted, reads
the plan state, and starts the next session. A fresh process means a
cleared context, so nobody has to type /clear or "go" between phases.

Runs on the Max subscription only, never an API key: child_env strips
every billing env var before a child session starts, and the runner
stops itself on a usage limit rather than spend API money.

Meant to run in a worktree, not the main checkout other sessions are
using (pass --here to override that check).
"""

from __future__ import annotations

import argparse
import atexit
import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PLANS = ROOT / ".claude" / "plans"
LOGS = ROOT / ".claude" / "autoplan"
LOCK = ROOT / ".claude" / "autoplan" / "run.lock"

ALLOWED_TOOLS = [
    "Read", "Glob", "Grep", "Edit", "Write", "Agent", "TodoWrite",
    "Bash(git add *)", "Bash(git commit *)", "Bash(git status *)",
    "Bash(git diff *)", "Bash(git log *)", "Bash(git show *)",
    "Bash(git rev-parse *)", "Bash(py -3 tools/*)",
    "Bash(py -3 -m py_compile *)", "Bash(ls *)", "Bash(wc *)",
    "Bash(grep *)", "Bash(sed -n *)", "Bash(head *)", "Bash(tail *)",
    "Bash(mkdir *)", "PowerShell(git add *)", "PowerShell(git commit *)",
    "PowerShell(git status *)", "PowerShell(git diff *)",
    "PowerShell(git log *)", "PowerShell(py -3 tools/*)",
    # Worktree sessions land their own phase and resolve merges.
    "Bash(git merge *)", "Bash(git mv *)", "Bash(git rm *)",
    "Bash(git branch --show-current)", "Bash(git grep *)",
    "PowerShell(git merge *)", "PowerShell(git mv *)", "PowerShell(git rm *)",
    "PowerShell(git branch --show-current)", "PowerShell(git grep *)",
]
# Project-specific tools (e.g. an engine's CLI): .claude/project/autoplan.json {"allowedTools": [...]}
try:
    ALLOWED_TOOLS += json.loads((ROOT / ".claude" / "project" / "autoplan.json").read_text(encoding="utf-8")).get("allowedTools", [])
except (OSError, ValueError, AttributeError):
    pass

# Env vars that would make a session spend API money instead of the Max
# subscription; child_env pops all of these before launching claude.
BILLING_ENV = ("ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN", "ANTHROPIC_BASE_URL",
               "CLAUDE_CODE_USE_BEDROCK", "CLAUDE_CODE_USE_VERTEX", "CLAUDE_CODE_USE_FOUNDRY",
               "AWS_BEARER_TOKEN_BEDROCK")
LIMIT_RE = re.compile(r"usage limit|rate limit|limit reached|out of (extra )?usage|limit will reset|resets at", re.I)

_PLAN_NAME = "?"  # set by main() before the loop; safety_commit's message needs it


def child_env(name: str, k: int, line: int) -> dict[str, str]:
    """Build the child session's env: strip billing vars (Max subscription only), set AUTOPLAN_*."""
    env = os.environ.copy()
    for key in BILLING_ENV:
        env.pop(key, None)
    env["AUTOPLAN"] = "1"
    env["AUTOPLAN_SESSION"] = str(k)
    env["AUTOPLAN_PLAN"] = name
    env["AUTOPLAN_LINE"] = str(line)
    env["CLAUDE_CODE_DISABLE_BACKGROUND_TASKS"] = "1"
    return env


def state_path(name: str) -> Path:
    """Path to plan name's state file, .claude/plans/<name>.state.md."""
    return PLANS / f"{name}.state.md"


def find_claude(explicit: str | None) -> str:
    """Resolve the claude CLI path: explicit, PATH, or newest installed version."""
    if explicit:
        if explicit.lower().endswith((".cmd", ".bat")):
            print("Pass the claude.exe path, not a .cmd shim.")
            sys.exit(1)
        return explicit
    found = shutil.which("claude")
    if found and not found.lower().endswith((".cmd", ".bat")):
        return found
    bases = []
    appdata = os.environ.get("APPDATA")
    if appdata:
        bases.append(Path(appdata) / "Claude" / "claude-code")
    localappdata = os.environ.get("LOCALAPPDATA")
    if localappdata:
        packages = Path(localappdata) / "Packages"
        if packages.is_dir():
            for pkg in packages.iterdir():
                if pkg.is_dir() and pkg.name.startswith("Claude_"):
                    bases.append(pkg / "LocalCache" / "Roaming" / "Claude" / "claude-code")
    best_dir = None
    best_key = None
    for base in bases:
        if not base.is_dir():
            continue
        for d in base.iterdir():
            if not d.is_dir():
                continue
            parts = []
            for piece in d.name.split("."):
                if piece.isdigit():
                    parts.append(int(piece))
                else:
                    parts = None
                    break
            if parts is None:
                continue
            if not (d / "claude.exe").exists():
                continue
            key = tuple(parts)
            if best_key is None or key > best_key:
                best_key = key
                best_dir = d
    if best_dir is not None:
        exe = best_dir / "claude.exe"
        if exe.exists():
            return str(exe)
    print("Claude Code CLI not found. Install it (see https://code.claude.com/docs) or pass --claude PATH.")
    sys.exit(1)


def git(*args: str, check: bool = False) -> str:
    """Run git in ROOT, return stdout text (utf-8, replace errors)."""
    result = subprocess.run(
        ["git", *args], cwd=ROOT, capture_output=True, text=True,
        encoding="utf-8", errors="replace",
    )
    if check and result.returncode != 0:
        print(result.stderr, file=sys.stderr)
        sys.exit(1)
    return result.stdout.strip()


def main_root() -> Path:
    """The main checkout: parent of the git common dir (ROOT itself when run from main)."""
    return Path(git("rev-parse", "--path-format=absolute", "--git-common-dir")).parent


def mode() -> str:
    """"worktree" if this checkout's git-common-dir differs from its toplevel, else "shared"."""
    common_dir = git("rev-parse", "--path-format=absolute", "--git-common-dir")
    common_root = os.path.normcase(os.path.abspath(str(Path(common_dir).parent)))
    toplevel = git("rev-parse", "--show-toplevel")
    toplevel = os.path.normcase(os.path.abspath(toplevel))
    return "worktree" if common_root != toplevel else "shared"


def dirty_paths() -> set[str]:
    """Paths reported dirty/untracked by porcelain v1 -z, renames add both old and new path."""
    result = subprocess.run(
        ["git", "status", "--porcelain=v1", "-z", "--untracked-files=all"],
        cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace",
    )
    out = result.stdout
    fields = out.split("\0")
    paths = set()
    i = 0
    while i < len(fields):
        entry = fields[i]
        i += 1
        if not entry:
            continue
        status = entry[:2]
        path = entry[3:]
        paths.add(path)
        if "R" in status or "C" in status:
            # the old path follows as its own NUL-separated field
            paths.add(fields[i])
            i += 1
    return paths


def head() -> str:
    """Current HEAD sha."""
    return git("rev-parse", "HEAD")


def ensure_plan_worktree(name: str) -> Path:
    """Create (if needed) and return the plan-<name> worktree, branch claude/plan-<name>."""
    wt = ROOT / ".claude" / "worktrees" / f"plan-{name}"
    branch = f"claude/plan-{name}"
    wt_norm = os.path.normcase(os.path.abspath(str(wt)))
    existing = False
    for line in git("worktree", "list", "--porcelain").splitlines():
        if line.startswith("worktree "):
            other = os.path.normcase(os.path.abspath(line[len("worktree "):]))
            if other == wt_norm:
                existing = True
                break
    if not existing:
        branch_exists = bool(git("branch", "--list", branch).strip())
        if branch_exists:
            git("worktree", "add", str(wt), branch, check=True)
        else:
            git("worktree", "add", "-b", branch, str(wt), "HEAD", check=True)
        print(f"Plan worktree: .claude/worktrees/plan-{name} (branch {branch})")

    # bind the worktree to this plan, so the SessionStart hook there doesn't have to guess
    here = wt / ".claude" / "plans" / "HERE"
    here.parent.mkdir(parents=True, exist_ok=True)
    with open(here, "w", newline="\n", encoding="utf-8") as f:
        f.write(f"{name}\n")

    return wt


def pid_alive(pid: int) -> bool:
    """True if pid is a running process."""
    if os.name == "nt":
        result = subprocess.run(
            ["tasklist", "/FI", f"PID eq {pid}", "/NH"],
            capture_output=True, text=True, encoding="utf-8", errors="replace",
        )
        return str(pid) in result.stdout
    try:
        os.kill(pid, 0)
        return True
    except OSError:
        return False


def live_claude_here(name: str) -> list[int]:
    """Pids of headless autoplan claude/node processes visible on this machine (Windows only)."""
    if os.name != "nt":
        return []
    try:
        result = subprocess.run(
            [
                "powershell", "-NoProfile", "-Command",
                "Get-CimInstance Win32_Process -Filter \"Name='claude.exe' or Name='node.exe'\" "
                "| Select-Object ProcessId,CommandLine | ConvertTo-Json",
            ],
            capture_output=True, text=True, encoding="utf-8", errors="replace",
        )
        if result.returncode != 0 or not result.stdout.strip():
            return []
        data = json.loads(result.stdout)
        if isinstance(data, dict):
            data = [data]
        pids = []
        for entry in data:
            cmdline = entry.get("CommandLine") or ""
            if " -p " not in cmdline or "stream-json" not in cmdline:
                continue
            if f"[autoplan | plan {name} |" not in cmdline and f"[autoplan \u00b7 plan {name} \u00b7" not in cmdline:
                continue
            pid = entry.get("ProcessId")
            if pid is not None:
                pids.append(int(pid))
        return pids
    except Exception:
        return []


def acquire_lock(name: str, force: bool) -> None:
    """Take LOCK for this run; refuse (or kill, with force) a live autoplan run in this checkout."""
    if LOCK.exists():
        try:
            info = json.loads(LOCK.read_text(encoding="utf-8"))
            pid = int(info.get("pid"))
        except (OSError, ValueError, TypeError, json.JSONDecodeError):
            pid = None
        if pid is not None and pid_alive(pid):
            print(
                f"Another autoplan run (pid {pid}, plan {info.get('plan')}) is "
                "running in this checkout; stop it first."
            )
            sys.exit(1)
        LOCK.unlink()

    pids = live_claude_here(name)
    if pids:
        if not force:
            print(
                f"A headless autoplan session is still running (pids {pids}). "
                "Stop it, or re-run with --force to kill it."
            )
            sys.exit(1)
        for pid in pids:
            subprocess.run(["taskkill", "/PID", str(pid), "/T", "/F"], capture_output=True)

    LOCK.parent.mkdir(parents=True, exist_ok=True)
    our_pid = os.getpid()
    LOCK.write_text(
        json.dumps({"pid": our_pid, "plan": name, "started": time.strftime("%Y-%m-%d %H:%M:%S")}),
        encoding="utf-8",
    )

    def release():
        try:
            info = json.loads(LOCK.read_text(encoding="utf-8"))
            if info.get("pid") == our_pid:
                LOCK.unlink()
        except (OSError, ValueError, json.JSONDecodeError):
            pass

    atexit.register(release)


def progress_rows(plan_lines: list[str]) -> list[dict]:
    """Rows of the plan's ## Progress table: n, title, status, rests_on, needs (None: no Needs column)."""
    rows = []
    cols: dict[str, int] = {}
    in_progress = False
    for line in plan_lines:
        if line.startswith("## Progress"):
            in_progress = True
            continue
        if in_progress and line.startswith("## "):
            break
        if not in_progress or not line.startswith("| "):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if not cols:
            if cells and cells[0] == "#":
                cols = {c.lower(): i for i, c in enumerate(cells)}
            continue
        if not line[2:3].isdigit() or len(cells) < 2:
            continue
        rests_i = cols.get("rests on", len(cells) - 2)
        needs_i = cols.get("needs")
        rows.append({
            "n": cells[0],
            "title": cells[1],
            "status": cells[-1].lower(),
            "rests_on": cells[rests_i] if rests_i < len(cells) else "",
            "needs": None if needs_i is None or needs_i >= len(cells)
            else re.findall(r"\d+", cells[needs_i]),
        })
    return rows


def next_runnable(rows: list[dict]) -> dict | None:
    """First row that is not done and not held back (deferred, or needing a held phase), else None."""
    held: set[str] = set()
    for row in rows:
        if row["status"].startswith("done"):
            continue
        needs = row["needs"]
        is_held = (
            row["status"].startswith("deferred")
            or (needs is not None and any(x in held for x in needs))
            or (needs is None and bool(held))
        )
        if is_held:
            held.add(row["n"])
            continue
        return row
    return None


def read_plan(name: str) -> dict:
    """Parse .claude/plans/<name>.md: stage, todo/done/deferred counts and the runnable phase."""
    text = (PLANS / f"{name}.md").read_text(encoding="utf-8")
    stage = ""
    for line in text.splitlines():
        if line.strip().startswith("Stage:"):
            stage = line.split("Stage:", 1)[1].strip().lower()
            break
    rows = progress_rows(text.splitlines())
    done = sum(1 for r in rows if r["status"].startswith("done"))
    deferred = sum(1 for r in rows if r["status"].startswith("deferred"))
    return {
        "stage": stage, "todo": len(rows) - done, "done": done,
        "deferred": deferred, "runnable": next_runnable(rows),
    }


def read_state(name: str) -> dict:
    """Parse .claude/plans/<name>.state.md: status, Blocker, Next phase and Questions sections."""
    sp = state_path(name)
    if not sp.exists():
        return {"status": None, "blocker": None, "next_phase": None, "questions": None, "q_count": 0}
    lines = sp.read_text(encoding="utf-8").splitlines()
    status = None
    for line in lines:
        m = re.match(r"status:\s*[`*]*([a-z-]+)", line.strip(), re.I)
        if m:
            status = m.group(1).lower()
            break

    def section_after(is_heading) -> str | None:
        start = next((i for i, line in enumerate(lines) if is_heading(line)), None)
        if start is None:
            return None
        end = len(lines)
        for j in range(start + 1, len(lines)):
            if lines[j].startswith("## "):
                end = j
                break
        return "\n".join(lines[start + 1:end]).strip()

    def one_line(label: str) -> str | None:
        for line in lines:
            stripped = line.strip()
            if stripped.startswith(f"- **{label}:**") or stripped.startswith(f"{label}:"):
                return stripped.replace(f"- **{label}:**", "").replace(f"{label}:", "").strip("* ")
        return None

    blocker = section_after(lambda line: line.strip() == "## Blocker")
    if blocker is None:
        blocker = one_line("Blocker")
    next_phase = section_after(lambda line: line.strip().startswith("## Next phase"))
    if next_phase is None:
        next_phase = one_line("Next phase")
    questions = section_after(lambda line: line.strip() == "## Questions")
    q_count = 0
    if questions and questions.strip("`*_.- \n").lower() != "none":
        q_count = len(set(re.findall(r"Q\d+", questions)))
    return {
        "status": status, "blocker": blocker, "next_phase": next_phase,
        "questions": questions, "q_count": q_count,
    }


def resolve_plan(explicit: str | None) -> str:
    """Resolve the plan name: CLI arg, .claude/plans/HERE, or the single ready/running plan."""
    if explicit:
        return explicit
    here = PLANS / "HERE"
    if here.exists():
        name = here.read_text(encoding="utf-8").strip()
        if name:
            return name
    candidates = sorted(
        p for p in PLANS.glob("*.md")
        if p.name != "TEMPLATE.md" and ".state." not in p.name and ".spec-" not in p.name
    )
    active = []
    for p in candidates:
        plan = read_plan(p.stem)
        if plan["stage"] in ("ready", "running"):
            active.append(p.stem)
    if len(active) == 1:
        return active[0]
    print("Plans:")
    for p in candidates:
        plan = read_plan(p.stem)
        print(f"  {p.stem}: {plan['stage']}")
    sys.exit(1)


def phase_brief(name: str) -> str:
    """Build the phase brief for the prompt: state file, next phase section, cited decisions, carry-forward, specs."""

    def cut(text: str, cap: int) -> str:
        if len(text) > cap:
            return text[:cap] + "[...cut]"
        return text

    def extract_section(lines: list[str], start: int) -> str:
        m = re.match(r"^(#{1,6})\s", lines[start])
        level = len(m.group(1))
        end = len(lines)
        for j in range(start + 1, len(lines)):
            m2 = re.match(r"^(#{1,6})\s", lines[j])
            if m2 and len(m2.group(1)) <= level:
                end = j
                break
        return "\n".join(lines[start:end])

    parts = []

    state_text = ""
    sp = state_path(name)
    if sp.exists():
        state_text = sp.read_text(encoding="utf-8")
        parts.append(f"## {sp.relative_to(ROOT).as_posix()}\n\n" + cut(state_text, 5000))

    plan_path = PLANS / f"{name}.md"
    plan_text = plan_path.read_text(encoding="utf-8")
    plan_lines = plan_text.splitlines()

    runnable = next_runnable(progress_rows(plan_lines))
    n = runnable["n"] if runnable else None

    phase_section = ""
    if n is not None:
        heading_re = re.compile(rf"^#{{2,4}} (?:.*Phase\s+{re.escape(n)}\b|{re.escape(n)}\s*·)", re.I)
        base = next((i for i, line in enumerate(plan_lines) if line.startswith("## Phases")), 0)
        start = next((i for i, line in enumerate(plan_lines) if i >= base and heading_re.match(line)), None)
        if start is not None:
            phase_section = extract_section(plan_lines, start)
        else:
            phase_section = f"Phase {n}: section not found; grep the plan for it."
    parts.append(f"## Phase {n} (from .claude/plans/{name}.md)\n\n" + cut(phase_section, 6000))

    rests_on = runnable["rests_on"] if runnable else ""
    tokens = sorted(set(re.findall(r"D\d+", state_text + "\n" + phase_section + "\n" + rests_on)))
    decision_blocks = []
    i = 0
    while i < len(plan_lines):
        line = plan_lines[i]
        stripped = line.strip()
        hit = any(re.match(rf"^(?:- \*\*|\| )?{re.escape(tok)}\b", stripped) for tok in tokens)
        if hit:
            block = [line]
            j = i + 1
            if stripped.startswith("- **"):
                # a bullet runs until the next bullet or heading
                while j < len(plan_lines) and not (
                    plan_lines[j].strip().startswith("- **") or plan_lines[j].startswith("#")
                ):
                    block.append(plan_lines[j])
                    j += 1
            elif not stripped.startswith("| "):
                while j < len(plan_lines) and plan_lines[j] and plan_lines[j][0] in (" ", "\t"):
                    block.append(plan_lines[j])
                    j += 1
            decision_blocks.append("\n".join(block))
            i = j
        else:
            i += 1
    parts.append("## Decisions cited\n\n" + cut("\n\n".join(decision_blocks), 4000))

    carry_start = next(
        (i for i, line in enumerate(plan_lines) if line.strip().lower().startswith("## carry forward")), None
    )
    if carry_start is not None:
        parts.append("## Carry forward\n\n" + cut(extract_section(plan_lines, carry_start), 2000))

    spec_files = sorted(PLANS.glob(f"{name}.spec-*.md"))
    if spec_files:
        listing = "\n".join(f"- {p.relative_to(ROOT)}" for p in spec_files)
        parts.append("## Saved specs (send these to the implementer first)\n\n" + listing)

    return "\n\n".join(parts)


def session_prompt(name: str, k: int, rescue: dict | None, line: int, kill: int) -> str:
    """Build the -p prompt text for session k of plan name, with an optional rescue note and phase brief."""
    prompt = f"""[autoplan | plan {name} | session {k}]
You are running unattended under tools/autoplan.py. Nobody answers:
AskUserQuestion is disabled. Read .claude/skills/plan/unattended.md
first; it replaces SKILL.md's unattended section. The phase brief below
is already loaded: do not re-read the plan's state file or the plan for it.

Context: CONTEXT WATCH warns at {line // 1000}k; the runner kills this
session at {kill // 1000}k. Execute the next phase (below) and stop when
its Handoff protocol is complete, or save your design as spec files
(unattended.md) when it will not fit."""
    if rescue:
        tokens = rescue.get("tokens", 0)
        sha = rescue.get("sha")
        if sha:
            work_note = (
                f"The runner committed its uncommitted files as {sha} (unverified "
                f"work in progress): run `git show --stat {sha}` and verify that "
                "work before building on it."
            )
        else:
            work_note = "It left nothing uncommitted."
        prompt += f"""

The previous session was stopped by the runner at {tokens // 1000}k
context tokens, mid-phase. {work_note}. The plan's state file may be one
phase stale: trust git log over it, and treat the phase as partial."""
    prompt += "\n\n# Phase brief\n\n" + phase_brief(name)
    return prompt


def build_cmd(claude: str, prompt: str, args, budget: float | None) -> list[str]:
    # The absolute-path Commit command the mode file prints (main checkout's try.py).
    try_py = f"py -3 {main_root().as_posix()}/tools/try.py *"
    allowed = [*ALLOWED_TOOLS, f"Bash({try_py})", f"PowerShell({try_py})"]
    cmd = [
        claude, "-p", prompt,
        "--output-format", "stream-json", "--verbose",
        "--model", args.model, "--effort", args.effort,
        "--permission-mode", args.permission_mode,
        "--permission-prompts", "none",
        "--disallowedTools", "AskUserQuestion",
        "--allowedTools", *allowed,
        "--settings", json.dumps({"env": {
            "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "75",
            "AUTOPLAN_LINE": str(args.line),
        }}),
    ]
    if budget is not None:
        cmd += ["--max-budget-usd", f"{budget:.2f}"]
    return cmd


def kill_tree(proc: subprocess.Popen) -> None:
    """Kill proc and its children (taskkill /T on Windows, proc.kill() elsewhere)."""
    if os.name == "nt":
        subprocess.run(["taskkill", "/PID", str(proc.pid), "/T", "/F"], capture_output=True)
    else:
        proc.kill()
    try:
        proc.wait(timeout=30)
    except subprocess.TimeoutExpired:
        pass


def run_session(cmd: list[str], env: dict, log_path: Path, kill_at: int, label: str, warn_line: int) -> dict:
    """Stream a claude -p session, print progress, kill it past kill_at, return a summary dict."""
    try:
        proc = subprocess.Popen(
            cmd, cwd=ROOT, env=env,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL,
        )
    except FileNotFoundError:
        print(f"Claude CLI not found at: {cmd[0]}")
        sys.exit(1)

    log_file = None
    try:
        log_path.parent.mkdir(parents=True, exist_ok=True)
        log_file = open(log_path, "a", encoding="utf-8", errors="replace")
    except OSError as e:
        print(f"Warning: could not open log file {log_path}: {e}")
        log_file = None

    ctx = 0
    peak = 0
    killed = False
    result = None
    last_boundary = 0
    limit = False
    non_json_tail: list[str] = []  # last ~20 non-JSON lines, for a usage-limit check on a bad exit

    def stop_child():
        kill_tree(proc)

    try:
        for raw in proc.stdout:
            line = raw.decode("utf-8", errors="replace").lstrip("\ufeff")
            if log_file:
                log_file.write(line)
            stripped = line.strip()
            if not stripped:
                continue
            try:
                event = json.loads(stripped)
            except json.JSONDecodeError:
                print(f"  | {stripped[:200]}")
                non_json_tail.append(stripped)
                non_json_tail = non_json_tail[-20:]
                continue
            if not isinstance(event, dict):
                print(f"  | {stripped[:200]}")
                non_json_tail.append(stripped)
                non_json_tail = non_json_tail[-20:]
                continue

            etype = event.get("type")

            if etype and "rate_limit" in str(etype):
                info = event.get("rate_limit_info") or event
                if isinstance(info, dict) and info.get("status") == "rejected":
                    limit = True

            if etype == "assistant":
                message = event.get("message", {}) or {}
                is_sub = event.get("parent_tool_use_id") is not None
                usage = message.get("usage") or {}
                if not is_sub:
                    u = usage
                    ctx = (
                        (u.get("input_tokens") or 0)
                        + (u.get("cache_creation_input_tokens") or 0)
                        + (u.get("cache_read_input_tokens") or 0)
                    )
                    peak = max(peak, ctx)
                for block in message.get("content", []) or []:
                    btype = block.get("type")
                    if btype == "tool_use":
                        name = block.get("name", "?")
                        inp = block.get("input", {}) or {}
                        arg = (
                            inp.get("description") or inp.get("file_path")
                            or inp.get("command") or inp.get("pattern")
                            or inp.get("subagent_type") or ""
                        )
                        arg = str(arg).replace("\n", " ")
                        for root_variant in (str(ROOT), str(ROOT).replace("\\", "/")):
                            arg = re.sub(re.escape(root_variant), "", arg, flags=re.IGNORECASE)
                        arg = arg.lstrip("/\\")[:90]
                        if is_sub:
                            print(f"    | {name} {arg}")
                        else:
                            print(f"{label} {ctx // 1000}k -> {name} {arg}")
                    elif btype == "text" and not is_sub:
                        text = block.get("text", "") or ""
                        first_line = text.splitlines()[0] if text.splitlines() else ""
                        print(f"{label} {ctx // 1000}k {first_line[:140]}")
                boundary = ctx // 10000
                if boundary > last_boundary:
                    last_boundary = boundary
                    print(f"context {ctx // 1000}k / line {warn_line // 1000}k")

            elif etype == "system":
                subtype = event.get("subtype")
                if subtype == "compact_boundary":
                    print("compaction happened")
                    killed = True
                elif subtype == "api_retry":
                    print(f"retry attempt {event.get('attempt')} / {event.get('error_status')}")

            elif etype == "result":
                result = {
                    "subtype": event.get("subtype"),
                    "is_error": event.get("is_error"),
                    "total_cost_usd": event.get("total_cost_usd"),
                    "num_turns": event.get("num_turns"),
                    "result": (event.get("result") or "")[:300],
                    "terminal_reason": event.get("terminal_reason"),
                }
                if (result["is_error"] or result["subtype"] != "success") and LIMIT_RE.search(
                    result["result"]
                ):
                    limit = True

            if not killed and ctx >= kill_at:
                killed = True

            if killed and proc.poll() is None:
                print(f"context {ctx // 1000}k >= kill line: stopping this session")
                stop_child()
                break
    except KeyboardInterrupt:
        stop_child()
        raise
    finally:
        if log_file:
            log_file.close()

    if proc.poll() is None:
        proc.wait()

    if not limit and proc.returncode not in (0, None) and non_json_tail:
        if LIMIT_RE.search("\n".join(non_json_tail)):
            limit = True

    cost_known = result is not None
    cost = (result or {}).get("total_cost_usd") or 0.0 if cost_known else 0.0

    return {
        "ctx": ctx,
        "peak": peak,
        "killed": killed,
        "result": result,
        "exit": proc.returncode,
        "cost": float(cost),
        "cost_known": cost_known,
        "limit": limit,
    }


def safety_commit(pre_dirty: set[str], label: str, reason: str) -> str | None:
    """Commit any paths dirtied since pre_dirty (never -a/-A); return the new sha or None."""
    new = dirty_paths() - pre_dirty
    if not new:
        return None
    paths = sorted(new)
    print("Committing uncommitted files:")
    for p in paths:
        print(f"  {p}")
    stdin_paths = "\0".join(paths)
    add_result = subprocess.run(
        ["git", "add", "--pathspec-from-file=-", "--pathspec-file-nul"],
        input=stdin_paths, cwd=ROOT, text=True, encoding="utf-8", capture_output=True,
    )
    if add_result.returncode != 0:
        print(add_result.stderr, file=sys.stderr)
        return None
    commit_result = subprocess.run(
        [
            "git", "commit",
            "-m", f"autoplan {_PLAN_NAME} {label}: uncommitted work at session end ({reason})",
            "-m", "Committed by tools/autoplan.py; unverified.",
            "-m", "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>",
            "--pathspec-from-file=-", "--pathspec-file-nul",
        ],
        input=stdin_paths, cwd=ROOT, text=True, encoding="utf-8", capture_output=True,
    )
    if commit_result.returncode != 0:
        print(commit_result.stderr, file=sys.stderr)
        return None
    sha = head()
    print(f"Committed as {sha}")
    return sha


def print_summary(sessions: list[dict], stop_reason: str) -> None:
    """Print the end-of-run table of sessions, total cost and the stop reason."""
    print()
    print("session | exit | peak | cost | status | done | head")
    total_cost = 0.0
    for s in sessions:
        total_cost += s.get("cost", 0.0)
        cost_str = f"${s['cost']:.2f}" if s.get("cost_known", True) else "?"
        print(
            f"{s['label']} | {s['exit']} | peak {s['peak'] // 1000}k | "
            f"{cost_str} | status {s['status']} | done {s['done_str']} | "
            f"head {s['head']}"
        )
    print(f"total cost: ${total_cost:.2f}")
    print(f"stop reason: {stop_reason}")


def main() -> int:
    """Parse args, run the mode/dirty/stage checks, then drive the main session loop."""
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

    parser = argparse.ArgumentParser(description="Run a multi-phase plan unattended.")
    parser.add_argument("plan", nargs="?", default=None)
    parser.add_argument("--max-sessions", type=int, default=30)
    parser.add_argument("--budget", type=float, default=None)
    parser.add_argument("--model", default="claude-opus-5-5")
    parser.add_argument("--effort", default="medium")
    parser.add_argument("--permission-mode", default="auto")
    parser.add_argument("--line", type=int, default=120000)
    parser.add_argument("--kill", type=int, default=140000)
    parser.add_argument("--claude", default=None)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--here", "--shared", dest="here", action="store_true")
    parser.add_argument(
        "--force", action="store_true", help="kill a leftover headless autoplan session"
    )
    args = parser.parse_args()

    if args.kill <= args.line:
        print("--kill must be greater than --line")
        sys.exit(1)

    name = resolve_plan(args.plan)
    claude = find_claude(args.claude)

    plan = read_plan(name)
    if plan["stage"] not in ("ready", "running"):
        print(f"Plan {name} stage is '{plan['stage']}', not ready/running.")
        sys.exit(1)

    m = mode()
    if m == "shared" and not args.here:
        plan_path = f".claude/plans/{name}.md"
        if plan_path in dirty_paths():
            print(f"Commit .claude/plans/{name}.md on main first; the worktree is cut from HEAD.")
            sys.exit(1)
        if args.dry_run:
            print(f"would use .claude/worktrees/plan-{name}")
        else:
            guard_paths = ["tools/autoplan.py", ".claude/skills/plan/unattended.md"]
            guard_result = subprocess.run(
                ["git", "status", "--porcelain", "--", *guard_paths],
                cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace",
            )
            for path in guard_paths:
                if path in guard_result.stdout:
                    print(f"Commit {path} on main first; the worktree is cut from HEAD.")
                    sys.exit(1)
            wt = ensure_plan_worktree(name)
            argv = sys.argv[1:]
            if not args.plan:
                argv = [name, *argv]
            result = subprocess.run(
                [sys.executable, str(wt / "tools" / "autoplan.py"), *argv], cwd=wt,
            )
            sys.exit(result.returncode)
    elif m == "worktree" and ROOT.name != f"plan-{name}":
        print(f"Note: running in {ROOT.name}, not plan-{name}.")

    pre_dirty = dirty_paths()
    if not args.dry_run and m == "worktree" and pre_dirty:
        print("Uncommitted changes found; commit or stash them first:")
        for p in sorted(pre_dirty):
            print(f"  {p}")
        sys.exit(1)

    if not args.dry_run:
        acquire_lock(name, args.force)

    global _PLAN_NAME
    _PLAN_NAME = name

    answer_msg = (
        f"Answer in the app: open a Claude Code session on {ROOT.as_posix()}, type go, "
        f"then rerun: py -3 {main_root().as_posix()}/tools/autoplan.py {name}"
    )
    if not args.dry_run:
        pre_state = read_state(name)
        if pre_state.get("status") in ("blocked", "questions") or (
            plan["runnable"] is None and plan["deferred"] > 0
        ):
            print(answer_msg)
            return 4

    first_cmd = build_cmd(
        claude, session_prompt(name, 1, None, args.line, args.kill), args, args.budget
    )

    if args.dry_run:
        print(f"plan: {name}")
        print(f"stage: {plan['stage']}")
        print(f"mode: {m}")
        print(f"claude: {claude}")
        print("command:")
        print(" ".join(json.dumps(c) if " " in c or c == "" else c for c in first_cmd))

        runnable = plan["runnable"]
        if runnable:
            print(f"phase: {runnable['n']} · {runnable['title']}")
        else:
            print(f"phase: none runnable ({plan['deferred']} deferred)")

        state = read_state(name)
        print(f"state: {state.get('status') or 'no state file'}")

        wt_path = ROOT if m == "worktree" else ROOT / ".claude" / "worktrees" / f"plan-{name}"
        exists = wt_path.exists()
        print(f"worktree: {wt_path} ({'exists' if exists else 'would be created'})")
        sys.exit(0)

    sessions = []
    spent = 0.0
    partial_streak = 0
    last_key = None
    rescue = None
    stop_reason = "max sessions reached"
    exit_code = 1
    error_streak = 0
    run_dir = LOGS / name / time.strftime("%Y%m%d-%H%M%S")

    try:
        k = 1
        while k <= args.max_sessions:
            plan = read_plan(name)
            if plan["stage"] == "done":
                stop_reason = "plan done"
                exit_code = 0
                break
            if plan["runnable"] is None and plan["deferred"] > 0:
                stop_reason = f"questions: {plan['deferred']} deferred phase(s)"
                break
            if args.budget is not None and spent >= args.budget:
                stop_reason = "budget reached"
                break

            label = f"s{k}"
            remaining = None if args.budget is None else max(args.budget - spent, 0.0)
            cmd = build_cmd(
                claude, session_prompt(name, k, rescue, args.line, args.kill), args, remaining
            )

            env = child_env(name, k, args.line)

            log_path = run_dir / f"{label}.jsonl"

            start_head = head()
            res = run_session(cmd, env, log_path, args.kill, label, args.line)
            spent += res["cost"]
            if not res["cost_known"]:
                print("  cost unknown (session killed); --budget undercounts")

            if res["killed"]:
                reason = f"killed at {res['peak'] // 1000}k"
            else:
                reason = "session ended"
            sha = safety_commit(pre_dirty, label, reason)
            if sha is None and (dirty_paths() - pre_dirty):
                stop_reason = "safety commit failed"
                sessions.append({
                    "label": label, "exit": res["exit"], "peak": res["peak"],
                    "cost": res["cost"], "cost_known": res["cost_known"], "status": None,
                    "done_str": f"{plan['done']}/{plan['done'] + plan['todo']}",
                    "head": head()[:7],
                })
                break

            if res["limit"]:
                stop_reason = "usage limit"
                break

            state = read_state(name)
            plan = read_plan(name)
            status = state.get("status")
            if status is None and plan["stage"] == "done":
                status = "plan-done"

            new_head = head()

            sessions.append({
                "label": label,
                "exit": res["exit"],
                "peak": res["peak"],
                "cost": res["cost"],
                "cost_known": res["cost_known"],
                "status": status,
                "done_str": f"{plan['done']}/{plan['done'] + plan['todo']}",
                "head": new_head[:7],
            })
            cost_str = f"${res['cost']:.2f}" if res["cost_known"] else "?"
            print(
                f"{label} | {res['exit']} | peak {res['peak'] // 1000}k | "
                f"{cost_str} | status {status} | "
                f"done {plan['done']}/{plan['done'] + plan['todo']} | head {new_head[:7]}"
            )

            if plan["stage"] == "done" or (status == "plan-done" and plan["todo"] == 0):
                stop_reason = "plan done"
                exit_code = 0
                break

            no_result_error = (res["result"] is None and not res["killed"]) or (
                res["result"] is not None and res["result"].get("is_error") and not res["killed"]
            )
            if no_result_error:
                text = ""
                if res["result"]:
                    text = f"{res['result'].get('result', '')} {res['result'].get('terminal_reason', '')}"
                if "login" in text.lower() or "auth" in text.lower():
                    print("Not logged in: run the claude CLI once in a terminal and use /login, then re-run.")
                    stop_reason = "not logged in"
                    break
                error_streak += 1
                if error_streak >= 2:
                    stop_reason = "session errored twice in a row"
                    break
                print(f"Session errored; retrying in 60s.")
                time.sleep(60)
                continue
            error_streak = 0

            if status == "blocked":
                blocker_lines = (state.get("blocker") or "").strip().splitlines()
                stop_reason = f"blocked: {blocker_lines[0] if blocker_lines else ''}"
                break

            if status == "questions":
                stop_reason = f"questions: {state.get('q_count', 0)} waiting"
                break

            if res["killed"]:
                rescue = {"tokens": res["peak"], "sha": sha}
                k += 1
                continue

            if new_head == start_head and sha is None:
                text = res["result"].get("result", "") if res["result"] else ""
                print(f"No progress: the session made no commit. {text}")
                stop_reason = "no progress: the session made no commit"
                break

            if status == "partial":
                key = (plan["done"], "partial")
                partial_streak = partial_streak + 1 if key == last_key else 1
                last_key = key
                if partial_streak >= 3:
                    stop_reason = "same phase partial 3 times: split it in the plan"
                    break
                rescue = None
                k += 1
                continue

            partial_streak = 0
            rescue = None
            k += 1
    except KeyboardInterrupt:
        safety_commit(pre_dirty, f"s{k}", "interrupted")
        print_summary(sessions, "interrupted")
        sys.exit(130)

    print_summary(sessions, stop_reason)
    if stop_reason == "usage limit":
        print(
            "Usage limit reached: stopped without spending anything. The phase is resumable; "
            f"when the limit resets run: py -3 {main_root().as_posix()}/tools/autoplan.py {name}"
        )
        return 3
    if m == "worktree":
        branch = git("rev-parse", "--abbrev-ref", "HEAD")
        print(
            "Each phase lands itself on local main. Anything left unlanded: "
            f"py -3 {main_root().as_posix()}/tools/try.py {branch} --commit"
        )
    if stop_reason.startswith(("blocked", "questions")):
        print(answer_msg)
        return 4
    return exit_code


if __name__ == "__main__":
    sys.exit(main())

