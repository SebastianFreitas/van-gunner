Status: blocked
# Plan state: arms-blender-source

## Plan

`arms-blender-source`, `.claude/plans/arms-blender-source.md`; branch `claude/cranky-rhodes-dde1e9`, worktree `C:/Users/Traff/Documents/van-gunner/.claude/worktrees/cranky-rhodes-dde1e9`.

## Architecture now

- `tools/blender/arms.py`: stdlib runner (Blender 5.2, env `BLENDER` overrides); `import [<glb>] [--force]`, `build`, `preview <dir>`, `hunt <file> <dir>`; fails on "Traceback"/"Error:" or a non-zero exit.
- `tools/blender/arms_bl.py`: import/build/export/preview (`do_build` calls `arms_edit_bl.apply`); `arms_hunt_bl.py`: the defect hunt (D53).
- `tools/blender/arms_edit_bl.py`: three edit steps, all `"on": False`: `wrist_mirror`, `seam_smooth`, `width` (now holds the D59/D60 fallback f `1 .998 .99 .997 .866 .845 .948 1 1`; moves only 54 source vertices per arm). Group names like `DEF-forearm.R.001`.
- `scripts/debug/debug_arms_hands.gd` (384 lines): `_shape` counts a slab vertex when hand + palm weight >= `HAND_SHARE` 0.30 (D58); W_k is now an area-weighted 95th percentile of |lat| (`_vertex_area`, `_p95`, D59); `mono`/`jump` on slabs 0..7, jump over (W7-W0)/7.
- `tools/blender/arms.blend`, `assets/models/arms/arms.glb` = the no-edit build; CC0 at tag `archive/arms-glb-cc0`.

## Completed phase

Phase 4 · Proportion audit, third try: **blocked at spec 1 step 2 (width)**; the glb is unchanged (no-edit build).
- Probe p95 (D59) e77a28c1 (+ warning fix in this commit). No-edit rows R / L: W0..8 .074 .081 .088 .093 .107 .115 .111 .107 .099 / .079 .077 .093 .093 .107 .115 .112 .107 .099, mono false both, jump 3.12 / 4.00, dome .355 / .321, palm_depth .497 / .497, wrist/palm .819 / .789, knuckle unchanged. Raw `Temp/vg-p4/hands_p95.txt` (the new baseline). L/R sanity missed by .001 at W0..W2: L wrist slab 1 is the one thumb-dominant case (W .077, .069 without thumb verts).
- Width per D60 (ramp to W7, f <= 1), d8fbb56d: first try R .074 .080 .086 .090 .103 .107 .105 .102 .099 mono false jump 3.25 wrist/palm .840; D40 fallback (f4 .866, f5 .845) R jump 3.73, L 4.21, mono false both. Step off, rebuilt.
- Diagnostic (p4-3, audit "Width diagnostic (p4-3)"): the bulge is NOT thumb verts (0-19 % of area at k4..6, W moves <= .001 without them). The step moves 54 coarse source verts; the probe reads the refined, inflated mesh (`ArmBulk`, `ArmRefine`), which adds width back: asked W4 .098 / W5 .102, got .103 / .107 (about 45-60 % of the asked drop lands).
- Not run: spec 2 (`spec-4-2.md`), smoke, preview, insp4.

## Next phase

Parked by the owner (D61). Nothing runs until the game-vs-Blender review lands and makes Blender edits survive the game's procedural build; then phase 4 again from spec 1 step 2 with the width question re-asked on the new pipeline, D62 (slab 1 >= W0), then spec 2.

## Requirements / gotchas

- After `arms.py build`, run `py -3 tools/check.py` before `arms hands`, else the probe reads the stale import. The build re-saves `arms.blend` even when nothing changes.
- Baselines: `arms hands` = `C:/Users/Traff/AppData/Local/Temp/vg-p4/hands_p95.txt`; `arms touch` = `vg-p1/touch_after.txt`; hunt "before" `vg-p2/hunt2/{posed,rest}/hunt.txt`.
- A source-mesh lateral scale lands only about half its drop on the probe's slabs: code-side inflate/refine re-widens the hand.

## Questions

none

## Blocker

Parked by the owner (D61, 2026-10-17): review the game vs Blender first. The game's procedural steps (`ArmBulk`, `ArmRefine`, vein relief, ...) reshaped the hand after load, so a Blender edit landed only about half; they are removed (tag `archive/arms-procedural-build`), so a Blender edit now lands as made. Restart only when the owner says the review is done.

## Saved specs (send these to the implementer first)

- .claude\plans\arms-blender-source.spec-4-1.md (rewrite step 1's f from the owner's answer)
- .claude\plans\arms-blender-source.spec-4-2.md
