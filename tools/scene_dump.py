#!/usr/bin/env python3
"""Headless scene dump for van-gunner: `py -3 tools/scene_dump.py [--bless]`.

Runs one Godot pass that instantiates scenes/van/van.tscn headlessly (save
sandbox on, never touching a real save on disk) and writes a deterministic
text dump of every node, property, resource and persistent connection to
tools/scene_dump/van.txt. Fails on any output line containing SCRIPT ERROR,
Parse Error or ERROR:, on a non-zero exit, on a timeout, or if the dump file
is missing.

Without `--bless`, the dump is diffed against the committed
tools/scene_dump/van.baseline.txt; with `--bless`, the baseline is
overwritten after a clean run. A failing compare prints a node summary (added,
removed, renamed, value changes) before the raw diff, capped at 40 lines. This exists so a later text-edit split of
van.tscn into sub-scenes can prove the instantiated tree is unchanged.
"""
import difflib
import pathlib
import re
import subprocess
import sys
import time

from godot_env import godot_exe, project_lock, seed_import_cache, stamp_clean

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

ROOT = pathlib.Path(__file__).resolve().parent.parent
FAILURE = re.compile(r"SCRIPT ERROR|Parse Error|ERROR:")
ANSI = re.compile(r"\x1b\[[0-9;]*m")
TIMEOUT_SECONDS = 120

DUMP = ROOT / "tools" / "scene_dump" / "van.txt"
BASELINE = ROOT / "tools" / "scene_dump" / "van.baseline.txt"


def parse_dump(text: str) -> dict[str, tuple[str, list[str]]]:
    """Maps node path -> (header after the path, body lines)."""
    nodes: dict[str, tuple[str, list[str]]] = {}
    path = ""
    for line in text.splitlines():
        if line.startswith("NODE "):
            path, _, rest = line[5:].partition(" ")
            nodes[path] = (rest, [])
        elif path:
            nodes[path][1].append(line)
    return nodes


def summarize(baseline: str, current: str) -> list[str]:
    """Short readable summary of what changed between two dumps."""
    old, new = parse_dump(baseline), parse_dump(current)
    # A shared resource's owner label moves when its first owner is renamed; that
    # is not a value change, so the comparison ignores the text after `Class@`.
    label = re.compile(r"@[^{,\s\]}]*")
    old = {p: (h, [label.sub("@", b) for b in body]) for p, (h, body) in old.items()}
    new = {p: (h, [label.sub("@", b) for b in body]) for p, (h, body) in new.items()}
    removed = sorted(set(old) - set(new))
    added = sorted(set(new) - set(old))

    def shape(path: str, nodes: dict) -> tuple:
        header, body = nodes[path]
        return header, [b.replace(path + ":", "@:").replace(path + ".", "@.") for b in body]

    renamed: list[tuple[str, str]] = []
    for r in list(removed):
        parent = r.rpartition("/")[0]
        for a in added:
            if a.rpartition("/")[0] == parent and shape(a, new) == shape(r, old):
                renamed.append((r, a))
                removed.remove(r)
                added.remove(a)
                break

    def under_rename(path: str, side: int) -> bool:
        return any(path.startswith(pair[side] + "/") for pair in renamed)

    removed = [p for p in removed if not under_rename(p, 0)]
    added = [p for p in added if not under_rename(p, 1)]
    out = [f"-- scene dump summary: {len(added)} added, {len(removed)} removed, "
           f"{len(renamed)} renamed"]
    out += [f"   + added   {p}" for p in added]
    out += [f"   - removed {p}" for p in removed]
    out += [f"   > renamed {r} -> {a.rpartition('/')[2]}" for r, a in renamed]
    changed = [p for p in old if p in new and old[p] != new[p]]
    out.append(f"   {len(changed)} node(s) with value changes")
    for p in changed:
        keys = lambda body: {b.strip().partition("=")[0]: b for b in body}
        ko, kn = keys(old[p][1]), keys(new[p][1])
        props = sorted(k for k in set(ko) | set(kn) if ko.get(k) != kn.get(k))
        if old[p][0] != new[p][0]:
            props.insert(0, "(header)")
        out.append(f"   ~ {p}: {', '.join(props)}")
    return out


def main() -> int:
    bless = "--bless" in sys.argv[1:]

    if DUMP.exists():
        DUMP.unlink()

    seed_import_cache(ROOT)
    exe = godot_exe()
    args = [
        exe, "--headless", "--path", str(ROOT),
        "res://tools/scene_dump/scene_dump.tscn", "--", "--smoke-sandbox",
        "res://scenes/van/van.tscn", "res://tools/scene_dump/van.txt",
    ]
    print(
        "== scene_dump: godot --headless --path . res://tools/scene_dump/scene_dump.tscn "
        "-- --smoke-sandbox res://scenes/van/van.tscn res://tools/scene_dump/van.txt"
    )
    with project_lock(ROOT):
        started = time.time()
        try:
            proc = subprocess.run(
                args,
                cwd=ROOT,
                capture_output=True,
                encoding="utf-8",
                errors="replace",
                timeout=TIMEOUT_SECONDS,
                creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
            )
        except subprocess.TimeoutExpired:
            print(f"   timed out after {TIMEOUT_SECONDS}s")
            print("SCENE DUMP FAILED: timed out")
            return 1

    lines = [ANSI.sub("", line.rstrip()) for line in (proc.stdout + proc.stderr).splitlines()]
    hits = [line for line in lines if FAILURE.search(line)]
    for hit in hits:
        print("   " + hit)
    warnings = [line for line in lines if "WARNING:" in line]
    print(f"   {len(warnings)} warning(s)")
    print(f"   exit {proc.returncode}, {len(hits)} failure line(s)")

    if hits:
        print(f"SCENE DUMP FAILED: {len(hits)} failure line(s)")
        return 1
    if proc.returncode != 0:
        print(f"SCENE DUMP FAILED: exit code {proc.returncode}")
        return 1
    if not DUMP.exists():
        print("SCENE DUMP FAILED: missing van.txt")
        return 1

    if bless:
        BASELINE.write_bytes(DUMP.read_bytes())
        print("BASELINE WRITTEN")
        stamp_clean(ROOT, "scene_dump", started)
        print("SCENE DUMP CLEAN")
        return 0

    if not BASELINE.exists():
        print("SCENE DUMP FAILED: no baseline; run `py -3 tools/scene_dump.py --bless` first")
        return 1

    current = DUMP.read_text(encoding="utf-8").replace("\r\n", "\n")
    baseline = BASELINE.read_text(encoding="utf-8").replace("\r\n", "\n")
    if current != baseline:
        diff = difflib.unified_diff(
            baseline.splitlines(keepends=True),
            current.splitlines(keepends=True),
            fromfile="van.baseline.txt",
            tofile="van.txt",
        )
        print("\n".join(summarize(baseline, current)))
        shown = list(diff)
        sys.stdout.writelines(shown[:40])
        if len(shown) > 40:
            print(f"... {len(shown) - 40} more diff line(s) not shown")
        print("SCENE DUMP FAILED: dump differs from baseline")
        return 1

    print(f"scene dump: identical ({len(current.splitlines())} lines)")
    stamp_clean(ROOT, "scene_dump", started)
    print("SCENE DUMP CLEAN")
    return 0


if __name__ == "__main__":
    sys.exit(main())
