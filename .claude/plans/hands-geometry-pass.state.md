Status: blocked
# Plan state: hands-geometry-pass

## Plan

`hands-geometry-pass`, `.claude/plans/hands-geometry-pass.md`; branch `claude/focused-pare-31d54c`, worktree `C:/Users/Traff/Documents/van-gunner/.claude/worktrees/interactable-visual-effect-6ccd9b`.

## Architecture now

- `tools/hand_crops.py`: six fixed boxes (fingertips, knuckles, claws x4; lhand x2; wrist_side x4; curled 640x480 x1). Never move.
- `scripts/player/arms/arm_finger_profile.gd`, `arm_finger_ring.gd`, `arm_finger_web.gd`, `ArmKnuckles.apply` (meta `knuckle_rise`); `arm_fingers.gd` 300 lines; `ArmRig.horn_length`.
- `arm_bulk.gd`: WRIST_END_GAIN 1.30; new `HAND_GROW_END` 0.95 (DEF-hand and DEF-palm ease over 0.95 of the bone; thumb keeps HAND_RAMP_END 0.45); per-vert offset for hand/palm bones goes through `ArmHandDome.offset`.
- New `arm_hand_dome.gd` (`ArmHandDome`, static): `axes`, `offset`; DORSAL_K 0.80, PALM_K 0.95.
- `arm_weight_smooth.gd` unchanged (relax_seam built 40898dde, reverted 97626a99).
- `debug_arms_hands.gd`: `_wrist` banded; `_shape` prints `growth`/`mono`/`jump`/`dome`/`palm_depth` unbanded.

## Completed phase

Phase 4c · built, **blocked** on its own rows (ded0351a, 6ca4f190, 40898dde + revert 97626a99, b3f0988c).
- `py -3 tools/check.py` CHECK CLEAN; `py -3 tools/smoke.py` SMOKE CLEAN, HANDS OK (the shape rows are unbanded, so HANDS OK does not cover them).
- Rows R / L: growth 0.075 .080 .086 .093 .100 .101 .104 .098 .094 / 0.060 .073 .081 .091 .098 .101 .104 .098 .094; mono false / false; jump 3.18 / 3.04 (bar 1.6; 4b 4.75 / 3.33); dome 0.379 / 0.352 (band 0.35..0.40, 4b 0.437 / 0.405); palm_depth 0.486 / 0.499 (in band); wrist_step 0.000 / 0.036; wrist/palm 0.819 / 0.789; knuckle 0.37 0.39 0.41 0.36.
- Fallbacks taken (D46, D47): HAND_GROW_END 0.80 → 0.95; relax_seam made rows worse, reverted; DORSAL_K 0.70 → 0.75 → 0.80.
- Crops `after4b` vs `after4c` (`crops4c`): fingertips 8697, knuckles 7029, claws 4423, lhand 11988, wrist_side 1814, curled 14889 (noise floor 502 / 340 / 3983 / 1755 / 1182 / 4231).
- `smoke.py --shots shots4c` vs `shots4b`: back 02 0.608, 05 3.273, 08 0.695, 11 0.613 (same); a01..a18 same (max a13 0.300 at tol 1.0); moved: a19-arms-inspect 1.195 (tol 0.068), 01-idle-front 0.200, 07-elevator-stop-front 0.295.
- Not blessed (rows fail; Constraints bless only once rows pass).
- look-judge (advisory, D43) on lhand/knuckles: FAIL wrist, growth, dome ("still a round bulb; flattening a few pixels"), `p4c-look.md`.
- **Owner views for the supervisor to send:** `C:/Users/Traff/AppData/Local/Temp/vg-hands-pass/insp4c/back.png` and `insp4c/palm.png` beside `insp4b/back.png` and `insp4b/palm.png`; PROBE CLEAN. Reports in the same folder: `p4c-A-report.md`, `p4c-A2-report.md`, `p4c-B-report.md`, `p4c-verify.md`, `p4c-look.md`.

## Next phase

Paused (D49) until the arms model's Blender pass lands (palm width grows smoothly from the wrist, wrist seam smoothed). On resume, first actions: band `dome` and `palm_depth` in `debug_arms_hands.gd`, keep `growth` print-only unless it passes after the Blender pass, bless (`py -3 tools/smoke.py --bless`, say so), then phase 5 · Density (`### Phase 5`).

## Requirements / gotchas

- Run `py -3 tools/check.py` before `tools/hand_shots.py` (import cache).
- `wrist_side` cannot judge the wrist (gun covers it); use `lhand`. The `knuckles` crop holds no wrist or dome.
- Phase 3's facet look (D32) is out of scope.
- Implementers hit their 60k line on measurement work: one file, one function per spec; a separate general-purpose agent runs shots and probes.
- Gains and seam weights do not move the hand-side width profile (D37, D46); only vertex positions or the glb mesh do.
- Crop px counts carry render noise up to the floor above.
- 4c's a19-inspect moved 1.195: the a-views move on purpose once 4c is accepted; re-bless then.

## Questions

none

## Blocker

Paused by the owner (D49, 2026-10-17): the palm and wrist get fixed in Blender first. A `go` here checks the Blender pass has landed (`git log main` for the arms model commit) before restarting the run at phase 5.
