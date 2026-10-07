#!/usr/bin/env python3
"""Headless smoke test for van-gunner: `py -3 tools/smoke.py [--bless]`.

Runs several Godot jobs in parallel (tools/smoke_jobs.py, at most `--jobs N`, default
min(cpu count, 6); `--serial` is `--jobs 1`; about 100 s wall on 4 cores, 260 s serial):
the game run, five facade stress shards and six van audit shards, longest first. The
game run plays a full van run headlessly (class pick, boons,
bench, combat, rest offer) with the save sandbox on, so it never touches a
real save on disk. Fails on any output line containing SCRIPT ERROR, Parse
Error or ERROR:, on a non-zero exit, on a timeout, or if the run does not log
`SMOKE: done`.

The run writes a deterministic fingerprint of class stats, loot pools, the
act deck and wave plans to tools/smoke/fingerprint.txt. Without `--bless`,
this is diffed against the committed tools/smoke/fingerprint.baseline.txt;
with `--bless`, the baseline is overwritten after a clean run. The headless run's
audit shards (`van_audit.PASSES`, summed) fail on any audit finding; `--plant-flicker`
runs one unsharded audit with a coplanar box pair planted to prove it fails.

`--shots DIR` plays the same run in a real window instead of headless, since
headless Godot renders nothing, and saves PNGs to DIR at four checkpoints (idle,
combat, the elevator stop and the rear-park stop). After a one-second settle,
each checkpoint saves three views: the front as the player sees it, the back
through the rear doors, and an outside view from above the cab looking back
over the van; the UI is hidden for the back and outside views. On Windows the
window runs on a separate hidden desktop (see tools/hidden_desktop.py), so it
is never visible and never takes focus or alt-tabs the owner out of a
fullscreen app; the run needs no config file override. Windows desktop only;
behaviour of the headless run is unchanged.

`--van-seeds N` (with `--shots`) also shoots the van's side view for N rerolled
look seeds at the idle checkpoint.
"""
import argparse
import difflib
import os
import pathlib
import re
import sys
import time

import check
import hidden_desktop
import van_audit
from smoke_jobs import Job, run_jobs
from godot_env import godot_exe, has_import_cache, project_lock, seed_import_cache, stamp_clean


if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

ROOT = pathlib.Path(__file__).resolve().parent.parent
FAILURE = re.compile(r"SCRIPT ERROR|Parse Error|ERROR:")
ANSI = re.compile(r"\x1b\[[0-9;]*m")
TIMEOUT_SECONDS = 300

FINGERPRINT = ROOT / "tools" / "smoke" / "fingerprint.txt"
BASELINE = ROOT / "tools" / "smoke" / "fingerprint.baseline.txt"


STRESS_SHARDS = 5
# Estimated seconds alone, for the longest-first start order.
EST_GAME, EST_STRESS = 38.0, 17.0
EST_AUDIT = {"closed": 40.0, "tail": 19.0}


def _lines(job: Job) -> list[str]:
    return [ANSI.sub("", line.rstrip()) for line in job.output.splitlines()]


def _job_failed(job: Job, label: str) -> bool:
    """Prints why a job could not even produce output (timeout, no start)."""
    if job.timed_out:
        print(f"   timed out after {TIMEOUT_SECONDS}s")
        print(f"SMOKE FAILED: {label} timed out")
        return True
    if job.error:
        print(f"SMOKE FAILED: {label} could not start: {job.error}")
        return True
    return False


def _game_ok(job: Job) -> bool:
    if _job_failed(job, "game run"):
        return False
    lines = _lines(job)
    hits = [line for line in lines if FAILURE.search(line)]
    for hit in hits:
        print("   " + hit)
    warnings = [line for line in lines if "WARNING:" in line]
    print(f"   {len(warnings)} warning(s)")
    smoke_lines = [line for line in lines if line.startswith("SMOKE:")]
    for line in smoke_lines:
        print("   " + line)
    print(f"   exit {job.returncode}, {len(hits)} failure line(s)")

    if hits:
        print(f"SMOKE FAILED: {len(hits)} failure line(s)")
        return False
    if job.returncode != 0:
        print(f"SMOKE FAILED: exit code {job.returncode}")
        return False
    if not any(line == "SMOKE: done" for line in smoke_lines):
        print("SMOKE FAILED: missing 'SMOKE: done' line")
        return False
    if not FINGERPRINT.exists():
        print("SMOKE FAILED: missing fingerprint.txt")
        return False
    return True


def _stress_ok(jobs: list[Job]) -> bool:
    ok = True
    for job in jobs:
        label = f"facade stress shard {job.name.removeprefix('stress ')}"
        lines = _lines(job)
        stress = [line for line in lines if line.startswith("STRESS")]
        hits = [line for line in lines if FAILURE.search(line)]
        if _job_failed(job, label):
            ok = False
        elif hits or job.returncode != 0 or "STRESS: done" not in lines:
            for line in stress + hits:
                print("   " + line)
            print(f"   exit {job.returncode}, {len(hits)} failure line(s)")
            print(f"SMOKE FAILED: {label}")
            ok = False
        else:
            for line in stress:
                if line.startswith("STRESS: OK stress"):
                    print("   " + line)
    return ok


def _audit_ok(jobs: list[Job]) -> bool:
    """Judges the audit shards (errors only), then the summed counts strictly."""
    ok = True
    totals: dict[str, int] = {}
    for job in jobs:
        print(f"   {job.name}:")
        if _job_failed(job, job.name):
            ok = False
            continue
        code, text = van_audit.judge(job.output, job.returncode, False)
        for line in text.splitlines():
            if not line.startswith(("AUDIT SUMMARY", "VAN AUDIT CLEAN", "VAN AUDIT FINDINGS")):
                print("   " + line)
        if code != 0:
            ok = False
        for key, value in van_audit.summary_counts(job.output).items():
            totals[key] = totals.get(key, 0) + value
    summary = " ".join(f"{key}={value}" for key, value in totals.items())
    print("AUDIT SUMMARY " + summary)
    if any(totals.values()):
        print(f"VAN AUDIT FINDINGS: {summary}")
        ok = False
    elif ok:
        print("VAN AUDIT CLEAN")
    if not ok:
        print("SMOKE FAILED: van audit (strict) failed; reports at .godot/van_audit/")
    return ok


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--bless", action="store_true", help="rewrite fingerprint.baseline.txt after a clean run"
    )
    parser.add_argument(
        "--shots", metavar="DIR",
        help="play in an off-screen window and save screenshots to DIR (Windows desktop only)",
    )
    parser.add_argument(
        "--van-seeds", type=int, default=0, metavar="N",
        help="with --shots: also shoot the van's side view for N rerolled look seeds at IDLE",
    )
    parser.add_argument(
        "--plant-flicker", action="store_true",
        help="plant a coplanar box pair in the audit to prove the strict audit fails",
    )
    parser.add_argument(
        "--jobs", type=int, default=min(os.cpu_count() or 2, 6), metavar="N",
        help="run at most N Godot jobs at once (default min(cpu count, 6))",
    )
    parser.add_argument("--serial", action="store_true", help="same as --jobs 1")
    parser.add_argument(
        "--pre", action="append", default=[], metavar="LINE",
        help="debug console line to run before the van scene loads (repeatable)",
    )
    opts = parser.parse_args()
    max_jobs = 1 if opts.serial else max(opts.jobs, 1)

    if opts.plant_flicker and opts.shots:
        print("SMOKE FAILED: --plant-flicker needs the headless run")
        return 1

    if opts.bless and opts.shots:
        print("SMOKE FAILED: --bless and --shots don't mix; bless from a headless run")
        return 1

    if opts.van_seeds < 0 or (opts.van_seeds > 0 and not opts.shots):
        print("SMOKE FAILED: --van-seeds needs --shots and a count of 0 or more")
        return 1

    if FINGERPRINT.exists():
        FINGERPRINT.unlink()

    shots: pathlib.Path | None = None
    if opts.shots:
        if sys.platform != "win32" and not os.environ.get("DISPLAY"):
            print(
                "SMOKE FAILED: --shots needs a display; this machine has none "
                "(cloud containers can't take screenshots)"
            )
            return 1
        shots = pathlib.Path(opts.shots).resolve()
        shots.mkdir(parents=True, exist_ok=True)
        for png in shots.glob("*.png"):
            png.unlink()

    seed_import_cache(ROOT)
    exe = godot_exe()
    game_blocking = None
    if shots is not None:
        args = [
            exe, "--path", str(ROOT),
            "--resolution", "1440x720", "res://tools/smoke/smoke_test.tscn", "--",
            "--smoke-sandbox", "--smoke-shots=" + shots.as_posix(),
        ]
        if opts.van_seeds > 0:
            args.append("--smoke-van-seeds=" + str(opts.van_seeds))
        args += ["--smoke-pre=" + line for line in opts.pre]
        print(
            "== smoke: godot --path . (hidden desktop) res://tools/smoke/smoke_test.tscn -- "
            f"--smoke-sandbox --smoke-shots={shots.as_posix()}"
            + (f" --smoke-van-seeds={opts.van_seeds}" if opts.van_seeds > 0 else "")
            + "".join(f" --smoke-pre={line}" for line in opts.pre)
        )
        if sys.platform == "win32":
            def game_blocking() -> tuple[int, str]:
                return hidden_desktop.run_hidden(args, ROOT, TIMEOUT_SECONDS)
    else:
        args = [
            exe, "--headless", "--path", str(ROOT),
            "res://tools/smoke/smoke_test.tscn", "--", "--smoke-sandbox",
        ]
        args += ["--smoke-pre=" + line for line in opts.pre]
        print(
            "== smoke: godot --headless --path . res://tools/smoke/smoke_test.tscn -- --smoke-sandbox"
            + "".join(f" --smoke-pre={line}" for line in opts.pre)
        )

    game = Job("game", args, EST_GAME, game_blocking)
    stress = [
        Job(
            f"stress {i}/{STRESS_SHARDS}",
            [
                exe, "--headless", "--path", str(ROOT), "res://tools/smoke/facade_stress.tscn",
                "--", "--smoke-sandbox", f"--stress-shard={i}/{STRESS_SHARDS}",
            ],
            EST_STRESS,
        )
        for i in range(STRESS_SHARDS)
    ]
    audit: list[Job] = []
    report_dir = ROOT / ".godot" / "van_audit"
    if shots is None and opts.plant_flicker:
        report_dir.mkdir(parents=True, exist_ok=True)
        audit.append(Job(
            "audit", van_audit.build_args(report_dir / "report.txt", plant_flicker=True), 155.0,
        ))
    elif shots is None:
        report_dir.mkdir(parents=True, exist_ok=True)
        for name in van_audit.PASSES:
            audit.append(Job(
                f"audit {name}",
                van_audit.build_args(report_dir / f"report_{name}.txt", passes=[name]),
                EST_AUDIT.get(name, 30.0),
            ))

    wall_start = time.time()
    with project_lock(ROOT):
        # The game never imports: without the cache every texture and class lookup
        # fails and the run hangs until the timeout, so a longer timeout would not
        # help (a fresh worktree whose main checkout has no cache, or the main
        # checkout before any editor run). A seeded cache is also stale for classes
        # the branch added (global_script_class_cache.cfg), so the scan always runs;
        # warm it costs only seconds.
        if has_import_cache(ROOT):
            print("   refreshing the import and class cache")
        else:
            print("   no import cache in .godot/: running the import scan first")
        import_hits, _ = check.run_pass(exe, ["--import"], "import scan")
        if import_hits:
            print(f"SMOKE FAILED: import scan printed {len(import_hits)} failure line(s)")
            return 1
        run_jobs([game] + stress + audit, max_jobs, ROOT, TIMEOUT_SECONDS)
    started = game.start
    wall = f"   wall {time.time() - wall_start:.0f} s (jobs {max_jobs})"

    if not _game_ok(game):
        return 1
    if not _stress_ok(stress):
        return 1
    audit_ok = shots is not None or _audit_ok(audit)

    if opts.bless:
        BASELINE.write_bytes(FINGERPRINT.read_bytes())
        print("BASELINE WRITTEN")
        if not audit_ok:
            return 1
        stamp_clean(ROOT, "smoke", started)
        print(wall)
        print("SMOKE CLEAN")
        return 0

    if not BASELINE.exists():
        print("SMOKE FAILED: no baseline; run `py -3 tools/smoke.py --bless` first")
        return 1

    current = FINGERPRINT.read_text(encoding="utf-8").replace("\r\n", "\n")
    baseline = BASELINE.read_text(encoding="utf-8").replace("\r\n", "\n")
    if current != baseline:
        diff = difflib.unified_diff(
            baseline.splitlines(keepends=True),
            current.splitlines(keepends=True),
            fromfile="fingerprint.baseline.txt",
            tofile="fingerprint.txt",
        )
        sys.stdout.writelines(diff)
        print("SMOKE FAILED: fingerprint differs from baseline")
        return 1

    if not audit_ok:
        return 1
    stamp_clean(ROOT, "smoke", started)
    if shots is not None:
        pngs = sorted(shots.glob("*.png"))
        print(f"   {len(pngs)} shot(s) in {shots}:")
        for png in pngs:
            print("     " + png.name)
    print(wall)
    print("SMOKE CLEAN")
    return 0


if __name__ == "__main__":
    sys.exit(main())
