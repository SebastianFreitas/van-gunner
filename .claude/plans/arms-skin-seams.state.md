Status: blocked
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
3 · Blend the finger roots, after the owner answers the Blocker: apply the chosen streak fix in `arm_finger_root.gd`, move the streak port out of `scripts/debug/` to the player side (meter calls it), re-run `arms roots`, then the rest of `.claude/specs/p3-2.md` (gitignored, may be gone: plan `### 3 ·` Verification): shots into `.godot/shots/arms-p3/`, stipple, look-judge on Pass test (1) to (3), art-arms.md paragraph last.

## Requirements / gotchas
- Close-ups: `python3 tools/probe.py --cmd "arms cam orbit 0 70 0.2 left" --shot <png> --timeout 600`; `hand_shots.py` per-pose subfolders.
- `gh pr` GraphQL is refused; use `gh api` REST.
- `arm_bulk.gd` 309 and `arm_fingers.gd` 381 lines: new code goes in helpers.
- Implementers overran 60k twice: one deliverable per call, shots in their own call.

## Questions
none

## Blocker
Phase 3 streak check fails, with no fallback left (plan: "none within 0.1: stop and report"). `arms roots` per finger, index/middle/ring/pinky/thumb:
- Centre c_f: |S_f - S0| R .25/1.00/.06/1.00/1.00, L 1.00/1.00/1.00/.31/.18 (limit 0.1).
- After the ring-vertex fallback: |dS| R .07/.06/.06/.17/.15, L .31/.08/.05/.03/.09; still over 0.1 on R pinky, R thumb, L index.
- Sweep max(|dy|,|dz|) x 64 over t_c..t_c+0.30: 1.19 to 3.28 on every finger (limit 1.0; the plan expected under one). The fade crosses 1-3 noise cells, so the streak may show bands in the fade; the fallback cannot fix that.
Question (phase 3, plan `### 3 ·` CUSTOM0 line): how should the finger-root streak fade be made clean?
1. (Recommended) Fade the streak itself, not the noise coordinate: write a per-vertex streak-fade into CUSTOM0 (or another channel) that ramps the palm streak to the finger's flat value over t_c..t_c+0.30, xyz kept at the palm value; needs a small shader change in `arm_skin_layers.gdshaderinc`.
2. Lengthen the fade until sweep <= 1.0 (about 3x, t_c..t_c+0.9: streak reaches its flat value near the fingertip) and accept the best vertex where |dS| stays at 0.15-0.31.
3. Keep today's build (angles and normals fixed) and relax the streak limits; the look-judge decides from shots.
4. Drop the CUSTOM0 change (fingers keep xyz 0, as before) and keep only the normal blend.
Finished without it: normal blend (root shading line gone by the meter), streak meter, checks clean.
