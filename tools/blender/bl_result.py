"""Result file for the *_bl.py entry points: arms.py passes `--result <json>` after `--`.

`args()` returns the script's own arguments with that pair removed; `write()` stores
{"ok", "command", "errors", ...numbers} for the runner. No file means the run failed.
"""
import json
import sys

_path = None


def args() -> list:
    global _path
    a = sys.argv[sys.argv.index("--") + 1:]
    if "--result" in a:
        i = a.index("--result")
        _path = a[i + 1]
        a = a[:i] + a[i + 2:]
    return a


def write(command: str, ok: bool = True, errors: list | None = None, **numbers) -> None:
    if _path is None:
        return
    data = {"ok": ok, "command": command, "errors": errors or []}
    data.update(numbers)
    with open(_path, "w", encoding="utf-8") as f:
        json.dump(data, f)


def check_names() -> None:
    """Fail with the missing names (in the result JSON) if the open blend lacks an arm_names entry."""
    import bpy
    import arm_names as N
    miss = [n for n in (N.RIG,) + N.PARTS if n not in bpy.data.objects]
    rig = bpy.data.objects.get(N.RIG)
    bones = rig.data.bones if rig else {}
    for side in "LR":
        want = [N.VG_HAND, N.VG_PALM1] + [N.VG_THUMB_FMT % i for i in (1, 2, 3)]
        want += [N.VG_FING_FMT % (f, i) for f in N.FINGERS for i in (1, 2, 3)]
        miss += ["bone " + n + "." + side for n in want if n + "." + side not in bones]
        skin = bpy.data.objects.get(side + N.SKIN)
        if skin is None:
            continue
        groups = skin.vertex_groups
        miss += ["group %s on %s" % (n + "." + side, skin.name)
                 for n in want if n + "." + side not in groups]
        miss += ["uv %s on %s" % (u, skin.name) for u in (N.UV_A, N.UV_B) if u not in skin.data.uv_layers]
    if miss:
        write("names", ok=False, errors=["missing: " + n for n in miss])
        raise SystemExit("arm_names: missing " + ", ".join(miss))
