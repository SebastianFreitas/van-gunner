Status: phase-done
# Plan state: arms-skin-seams

## Plan
`arms-skin-seams`, `.claude/plans/arms-skin-seams.md`; branch `claude/plan-arms-skin-seams`, worktree `/home/user/van-gunner/.claude/worktrees/plan-arms-skin-seams`, cloud; PR https://github.com/SebastianFreitas/van-gunner/pull/22

## Architecture now
- `scripts/player/arms/arm_muscle.gd`: static `ArmMuscle.frame(heads)` / `frame_xyz(f, p)`; `apply` writes CUSTOM0 (vein mask fades, phase 2).
- `scripts/player/arms/arm_skin_nearest.gd` (`ArmSkinNearest`, static): `prefilter`, `nearest -> {p, n, s}`.
- `scripts/player/arms/arm_finger_root.gd` (`ArmFingerRoot`, new, 149 lines): `build` from `ArmFingers.build` (`arm_fingers.gd` 381 lines, collects `parts`, passes normals + CUSTOM0 into `ArmSkinMesh.build`). Palm-normal blend 0.5 x r[1] on rings t <= max(0.30, t_c), `SEARCH_T` 0.8; CUSTOM0 xyz lerps to c_f over t_c..t_c+0.30, w 0; meta `finger_roots` (build ms, per-finger c_f, t_c). Fallback c_f = ring vertex at t_c with S nearest S0 (preloads the debug streak script, see Blocker).
- `scripts/debug/debug_arms_roots_streak.gd` (new): GDScript port of `hash21`/`noise21`/`sn`/`streak`; `arms roots` (`debug_arms_roots.gd`) prints S0, S_f, |dS|, sweep per finger and build ms per hand; hint in `debug_arms_hints.gd`.

## Completed phase
3 · Blend the finger roots, partly: commit 4f75923. `python3 tools/check.py` CHECK CLEAN (0 warnings); `python3 tools/smoke.py` SMOKE CLEAN + VAN AUDIT CLEAN, no bless. `arms roots` (both hands): crossing angle 0.0-1.6 deg (before 39-155), dxyz 0.0000 (before 1.2-1.3), tube/palm w 0.00, build 39.8 / 39.7 ms. Streak: FAIL (Blocker). Reviewer: no gaps against the specs; must-fix: player code preloads a debug script. Not done: art-arms.md paragraph, shots into `.godot/shots/arms-p3/`, stipple, look-judge (no pictures taken this phase).

## Next phase
3 · Blend the finger roots, per D3 (owner chose: fade the streak itself via a per-vertex streak-fade channel plus a small `arm_skin_layers.gdshaderinc` change, xyz kept at the palm value): apply it in `arm_finger_root.gd`, move the streak port out of `scripts/debug/` to the player side (meter calls it), re-run `arms roots`, then the rest of `.claude/specs/p3-2.md` (gitignored, may be gone: plan `### 3 ·` Verification): shots into `.godot/shots/arms-p3/`, stipple, look-judge on Pass test (1) to (3), art-arms.md paragraph last.

## Requirements / gotchas
- Close-ups: `python3 tools/probe.py --cmd "arms cam orbit 0 70 0.2 left" --shot <png> --timeout 600`; `hand_shots.py` per-pose subfolders.
- `gh pr` GraphQL is refused; use `gh api` REST.
- `arm_bulk.gd` 309 and `arm_fingers.gd` 381 lines: new code goes in helpers.
- Implementers overran 60k twice: one deliverable per call, shots in their own call.

## Questions
none

## Blocker
none
