# arms-blender-source

Stage: ready
Started: 2026-10-17
Procedure: `.claude/skills/plan/interview.md` (the interview), then `run.md` (state in `.claude/plans/arms-blender-source.state.md` while running).
Path: full (D13 turned the fix into a new look: monster hand)
Size: at most 26 KB (8 phases, D27), each phase at most 2.5 KB (interview.md "Plan size")
Interview: A, B and C done · 26 asked · ready gate passed (round 1 D38-D51, round 2 the last, no leftovers; last question: park missed questions) · missed: bake the skin with the engine or by hand (D52); how many hunt close-ups to render (D53); whether the glb's weights are mirrored left to right, not only its mesh (D55); where in code the L hand's weights stop mirroring (D56); a seam window measured against real vertex spacing (D57); whether the hand ramps to the knuckle row or peaks mid-palm, measured density-independently (D59); whether a Blender edit survives the game's procedural build before planning mesh edits in Blender (D61); recompute f from the fixed probe's rows (D58)
Questions: ask

## Brief (owner's words, verbatim)

/plan new arms-blender-source: give the goblin arms model a Blender source inside van-gunner and fix the palm and wrist there.

Background (from the session that started this one): The owner (van-gunner, Godot 4.7 first-person roguelite) spent plan hands-geometry-pass (branch claude/focused-pare-31d54c) reshaping the goblin viewmodel hands from GDScript. Phases 1-4c landed on that branch, but four look checks failed: the hand's width profile and the wrist seam come from the glb mesh itself, which code gains can't reach. The owner chose to fix the model in Blender, with the source and scripts living inside van-gunner and exporting straight to assets/models/arms/arms.glb. The hands plan is paused before phase 5 (D49) until this lands. Owner's taste: the hands are one fixed design (posture untouchable, nails stay, improve not remove); removed art is archived, never deleted; the look-judge can't see hand geometry, so the owner judges large views. The owner's words on the problem: "The hand specially from the top of it not the under part looks funny. Probably because this model was small and then we make the hand bigger ... it felt like a balloon ... Instead of that slow growth from wrist up it feel like suddenly has a different width. And the palm and other side are very round. But the palm isn't that bad."

What to build (the plan's interview settles the details with the owner):
- Blender 5.2.2 LTS is installed under `C:/Program Files/Blender Foundation/` (the 5.2 folder; an older 4.3 folder there does not run). Claude drives it headless: `blender.exe -b <file> --python <script>`.
- Today the arms are only `assets/models/arms/arms.glb` (loaded in `scripts/player/arms/arm_rig.gd`), with no `.blend` source. Add a source file plus a few scripts in this repo (say `tools/blender/`): import the glb into a `.blend`, apply edits by script, export back to `assets/models/arms/arms.glb`, and render fixed-camera previews (back of hand, palm, wrist side) as PNGs in the scratchpad for the owner to judge. Ask the owner whether the `.blend` goes in git as-is or via Git LFS.
- First fix: the hand jumps wide right at the wrist (about 3x the smooth rate) and narrows again before the finger roots; it should widen smoothly from the wrist girth to the knuckle row. The back of the hand should be a low, broad dome, not a balloon (the model was small and was scaled up); the palm gets only a slight trim. Smooth the skin weights at the forearm/hand seam (palm.01-.04, DEF-hand, forearm.001).
- The game reshapes the hand at runtime: `ArmBulk.inflate` gains, `HAND_GROW_END`, `ArmHandDome` (`arm_hand_dome.gd`), `ArmWristRamp` (`arm_wrist_ramp.gd`), and the fingers are built in code (`arm_fingers.gd`, `ArmFingerProfile`). Decide with the owner what gets baked into the mesh and what stays in code, so the code doesn't undo the Blender fix.
- Measure with the existing `arms hands` rows in `scripts/debug/debug_arms_hands.gd` (`growth` mono/jump, `dome`, `palm_depth`, `wrist_step`, `wrist/palm`; current numbers are in `.claude/plans/hands-geometry-pass.state.md` "Completed phase"). Owner views: `tools/probe.py --cmd "arms inspect 1.1" --shot ...` (back) and `"arms inspect 2.4"` (palm).
- Done when the hand widens smoothly out of the wrist in those views and the rows pass, the game loads the new glb with check and smoke clean, and the owner has approved the look.

New goal (owner, verbatim, D13): "i think before you do anything you should review the model on blenmder and make a new fix plan based on that, knowning the goal, super buffed up monster hand, creepy with tendons and veins super salient,corkced fucked up finegrs , like a witch"

## Pass test (what "done" means; judged by the owner and named commands)

- Brief (verbatim): "the hand widens smoothly out of the wrist in those views and the rows pass, the game loads the new glb with check and smoke clean, and the owner has approved the look."
- The owner must be able to say, in `arms inspect 1.1` (back) and `2.4` (palm) (both the left hand) and the play view `a09` (D46), beside today's `C:/Users/Traff/AppData/Local/Temp/vg-arms-blender/review/game/{back,palm}.png`: (1) "the proportions look right": today's size, widening smoothly from the wrist to the knuckle row, no balloon; (2) "tendons and veins jump out at a glance"; (3) "the fingers are crooked and gnarled like a witch's", claws as long as today, grip unchanged; (4) "no small buggy-looking imperfections" in close views.
- Commands: `arms hands` HANDS OK plus the bands phases 4-6 set; `py -3 tools/check.py` CHECK CLEAN; `py -3 tools/smoke.py` SMOKE CLEAN. Blender previews are shape checks only.

## Scope

- In: `tools/blender/` (phases 1-2); `arms.glb`, `.gitattributes`, the arms `LICENSE.md`; `ArmHandDome` (neutral); `ArmVeinField`, `ArmVeinSet`, `ArmVeinRelief`, `arm_vein.gdshaderinc`, new `ArmVeinCords`, `arm_bulk.gd`'s relief call; `ArmSkinFolds`; `ArmFingerProfile`, `ArmFingerRing`, `ArmFingers`, new `ArmFingerBend`; the left-wrist step (phase 3); new `debug_arms_export.gd` and its hook; the `k2/r1` bar; each hunt defect's source file (`arm_claw.gd`, `arm_refine.gd` included); `art-arms.md`; the hands plan's bands; `gen_context.py`. `arm_surface.gdshader` (400 lines) only through an include.
- Out, stays exactly as is (code: except a hunt defect or the left-wrist fix): the 48 bones and rests, posture and grip (`ArmRig`); the hand's overall size; hand and finger length; forearm thickness; claw length, curve and colour; the gun; `HAND_SCALE`, `HAND_GROW_END` 0.95, `ArmWristRamp`, `ArmKnuckles`, `ArmMuscle`; mesh names `ArmL`/`ArmR`, UVs, no materials, no animations (`arm_rig.gd:17`); no texture images; every fingertip pole within 0.002 of its `tip_off`.

## Initial idea

A creepy monster hand at today's size with its proportions fixed, cords and veins standing out and witch's fingers, same grip on the same gun. Pieces (owner: "That is it", D30): 1 Blender source and round trip (phase 1); 2 defect hunt on the built hands (2, 3, 7); 3 proportion audit (4); 4 four raised cords (5); 5 reshaped veins (5); 6 zig-zag fingers (6); 7 the hands plan resumes (7); 8 the owner's look (8).

## Walk-through

- Pieces 1-8 · That is it; piece 3 became a proportion audit at today's size, shown again: That is it · D28-D30

## Current state (2026-10-17 at 35348bd8; grep the names)

- This checkout holds the hands plan's phases 1-4c, so landing this branch lands them too.
- The glb: `ArmR` 369 verts, hand 69 (too coarse for cords or veins as mesh); every monster trait on screen is code-made at load; `ArmL` is `ArmR`'s exact x-mirror, so every L/R difference is code (digest `research/arms-blender-source-01-monster.md`).
- `growth`, `dome`, `palm_depth` are text rows (`_shape`, unbanded in HANDS OK): phases 4-7 band them.
- Earlier `missed:` (hands-geometry-pass): a buff or a cord is checked by a row and the owner's view, never a row alone.

## Open items

- none

## Decisions

- D13-D51 are folded where `(D<n>)` marks (D38-D51: ready gate).
- D52 (auto, phase 2): `arms export` bakes each part to a static world-space mesh; `bake_mesh_from_current_skeleton_pose` refuses these skins, so the export CPU-skins (bone pose x bind x weights), checked by the hunt's `claw_gap` lines (posed vs rest within 0.0005).
- D53 (auto, phase 2): hunt close-ups only for the 8 worst clusters per kind per file (3 angles); every cluster stays in hunt.txt.
- D54 (auto, phase 3): D6/D7 carry to phase 7: the D6 "holes" are `ArmFingerWeb.build`'s open top row (ring 3, SAG 0, a 2-edge free fin edge between tubes still apart, arm_finger_web.gd), so no winding or index fix closes them without a shape change (skip, weld or drop the top row); the 1e-5 inside-out patches are the near-degenerate top quads; D7 is the same non-manifold strip flipping Blender's recalc. Phase 7 decides: hunt lists the top edge as expected, or the web top is welded within the band.
- D55 (owner, phase 3 blocker): the narrow left wrist is the source glb's unmirrored thumb/palm weights at the wrist, not a code step (`research/arms-blender-source-03-wrist.md`), so D49's wrist fix moves into phase 4's spec 1 (seam weights in Blender): mirror R's wrist and thumb-root weights (DEF-thumb.01 / DEF-palm.01 near the wrist) onto ArmL, then measure L W0 against R's .075 within 0.005 as D49 says; still short, stop with the table. Phase 3 has nothing left (spec 2 settled by D54) and closes without code.
- D56 (owner, phase 4 blocker): D55's premise is false (the glb's L weights already equal R's mirror, `research/arms-blender-source-04-audit.md`; `wrist_mirror` stays off). The left-wrist fix goes back to code, D49's original path: a short diagnosis finds which `ArmBulk.inflate` step turns the mirrored glb weights unmirrored on the L hand (start with `ArmRefine`, whose off-toggle moved L and R differently; also rule out `_shape`'s dominant-bone pick in debug_arms_hands.gd as a measuring artefact) and fixes it at that source, then L W0 within 0.005 of R's .075 (D49); still short, stop with the table. Then phase 4 carries on from spec 1 step 2.
- D57 (owner, phase 4): spec 1's `seam_smooth` step is skipped (its 0.06 forearm-length window selects no vertex, and both hands already meet its pass line: `wrist_step` R .000, L .036, both <= 0.05).
- D58 (auto, phase 4): keep the probe fix of D56 (side-symmetric hand-plus-palm share, L W0 .074 vs R .075; R's growth rows moved up to .008 as the old pick mis-measured them too) and recompute spec 1's width f from the new R rows (T unchanged): 1 .924 .878 .855 .831 .887 .856 .909 1.
- D59 (owner, phase 4 width blocker): the width target is re-derived from the fixed probe's rows (`Temp/vg-p4/hands_wrist.txt`, `research/arms-blender-source-04-audit.md` "Width"). First make the probe's slab width density-independent (e.g. a 95th-percentile lateral offset over vertices sampled once per face area, so slab vertex count no longer moves it) and re-measure. Then the target T ramps from W0 to the measured mid-palm peak (W6/W7, about .105), the knuckle row W8 is held and may taper, `mono` is checked on slabs 0..7 only, `jump` is measured on that ramp, and the step only slims the mid-hand bulge (W4/W6), widening nothing. Still short of the bars, stop with the table.
- D60 (auto, phase 4): D59's ramp ends at the measured W7 (T_k = W0 + (W7-W0)(1-(1-k/7)^1.5), k 0..7; f_k = min(1, T_k/W_k), f8 = 1), so the knuckle side is never widened and mono on 0..7 is reachable; the probe's p95 rows put the peak at W5 .115, not W6/W7.
- D61 (owner, phase 4 width blocker, 2026-10-17): the plan is parked. Owner's words: "We need to take a step back. And review our game vs blender make sure it works well. The game has a lot of procedurally generated shit. That's most likely the culprit. Put the current plan on the bank. And try to make sure of this. So that we can actually work on blender properly." A Blender edit to the source verts lands only about half after `ArmBulk`/`ArmRefine` inflate the hand, so the game's procedural steps decide the shape, not the Blender mesh. No phase runs until a game-vs-Blender review makes Blender edits land as made; then the width question is asked again on the new pipeline.
- D62 (owner, phase 4): L's slab 1 dip under W0 (.077 vs .079, the thumb root) is fixed, not just listed: slab 1 at least as wide as W0 on both hands.

## Constraints (every phase)

- Order: this plan runs first; the hands plan stays paused before its phase 5 (D2, D17).
- One design: every glb edit is made once from `ArmR`'s numbers and mirrored in x to `ArmL` (D3); the vein sets stay per arm (`art-arms.md`).
- What may move in the glb (D4): only vertices whose largest weight is `DEF-hand`, a `DEF-palm` bone or `DEF-forearm.*.001`, and their weights among those bones; bones, rests, UVs and names stay; joint names and bind matrices unchanged within 2e-5.
- Mesh vs code (D21): the mesh holds the hand's mass; `ArmHandDome` is neutral; cords and veins are code relief; fingers are code; Scope's Out stays.
- Style (D18): creepy, stylised, still low-poly; exaggerated cartoon-scale veins and cords, not real anatomy.
- Claws (D16, D33): length, curve and colour stay (`claw_len` rows unchanged); a hunt defect in `arm_claw.gd` or `arm_refine.gd` is fixed here; claw root and density stay the hands plan's.
- Blender runs only headless through `py -3 tools/blender/arms.py`; nobody Reads a `.blend` or `.glb` (file-guard).
- Specs name under Read first `.claude/rules/art-arms.md`, `art-arms-pose.md` and `art-style.md` (CLAUDE.md invariant 15).
- Look stops (D37, D9): pictures go to the owner after every phase, never a stop (phase 1 `arms.py preview`, phases 2-7 `<scratch>/insp<phase>/{back,palm}.png`); no look proof phase or look-judge in phases 1-7 (blind on hand geometry, memory). The owner judges everything at phase 8, the one look stop; else the run stops only when a phase's numbers fail after its fallback.
- Monster dial (D36, medium first try): veins and cords twice today's height (phase 5), fingers kink 15 degrees and knuckles about 8 % bigger (phase 6).
- `arms touch` (`debug_arms_touch.gd`): every phase's output equal to phase 1's (the grip stays).
- Run: `Questions: ask` (owner, ready gate): a question the plan missed parks its phase for the owner; a fallback that fires is recorded as `D<n> (auto)`.
- Slab frame (as `_shape`, `debug_arms_hands.gd:103-182`): head = `DEF-hand`'s rest head; axis = head to `DEF-f_middle.01`'s head; s = axial distance over span (s 0 wrist, 1 knuckle row); lat = index to pinky `.01` heads less the axis part; dorsal = up less the axis part.

## Progress

| # | Phase | Kind | Needs | Rests on | Status |
|---|---|---|---|---|---|
| 1 | Blender tooling and identity export | code | - | D5-D8, D10 | done d640f2a2 |
| 2 | Defect hunt tool, first hunt | code | 1 | D26 | done 50653bb2 |
| 3 | Left wrist, hunt fixes at their source | code | 2 | D16, D26, D33, D49 | done 42afaff4 (no code: wrist moved to phase 4 by D55, hunt fixes carried by D54) |
| 4 | Proportion audit, the hand's mass in Blender | code | 3 | D21, D28, D29, D34, D49 | parked (D61: game-vs-Blender review first; probe p95 e77a28c1, width step off) |
| 5 | Round loud veins, four raised cords | code | 4 | D21-D23, D31 | todo |
| 6 | Zig-zag fingers, knotted knuckles | code | 3 | D15, D24, D32 | todo |
| 7 | Second hunt, docs, the hands plan's bands | code + doc | 5, 6 | D17, D26 | todo |
| 8 | The owner's look | review | 7 | D9, D37 | todo |

## Phases

### Phase 1 · Blender tooling and identity export (code, 1 spec, 2 on the fallback)

Read to design: `research/arms-blender-source-00-intake.md`, `arm_rig.gd:1-40`.
- `tools/blender/.gdignore` (Godot imports any `.blend` under `res://`, D6); `.gitattributes` gains `*.blend binary` and `*.glb binary`.
- `arms.py` (stdlib runner): `C:/Program Files/Blender Foundation/Blender 5.2/blender.exe` (env `BLENDER` overrides) with `-b --factory-startup [<blend>] --python <script> -- <args>`, prints the tail, fails on a traceback. `import`: the CC0 glb to `arms.blend` (rig, `ArmL`, `ArmR`, plus a hidden, never-exported copy in collection `cc0`; the importer's `Icosphere` deleted). `build`: rebuild `ArmL`/`ArmR` from `cc0`, apply `arms_edit_bl.py`, save compressed, export. `preview <dir>`.
- `arms_edit_bl.py`: the edit numbers in one table at its top, every step off this phase. Builds start from `cc0`, so they never compound.
- Export (D6): GLB to `assets/models/arms/arms.glb`, rig and both meshes only, no materials, animations, morph targets or extras, deform bones only, Y up, normals, UVs, skins.
- Previews (D7): Workbench, orthographic, the right hand framed on its `cc0` bounds from the back, the palm and the wrist side, 800 px, `cc0` left and current right in one PNG, `<dir>/{back,palm,side}.png`, scratchpad, shape checks only.
- Before the glb changes: tag `archive/arms-glb-cc0` on HEAD (D8). `arms.blend` committed plainly, compressed, about 144 KB (D10).
Identity check (D5; Blender may reorder vertices, joints and nodes): rows and `py -3 tools/shots.py capture glb-before` on the CC0 glb; `arms.py build` with no edits; rows and `capture glb-id`; `compare glb-before glb-id`. Pass: every row equal to the printed digits, every `a*` view `same`. Fallback (spec 2): `tools/blender/glb_patch.py` writes the export's positions, normals, joints and weights into the CC0 glb's buffers in its own vertex order (matched by position within 1e-5 and UV, joints by name) and `build` exports through it; check again.
Verification (implementer): the identity check; CHECK, SMOKE CLEAN; `arms.py preview` writes three PNGs.
Reviewed: Right (D35)

### Phase 2 · Defect hunt tool, first hunt (code, 2 specs; piece 2)

Read to design: `debug_arms_commands.gd:214-240`, `arms.py`.
Owner (D26): "the hands have many issues like tiny weird buggy looking stuff ... its up to you to find these": the hunt looks at the hands as the game builds them, not the raw glb.
- Spec 1: `scripts/debug/debug_arms_export.gd`, `arms export <path.glb> [rest]`: both hands' skin, finger tubes and claws as built, posed (default) or in bind pose (`rest`: a defect seen only posed is a weight one), through `GLTFDocument.append_from_scene` and `write_to_filesystem`, one object per part (`R_skin`, `R_claw_index`, ...). `debug_arms_commands.gd` stays <= 400 lines (fold two one-line branches into a lookup). Fallback when the file loses the pose or skin: CPU-skin each vertex (global pose x inverse bind, weighted) and write the same objects as OBJ.
- Spec 2: `arms_hunt_bl.py` and `arms.py hunt <file> <dir>`: per object, one line per defect cluster in `<dir>/hunt.txt` (kind, object, nearest bone, slab s, count, worst value): inside-out (winding against `recalc_face_normals` outside, memory), slivers (smallest angle under 3 deg, or longest over shortest edge above 15), spikes (a vertex more than 0.6 x its mean ring edge off its ring's plane), creases (skin dihedral above 75 deg; claws excepted), holes (boundary loops other than the forearm cut and the tube roots, listed once as expected), coincident faces. Renders each cluster close up from 3 angles plus 12 orbit views per hand (Workbench, backface culling on, 800 px) into `<dir>`.
- Run: `py -3 tools/probe.py --cmd "arms inspect 1.1" --cmd "arms export <scratch>/hunt2/posed.glb"`, the same with `rest`, `arms.py hunt` on both. The session writes `research/arms-blender-source-02-hunt.md`, one line per defect: what, where, the step making it (object, rest vs posed, nearness to a vein, knuckle ridge or refine ring), its source file.
Verification (implementer): CHECK and SMOKE CLEAN; `hunt.txt` for both files; a planted copy (3 faces flipped, 1 vertex moved 1.5 x its mean ring edge along its normal, the spike rule's own units, D38) reports both; HANDS rows unchanged. The manager sends the owner the list and its close-ups.
Reviewed: Right (D35)
Notes: done 89a388e0, 66cf90f0, 50653bb2; triage `.claude/plans/research/arms-blender-source-02-hunt.md` (7 real defects D1-D7 of that file, 8 rule false positives); rules kept as written, false positives left for phase 7's rule pass.

### Phase 3 · Left wrist, hunt fixes at their source (code, at most 2 specs; piece 2)

Read to design: `research/arms-blender-source-02-hunt.md`, the range of the source file with the most defects.
- Spec 1, the left wrist (D49: "fixes the code step that narrows it; both hands 1.6 or less"; inspect beats 2-3 show the left hand, `art-arms-pose.md`): L W0 .060 against R .075 (`wrist_step` .036 / .000) is code-made (the glb is mirrored). Measure `arms hands` growth with each load step (`ArmBulk.inflate`'s steps, the vein relief) off in turn (temporary toggle); the step that narrows L is fixed at its source so L W0 rises to R's .075 within 0.005; R is never narrowed (its rows as phase 2's, D39). L `wrist_step` reported (phase 4 bars it).
- Spec 2: the hunt file with the most defects. A defect made by a file a later phase rewrites waits for that phase (the glb mass: 4; the vein profile and relief: 5; `arm_fingers.gd`: 6), named in that phase's report; other files' defects carry to phase 7 (Carry forward).
- A fix changes the step that makes the defect, never a smoothing pass over it afterwards; claws as Constraints (D16, D33).
Verification (implementer): `arms.py hunt` on new posed and rest exports: each fixed defect's count 0 and no kind's count higher anywhere; `arms hands` rows equal to phase 2's except the ones a fix names, which stay in their bands (unbanded `growth`, `dome`, `palm_depth`: within +-0.02 of phase 2's, `jump` +-0.1, D39; spec 1's L rows excepted); CHECK and SMOKE CLEAN; `insp3` views. Fallback: a hunt fix that moves a row out of its band is reverted and its defect carried to phase 7 with the reason; spec 1 short of 0.005, or the only differing step widens R (a vein crown on R's slab-0 edge is about .015): stop with its table (D49: R's mirrored f leaves L from .060 at `jump` about 2.7).
Reviewed: Right (D35)

### Phase 4 · Proportion audit, the hand's mass in Blender (code, 2 specs; piece 3)

Read to design: `debug_arms_hands.gd:103-267`, `arms_edit_bl.py`.
Today's size (D28). Off (D29, D34): breaks the smooth widening to the knuckle row (the widest) or the low broad back; thumb base and other L/R differences listed, never forced. Today R / L (hands 4c; recompute T, f from phase 3's rows if W0 moved): W0..8 .075 .080 .086 .093 .100 .101 .104 .098 .094 / .060 .073 .081 .091 .098 .101 .104 .098 .094, `jump` 3.18 / 3.04, `dome` .379 / .352, `palm_depth` .486 / .499, `wrist_step` .000 / .036, `wrist/palm` .819 / .789.
1. Seam weights (spec 1): vertices mostly on `DEF-forearm.*.001`, `DEF-hand` or a palm bone within 0.06 forearm lengths of the head (2x `wrist_step`'s window): Smooth Vertex Weights on those bones, factor 0.5, 2 repeats, limit 4, normalise. `wrist_step` <= 0.05 both, else factor 0.25, 1 repeat, else none.
2. Width (spec 1, D29): T_k = W0 + (W8 - W0)(1 - (1 - k/8)^1.5), k 0..6; T7 = W8/0.99 - 0.0005 (the `mono` ceiling, slabs 7-8 being the knuckle row; keeps `wrist/palm` under 0.85); T8 = W8. R: T .075 .0785 .0817 .0846 .0873 .0896 .0916 .0945 .094, f_k = T_k/W_k 1 .981 .950 .910 .873 .887 .881 .964 1 (mid-hand ~12 % slimmer, roots unmoved), `jump` 1.45, `mono` true. Movable vertices at s 0..1: lat offset x f(s), linear between slabs; area-weighted normals on them and their one-ring. L: mirrored f (D3); phase 3 lifted L's W0 to R's, so L has R's bars (D49).
3. Back and palm (spec 2): `ArmHandDome.DORSAL_K`, `PALM_K` (0.80, 0.95) to 1.0, file and call kept, `##` line: the mesh holds the dome. Blender: dorsal offsets x d(s), palm offsets x p(s): 1 at s 0, smoothstep to m at 0.375, held to 0.625, smoothstep to 0.80 (d) / 0.95 (p) at 0.875 on. Neutral predicts dome .543 / .504, pd .586 / .602: m_d 0.716 (dome .389 / .361, 10 % lower) and m_p 0.830 (pd .486 / .499).
Writes `research/arms-blender-source-04-audit.md` (off numbers before/after, unreachable list); the owner's line with `insp4` (D48): slimmer by design (D28), buff in phases 5-6.
Verification (implementer): R and L `mono` true, `jump` <= 1.6; `wrist/palm` 0.70..0.85; `knuckle` 0.35..0.48; `dome` 0.35..0.40; `palm_depth` within 0.02 of the prediction; `tip_off` within 0.002; CHECK, SMOKE CLEAN; preview; `insp4`. Fallback once (D40), all measured on R (D3): m_d, m_p x band middle over measured; f_k x T_k over measured W_k per slab; `wrist/palm` over 0.85: f7 raised toward 1 until under; either hand still out, stop.
Reviewed: Right (D35)

### Phase 5 · Round loud veins, four raised cords (code, 2 specs; pieces 4, 5)

Read to design: `arm_vein_field.gd:31-60`, `arm_skin_folds.gd:34-100`.
- Spec 1 (D23 "the veins where there already just not very well shaped"; D31): the existing paths stay, each arm its own. The cross-section in `ArmVeinField.sample` and `arm_vein.gdshaderinc:61` becomes (1 - q^2)^2 with q = d / (F r), F 2.26 (D50: sqrt 2 x today's 1.6 as the height doubles; 3.2 keeps today's shape): zero slope at its edge (today's sqrt meets the skin at a crease); half-height half-width 0.541 F r = 1.22 r (today 0.866 r). `NEAR` = F x `MAX_R` + 0.002 = 0.0156. Ends: `FADE_LEN` 0.012 to 0.024, end radius share 0.4 to 0.25 (`pack`). Louder (D36, twice today's height): `RELIEF_M` 0.014 to 0.028 (`arm_vein_relief.gd:9`); the vein shading (`vein_shade`, `vein_under` 1.8, `arm_materials.gd:39-40`) stays. The relief cache key gains a profile version (it hashes constants only).
- Spec 2 (D22): new `ArmVeinCords` (RefCounted), one shared set: four paths from `ArmSkinFolds`' tendon ends, wrist lerp 0.15 toward each `.01` head, to that head, in chart space as the vein sets (`art-arms.md`: x, 0.035 atan2(z, y)); 3 points, radius `MAX_R` (height 1, the field's cap: wider clips flat), crown `RELIEF_M` 0.028 (D36); both ends free. Added only to a copy of the arm's set before `ArmVeinRelief.apply` (`arm_bulk.gd:279`), never to the shader's `vein_pts` (D42: teal tint, groove and crest, `arm_surface.gdshader:228-235`; cords are tendons, lit by `tendon_light`), which keeps the vein set alone (cap 160, `arm_vein.gdshaderinc:3`). The tendon shading moves onto the cords, half-width (rest space; today `TENDON_HALF` x fr, `arm_skin_folds.gd:59`) = F x `MAX_R` x rho / 0.035, rho = |CUSTOM0 (y, z)| at the skin vertex nearest the cord's middle (D41); the implementer prints old and new per cord.
- Neighbour cords at the knuckles at least 2F x `MAX_R` = 0.027 apart in chart v; else that pair's radius = spacing / 2F.
Verification (implementer): hunt: creases and spikes on vein and cord paths 0; `dome` rises by the cords' crown (reported; new band: that value +-0.02); every other row in phase 4's bands (not its values); CHECK, SMOKE CLEAN; `insp5` to the owner. Fallback: a crease or spike left on a path carries to phase 7's hunt (Carry forward) with its source; a width band broken where a vein or cord point lies within `NEAR` (0.0156) of that slab's lateral edge: the point moves inward until it is `NEAR` inside; still out, stop.
Reviewed: Right (D35)

### Phase 6 · Zig-zag fingers, knotted knuckles (code, 2 specs; piece 6)

Read to design: `arm_fingers.gd:101-275`, `arm_finger_profile.gd:16-36,123-146`.
- Spec 1 (D15): `arm_fingers.gd` (400 lines) splits into its core and `ArmFingerBend` (RefCounted: `_crook`, `_bend_g`, the ring centre placement); output identical (every `arms hands` row equal, `shots.py compare` `same` against a capture before).
- Spec 2 (D24; D32 "each zig-zag their own way", D43): lateral shift z, a = 15 deg (D36) x index 1.0, middle 0.7, ring 0.85, pinky 1.15. Kink at `.02` (index, ring, pinky): z = 0 on bone 1, tan(a) x t x L2 on bone 2, tan(a) x (L2 - t x L3) on bone 3. Kink at `.03` (middle): z = 0 on bones 1-2, tan(a) x t x L3 on bone 3. Signs: index and middle toward the thumb, pinky away, ring toward the middle (the one gap that narrows, middle-ring on bone 2, held by `gap2`). L mirrors R. The lean lands the pole: `bend_k` = (`tip_off` - z at the pole) / g at the pole. Knuckles (D36 +8 %, D51): half swelling, `DIGITS` `knob` 1.22-1.28 + 0.05 = 1.27, 1.29, 1.31, 1.33 (`arm_finger_profile.gd:19-35`, both hands; 1.4 read as balls, `:137`), half sharper joint knots, `KNOT` 0.32 to 0.40 (`arm_finger_ring.gd:9`; `art-arms.md`: knots, never round blobs); root `k[1]` 1.0 stays (`ArmKnuckles`); bar `k2/r1` <= 0.97 (`debug_arms_hands.gd:299`) to <= 1.01 (largest: middle 1.29 x 0.78 = 1.006, D44). Thumb, no zig-zag: `k[2]` 1.05 to 1.09, `k[3]` 1.22 to 1.27 (`:132`, `:145`).
Verification (implementer): HANDS OK; `tip_off` within 0.002; `gap2` >= -0.31 / -0.20, `gap3` >= -0.15 / 0.0; `claw_len` unchanged; `arms fit` FIT OK (else the thumb's knobs back to 1.05 / 1.22, D44); hunt on the tubes: 0 new; CHECK, SMOKE CLEAN; `insp6` to the owner. Fallback once: a failing pair's factors x 0.6; still failing, the finger whose kink closes that gap flips its sign (middle-ring: ring away from the thumb; index-middle: middle away; ring-pinky: pinky toward).
Reviewed: Right (D35)

### Phase 7 · Second hunt, docs, the hands plan's bands (code + doc, at most 2 specs; pieces 2, 7)

- The phase 2 hunt on the finished hands, posed and rest; every defect found or carried is fixed at its source (phase 3's rules), at most 2 specs; what is left is listed, with where, for the owner's look. No third hunt.
- `LICENSE.md` gains: edited in Blender from `tools/blender/arms.blend` (`arms.py build`), the CC0 original at tag `archive/arms-glb-cc0` (D8). `art-arms.md`: the Blender source, `ArmHandDome` neutral, cords are relief-only vein paths, the vein profile, the zig-zag; it replaces "tendons are shading only" (cords are raised relief, `ArmSkinFolds` shades them) and the stale knob and knot numbers (as built: `DIGITS`, thumb, `KNOT`, `KNOT_SPARSE`) (D45); its `paths:` gain `arm_hand_dome.gd`, `arm_wrist_ramp.gd`, `arm_vein_cords.gd`, `tools/blender/**`. Then `py -3 tools/gen_context.py`.
- Hands plan (D17), `hands-geometry-pass.md`: its `dome`, `palm_depth`, `knuckle` and `growth` bands from this phase's rows (value +-0.02; growth: `mono` and `jump` <= value + 0.1); its claw phases 5-6 start from this plan's `arm_claw.gd` and `arm_refine.gd`; it resumes at its phase 5 only after phase 8's yes (D47).
Verification (implementer): hunt counts 0 or listed; HANDS OK and phases 4-6 bands; CHECK, SMOKE CLEAN; `insp7` to the owner.
Reviewed: Right (D35)

### Phase 8 · The owner's look (review; piece 8)

- Implementer: HANDS OK and every band; CHECK and SMOKE CLEAN (no `--bless`: the hands are not in the fingerprint, so a diff there fails); `arms.py preview <scratch>/blender`; `insp8` back and palm; `py -3 tools/shots.py capture final` (the play view `a09-arms-gunfront-boons`, D46).
- Stop, the run's one (D9, D37): the manager shows the owner `insp8` beside today's `review/game/{back,palm}.png` and `final`'s `a09` beside phase 1's `glb-before` `a09` (D46), phase 4's unreachable list and phase 7's leftovers, and asks the four Pass test statements; the look-judge is advisory. A yes resumes the hands plan at its phase 5 (D47). A no names what changes: the run adds a phase that re-runs the phase owning it (pieces, D30: proportions 4; the dial, stronger or softer (D36), veins, cords, fingers 5 and/or 6; a named defect 7's hunt rules), then phase 7's band step and this look again (D47).
Reviewed: Right (D35)

## Carry forward

- Defects deferred by phase 3 to phase 7: D6 finger web root holes and tiny inside-out patches, D7 L ring tube inside out (rest), both `arm_finger_web.gd` top row (D54).
- Defects owned by later phases (phase 3 triage, `research/arms-blender-source-02-hunt.md`): D2 right palm crush (glb palm weights under the curl, dome sculpt) and D5 glb fingertip shards (`TIP_CORE`, the glb .03 skin) to phase 4 (the glb mass, `ArmHandDome`); D1 elbow fold (glb elbow weights) to phase 4's weight pass if in reach, else 7; D3 vein seam cracks (`ArmVeinRelief._split` keys edges by index, arm_vein_relief.gd:198-282) to phase 5; D4 finger joint folds (`ArmFingers._ring_weights`) to phase 6.
