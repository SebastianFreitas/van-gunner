#!/usr/bin/env python3
"""Headless Blender runner for the arms glb (source of truth: tools/blender/arms.blend).

`py -3 tools/blender/arms.py import [<glb>] [--force]` writes arms.blend from the glb
(default assets/models/arms/arms.glb; refuses to overwrite an existing arms.blend without
--force). `import-baked <baked.glb> [--force]` (for re-seeding from a glb someone supplies; the hands' source is now arms.blend itself and the
`arms bake` console is retired, tag archive/arms-procedural-build) makes its six parts (L_/R_ skin, fingers, webs) the source meshes on the existing rig and moves
the old ArmL/ArmR and cc0 copies to the hidden `archive_` collection. `build` saves the blend
compressed and exports the six parts to assets/models/arms/arms.glb. `prove [<dir>]` moves
the right hand's back-of-hand slab 4 mm outward in memory, exports a scratch glb + json to <dir>
(default the temp dir), runs the game-side measure through tools/probe.py and writes
.claude/specs/reports/prove.md; arms.blend and arms.glb are not touched. `preview <dir>` writes
back.png, palm.png and side.png (cc0 right hand left, current ArmR right). `hunt <glb> <dir>`
(a glb from the `arms export` console command, with its .bones.json beside it) writes hunt.txt,
one line per defect cluster, plus orbit and close-up renders; it does not need arms.blend. Blender is
C:/Program Files/Blender Foundation/Blender 5.2/blender.exe unless the BLENDER env var
names another. Prints the tail of Blender's output; exit 1 on a Python traceback or error.
"""
from __future__ import annotations

import os
import pathlib
import subprocess
import sys
import tempfile

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent.parent
BLEND = HERE / "arms.blend"
GLB = ROOT / "assets" / "models" / "arms" / "arms.glb"
DEFAULT_BLENDER = r"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe"


def run(blend: pathlib.Path | None, *args: str, script: str = "arms_bl.py") -> int:
    cmd = [os.environ.get("BLENDER", DEFAULT_BLENDER), "-b", "--factory-startup"]
    if blend is not None:
        cmd.append(str(blend))
    cmd += ["--python", str(HERE / script), "--"] + list(args)
    p = subprocess.run(cmd, capture_output=True, text=True, errors="replace")
    out = p.stdout + p.stderr
    print("\n".join(out.splitlines()[-25:]))
    bad = "Traceback" in out or "Error:" in out or "Error: Python" in out
    return 1 if p.returncode or bad else 0


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
    if cmd == "import-baked" and rest:
        return run(BLEND, "import-baked", str(pathlib.Path(rest[0]).resolve()),
                   *(["force"] if force else []))
    if cmd == "build":
        return run(BLEND, "build")
    if cmd == "preview" and rest:
        out = pathlib.Path(rest[0]).resolve()
        return run(BLEND, "preview", str(out))
    if cmd == "hunt" and len(rest) == 2:
        return run(None, str(pathlib.Path(rest[0]).resolve()), str(pathlib.Path(rest[1]).resolve()),
                   script="arms_hunt_bl.py")
    if cmd == "prove":
        return prove(pathlib.Path(rest[0]).resolve() if rest else None)
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
