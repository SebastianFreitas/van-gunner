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
| `*-back` (van interior) | 0.011 | 0.025 | 0.05 |
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
- Dark budget: every `*-back` view was over its budget before the work-lamp
  round and stays at or below its earlier values (`02-idle-back` mean 0.0115,
  p95 0.0525 after spec 10b). The van's two hanging work lamps
  (`WorkLampFront`, `WorkLampRear`) have a front energy of 7.0: that is the
  knob. Energy 2.5 with a 65-degree cone nearly met the budget at the cost of a
  darker gun (spec 10b try 1), so the trade is an owner call.
- Each `VanWorkLamp` has a downward spot plus a 2 m fill omni; the scene dump
  lists the Fill nodes. Pitfall: raising the rear lamp's fill does not light the
  far rear wall that `02-idle-back` frames (6 m or more from the lamp) and
  pushes `05`, `08`, `11` and `01` over budget (spec 10d, three tries).
- A change to a large surface reads on near walls, docks and stoops, not in
  the means: look at the PNGs as well.
- The smoke shots visit only the street, the elevator stop (shop) and the
  rear-park stop (garage). For the mechanic, the warehouse, a junction, a
  statue or an overhead, check with a temporary debug swap (`stop elevator
  mechanic`, `stop warehouse`) that is never committed.
