Status: blocked
# Plan state: arms-skin-seams

## Plan
`arms-skin-seams`, `.claude/plans/arms-skin-seams.md`; branch `claude/plan-arms-skin-seams`, worktree `/home/user/van-gunner/.claude/worktrees/plan-arms-skin-seams`, cloud; PR https://github.com/SebastianFreitas/van-gunner/pull/22

## Architecture now
- `scripts/player/arms/arm_muscle.gd`: static `ArmMuscle.frame(heads)` / `frame_xyz(f, p)`; `apply` writes CUSTOM0 (vein mask fades, phase 2).
- `scripts/player/arms/arm_skin_nearest.gd` (`ArmSkinNearest`, static): `prefilter`, `nearest -> {p, n, s}`.
- `scripts/player/arms/arm_finger_root.gd` (`ArmFingerRoot`): `build` from `ArmFingers.build`. Palm-normal blend `BLEND_R` 0.5 x r[1] on rings t <= max(0.30, t_c), `SEARCH_T` 0.8; CUSTOM0 xyz = the palm frame at the vertex, w 0; streak fade g = smoothstep(t_c, t_c+0.30, t) passed as `streak_fade` to `ArmSkinMesh.build`, written as CUSTOM3 (R float; only fingers write it, others read 0). Meta `finger_roots` (build ms, t_c per finger).
- Shader: `arm_surface.gdshader` varying `finger_g` from CUSTOM3.r; `arm_skin_layers.gdshaderinc` `sk_streak` and `sk_dirt` mix every vein_data-xyz term toward its xyz-0 value by `finger_g` (g 1 = today's fingers).
- `scripts/player/arms/arm_skin_streak.gd` (moved from `scripts/debug/debug_arms_roots_streak.gd`): CPU port of `hash21`/`noise21`/`sn`/`streak` incl. the g mix; `arms roots` (`debug_arms_roots.gd`) prints S0, S_end, |dS|, sweep (total variation of the faded streak), angle, dxyz, w, build ms.

## Completed phase
3 · Blend the finger roots, D3 applied: commit 230f0f1. `python3 tools/check.py` CHECK CLEAN; `python3 tools/smoke.py` SMOKE CLEAN + VAN AUDIT CLEAN, no bless. `arms roots` both hands: angle <= 1.7 deg, dxyz 0.0000, w 0.00, |S_end - S0| 0.00 (by construction, D4), sweep <= 1.00, build 45.8 / 47.6 ms. Reviewer: no gaps. Stipple (dark/light/dim) left 344/2533/1584, right 458/1697/2038 (before 344/2535/1660, 457/1776/2056; right dark +1). Art-arms.md paragraph added.
Look-judge FAIL (`/tmp/look-p3.md`): closeup-left pale hard-edged wedge at the index root and ragged notch at the middle root; weave/side dark triangle at the right index root; all unchanged since before the phase. closeup-right: the gun hides the right roots, so both hands cannot be judged. Pass test (2) and (3) pass on all 14 views.
Fallback 1.0 x r[1] blend (D5): no visible change (`/tmp/look-p3b.md`; marks read as geometry, straight polygon edges), stipple flat (346/2531/1575, 459/1699/2052), one build print 58.9 ms; reverted to 0.5, not committed.
Shots for the supervisor to send: `.godot/shots/arms-p3/closeup-left.png`, `.godot/shots/arms-p3/weave/side.png` (after D3); before: `.godot/shots/arms-before/closeup-left.png`, `.godot/shots/arms-before/weave/side.png`. Fallback set: `.godot/shots/arms-p3b/`.

## Next phase
None until the owner answers the Blocker; then phase 3 again per the answer.

## Requirements / gotchas
- Close-ups: `python3 tools/probe.py --cmd "arms cam orbit 0 70 0.2 left" --shot <png> --timeout 600`; `hand_shots.py` per-pose subfolders. The right close-up shows the gun over the roots: a right-hand view needs another orbit.
- `gh pr` GraphQL is refused; use `gh api` REST.
- `arm_bulk.gd` 309 and `arm_fingers.gd` 381 lines: new code goes in helpers.
- Implementers overran 60k twice: one deliverable per call, shots in their own call.
- `git add` with one bad path aborts the whole add; a following commit then lands only what was already staged.

## Questions
none

## Blocker
Phase 3, plan line "Look-judge sees a root line: widen the normal blend to 1.0 x `r[1]` once, re-shoot; still seen, stop and report (no flare)." Both blends leave the same root marks, which the judge reads as geometry: tube faces meeting the palm at hard polygon edges (pale wedge at the left index root, notch at the left middle root, dark triangle at the right index root). Shading and the streak are now continuous (angle <= 1.7 deg, dxyz 0, streak fade by construction). Question for the owner, options:
1. (Recommended) Allow a geometry fix at the root without a flare: clip or weld the tube's buried ring faces to the palm surface (tube vertices below the palm snap onto it), keeping the visible finger shape.
2. Allow a small root flare (tube radius grows over the buried rings only) so the tube meets the palm tangentially.
3. Accept the marks as knuckle creases and close phase 3 as is (D3 work kept).
4. Take a close-up first at a right-hand orbit without the gun, and judge both hands before deciding.
