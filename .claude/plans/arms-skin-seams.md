# arms-skin-seams

Stage: planning
Started: 2026-10-11
Procedure: `.claude/skills/plan/interview.md` (the interview), then `run.md` (state in `.claude/plans/<name>.state.md` while running).
Path: light (one area: the first-person arm mesh and skin shader; a fix pass, no new design) (from Brief)
Size: at most 20 KB (10 KB on the light path), each phase at most 2.5 KB (interview.md "Plan size")
Interview: A open · 0 asked (intake written, 4 questions out)   <- A/B/C open or done, running total; missed: lines while running
Questions: ask   <- or auto: phase questions never defer, the recommended option is taken (run.md "Phase questions")

## Brief (owner's words, verbatim)

do a whole plan dude, to make a pass on the 3d arms, theres soem texture thta seems kinda like they finsih on straight lines, the places where finegrs connect to the hand for example also look weird, there lines seperating it, instead of just being seamless skin

## Pass test (what "done" means; judged by the `look-judge` or a named command)

- Drafted from the Brief (asked in intake): (1) "seamless skin" where each finger meets the hand: no line, crease, colour step or shading edge at the finger roots, on both hands; (2) no skin pattern (veins, grime streaks, blotches, creases) "finishes on straight lines" anywhere on either arm: each fades out; (3) everything else reads as before (shape, tattoo, scars, nails, knots, colours).
- Judged on: `tools/hand_shots.py` views front, side, left, top in poses rest and weave, plus close-ups `arms cam orbit 0 70 0.2 left` and `right` (the wrist views `tools/stipple.py` meters), before and after; look-judge on (1) to (3); `tools/stipple.py` dark-pixel count on the close-ups not above before.

## Scope

- In: finger tubes and their join (`arm_fingers.gd`, `arm_skin_mesh.gd`, `arm_bulk.gd` finger core), vein mask and vein frame (`arm_muscle.gd`), knuckle creases (`arm_skin_folds.gd`), the skin shader (`scenes/player/arm_surface.gdshader` + `arm_skin_*.gdshaderinc`), `arms seam` (`debug_arms_seam.gd`) to measure finger roots.
- Out (stays exactly as is): poses and animation, gun, claws, dressing, tattoo text and placement, arm and finger shape outside the joins, materials of anything but skin.

## Current state (explored 2026-10-11; anchors drift, grep the names)

- Fingers are a separate mesh: `ArmFingers.build` (`arm_fingers.gd:32-72`) makes one `Skin_fingers` mesh per hand of five 8-sector tubes (`SECTORS` 8, `BONY_CORNER` 1.18 squared rings, `:6-9`), capped at the tip only (`_cap`, `:365`); the root ring starts a quarter bone inside the palm, open (`_root_profile`, `:239-245`, t -0.25). The glb's own fingers shrink to a hidden core: gain 1.0 to `FINGER_CORE` 0.55 over 0.10-0.35 of the `.01` bone, tips `TIP_CORE` 0.05 (`arm_bulk.gd:31-39, :247`). Nothing welds tube to palm: the join is where two surfaces cross, so the normal jumps there.
- Tube normals come from the tube's own faces (`ArmSkinMesh.build`, `arm_skin_mesh.gd:137-149`); the arm's are welded by position at 0.0001 (`ArmMuscle._normals`, `arm_muscle.gd:133-162`).
- Tubes get CUSTOM0 all zero (`arm_fingers.gd:69` passes an empty array, zero-filled at `arm_skin_mesh.gd:150-152`). CUSTOM0 is the vein frame (x along the arm, y z across, w vein mask), so on fingers: no veins (`vein_field` times `c.w`, `arm_surface.gdshader:206-240`) and the dirt streak noise is one constant (`sk_dirt`, `arm_skin_layers.gdshaderinc:157-172`), while the palm next to it has both.
- Vein mask is a hard per-vertex switch by dominant bone family (`ArmMuscle.MASK`, `arm_muscle.gd:19, :73-79`): forearm 1.0, hand 1.0, upper arm 0.6, palm, thumb and fingers 0. It steps across one triangle, so veins stop on mesh edges (hand to palm on the back of the hand, elbow 1.0 to 0.6). The limb tail is 1.0 against the upper arm's 0.6 (`arm_limb_tail.gd:57`).
- Knuckle creases sit on the join: `ArmSkinFolds.apply` puts 3 grooves at each `.01` head, reach 2.4 finger radii (`arm_skin_folds.gd:16, :64-66`), shade 0.8 (`FOLD_SHADE`), grooves are planes across the rest finger axis with a 0.25 gap wobble (`arm_skin_folds.gdshaderinc:30-53`).
- Not causes (checked): rest chart hand weight is 1.0 on tubes and palm alike (`arm_bulk.gd:269-306`); mottle, grain, knots and blights are triplanar on rest position, the same space on both meshes; `knot_height` searches far enough not to clip at cell edges (`arm_surface.gdshader:138-158`).
- Likely causes, ranked. Finger joins: 1 the tube crossing the palm (normal break), 2 the knuckle crease band on the root, 3 the CUSTOM0 step (veins and streaks stop at the root). Straight lines elsewhere: 1 the vein mask switch, 2 the dirt streaks stopping on the tubes, 3 the crease bands' ends, 4 8-sector tube facets.
- Tools: `arms seam` only measures the hand to forearm gap (`debug_arms_seam.gd:2`), nothing at finger roots. Elimination by turning one layer off and counting changed pixels in a crop is the precedent (`art-arms.md` "Thumb-root hump").
- Shots here: `xvfb-run` and Godot 4.7 exist; after `godot --headless --import` (20 s, the clone had no `.godot/imported`) a direct `xvfb-run ... probe_runner.tscn --probe-views=front` rendered (llvmpipe, OpenGL 3), but `tools/hand_shots.py` timed out twice at probe.py's 180 s cap. `py` is missing: use `python3`. Front view seen once: hands too small to judge the joins, use the close-ups.

## Open items

- intake questions: finger join fix, knuckle creases, vein ends, where else lines show (asked next)

## Decisions (while asking; folded into the phases in Part C; `(auto)` = taken while running)

- **D1 · Light path.** One area (arm mesh and skin shader), a fix pass with no new design (from Brief). Goes to: Constraints.

## Initial idea (full path, Part B; prose, beginning to end, as the owner experiences it)

<a page at most; every sentence rests on a D or the Brief; guesses carry [?] until asked>

### Piece 1 · <name>
<3 to 8 lines: what is on screen, what moves, what is read or heard, what the user does, in order>

## Walk-through (one line: the pieces were shown together)

- Pieces 1-<n> · <That is it / changed: ...> · D<n>

## Constraints (every phase)

- <rules that hold for the whole plan, including decisions several phases use (D<n>): invariants, art rules, perf, screenshots and baselines unchanged outside the phase's scope>

## Progress

| # | Phase | Kind | Needs | Rests on | Status |
|---|---|---|---|---|---|
| 1 | <name> | code | - | Brief | todo |
| 2 | <name> | code | 1 | D5 | todo |

Needs: earlier phases whose output it builds on. Rests on: decisions still in the list, or Brief. Status: todo, done <sha>, deferred Q<k>.

## Phases

### 1 · <name>
Research: <full path only, optional: topics and where things are, then "go past the list">.
Deliverable: <what it delivers, with the decisions it uses written in plain words (D<n>); every number with its working, check and fallback ("x = a (file:line) − b (file:line) = 0.3 cm. Check: ...; else ..."); only what cannot be known before building as "→ phase decides: measure X, then apply rule Y">. Files: <exact files / functions; at most two it reads to design>.
Verification: <exact commands from CLAUDE.md § Verify, and the screenshots that must change / stay the same; who runs each (implementer, reviewer, look-judge); look checks: "look-judge on <views>, FAIL stops the run">.
Reviewed: <the owner's answer to the phases question>
Notes: <filled when done: what changed, sha>

### 2 · <name>
…

## Carry forward

- <facts later phases need: names, numbers measured, screenshot set names>
