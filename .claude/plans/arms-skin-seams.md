# arms-skin-seams

Stage: planning
Started: 2026-10-11
Procedure: `.claude/skills/plan/interview.md` (the interview), then `run.md` (state in `.claude/plans/<name>.state.md` while running).
Path: light (one area: the first-person arm mesh and skin shader; a fix pass, no new design) (from Brief)
Size: at most 20 KB (10 KB on the light path), each phase at most 2.5 KB (interview.md "Plan size")
Interview: C written, phases question next · 4 asked   <- A/B/C open or done, running total; missed: lines while running
Questions: ask   <- or auto: phase questions never defer, the recommended option is taken (run.md "Phase questions")

## Brief (owner's words, verbatim)

do a whole plan dude, to make a pass on the 3d arms, theres soem texture thta seems kinda like they finsih on straight lines, the places where finegrs connect to the hand for example also look weird, there lines seperating it, instead of just being seamless skin

## Pass test (what "done" means; judged by the `look-judge` or a named command)

- (1) "seamless skin" where each finger meets the hand: no line, colour step or shading edge at the finger roots, on both hands; the three knuckle-row creases stay as they are. (2) No skin pattern (veins, grime streaks, blotches) "finishes on straight lines" on either arm: veins fade out over the back of the hand before the knuckles and blend across the elbow. (3) Everything else reads as before (shape, finger facets, creases, tattoo, scars, nails, knots, colours).
- Judged on: `tools/hand_shots.py` views front, side, left, top, elbow in poses rest and weave, plus close-ups `arms cam orbit 0 70 0.2 left` and `right`, before and after; look-judge on (1) to (3); `tools/stipple.py` count on the close-ups not above before; `arms roots` numbers (phase 1) within the phases' limits.

## Scope

- In: finger tube roots (`arm_fingers.gd` call site plus a new helper), the vein mask and frame (`arm_muscle.gd`, the head list in `arm_bulk.gd`, `arm_limb_tail.gd` mask), a new `arms roots` debug meter.
- Out (stays exactly as is): knuckle creases (`arm_skin_folds.gd`, `arm_skin_folds.gdshaderinc`; D3), finger facet count (`SECTORS` 8; D5), the skin shaders, poses and animation, gun, claws, dressing, tattoo, finger and arm shape outside the root rings, materials of anything but skin.

## Current state (explored 2026-10-11; anchors drift, grep the names)

- `ArmFingers.build` (`arm_fingers.gd:32-72`, 377 lines: new code goes in a helper) builds `Skin_fingers`, five open 8-sector tubes per hand; the root ring sits at t -0.25 of the `.01` bone inside the palm (`_root_profile`), radius `r[1]` = `GIRTH` 2.10 (`arms_builder.gd:192`) x the glb root radius. It passes no normals and no CUSTOM0, so `ArmSkinMesh.build` (`arm_skin_mesh.gd:127-152`) makes face normals and zero CUSTOM0; CUSTOM2 (rest normal) copies those normals.
- The tube crosses the palm surface with nothing welding them: the normal jumps there, and CUSTOM0 (vein frame x, y, z and mask w) steps from the palm's values to 0, so streaks (`sk_dirt`, `arm_skin_layers.gdshaderinc:157-172`) change across the root.
- Vein frame and mask: `ArmMuscle.apply` (`arm_muscle.gd:71-79`): origin `DEF-upper_arm` head, axis to `DEF-hand` head, u toward the thumb; w is `MASK` of the dominant bone (forearm 1.0, hand 1.0, upper arm 0.6, others 0), a full step inside one triangle. `heads` holds only upper_arm, forearm, hand, thumb.01 (`arm_bulk.gd:147`). Limb tail w is 1.0 (`arm_limb_tail.gd:57`) against the upper arm's 0.6.
- Debug: `arms seam` (`debug_arms_seam.gd`, wired in `debug_arms_commands.gd:213`, hint in `debug_arms_hints.gd:25`) only measures the wrist. `tools/probe.py --cmd "<arms line>"` runs a console line headless.

## Open items

- none

## Decisions (while asking; folded into the phases in Part C; `(auto)` = taken while running)

- none (D1 to Constraints; D2 to phase 2; D3, D5 to Scope and phases 2, 3; D4 to phase 3)

## Initial idea

Initial idea skipped (light path).

## Constraints (every phase)

- Light path, a fix pass: no new look, only the lines go (D1). Knuckle creases and `SECTORS` stay exactly as they are (D3, D5); nothing outside Scope In changes.
- Shots in this cloud container: no `py`, use `python3`. Once per checkout run `godot --headless --import` (about 20 s). Run `tools/hand_shots.py` and `tools/probe.py --shot` with `--timeout 600` (the 180 s default timed out twice; they use `xvfb-run`, llvmpipe). If a view still gives no PNG: one direct `xvfb-run` probe per view; if that fails too, the phase reports the look check as "not taken: <reason>" and passes on its numbers, and the owner judges the views in Try at the end.
- Before set: `.godot/shots/arms-before/` (gitignored, kept) from phase 1; every after set goes to `.godot/shots/arms-p<k>/`. Never read a picture in the phase session; the look-judge reads them.
- Verify (implementer): `python3 tools/check.py`, `python3 tools/smoke.py`; the reviewer reads specs and diffs as run.md says.

## Progress

| # | Phase | Kind | Needs | Rests on | Status |
|---|---|---|---|---|---|
| 1 | Root meter and before shots | code | - | Brief | todo |
| 2 | Blend the finger roots | code | 1 | Brief | todo |
| 3 | Fade the vein mask | code | 1, 2 | Brief | todo |

## Phases

### 1 · Root meter and before shots
Deliverable: a console line `arms roots` (new `scripts/debug/debug_arms_roots.gd`, wired like `seam` in `debug_arms_commands.gd` and `debug_arms_hints.gd`) that prints per hand: per finger, the max angle (deg) between a `Skin_fingers` vertex normal and the arm mesh normal at its nearest arm vertex, over the crossing: tube vertices (bind-space mesh arrays) whose height above the nearest arm vertex along its normal is at most 0.25 of their distance to their finger's `.01` bone line (thumb `.02`); per finger, the max |CUSTOM0 w| and max |CUSTOM0 xyz| difference between those pairs; and for the arm mesh, the max vein-mask step |w_a - w_b| over its edges, split into hand (x past the hand head on the vein axis), elbow (within 0.25 upper-arm lengths of the forearm head) and rest, plus the max w past 0.65 of the wrist-to-knuckle span. Read only, under 200 lines. Then the before set: hand_shots rest and weave, views front, side, left, top, elbow, and the two close-ups, into `.godot/shots/arms-before/`, plus `stipple.py` on the close-ups. Files to design from: `debug_arms_seam.gd`, `arm_fingers.gd`.
Verification: implementer runs check, smoke, `python3 tools/probe.py --cmd "arms roots"` and records today's numbers and the stipple counts in Carry forward (expected: angles tens of degrees, hand step 1.0). No look check (nothing visible changes).
Reviewed:
Notes:

### 2 · Blend the finger roots
Deliverable: the finger tubes keep today's gnarled shapes; each root is smoothed into the palm skin and carries the palm's skin data, so shading runs across without a line (D2). New `scripts/player/arms/arm_finger_root.gd` (RefCounted), called from `ArmFingers.build`, returns normals and CUSTOM0 for the tube vertices, passed to `ArmSkinMesh.build`:
- Normals: for tube vertices on root rings (t at most 0.30 of `.01`; the thumb's two buried rings and head ring), find the nearest point on the arm mesh (bind space; only triangles with a vertex within 2 `r[1]` of the root ring centres; the thumb uses its `r[2]`) with its normal n_p and height s = (v - p) . n_p. Weight w = 1 - smoothstep(0, 0.5 x `r[1]`, max(s, 0)); normal = normalize(w n_p + (1 - w) n_tube). Other rings keep face normals.
- CUSTOM0: every tube vertex gets the arm's vein frame (same origin and axes as `ArmMuscle.apply`, from a static helper shared by both) for xyz; w = 0, because veins end before the knuckles (D4, phase 3).
Check: `arms roots` crossing angle at most 10 degrees, CUSTOM0 difference under 0.001, both hands; added build time under 50 ms a hand (else nearest vertex instead of nearest triangle). Fallback if the look-judge still sees a root line: flare root rings by radius x (1 + 0.15 w), recorded as D (auto).
Verification: implementer runs check, smoke, `arms roots`, the after set into `.godot/shots/arms-p2/` and stipple (not above before). Look-judge on close-ups and top, front, rest and weave against Pass test (1) and (3), FAIL stops the run.
Reviewed:
Notes:

### 3 · Fade the vein mask
Deliverable: veins fade out over the back of the hand and never reach the knuckles, with no hard stop on a mesh edge (D4); the elbow step blends (D5). In `ArmMuscle.apply`: w = sum of weight x `MASK[family]` over a vertex's bones divided by the weight sum, times h = 1 - smoothstep(x_w + 0.25 L, x_w + 0.65 L, x), where x is CUSTOM0 x, x_w the hand head on the axis, L the mean of the four `DEF-f_*.01` heads minus x_w (add those heads to the list in `arm_bulk.gd:147`). Limb tail w 1.0 to 0.6 (`arm_limb_tail.gd:57`, it continues the upper arm; from code).
Check: `arms roots` hand and elbow steps at most 0.25, w 0 past 0.65 L. Fallback: elbow over: w = lerp(0.6, 1.0, smoothstep(x_e - 0.12 Lu, x_e + 0.12 Lu, x)) on upper arm and forearm; hand over: start the fade at 0.10 L.
Verification: implementer runs check, smoke, `arms roots`, the full after set into `.godot/shots/arms-p3/`, stipple. Look-judge on every Pass test view against (1) to (3), FAIL stops the run; pictures go to the owner.
Reviewed:
Notes:

## Carry forward

- <phase 1: today's `arms roots` numbers and stipple counts>
