---
paths:
  - "tools/shot_stats.py"
  - "tools/shots.py"
  - "tools/gap_check.py"
  - "tools/smoke/smoke_shots*.gd"
---

# Art style: screen targets

The targets `tools/shot_stats.py` checks ("Screen check" in `art-style.md`).

Calibrated in art-pass step 1 (2026-09-25) from the stop shots, which are
the "dark enough" line (`09` mean 0.0052, `12` mean 0.0123, p95 0.019).
Values are linear luminance; clip% is the share of pixels with any channel
at 250 or more. `*-outside` is the camera above the cab; `*-back` the van
interior facing the cab end, not the rear doors (owner, 2026-10-08: the rear
doors from inside are `g02-gap-rear-in-whole`); `*-front` the player's view with the HUD.

| Shots | Mean max | p95 max | Clip% max |
|---|---|---|---|
| `*-outside` (street and stops) | 0.015 | 0.030 | 1.0 |
| `*-back` (van interior, readable budget, see below) | 0.10 | 0.28 | 0.5 |
| `*-front` (HUD on, loose check) | 0.030 | 0.10 | 0.20 |

After the 3D art pass (2026-09-25) every shot is inside its target except
`06-combat-outside` (mean 0.036, p95 0.178, clip 1.6%; it was 0.099, 0.85
and 7.4% before). That is accepted: the overhead camera sits at
second-floor height right beside the big vertical sign and near lit panes,
so `06` reads emissives close to a high camera, not the street's ambient
darkness. Judge a change by how far it moves `06`, not by the table.

Reading the numbers:

- Shots are not pixel-deterministic between runs, and facade layouts are
  seeded per run, so street numbers move with the buildings on screen.
  Compare against a before run of the same session, and treat about
  ±0.001 mean and ±0.1 clip% as noise.
- Interior budget (2026-10-09, spec 1 and 2): the van interior is readable, not
  dark, but never by ambient, fog or exposure: every light has a fixture. Measured
  after the junk lamps (linear luminance; p5 is the low-end floor so black regions
  do not come back):

  | View | Mean | p5 | p95 | Clip% |
  |---|---|---|---|---|
  | `02-idle-back` | 0.088 | 0.0064 | 0.250 | 0.00 |
  | `05-combat-back` | 0.034 | 0.0011 | 0.125 | 0.05 |
  | `08-elevator-stop-back` | 0.055 | 0.0024 | 0.180 | 0.10 |
  | `11-rear-park-stop-back` | 0.061 | 0.0032 | 0.193 | 0.13 |
  | `f01` to `f05` floor views | 0.036 to 0.073 | 0.0 to 0.008 | 0.10 to 0.26 | 0.00 to 0.21 |
  | `g02-gap-rear-in-whole` | 0.052 | 0.00006 | 0.163 | 0.03 |

  Budget with margin: every `*-back` view mean 0.03 to 0.10, p5 at least 0.001,
  p95 at most 0.28, clip at most 0.5%. Floor and `g02` views: mean at least 0.025,
  p95 at most 0.28, clip at most 0.5%, and the floor itself never black (measured
  on the floor pixels only: `g02` rows below y 550 p5 0.043, `f04` floor region
  p5 0.033). Whole-frame p5 of `f04` (0.0) and `g02` (0.0001) is the window panes
  and the dark rear-door edge, which show the night outside and take no lamp. The old dark budget (`*-back` mean 0.011, p95 0.025, clip
  0.05%) is retired.
- Knobs by zone (all under `Lighting` in `van.tscn`; `VanJunkLamp` is
  `scripts/van/look/van_junk_lamp.gd`): five interior lights in all.
  `WorkLampFront` and `WorkLampRear` (energy 12.0, range 6.5 each) the centre cargo
  floor and gun; `RearDoorLamp` (18.0, range 7, z 4.7, angle 70) the rear doors, the
  rear floor sheet and the right rear window; `CabEndLamp` (18.0, range 6, z -3.0,
  angle 75) the bulkhead, cab end and both side-door wells. The old window, side-door
  and rear-floor lamps were merged away. `DoorSpill`, `RearCone`, the moon, ambient,
  fog and exposure are not knobs. Raise a zone's lamp, never ambient.
- Interior lights have no fill omni, no shadows, volumetric fog energy 0, ranges kept
  to their target and about 5 lights in all (spec 4: the 9 spots plus 9 fills cost
  about 5 to 6.5 ms per frame; idle 69.8 fps with them, 104 fps slim, 107 hidden).
  A pixel of the cabin should be touched by as few lights as possible.
- Each `VanWorkLamp` is a downward spot only (its 2 m fill omni is gone).
- A change to a large surface reads on near walls, docks and stoops, not in
  the means: look at the PNGs as well.
- The smoke shots visit only the street, the elevator stop (shop) and the
  rear-park stop (garage). For the mechanic, the warehouse, a junction, a
  statue or an overhead, check with a temporary debug swap (`stop elevator
  mechanic`, `stop warehouse`) that is never committed.
