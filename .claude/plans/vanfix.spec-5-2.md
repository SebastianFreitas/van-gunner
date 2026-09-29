# Spec 5-2 · Spare, tank and toolbox behind the open side door (D30)

Worktree: C:/Users/Traff/Documents/van-gunner/.claude/worktrees/go-cc7a37. Do not commit.

## Goal
The side door slides back to z ≈ 0.135 when open; today the toolbox (z 0.1 ± 0.46), tank
(z 0.1 ± 0.75) and spares (z -1.55 ± 0.42) sit in its path. Pack them into the slot behind the
open door, in front of the first rear arch's flare, and skip whatever doesn't fit (D6).

## Target file
`scripts/van/look/van_chassis.gd` only: `build`, `_build_tank`, `_build_toolbox`, `_build_spare`.
It is 302 lines: keep the change compact (no new file unless it passes 330).

## Symbols
- `const SLOT_Z0 := 0.16` (## Front of the slot behind the open side door's rear edge (z 0.135).)
- `const SLOT_GAP := 0.02` (## Gap between packed add-ons and before the flare (D12).)
- `const TANK_LEN := 1.2` (## Saddle tank length, shortened from 1.5 to fit the slot (D30).)
- `const TOOLBOX_LEN := 0.92` (the lid's z size), `const SPARE_LEN := 0.84` (tyre diameter).
- `_build_tank(side, mat, z0)`, `_build_toolbox(side, mat, z0)`, `_build_spare(side, label, rubber, mat, z0)`:
  `z0` is the part's front (most negative z) edge; each computes `zc := z0 + LEN * 0.5`.

## Logic steps
1. In `build`, after the steps loop: `slot_end := rear_axles[0] - (VanWheels.REAR_RADIUS + FLARE_GAP + FLARE_T) - SLOT_GAP`
   (4-wheel: 2.30; 6-wheel: 1.60).
2. Exhaust side (`exhaust_side`): z := SLOT_Z0; if `z + TOOLBOX_LEN <= slot_end` build the toolbox at z
   and advance z by `TOOLBOX_LEN + SLOT_GAP`; then if that side's spare bit is set (bit 1 = L/-1.0,
   bit 2 = R/+1.0, as today) and `z + SPARE_LEN <= slot_end`, build the spare at z.
3. Other side (`-exhaust_side`): the same with the tank (`TANK_LEN`) first, then the spare.
4. `_build_toolbox`: the three meshes keep their x/y/size; z = `zc` instead of 0.1.
5. `_build_tank`: `tank_mesh.height = TANK_LEN`; tank, straps, brackets at `zc` with the ±0.5
   offsets changed to ±0.4; the cap at `zc + 0.45`.
6. `_build_spare`: every `-1.55` becomes `zc` (tyre, hub, mount, chain origin).
7. `_build_exhaust` unchanged. Comment why at the packing: the sliding door passed through all three.

## Edge cases
- 6-wheel: slot 1.44 m: toolbox and tank fit, spares skip. 4-wheel: 2.14 m: both sides fit a spare.
- Node names unchanged (`FuelTank`, `ToolBox`, `SpareL`...), so a skipped part simply is absent.

## Do not touch
Flares, wells, steps, exhaust, rear bumper, `van_wheels.gd`, x/y positions and sizes other than
the tank length.

## Rules
Tabs, typed everything, `##` doc on new consts, two blank lines between funcs, ~100 columns.

## Verification
1. `py -3 tools/check.py 2>&1 | tail -5` → CHECK CLEAN.
2. `py -3 tools/van_audit.py 2>&1 | tail -3`; `grep -E "Spare|FuelTank|Tank|ToolBox" .godot/van_audit/report.txt | cut -c1-200`:
   no row pairs them with `SideDoors/*` or the flares; report the rows left and the SUMMARY line.
3. `py -3 tools/smoke.py 2>&1 | tail -5` passes; `py -3 tools/scene_dump.py 2>&1 | tail -5`.
