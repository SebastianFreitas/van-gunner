#!/usr/bin/env python3
"""Headless Blender runner for the arms glb (source of truth: tools/blender/arms.blend).

`py -3 tools/blender/arms.py import [<glb>] [--force]` writes arms.blend from the glb
(default assets/models/arms/arms.glb; refuses to overwrite an existing arms.blend without
--force). `build [<blend>] [--out <dir>]` saves the blend compressed and exports the six parts to assets/models/arms/arms.glb (or <dir>/arms.glb), then runs `check`; give a scratch copy of the blend and a scratch dir to leave the real ones alone. `check [<blend>] [--bless]` counts mesh defects (non-manifold or flipped edges, inside-out and zero-area faces, loose vertices, bad deform weights, UV maps) per part and fails when a count rises above arms_mesh.baseline.json (--bless rewrites it); it never saves. `prove [<dir>]` moves
the right hand's back-of-hand slab 4 mm outward in memory, exports a scratch glb + json to <dir>
(default the temp dir), runs the game-side measure through tools/probe.py and writes
.claude/specs/reports/prove.md; arms.blend and arms.glb are not touched. `preview <dir>` writes
back.png, palm.png and side.png (cc0 right hand left, current ArmR right). `look <dir> [--before <step>]`
renders both hands at rest (back, palm, side, plus 4x fingertip and knuckle close-ups, 2048x1024; left
half the archive_ `<step>_*` copies, right half the live parts) and writes look.txt; it never saves
arms.blend. `step <name> [args] [--blend <copy>] [--out <dir>]` runs the scripted edit `arms_<name>_bl.py` (e.g. `step mass`; archive_ copies
`<name>_<part>` first, a re-run restores them, then build). `veinpaths <dir>` runs research 04's vein gates (Set v2) on the real mesh chart and
writes <dir>/paths.txt (needs the ARMS_PHOTO env var, the owner's fist photo; fails, exempt fails with skin vertex ids); it never saves arms.blend. `relief <dir>` writes <dir>/relief.txt (vein crest per hand and path, finger cord gates; read-only). `veindump <dir>`
writes the mesh chart tables <dir>/mesh_R.json and mesh_L.json for research 04's offline mesh_table.py. `hunt <glb> <dir>`
(a glb from the `arms export` console command, with its .bones.json beside it) writes hunt.txt,
one line per defect cluster, plus orbit and close-up renders; it does not need arms.blend. Blender is
the BLENDER env var, else the newest C:/Program Files/Blender Foundation/Blender */blender.exe
(5.2 or newer). Runs with --python-exit-code 1; each *_bl.py writes a JSON result (bl_result.py)
to the temp dir via `--result`. Prints one `RESULT <command>: ok|FAIL ...` line, plus the last 40
lines of Blender's output on failure; exit 1 on a non-zero exit, a missing result or a failure.
"""
from __future__ import annotations

import glob
import json
import os
import pathlib
import re
import subprocess
import sys
import tempfile

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent.parent
BLEND = HERE / "arms.blend"
GLB = ROOT / "assets" / "models" / "arms" / "arms.glb"
MIN_VERSION = (5, 2)
_blender: str | None = None


def find_blender() -> str | None:
    """BLENDER env var, else the newest Blender Foundation install; checked once per run."""
    global _blender
    if _blender is not None:
        return _blender
    env = os.environ.get("BLENDER")
    if env:
        found = env if os.path.isfile(env) else None
    else:
        def ver(p: str) -> tuple:
            return tuple(int(n) for n in re.findall(r"\d+", p.split("Blender ")[-1].split("/")[0]))
        found = max(glob.glob("C:/Program Files/Blender Foundation/Blender */blender.exe"),
                    key=ver, default=None)
    if found is None:
        print("Blender not found: set BLENDER or install Blender %d.%d+ under "
              "C:/Program Files/Blender Foundation/" % MIN_VERSION)
        return None
    p = subprocess.run([found, "--version"], capture_output=True, text=True, errors="replace")
    m = re.search(r"Blender (\d+)\.(\d+)", p.stdout)
    if not m or (int(m.group(1)), int(m.group(2))) < MIN_VERSION:
        print("Blender %d.%d+ needed; %s reports: %s"
              % (MIN_VERSION + (found, (p.stdout.splitlines() or ["nothing"])[0])))
        return None
    _blender = found
    return found


def run(blend: pathlib.Path | None, *args: str, script: str = "arms_bl.py") -> int:
    exe = find_blender()
    if exe is None:
        return 1
    res = pathlib.Path(tempfile.gettempdir()) / ("arms_result_%d.json" % os.getpid())
    res.unlink(missing_ok=True)
    cmd = [exe, "-b", "--factory-startup", "--python-exit-code", "1"]
    if blend is not None:
        cmd.append(str(blend))
    # Blender ignores PYTHONPATH, so this one bootstrap puts the folder on its path: the scripts
    # import each other (and arm_names) plainly.
    cmd += ["--python-expr", "import sys; sys.path[:0] = [%r]" % str(HERE),
            "--python", str(HERE / script), "--"] + list(args) + ["--result", str(res)]
    p = subprocess.run(cmd, capture_output=True, text=True, errors="replace")
    out = p.stdout + p.stderr
    data = None
    if res.exists():
        try:
            data = json.loads(res.read_text(encoding="utf-8"))
        except ValueError:
            pass
        res.unlink(missing_ok=True)
    # The text match is only a backstop; the exit code and the JSON decide.
    bad = "Traceback" in out or "Error: Python" in out
    ok = p.returncode == 0 and data is not None and data.get("ok") and not bad
    name = data.get("command", script) if data else script
    if ok:
        nums = " ".join("%s=%s" % (k, v) for k, v in data.items()
                        if k not in ("ok", "command", "errors", "notes"))
        print("RESULT %s: ok %s" % (name, nums))
        for n in data.get("notes", []):
            print("NOTE", n)
        return 0
    print(chr(10).join(out.splitlines()[-40:]))
    why = "exit %d" % p.returncode if p.returncode else (
        "no result file" if data is None else "ok=false or traceback in output")
    errs = "; ".join(map(str, data.get("errors", []))) if data else ""
    print("RESULT %s: FAIL %s %s" % (name, why, errs))
    return 1


def prove(out: pathlib.Path | None) -> int:
    """Scratch edit in Blender, then `arms prove` in the game headless; the report is the output."""
    out = out or pathlib.Path(tempfile.gettempdir()) / "arms_prove"
    out.mkdir(parents=True, exist_ok=True)
    glb, js = out / "prove.glb", out / "prove.json"
    if run(BLEND, "prove", str(glb), str(js)):
        return 1
    # The scratch glb lies outside res://, so the game reads it by absolute path.
    cmd = ["py", "-3", str(ROOT / "tools" / "probe.py"), "--cmd",
           "arms prove %s %s" % (str(glb).replace("\\", "/"), str(js).replace("\\", "/"))]
    p = subprocess.run(cmd, capture_output=True, text=True, errors="replace", cwd=ROOT)
    text = p.stdout + p.stderr
    lines = [ln for ln in text.splitlines() if "PROVE" in ln or ln.strip().startswith("part")
             or ln.strip().startswith("group")]
    report = ROOT / ".claude" / "specs" / "reports" / "prove.md"
    body = chr(10).join(lines)
    report.write_text("# arms prove" + chr(10)*2 + "```" + chr(10) + body + chr(10) + "```" + chr(10), encoding="utf-8")
    print(body)
    bad = [ln for ln in text.splitlines() if "SCRIPT ERROR" in ln or "ERROR:" in ln]
    print(chr(10).join(bad))
    return 0 if lines and not bad and "PROVE OK" in text else 1


def check(blend: pathlib.Path, flags: list[str]) -> int:
    """Mesh health of the six parts vs arms_mesh.baseline.json; opens the blend, never saves."""
    return run(blend, *flags, script="arms_meshcheck_bl.py")


def main(argv: list[str]) -> int:
    if not argv:
        print(__doc__)
        return 2
    cmd, rest = argv[0], argv[1:]
    force = "--force" in rest
    rest = [a for a in rest if a != "--force"]
    if cmd == "import":
        if BLEND.exists() and not force:
            print("arms.blend exists; pass --force to overwrite")
            return 1
        src = pathlib.Path(rest[0]).resolve() if rest else GLB
        return run(None, "import", str(src))
    if cmd == "build":
        out = pathlib.Path(rest[rest.index("--out") + 1]).resolve() if "--out" in rest else None
        pos = [a for i, a in enumerate(rest) if not a.startswith("--") and (i == 0 or rest[i - 1] != "--out")]
        blend = pathlib.Path(pos[0]).resolve() if pos else BLEND
        glb = [str(out / "arms.glb")] if out else []
        if out:
            out.mkdir(parents=True, exist_ok=True)
        return run(blend, "build", *glb) or check(blend, [])
    if cmd == "check":
        blend = [a for a in rest if not a.startswith("--")]
        return check(pathlib.Path(blend[0]).resolve() if blend else BLEND, [a for a in rest if a == "--bless"])
    if cmd == "preview" and rest:
        out = pathlib.Path(rest[0]).resolve()
        return run(BLEND, "preview", str(out))
    if cmd == "hunt" and len(rest) == 2:
        return run(None, str(pathlib.Path(rest[0]).resolve()), str(pathlib.Path(rest[1]).resolve()),
                   script="arms_hunt_bl.py")
    if cmd == "look" and rest:
        step = rest[rest.index("--before") + 1:][:1] if "--before" in rest else []
        return run(BLEND, str(pathlib.Path(rest[0]).resolve()), *step, script="arms_look_bl.py")
    if cmd == "veinpaths" and rest:
        return run(BLEND, str(pathlib.Path(rest[0]).resolve()), script="arms_veinpaths_bl.py")
    if cmd == "relief" and rest:
        base = ["--baseline", str(pathlib.Path(rest[rest.index("--baseline") + 1]).resolve())] \
            if "--baseline" in rest else []
        return run(BLEND, str(pathlib.Path(rest[0]).resolve()), *base, script="arms_relief_bl.py")
    if cmd == "veindump" and rest:
        return run(BLEND, str(pathlib.Path(rest[0]).resolve()), script="arms_veindump_bl.py")
    if cmd == "step" and rest:
        sargs = list(rest)
        blend = pathlib.Path(sargs.pop(sargs.index("--blend") + 1)).resolve() if "--blend" in sargs else BLEND
        if "--blend" in sargs:
            sargs.remove("--blend")
        if "--out" in sargs:  # a scratch dir: the step exports there instead of assets/models/arms
            out = pathlib.Path(sargs.pop(sargs.index("--out") + 1)).resolve()
            sargs.remove("--out")
            out.mkdir(parents=True, exist_ok=True)
            os.environ["ARMS_GLB_OUT"] = str(out / "arms.glb")
        return run(blend, *sargs, script="arms_step_bl.py")
    if cmd == "prove":
        return prove(pathlib.Path(rest[0]).resolve() if rest else None)
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
