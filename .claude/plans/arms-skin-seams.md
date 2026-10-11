# arms-skin-seams

Stage: planning
Started: 2026-10-11
Procedure: `.claude/skills/plan/interview.md` (the interview), then `run.md` (state in `.claude/plans/<name>.state.md` while running).
Path: light (one area: the first-person arm mesh and skin shader; a fix pass, no new design) (from Brief)
Size: at most 20 KB (10 KB on the light path), each phase at most 2.5 KB (interview.md "Plan size")
Interview: A done · C done · 8 asked (light path)   <- A/B/C open or done, running total; missed: lines while running
Questions: ask   <- or auto: phase questions never defer, the recommended option is taken (run.md "Phase questions")

## Brief (owner's words, verbatim)

do a whole plan dude, to make a pass on the 3d arms, theres soem texture thta seems kinda like they finsih on straight lines, the places where finegrs connect to the hand for example also look weird, there lines seperating it, instead of just being seamless skin

## Pass test (what "done" means; judged by the `look-judge` or a named command)

- (1) "seamless skin" where each finger meets the hand: no line, colour step or shading edge at the finger roots, on both hands; the three knuckle-row creases stay as they are. (2) No skin pattern (veins, grime streaks, blotches) "finishes on straight lines" on either arm: veins fade out over the back of the hand before the knuckles and blend across the elbow; the palm's dirt streaks fade out just past each knuckle. (3) Everything else reads as before (shape, finger facets, creases, tattoo, scars, nails, knots, colours); the fingers are as clean as today.
- Judged on: `tools/hand_shots.py` views front, side, left, top, elbow in poses rest and weave, plus close-ups `arms cam orbit 0 70 0.2 left` and `right`, before and after; look-judge on (1) to (3); `tools/stipple.py` count on the close-ups not above before; `arms roots` numbers (phase 1) within the phases' limits.

## Scope

- In: two static helpers (vein frame, nearest skin point), the vein mask (`arm_muscle.gd`, the head list in `arm_bulk.gd`, `arm_limb_tail.gd` mask), finger tube roots (`arm_fingers.gd` call site plus a new helper), a new `arms roots` debug meter, a note in `.claude/rules/art-arms.md`.
- Out (stays exactly as is): knuckle creases (`arm_skin_folds.gd`, `arm_skin_folds.gdshaderinc`; owner), finger facet count (`SECTORS` 8; owner), finger and arm shape (no root flare; owner), the skin shaders, poses and animation, gun, claws, dressing, tattoo, materials of anything but skin.

## Current state (explored 2026-10-11; anchors drift, grep the names)

- `ArmFingers.build` (`arm_fingers.gd:32-72`, 377 lines: new code goes in a helper) builds `Skin_fingers`, five open 8-sector tubes per hand; the root ring sits at t -0.25 of the `.01` bone inside the palm (`_root_profile`; t 0 is the knob ring), radius `r[1]` = `GIRTH` 2.10 (`arms_builder.gd:192`) x the glb root radius. It passes no normals and no CUSTOM0, so `ArmSkinMesh.build` (`arm_skin_mesh.gd:127-152`) makes face normals and zero CUSTOM0; CUSTOM2 (rest normal) copies those normals.
- The tube crosses the palm surface with nothing welding them: the normal jumps there, and CUSTOM0 (vein frame x, y, z and mask w) steps from the palm's values to 0. `sk_dirt` (`arm_skin_layers.gdshaderinc:157-172`) draws lengthwise streaks from CUSTOM0 y, z (x 64); with y = z = 0 the fingers get one flat streak value, which is today's clean look.
- Vein frame and mask: `ArmMuscle.apply` (`arm_muscle.gd:71-79`): origin `DEF-upper_arm` head, axis to `DEF-hand` head, u toward the thumb; xyz is the vertex position in that frame; w is `MASK` of the dominant bone (forearm 1.0, hand 1.0, upper arm 0.6, others 0), a full step inside one triangle. `heads` holds only upper_arm, forearm, hand, thumb.01 (`arm_bulk.gd:147`). Limb tail w is 1.0 (`arm_limb_tail.gd:57`) against the upper arm's 0.6. The arm mesh is the low-poly glb subdivided once (`arm_refine.gd` `LEVELS := 1`).
- Debug: `arms seam` (`debug_arms_seam.gd`, wired in `debug_arms_commands.gd:213`, hint in `debug_arms_hints.gd:25`) only measures the wrist. `tools/probe.py --cmd "<arms line>"` runs a console line headless.

## Open items

- none

## Decisions (while asking; folded into the phases in Part C; `(auto)` = taken while running)

- none

## Initial idea

Initial idea skipped (light path).

## Constraints (every phase)

- Light path, a fix pass: no new look, only the lines go (owner). Knuckle creases, `SECTORS` and every shape stay exactly as they are (owner); nothing outside Scope In changes.
- Names used below: x_w = `DEF-hand` head on the vein axis, L = mean of the four `DEF-f_*.01` heads on the axis minus x_w, x_e = `DEF-forearm` head on the axis, Lu = x_e minus the upper-arm head; e_h, e_e = the edge extents phase 1 prints.
- Shots in this cloud container: no `py`, use `python3`. Once per checkout run `godot --headless --import` (about 20 s). Run `tools/hand_shots.py` and `tools/probe.py --shot` with `--timeout 600` (the 180 s default timed out twice; they use `xvfb-run`, llvmpipe). If a view still gives no PNG: one direct `xvfb-run` probe per view; if that fails too, the phase reports the look check as "not taken: <reason>" and passes on its numbers, and the owner judges the views in Try at the end.
- Before set: `.godot/shots/arms-before/` (gitignored, kept) from phase 1; every after set goes to `.godot/shots/arms-p<k>/`. Never read a picture in the phase session; the look-judge reads them.
- Verify (implementer): `python3 tools/check.py`, `python3 tools/smoke.py`; the reviewer reads specs and diffs as run.md says.

## Progress

| # | Phase | Kind | Needs | Rests on | Status |
|---|---|---|---|---|---|
| 1 | Root meter and before shots | code | - | Brief | todo |
| 2 | Fade the vein mask | code | 1 | Brief | todo |
| 3 | Blend the finger roots | code | 1, 2 | Brief | todo |

## Phases

### 1 · Root meter and before shots
Deliverable: two static helpers, then a read-only meter. (a) `ArmMuscle.frame(heads)` returns origin and axes, and `ArmMuscle.apply` uses it (CUSTOM0 unchanged; smoke fingerprint unchanged). (b) New `scripts/player/arms/arm_skin_nearest.gd` (RefCounted, static): nearest point on the arm mesh in bind space, its triangle normal n_p and height s = (v - p) . n_p, searching only triangles with a vertex within 2 `r[1]` of the finger's root ring centre. (c) Console line `arms roots` (new `scripts/debug/debug_arms_roots.gd`, wired like `seam` in `debug_arms_commands.gd` and `debug_arms_hints.gd`, under 200 lines), per hand: per finger over the crossing (tube vertices with |s| at most 0.05 `r[1]`, thumb `r[2]`): max angle (deg) between the tube normal and n_p, max |CUSTOM0 xyz - frame formula at the vertex's own position|, max tube w, max palm w at p, and the largest t of a crossing vertex on its root bone (thumb `.02`); for the arm mesh: max w step over edges split into hand (x past x_w), elbow (within 0.25 Lu of x_e) and rest; max w past x_w + 0.65 L; e_h = the longest hand-region edge extent along the axis as a share of L; e_e = the same within 0.25 Lu of x_e as a share of Lu; and, once phase 3 exists, its build ms per hand. Then the before set: hand_shots rest and weave, views front, side, left, top, elbow, and the two close-ups, into `.godot/shots/arms-before/`, plus `stipple.py` on the close-ups.
Verification: implementer runs check, smoke, `python3 tools/probe.py --cmd "arms roots"` and records every number and the stipple counts in Carry forward (expected: angles tens of degrees, hand step 1.0). No look check (nothing visible changes).
Reviewed: Right (owner, phases question)
Notes:

### 2 · Fade the vein mask
Read first: `.claude/rules/art-style.md`, `.claude/rules/art-arms.md`.
Deliverable: veins fade out over the back of the hand and never reach the knuckles, with no hard stop on a mesh edge; the elbow step blends (owner). In `ArmMuscle.apply`: w = sum of weight x `MASK[family]` over a vertex's bones divided by the weight sum, times h = 1 - smoothstep(b - W, b, x), x = CUSTOM0 x, b = x_w + 0.65 L, W = max(0.40 L, 6 e_h) but at most 0.65 L (add the `DEF-f_*.01` heads to the list in `arm_bulk.gd:147`). Limb tail w 1.0 to 0.6 (`arm_limb_tail.gd:57`, it continues the upper arm; from code).
Math: the steepest smoothstep slope is 1.5 / W, so a hand edge of extent e_h steps w by up to 1.5 e_h / W; W = 6 e_h keeps that at 0.25. Hand bar = max(0.25, 1.5 e_h / W): e_h 0.10 L gives W 0.60 L, bar 0.25; e_h 0.20 L gives W 0.65 L (the cap), bar 0.46. Over 0.25 is accepted there because a vertex value ramps linearly across each triangle (no line); the look-judge decides "no hard stop".
Check: `arms roots` hand step within the hand bar, elbow step at most 0.25, w 0 past x_w + 0.65 L. Elbow over 0.25: w = lerp(0.6, 1.0, smoothstep(x_e - W_e/2, x_e + W_e/2, x)) on upper arm and forearm, W_e = max(0.24 Lu, 2.4 e_e) (step 0.6 e_e / W_e at most 0.25).
Verification: implementer runs check, smoke, `arms roots`, the after set into `.godot/shots/arms-p2/` and stipple (not above before). Look-judge on every view against Pass test (2) and (3) (veins only; the finger roots are phase 3's), FAIL stops the run.
Reviewed: Right (owner, phases question); moved before the root blend (both reviewers)
Notes:

### 3 · Blend the finger roots
Read first: `.claude/rules/art-style.md`, `.claude/rules/art-arms.md`.
Deliverable: the finger tubes keep today's shapes (no flare); each root is shaded into the palm skin without a line (owner). New `scripts/player/arms/arm_finger_root.gd` (RefCounted), called from `ArmFingers.build`, returns normals and CUSTOM0 for the tube vertices, passed to `ArmSkinMesh.build`; it times itself (`Time.get_ticks_usec`) per hand into a static that `arms roots` prints.
- Normals: on root rings (t at most 0.30 of `.01`; the thumb's two buried rings and head ring) take n_p and s from `ArmSkinNearest`; w = 1 - smoothstep(0, 0.5 x `r[1]`, max(s, 0)) (thumb `r[2]`); normal = normalize(w n_p + (1 - w) n_tube). Other rings keep face normals.
- CUSTOM0: xyz = f x frame formula at the vertex (the `ArmMuscle.frame` helper), f = 1 - smoothstep(t_c, t_c + 0.30, t), t_c = max(0, the phase 1 largest crossing t of that finger): the palm's streaks carry onto the root and fade out just past the knuckle, as a gradient; past t_c + 0.30 xyz is 0, as today, so the fingers stay as clean as now (owner). w = 0 (phase 2 already made the palm 0 there).
Check: `arms roots` crossing angle at most 10 degrees, xyz difference under 0.001, tube w and palm w at the crossing 0, both hands; build under 50 ms a hand (else nearest vertex instead of nearest triangle in `ArmSkinNearest`).
If the look-judge sees a root line: widen the normal blend to 1.0 x `r[1]` once and re-shoot; still seen, stop the run and report (no flare; owner).
Last: add a short paragraph to `.claude/rules/art-arms.md`: finger roots take the palm normal and vein frame over the buried rings, palm streaks fade out just past the knuckle, veins fade over b - W to b on the back of the hand and blend at the elbow, limb tail 0.6.
Verification: implementer runs check, smoke, `arms roots`, the full after set into `.godot/shots/arms-p3/`, stipple. Look-judge on every Pass test view against (1) to (3), FAIL stops the run; pictures go to the owner.
Reviewed: Right (owner, phases question); no flare, finger streaks fade past the knuckle (owner)
Notes:

## Carry forward

- <phase 1: every `arms roots` number (incl. e_h, e_e, t_c per finger) and stipple counts>
