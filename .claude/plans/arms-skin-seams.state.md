Status: phase-done
# Plan state: arms-skin-seams

## Plan
`arms-skin-seams`, `.claude/plans/arms-skin-seams.md`; branch `claude/plan-arms-skin-seams`, worktree `/home/user/van-gunner/.claude/worktrees/plan-arms-skin-seams`, cloud; PR https://github.com/SebastianFreitas/van-gunner/pull/22

## Architecture now
- `scripts/player/arms/arm_muscle.gd`: static `ArmMuscle.frame(heads) -> Dictionary` {origin, axis, u, v} and `ArmMuscle.frame_xyz(f, p) -> Vector3`; `apply` uses both (CUSTOM0 unchanged).
- `scripts/player/arms/arm_skin_nearest.gd` (`ArmSkinNearest`, static): `prefilter(positions, indices, centre, limit) -> PackedInt32Array`, `nearest(positions, indices, tris, v) -> {p, n, s}` (exact closest point; n = (c-a)x(b-a), checked outward by the meter, n.stored min 0.48-0.89).
- `scripts/debug/debug_arms_roots.gd` + `debug_arms_roots_mesh.gd`: console `arms roots`, wired in `debug_arms_commands.gd`, hint in `debug_arms_hints.gd`. r comes from the build's `shaft` via model meta `fingers`. S0/S_f/sweep/build ms not yet printed (phase 3).

## Completed phase
1 · Root meter and before shots, commits 9a07695, 6ce7c2d, 08c5ae9. `python3 tools/check.py` CHECK CLEAN; `python3 tools/smoke.py` SMOKE CLEAN + VAN AUDIT CLEAN, fingerprint unchanged, no bless; `python3 tools/probe.py --cmd "arms roots"` PROBE CLEAN, numbers in the plan's Carry forward (angles 39-155 deg, hand step 1.00 as expected). Reviewer: formulas match the plan, apply bit-identical; its two fixes landed in 08c5ae9. Before set in `.godot/shots/arms-before/` (14 PNGs), no picture read (nothing visible changed).

## Next phase
2 · Fade the vein mask (plan `### 2 ·`): weighted `MASK` in `ArmMuscle.apply` (thumb.01 1.0), hand fade over b - W to b, elbow blend, limb tail 0.6. Verification: check, smoke, `arms roots`, after set into `.godot/shots/arms-p2/`, stipple close-ups not above before; look-judge on every view against Pass test (2) and (3), FAIL stops the run. Rests on Brief. First action: spec from plan `### 2 ·` naming `arm_muscle.gd` `apply`/`MASK`, `arm_bulk.gd` heads (~147), `arm_limb_tail.gd` (~57).

## Requirements / gotchas
- e_h is 0.284 (> 0.20), so W = the 0.65 L cap and the hand bar is 1.5 e_h L / W (about 0.66); use the plan's numbers as written.
- Close-ups: `hand_shots.py` only takes named views (front, side, left, top, elbow, player) and writes `<out>/<view>.png` per pose, so use per-pose subfolders; close-ups via `python3 tools/probe.py --cmd "arms cam orbit 0 70 0.2 left" --shot <png> --timeout 600`.
- `gh pr` GraphQL is refused here; use `gh api repos/SebastianFreitas/van-gunner/pulls...` (REST).
- Keep implementer prompts narrow: the meter build overran the implementer's 60k line once.

## Questions
none

## Blocker
none
