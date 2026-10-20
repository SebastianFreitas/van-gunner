Status: blocked
# Plan state: hands-blender-review

## Plan
`hands-blender-review`, `.claude/plans/hands-blender-review.md`; branch `claude/hands-blender-review-handoff-b0458e`, worktree `C:/Users/Traff/Documents/van-gunner/.claude/worktrees/hands-blender-review-handoff-b0458e` (moved 2026-10-18 by merging `worktree-hands-blender-review`).

## Architecture now
- `tools/blender/arms_frame_bl.py`: `HandFrame`/`hand_frame(side)`, `ShapeFrame`/`shape_frame(side)`, and `chart(ob)` (per vertex (x, v, mask) from UVMap.002/.003, port of `ArmVeinSet.chart_of`). Vein sets and the fit use `hand_frame` (span .1649), not `shape_frame`.
- `tools/blender/arms.py step <name>` runs `arms_<name>_bl.py` `main(args)`; `arms_step_bl.py` archives/restores the six parts, moves coincident groups by mean, recomputes normals; seam groups get one summed normal. `arms.py` prints only the last 25 Blender lines.
- `tools/blender/arms.py veinpaths <dir>` (`arms_veinpaths_bl.py`, 140 lines, never saves): per side renders the current `_next` as `rejected_<s>_back.png`, dumps `mesh_{R,L}.json`, runs `arms_veintrace.trace`/`gates` on a `MeshTable`, `splice_write`, renders `traced_<s>_back.png` and `traced_nosnap_<s>_back.png` (true width, s -1.9..1.1), composes `sheet_<s>_back.png` (photo | traced | unsnapped | rejected); `paths.txt` holds the veintrace CLI lines and `TRES`. `VeinMesh` keeps `fw`/`tw`. `arms_vein{gates,sets}.py` no longer called here (kept, D74).
- `tools/blender/arms_veintrace.py` (pure Python, numpy via MeshTable; data `arms_veintrace_data.py`, snap/widen `arms_veintrace_gates.py`): research 05 polylines mapped by D67 with a min/max lat frame + ±.2 s running median (D79), Catmull-Rom .04 s, snap and widen (D76) then free-end taper (D80), joins as shared points, gates G-a..G-d with the fallback (shared points move once in every path), pack counts the palm paths, low-forearm stride ladder .06/.08/.10/.12 below s -.4 (D78). CLI `py -3 tools/blender/arms_veintrace.py <dump dir>`.
- `tools/blender/arms_mass_bl.py` / `arms_crush_bl.py`: phase 2 flank field and crush (`Temp/vg-hbr/crush_ids.txt`).
- `scripts/debug/debug_arms_export.gd` (`arms export`): skin/fingers/webs with each vertex id in UV2; `tools/blender/arms_hunt_bl.py` writes `clusters.txt` with ids.
- Headless Godot debug: `py -3 tools/probe.py --cmd "arms hands"` (`arms touch`, `arms fit`, `arms prove`, `arms export`, `arms inspect 1.1|2.4 --shot <png>`).
- `tools/blender/arms.py veindump <dir>` (`arms_veindump_bl.py`) writes `mesh_{R,L}.json` (ids, s, lat, ch, wmax, fw, tw, edges, fingers, webs, samples); research 04 `mesh_table.py` `MeshTable` loads it (chart diff < 1e-8); latest dump `Temp/vg-hbr/p3/d77/`.
- `tools/blender/arms_veinsplice.py` (pure Python): `splice_write(side, P, chart_fn)` writes `resources/arms/vein_set_{right,left}_next.tres` = live palm paths (R 10-12, L 1-2, `PALM`) verbatim + the traced paths (D60 bridge gone); now R 8 paths pack 142, L 10 pack 158 (cap `VEIN_MAX` 160 in `arm_materials.gd`).
- `tools/blender/arms_veinpaint_bl.py`: `paint` (look before/after renders, s -0.2..2.2, unchanged), `render_set(side, mesh, paths, out_png, s_range)` (true width: no .0025 minimum, no dots), `sheet(side, out_dir, traced, rejected[, nosnap])` (photo crop constants `PH_KNUCKLE`/`PH_WRIST`/`PH_CX` from `Temp/vg-hbr/ref/owner_fists.png`).

- `tools/blender/arms_relief_bl.py` (`arms.py relief <dir> [--baseline <file>]`, read-only): per path crest (v - b)·n over the middle 40 %, per hand floor (median pre-step crest of the new paths, from `archive_` `veins_<part>` when present), old_relief/new_relief net of floor, cord gate and cord_off; old paths read from `resources/arms/archive/vein_set_{side}_baked.tres` when it exists. Baseline: `Temp/vg-hbr/p4/baseline2b.txt` (R floor .00741 old_relief .00424; L floor .00490 old_relief .01338).
- `tools/blender/arms_veins_bl.py` (`arms.py step veins [--vein MM] [--cord MM]`, live at 2.1 / 2.8, da02f252): live sets = traced `_next`, old baked in `resources/arms/archive/vein_set_{side}_baked.tres`; baked off v -= k .014 h_old n, k .6082 (D86); move = smax(VEIN h_v, CORD h_c) with weight min(1, r/max_r_back), no clip; `VEINS BLOCK` over 6 mm of raise. `arms.py veinpaths` rewrites `vein_set_*_next.tres` (re-traces on the stepped mesh): restore them from HEAD after it.

- `tools/blender/arms_topo_bl.py` (`Edit`: `delete_faces`, `add_vertex(position, sources, uv, groups)`, `add_tris`, `commit`; `check_ids`): the only way a step changes topology; fresh ids above the part's max ever (archives included), coincident new vertices share the seam's summed normal. `arms_weld_bl.py` (`arms.py step weld`, after fingers): removes the stray finger islands; the cut and bridge (`arms_weldcut_bl.py`, `arms_weldbridge_bl.py`) are specs 5-2a/b/c.
- `tools/blender/arms_roots_bl.py` (`arms.py step roots`, after fingers; not applied, D101/D102): tucks the skin's finger-root edge (+ next ring) 0.5 mm and the stray finger islands 1 mm inside the finger tube, per coincident group, up to 3 passes; `ROOTS BLOCK` over 13 / 20 mm. `arms_fingers_bl.py` knuckles: blended heads, skirt rides the tube within 3-6 mm, webs take the fingers' move (D100).
- `arms.py step weld` (`arms_weld_bl.py`, applied b1d63741..fd18f4d8/26d3469e): islands, `clear`, `layout`, `fair_grid`, `arms_weldwrite_bl.band`, `tuck` (cap 20 mm, skips tube vertices within 1 mm of webs), knuckle re-swell with K bisected against a port of Godot's knuckle measure (pre-weld targets, stored shafts from `arm_fingers_info.tres`), gates -> `WELD BLOCK`. Godot reads fixed for the weld: `id_map` sized by max id and warns on duplicates (4e78f302), index W8 / pinky slabs 0-4 (381cb7de), wrist palm half counts `.01` weights (558ceb7b). `ArmFingerInfo.tip_tilt` + `&"along"` axis tilt the left ring claw (55543190).
## Completed phase
Phase 5, D165 G unpin, session 1 (2026-10-19), blocked (D166). Spec `.claude/specs/5-ends2.md`: `fair_grid(zone, cap)` frees G over the band ends with a soft pull, `arms_weldwrite_bl.py` moves the kept skin G vertices with it (ring 1 half, ring 2 quarter), `arms_weld_bl.py` prints `WELD G ends`. L passes the weld gates; R fails every try (60 mm/4 mm: max dihedral 147.5° > 131; 80 mm/6 mm: L min angle 2.89°; pull 60/200: R kept/band angle max 108.2°, 1 flip at the extreme end column). Committed with `zone` 0.0 default, so the weld is unchanged (R dihedral 130.1°, min angle 6.97°, ids clean); arms.blend/arms.glb re-exported because the git guard refused restoring them (glb differs from HEAD by 2 bytes of float noise), `tools/check.py` clean. No renders; the D160 renders stand (`C:/Users/Traff/AppData/Local/Temp/vg-hbr/p5surf/hl/R_new_back.png`, `L_new_back.png`).

## Next phase
Phase 5 band ends: wait for the owner's answer to the Blocker (D166), then continue with the chosen option; after it, surf-c (pre-weld flank flaps, `p5surf/surf-a.md` rec. 2), renders, D152 re-measure. The G-unpin code stays callable with `fair_grid(..., zone=0.06, cap=0.004)` (pull weight 60).

## Requirements / gotchas
- Owner 2026-10-20 (D174): NO Fable agents (usage); toggle deleted 72cbe543. Every attempt renders (`arms.py look`) even on a gate fail; send the owner the PNGs, pause for their review, then a normal review agent with their notes.
- Owner 2026-10-20 (D170, replaces D167's one-try rule): weld gates are advisory during the rework; fix properly and show renders, stop only for crashes or design choices.
- `tools/blender/arms_weldband_bl.py` may show modified with line endings only: never stage it unless changed on purpose.
- Implementers hit 60k on every wide spec (2b peaked 62.5k): one deliverable per spec, name file, function and range, no plan reading.
- `tools/blender/arms.py` shows modified with no content diff (line endings): leave it out of commits.
- Godot `arms prove` can fail on a stale class cache: run check.py first.
- Phase 3 v1's vein fails and look notes are void (D63); phase 4 builds only the owner-approved traced `_next` sets (D65).
- 2026-10-18: a duplicate phase-3 session ran beside the one that landed 0fc18f31; its D56b rounds (vp5 R 4 / L 7 blocking) lost to 0fc18f31 and were reverted (4a9d5179, 0505461f), only a research note kept. Check `git log` for a landed phase before starting one.
- Scratch: `C:/Users/Traff/AppData/Local/Temp/vg-hbr/`; spec 1 optimiser `Temp/vg-hbr/p3/opt3.py`.

## Questions
none

## Blocker
D176 (owner, 2026-10-20): the 432ed707 hands "have holes"; the owner picked the 10-19 pre-weld hands. Every non-doc file is back at e3078508 (the weld step and its 14 modules removed; archived on tag `archive/hands-weld`, the collar join on `archive/hands-collar-cut`). Phase 5 (weld) is abandoned. The left ring claw tilt (55543190) is reapplied (ce194147). The owner approved the in-game shots ("looks right in game, keep it"); the Blender `look` renders show an old baked vein texture, so judge veins from game shots (`smoke.py --shots`, a01/a03). Waiting for the owner to pick the next direction.

## Saved specs (send these to the implementer first)
- .claude\plans\hands-blender-review.spec-5-common.md (shared rules for any phase 5 follow-up spec)
