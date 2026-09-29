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


def run(
    out: pathlib.Path, strict: bool = False, timeout: int = 600,
    probes: list[str] | None = None, van_seed: int | None = None,
    plant_flicker: bool = False,
) -> int:
    probes = probes or []
    out.parent.mkdir(parents=True, exist_ok=True)

    seed_import_cache(ROOT)
    exe = godot_exe()
    args = [
        exe, "--headless", "--path", str(ROOT),
        "res://tools/van_audit/van_audit.tscn", "--", "--smoke-sandbox",
        "--audit-out=" + out.as_posix(),
    ]
    args += ["--probe=" + probe for probe in probes]
    extra = ""
    if van_seed is not None:
        args.append(f"--van-seed={van_seed}")
        extra += f" --van-seed={van_seed}"
    if plant_flicker:
        args.append("--plant-flicker")
        extra += " --plant-flicker"
    print(
        "== van_audit: godot --headless --path . res://tools/van_audit/van_audit.tscn "
        "-- --smoke-sandbox --audit-out=" + out.as_posix() + extra
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

    lines = [ANSI.sub("", line.rstrip()) for line in (proc.stdout + proc.stderr).splitlines()]
    for line in lines:
        if line.startswith("AUDIT"):
            print(line)

    hits = [line for line in lines if FAILURE.search(line)]
    for hit in hits:
        print("   " + hit)
    warnings = [line for line in lines if "WARNING:" in line]
    print(f"   {len(warnings)} warning(s)")
    print(f"   exit {proc.returncode}, {len(hits)} failure line(s)")

    if hits:
        print(f"VAN AUDIT FAILED: {len(hits)} failure line(s)")
        return 1
    if proc.returncode != 0:
        print(f"VAN AUDIT FAILED: exit code {proc.returncode}")
        return 1
    if probes:
        return 0
    if not any(line == "AUDIT DONE" for line in lines):
        print("VAN AUDIT FAILED: missing 'AUDIT DONE' line")
        return 1

    summary = ""
    findings = False
    for line in lines:
        match = SUMMARY.match(line)
        if match:
            summary = match.group(1).strip()
            for pair in summary.split():
                _, _, value = pair.partition("=")
                if value and int(value) != 0:
                    findings = True

    if findings:
        print(f"VAN AUDIT FINDINGS: {summary}")
        return 1 if strict else 0

    print("VAN AUDIT CLEAN")
    return 0


if __name__ == "__main__":
    sys.exit(main())
