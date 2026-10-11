Status: phase-done
# Plan state: arms-skin-seams

## Plan
`arms-skin-seams`, `.claude/plans/arms-skin-seams.md`; branch `claude/plan-arms-skin-seams`, worktree `/home/user/van-gunner/.claude/worktrees/plan-arms-skin-seams`, cloud; PR https://github.com/SebastianFreitas/van-gunner/pull/22

## Architecture now
- `scripts/player/arms/arm_muscle.gd`: static `ArmMuscle.frame(heads) -> Dictionary` {origin, axis, u, v} and `ArmMuscle.frame_xyz(f, p) -> Vector3`; `apply` uses both (CUSTOM0 unchanged).
- `scripts/player/arms/arm_skin_nearest.gd` (`ArmSkinNearest`, static): `prefilter(positions, indices, centre, limit) -> PackedInt32Array`, `nearest(positions, indices, tris, v) -> {p, n, s}` (exact closest point; n = (c-a)x(b-a), checked outward by the meter, n.stored min 0.48-0.89).
- `ArmMuscle.apply`: w = weighted MASK (thumb.01 1.0) x hand fade h x thumb-root g, elbow lerp 0.6-1.0; heads list in `arm_bulk.gd` now has `DEF-f_*.01`, `DEF-thumb.02/.03`; limb tail w 0.6.
- `scripts/debug/debug_arms_roots.gd` + `debug_arms_roots_mesh.gd`: console `arms roots`, wired in `debug_arms_commands.gd`, hint in `debug_arms_hints.gd`. r comes from the build's `shaft` via model meta `fingers`. S0/S_f/sweep/build ms not yet printed (phase 3).

## Completed phase
2 · Fade the vein mask, commit 559d5d8 (`arm_muscle.gd` 218 lines, `arm_bulk.gd` 309, `arm_limb_tail.gd`). `python3 tools/check.py` CHECK CLEAN; `python3 tools/smoke.py` SMOKE CLEAN + VAN AUDIT CLEAN, no bless (no fingerprint line printed). `arms roots`: max w step thumb 0.27 R / 0.26 L (bar 0.25, accepted per plan: judge saw no hard stop), hand 0.02 (bar 0.66), elbow 0.13, w past x_w+0.65L 0.00, tube and palm w 0.00 at every crossing. Stipple close-ups (dark/light/dim) left 344/2532/1583, right 453/1747/2045, none above before. Reviewer: no gaps (meter reads built CUSTOM0 w; same bind space). Look-judge PASS 14/14 on Pass test (2) veins and (3) (veins thin out partway down the hand, gone before knuckles; no line at wrist, thumb mound or elbow; in wide views veins too small to read, close-ups and side views carry it); report was /tmp/p2-look.md. Shots for the supervisor to send: `.godot/shots/arms-p2/closeup-left.png`, `.godot/shots/arms-p2/rest/side.png` (before: `.godot/shots/arms-before/` same names).

## Next phase
3 · Blend the finger roots (plan `### 3 ·`): new `scripts/player/arms/arm_finger_root.gd` (RefCounted) called from `ArmFingers.build`, palm normal blend and CUSTOM0 xyz fade to c_f on the root rings, `arms roots` prints S0/S_f/sweep/build ms; art-arms.md paragraph last. Verification and checks per plan `### 3 ·` (angle at most 10 deg, xyz diff under 0.001, |S_f - S0| at most 0.1, sweep at most 1.0, build under 50 ms a hand; look-judge on Pass test (1) to (3), root-line fallback widen to 1.0 x r[1] once). Rests on Brief. First action: spec from plan `### 3 ·` naming `arm_fingers.gd` `build`/`_root_profile`, `arm_skin_mesh.gd` build (~127-152), `arm_skin_nearest.gd`, `debug_arms_roots*.gd`, `grime.gdshaderinc:5-25`, `arm_skin_layers.gdshaderinc:162-166`; it is two specs (helper+call site, then meter S0/S_f/sweep/ms + art-arms note).

## Requirements / gotchas
- e_h is 0.284 (> 0.20), so W = the 0.65 L cap and the hand bar is 1.5 e_h L / W (about 0.66); use the plan's numbers as written.
- Close-ups: `hand_shots.py` only takes named views (front, side, left, top, elbow, player) and writes `<out>/<view>.png` per pose, so use per-pose subfolders; close-ups via `python3 tools/probe.py --cmd "arms cam orbit 0 70 0.2 left" --shot <png> --timeout 600`.
- `gh pr` GraphQL is refused here; use `gh api repos/SebastianFreitas/van-gunner/pulls...` (REST).
- `arm_bulk.gd` is 309 lines (305 before): add nothing there; new code goes in helpers.
- Keep implementer prompts narrow: the meter build overran the implementer's 60k line once.

## Questions
none

## Blocker
none
