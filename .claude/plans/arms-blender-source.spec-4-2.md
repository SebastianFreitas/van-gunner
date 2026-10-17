# Spec p4-2 · Arms glb: back and palm depth in the mesh, ArmHandDome neutral (plan arms-blender-source phase 4, spec 2)

Intent: the mesh holds the hand's dome; the code dome goes neutral. Spec p4-1 already added `wrist_mirror`, `seam_smooth`, `width` steps to `tools/blender/arms_edit_bl.py`; add one more after them. Do not commit; report.

Read first: `.claude/rules/art-arms.md`, `art-arms-pose.md`, `art-style.md`; `tools/blender/arms_edit_bl.py` (the slab frame helpers p4-1 wrote); `scripts/player/arms/arm_hand_dome.gd` (`DORSAL_K` :5, `PALM_K` :6; called from `arm_bulk.gd:223`, `:269`); `scripts/debug/debug_arms_hands.gd:103-182` (`dome`, `palm_depth`: slab 4's dorsal / palmar maxima over W4); `.claude/plans/research/arms-blender-source-04-audit.md`.

1. `arm_hand_dome.gd`: `DORSAL_K` 0.80 -> 1.0 and `PALM_K` 0.95 -> 1.0; file and calls kept; add a `##` line saying the mesh holds the dome (arms glb, `tools/blender/arms_edit_bl.py` `depth` step), so this stays neutral.
2. `depth` step in `arms_edit_bl.py` (same movable set and frame as `width`, s in [0,1], both arms, mirrored per D3): a vertex's dorsal offset (positive dorsal) x d(s), its palmar offset (negative dorsal) x p(s). Profile g(s; m, end): 1 at s 0, smoothstep to m at s 0.375, held to 0.625, smoothstep to `end` at 0.875, held after. d = g(m_d 0.716, end 0.80), p = g(m_p 0.830, end 0.95). Normals on moved verts and one-ring as `width` does.
3. Rebuild `py -3 tools/blender/arms.py build`, measure `py -3 tools/probe.py --cmd "arms hands"` (to `C:/Users/Traff/AppData/Local/Temp/vg-p4/hands_depth.txt`).

Targets: `dome` 0.35..0.40 both (predicted .389 R / .361 L); `palm_depth` within 0.02 of .486 R / .499 L; plus p4-1's still hold: `mono` true, `jump` <= 1.6, `wrist/palm` 0.70..0.85, `knuckle` 0.35..0.48. Fallback once (D40, measured on R, applied to both): m_d x= 0.375 / measured R dome; m_p x= 0.486 / measured R palm_depth. Still out: stop and report the table.

Constraints: as p4-1 (bones, rests, UVs, names, vertex counts, binds within 2e-5; only the movable set; `tip_off` within 0.002 and `claw_len` unchanged vs `C:/Users/Traff/AppData/Local/Temp/vg-p1/hands_after.txt`). Never Read .glb/.blend/.png except the two insp shots below, once each.

Acceptance (once, on the finished change; report numbers): targets above, HANDS OK; `arms touch` equal to `C:/Users/Traff/AppData/Local/Temp/vg-p1/touch_after.txt`; `py -3 tools/check.py` CHECK CLEAN; `py -3 tools/smoke.py` SMOKE CLEAN (any fingerprint drift from the glb: report it, do not bless); `py -3 tools/blender/arms.py preview C:/Users/Traff/AppData/Local/Temp/vg-p4/preview2`; insp4 shots `py -3 tools/probe.py --cmd "arms inspect 1.1" --shot C:/Users/Traff/AppData/Local/Temp/vg-p4/insp4/back.png` and the same with `2.4` -> `palm.png`, one line each on what they show (look for dents, spikes, see-through faces).

Deliverable also: append to `.claude/plans/research/arms-blender-source-04-audit.md` the `depth` step's rows (after), which fallbacks fired, an "unreachable" list (any off-row from D29/D34 left out, e.g. thumb base and other L/R differences, listed never forced), and the owner's line: "insp4: slimmer by design (D28), buff in phases 5-6". Report: numbers, table, changed paths.
