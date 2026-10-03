#!/usr/bin/env python3
"""Headless van audit for van-gunner: `py -3 tools/van_audit.py [--out PATH] [--strict]
[--timeout S] [--van-seed N] [--plant-flicker]`.

Boots the van run headless (save sandbox on), collects every visible triangle of the
van and runs the audit's checks, writing a report to `--out` (default
`.godot/van_audit/report.txt`). Echoes every `AUDIT` line to stdout. Fails on any
output line with SCRIPT ERROR / Parse Error / ERROR:, a non-zero exit, a timeout, or a
missing `AUDIT DONE` line. Prints `VAN AUDIT CLEAN` when the summary counts are all
zero, else `VAN AUDIT FINDINGS: <summary>`. Report mode (default) always exits 0 on a
clean run; `--strict` exits 1 when the summary counts any finding. `--van-seed N`
rerolls the van's look to seed N first; `--plant-flicker` adds a coplanar box pair so
the audit must report a FLICKER (proves `--strict` fails). `tools/smoke.py` calls
`run()` in strict mode.
"""
import argparse
import pathlib
import re
import subprocess
import sys

from godot_env import godot_exe, project_lock, seed_import_cache

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

ROOT = pathlib.Path(__file__).resolve().parent.parent
FAILURE = re.compile(r"SCRIPT ERROR|Parse Error|ERROR:")
ANSI = re.compile(r"\x1b\[[0-9;]*m")
SUMMARY = re.compile(r"AUDIT SUMMARY (.*)")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--out", default=str(ROOT / ".godot" / "van_audit" / "report.txt"),
        help="path to write the report to",
    )
    parser.add_argument(
        "--strict", action="store_true",
        help="exit 1 when the summary counts any finding",
    )
    parser.add_argument("--timeout", type=int, default=600, help="timeout in seconds")
    parser.add_argument(
        "--probe", action="append", default=[], metavar="X,Y,Z:DX,DY,DZ",
        help="rig-local ray to probe instead of the audit; repeatable",
    )
    parser.add_argument(
        "--van-seed", type=int, default=None, metavar="N",
        help="reroll the van's look to seed N before auditing",
    )
    parser.add_argument(
        "--plant-flicker", action="store_true",
        help="plant a coplanar box pair so the audit reports a FLICKER (test switch)",
    )
    return parser.parse_args()


def main() -> int:
    opts = parse_args()
    return run(
        pathlib.Path(opts.out).resolve(), opts.strict, opts.timeout, opts.probe,
        opts.van_seed, opts.plant_flicker,
    )


PASSES = ("closed", "half", "open", "win_half", "win_open", "tail")


def build_args(
    out: pathlib.Path, probes: list[str] | None = None, van_seed: int | None = None,
    plant_flicker: bool = False, passes: list[str] | None = None,
) -> list[str]:
    """The Godot command line for one audit launch; `passes` None runs them all."""
    args = [
        godot_exe(), "--headless", "--path", str(ROOT),
        "res://tools/van_audit/van_audit.tscn", "--", "--smoke-sandbox",
        "--audit-out=" + out.as_posix(),
    ]
    args += ["--probe=" + probe for probe in probes or []]
    if van_seed is not None:
        args.append(f"--van-seed={van_seed}")
    if plant_flicker:
        args.append("--plant-flicker")
    if passes:
        args.append("--audit-passes=" + ",".join(passes))
    return args


def summary_counts(text: str) -> dict[str, int]:
    """Sums every `AUDIT SUMMARY K=V ...` line in the output into one dict."""
    counts: dict[str, int] = {}
    for line in text.splitlines():
        match = SUMMARY.match(ANSI.sub("", line.rstrip()))
        if match:
            for pair in match.group(1).split():
                key, _, value = pair.partition("=")
                if value:
                    counts[key] = counts.get(key, 0) + int(value)
    return counts


def judge(
    stdout_text: str, returncode: int, strict: bool, probes: bool = False,
) -> tuple[int, str]:
    """Judges one audit launch's output; returns (exit code, the lines to print)."""
    lines = [ANSI.sub("", line.rstrip()) for line in stdout_text.splitlines()]
    out = [line for line in lines if line.startswith("AUDIT")]

    hits = [line for line in lines if FAILURE.search(line)]
    out += ["   " + hit for hit in hits]
    warnings = [line for line in lines if "WARNING:" in line]
    out.append(f"   {len(warnings)} warning(s)")
    out.append(f"   exit {returncode}, {len(hits)} failure line(s)")

    def done(code: int, last: str | None = None) -> tuple[int, str]:
        if last:
            out.append(last)
        return code, "\n".join(out)

    if hits:
        return done(1, f"VAN AUDIT FAILED: {len(hits)} failure line(s)")
    if returncode != 0:
        return done(1, f"VAN AUDIT FAILED: exit code {returncode}")
    if probes:
        return done(0)
    if not any(line == "AUDIT DONE" for line in lines):
        return done(1, "VAN AUDIT FAILED: missing 'AUDIT DONE' line")

    summary = ""
    for line in lines:
        match = SUMMARY.match(line)
        if match:
            summary = match.group(1).strip()
    if any(value != 0 for value in summary_counts(stdout_text).values()):
        return done(1 if strict else 0, f"VAN AUDIT FINDINGS: {summary}")
    return done(0, "VAN AUDIT CLEAN")


def run(
    out: pathlib.Path, strict: bool = False, timeout: int = 600,
    probes: list[str] | None = None, van_seed: int | None = None,
    plant_flicker: bool = False,
) -> int:
    probes = probes or []
    out.parent.mkdir(parents=True, exist_ok=True)

    seed_import_cache(ROOT)
    args = build_args(out, probes, van_seed, plant_flicker)
    print(
        "== van_audit: godot --headless --path . res://tools/van_audit/van_audit.tscn "
        "-- " + " ".join(args[args.index("--") + 1:])
    )

    with project_lock(ROOT):
        try:
            proc = subprocess.run(
                args,
                cwd=ROOT,
                capture_output=True,
                encoding="utf-8",
                errors="replace",
                timeout=timeout,
                creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
            )
        except subprocess.TimeoutExpired:
            print(f"   timed out after {timeout}s")
            print("VAN AUDIT FAILED: timed out")
            return 1

    code, text = judge(proc.stdout + proc.stderr, proc.returncode, strict, bool(probes))
    print(text)
    return code


if __name__ == "__main__":
    sys.exit(main())
