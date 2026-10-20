# hands-blender-review · 00 intake digest (2026-10-17)

Sources and what we take from each, in our own words. The five `arms-blender-source` digests (`arms-blender-source-00` to `-04`: Blender pipeline, mesh tooling, hand anatomy references, the hunt recipe, the old proportion targets) stand and are not repeated here.

## Sources

- **e837b305 (commit message) and `tools/blender/arms_bl.py`, `arms.py`.** The six hand parts are now loaded from `arms.blend` as is; `build` saves the blend and exports `arms.glb` (13.5 MB, no materials); `prove` moves 1937 dorsal vertices 4 mm and the game confirms them by vertex id (error < 0.0002, drift < 0.0001). We take: every shape change is a Blender edit, exported by `build`, confirmed by `prove`; run `tools/check.py` after a build before any probe.
- **Tag `archive/arms-procedural-build` and `scripts/player/arms/arm_rig.gd`.** The retired code (dome, knuckles, muscle, vein relief, finger rings, webs, wrist ramp; 2862 lines) is already baked into the glb. Still code at load: channels, material and shader, claws (rebuilt from tip rings by vertex id), limb tail, pose. We take: dome, knuckle heads, webs, relief, finger rings and kink and the wrist seam are Blender-only now; claws follow a fingertip edit for free; vertex ids must not change.
- **`arms_edit_bl.py`, `arms_hunt_bl.py`.** The old edit steps are off and target the archived 369-vertex arms; the hunt module has a backface-culled 800 px render and a `shoot(target, view, scale)` close-up. We take: the hunt renderer is the model for a per-phase look render; the old edit steps are not reused.
- **`scripts/debug/debug_arms_hands.gd`, `assets/models/arms/arm_fingers_info.tres`.** About half the `arms hands` rows read design constants from the tres rather than the mesh, so they cannot react to a Blender edit. We take: a phase rewrites the rows its edit would move to measure the mesh, drops the rest from HANDS OK, and re-bakes a tres value a mesh edit moves (plan D7).
- **`tools/smoke/smoke_shots.gd:252-287`, `tools/probe.py`, `tools/hand_crops.py`.** The smoke saves only `arms inspect 4.0`; `probe.py --cmd "arms inspect 1.1|2.4" --shot` gives the back and palm views; the hands are outside the fingerprint. We take: the per-phase Godot check (plan D8) and that smoke needs no bless for a hand change.
- **`.claude/rules/art-arms.md:24-45,135-137` and the memories (hands-one-fixed-design, improve-dont-reanimate, look-judge-blind-on-hands, archive-removed-art-not-delete).** We take: plan D4 (posture untouchable, one design, improve never remove, size stays, claws uncovered, owner judges large views) and D5's archive-before-edit rule.
- **Old plans `arms-blender-source` (D5-D8, D24, D36, D53, D59, D61, D62) and `hands-geometry-pass` (Pass test, D29, D33, D43, Carry forward).** We take: the edit mechanics (D5), the monster dial numbers (D9), the width-target options (Q1), the nail wording of the Pass test, the baselines in `Temp/vg-p1`, `vg-p4`, `vg-p2/hunt2` and `vg-arms-blender/review/game`.

## Not researched

No web research: the mesh is already dense along the vein paths (0.003 edges), so cords and knots are vertex displacement along normals with a smooth falloff in each hand's slab frame, the same operation the retired relief performed; and the render recipe exists in `arms_hunt_bl.py`.
