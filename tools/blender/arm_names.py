"""Every name the arms scripts share: parts, rig vertex groups, UV maps and scratch paths.

Constants only. A rename in the blend is a one-line fix here; bl_result.check_names() checks
each of them against the open blend at build/export time. `%s` is a finger name or a side.
"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
BLEND = os.path.join(HERE, "arms.blend")
GLB_OUT = os.environ.get("ARMS_GLB_OUT") or os.path.abspath(  # arms.py step --out sets it
    os.path.join(HERE, "..", "..", "assets", "models", "arms", "arms.glb"))


def photo_path() -> str:
    """The owner's fist photo (never in the repo): the file named by the ARMS_PHOTO env var."""
    p = os.environ.get("ARMS_PHOTO")
    if not p or not os.path.isfile(p):
        raise SystemExit("Error: set the ARMS_PHOTO env var to the owner's fist photo (owner_fists.png)")
    return p

RIG = "rig"
MESHES = ("ArmL", "ArmR")
SKIN, FINGERS_PART, WEBS = "_skin", "_fingers", "_webs"  # after the side letter: "R_skin"
PARTS = tuple(s + p for s in "LR" for p in (SKIN, FINGERS_PART, WEBS))

FINGERS = ("index", "middle", "ring", "pinky")
VG_HAND = "DEF-hand"  # + "." + side
VG_PALM = "DEF-palm"  # prefix of DEF-palm.01 ...
VG_PALM1 = "DEF-palm.01"
VG_FOREARM = "DEF-forearm"  # prefix of the DEF-forearm...001 end bones
VG_THUMB = "DEF-thumb"  # prefix, + ".0N.<side>"
VG_THUMB1 = "DEF-thumb.01"
VG_FING = "DEF-f_"  # prefix of every finger bone
VG_FING_FMT = "DEF-f_%s.0%d"  # (finger, joint), + "." + side
VG_FING_ROOT = "DEF-f_%s.01"
VG_FING_TIP = "DEF-f_%s.03"
VG_THUMB_FMT = "DEF-thumb.0%d"
VG_INDEX1 = "DEF-f_index.01"
VG_MIDDLE1 = "DEF-f_middle.01"
VG_PINKY1 = "DEF-f_pinky.01"

UV_A = "UVMap.002"  # chart u, v of the first pair
UV_B = "UVMap.003"  # chart u, v of the second pair

