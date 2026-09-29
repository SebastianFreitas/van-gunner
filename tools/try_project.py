"""Van Gunner's plug-in for the shared tools/try.py and tools/try_commit.py.

Plays a branch with the Godot console build (errors counted, full log in
.godot/try-last.log), and lands it after regenerating docs/PROJECT_MAP.md and
running tools/check.py (plus tools/smoke.py when main moved or with --smoke).
"""

from __future__ import annotations

import argparse
import pathlib
import re
import subprocess
import sys
import threading

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

from godot_env import godot_exe, project_lock, seed_import_cache  # noqa: E402

REGENERATED = ("docs/PROJECT_MAP.md",)
BASELINES = ("tools/smoke/fingerprint.baseline.txt", "tools/scene_dump/van.baseline.txt")

FAILURE = re.compile(r"SCRIPT ERROR|Parse Error|ERROR:")
ANSI = re.compile(r"\x1b\[[0-9;]*m")
OVERRIDE = """; Written by tools/try.py for this checkout only (gitignored): user:// goes
; to a separate profile, so a branch never touches the real saves or schematic.
[application]

config/use_custom_user_dir=true
config/custom_user_dir_name="van-gunner-try"
"""


def add_arguments(parser: argparse.ArgumentParser) -> None:
    parser.add_argument(
        "--smoke", action="store_true",
        help="with --commit: always run the smoke test on the combined tree",
    )
    parser.add_argument(
        "--editor", action="store_true",
        help="open the Godot editor on the branch instead of playing",
    )
    parser.add_argument("--scene", help="a res:// scene to play instead of the main scene")
    parser.add_argument(
        "--real-saves", action="store_true",
        help="use your real profile instead of the separate van-gunner-try one",
    )


def prepare_tree(tree: pathlib.Path) -> None:
    seed_import_cache(tree)


def write_override(tree: pathlib.Path, real_saves: bool) -> None:
    path = tree / "override.cfg"
    if real_saves:
        path.unlink(missing_ok=True)
    else:
        path.write_text(OVERRIDE, encoding="utf-8", newline="\n")


def import_scan(tree: pathlib.Path, exe: str) -> None:
    print("== import scan (re-imports only what changed since the last try)")
    with project_lock(tree):
        try:
            r = subprocess.run(
                [exe, "--headless", "--path", str(tree), "--import"],
                cwd=tree, capture_output=True, text=True, encoding="utf-8", errors="replace",
                timeout=900,
            )
        except subprocess.TimeoutExpired:
            print("   timed out after 900 s")
            return
    lines = [ANSI.sub("", line.rstrip()) for line in (r.stdout + r.stderr).splitlines()]
    hits = [line for line in lines if FAILURE.search(line)]
    for hit in hits[:10]:
        print("   " + hit)
    print(f"   {len(hits)} error line(s)")


def _pump(proc: subprocess.Popen, log_path: pathlib.Path) -> None:
    """Tails the game's output into the log, echoing and counting error lines, and
    prints the summary when the process exits."""
    errors = 0
    with open(log_path, "w", encoding="utf-8", newline="\n") as log:
        for line in proc.stdout:
            log.write(line)
            clean = ANSI.sub("", line)
            if FAILURE.search(clean):
                errors += 1
                print("   " + line.rstrip())
    print(f"\nGame closed: {errors} error line(s). Full log: {log_path}")


def launch(
    tree: pathlib.Path, args: argparse.Namespace, is_main: bool
) -> tuple[subprocess.Popen | None, str | None]:
    exe = godot_exe()
    if not is_main:
        write_override(tree, args.real_saves)
        if not args.editor:
            import_scan(tree, exe)
        if not args.real_saves:
            print("Saves and the schematic go to the separate van-gunner-try profile.")

    if args.editor:
        proc = subprocess.Popen(
            [exe, "--editor", "--path", str(tree)], cwd=tree,
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        return proc, None

    log_path = tree / ".godot" / "try-last.log"
    log_path.parent.mkdir(parents=True, exist_ok=True)
    proc = subprocess.Popen(
        [exe, "--path", str(tree)] + ([args.scene] if args.scene else []), cwd=tree,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        text=True, encoding="utf-8", errors="replace", bufsize=1,
    )
    # Not a daemon: the interpreter waits for it, so the summary prints even after a stop.
    threading.Thread(target=_pump, args=(proc, log_path)).start()
    return proc, None


def before_commit(tree: pathlib.Path) -> bool:
    r = subprocess.run(
        [sys.executable, "tools/gen_context.py"], cwd=tree,
        capture_output=True, text=True, encoding="utf-8", errors="replace",
    )
    if r.returncode != 0:
        for line in (r.stdout + r.stderr).splitlines()[-10:]:
            print("   " + line)
        return False
    return True


def verify(tree: pathlib.Path, main_moved: bool, args: argparse.Namespace) -> bool:
    run_smoke = main_moved or getattr(args, "smoke", False)
    tools = ["tools/check.py"] + (["tools/smoke.py"] if run_smoke else [])
    if run_smoke:
        why = "main moved since this branch was cut" if main_moved else "--smoke was given"
        print(f"   the smoke test runs too: {why}")

    for tool in tools:
        print(f"== {tool} on the combined tree")
        r = subprocess.run(
            [sys.executable, tool], cwd=tree,
            capture_output=True, text=True, encoding="utf-8", errors="replace",
        )
        output_lines = (r.stdout + r.stderr).splitlines()
        failures = [line for line in output_lines if FAILURE.search(ANSI.sub("", line))]
        if r.returncode != 0 or failures:
            for line in output_lines[-15:]:
                print("   " + line)
            print(
                f"{tool} fails on main plus this branch. In that session, ask Claude to "
                "merge main into its branch, fix it and commit; then run this again."
            )
            return False
        print("   " + (output_lines[-1] if output_lines else "ok"))
    return True


def after_land(root: pathlib.Path) -> None:
    print("If the Godot editor is open on this project, let it reimport the changed files.")
