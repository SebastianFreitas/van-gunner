# vanfix 01 · Geometry audit findings (seed 1337)

Source: `py -3 tools/van_audit.py` (report in `.godot/van_audit/report.txt`, 2,308 lines)
and `py -3 tools/smoke.py --shots` close-ups `c01`..`c32`. Run time about 3 min 50 s,
almost all of it the three FLICKER passes (55–66 s each); the phase that wires `--strict`
into smoke (phase 5) needs the spec 1-2 normal-bucketing speed-up or a moving-roots-only
flicker pass at half/open first.

Summary: `CLIP=229 EDGE=23 FLICKER=1888 HEIGHT=43 LEAK_IN=1 LEAK_OUT=109 OPENING=136 REAR_ROOF=8`.

Severity: **S1** the owner sees it from the normal play position; **S2** visible close up or
from outside; **S3** probably audit noise or harmless, triage when its phase comes.

## The owner's pictures matched

| Picture | Findings | Builder | Severity |
|---|---|---|---|
| 1 · side door from inside is a see-through hole | `LEAK_OUT sees=Interior/Shell/SideDoors/Left/CurvedOuter past=none rays=1348`, same `Right` (1251): from inside the cabin the rays reach the door's *outer* skin with no inward-facing leaf in front of it, i.e. the door has no solid inside face; `FLICKER a=b=SideDoors/<L,R>/RecessedPanel` (4.97 m², duplicated triangles in one mesh). Shots c01 (flat grey slab, no inner panel detail), c05. | `scripts/van/side_doors*.gd` door leaf builder (CurvedBody / CurvedOuter / RecessedPanel) | S1 |
| 2 · same, with the port open | Same LEAK_OUT rows; the port itself is skipped (D10), so the hole around it is the leaf, not the port. | same | S1 |
| 3 · opened window's frame ring and reveal have sawtooth edges | `FLICKER a=SideWindows/LeftRear/Hinge/CurvedFrame b=VanLook/Hull/SideWindowCasingL0` (0.11 m², 178 pairs) and `b=VanLook/Hull/SideSkinL` (0.07 m²), same on all four windows; `IronCross` pieces coplanar with `CurvedFrame` in every pose; `LEAK_OUT sees=SideWindows/*/Hinge/CurvedFrame past=none` (68–89 rays). Shot c10 shows the ragged ring. | `scripts/van/side_windows*.gd` frame + `scripts/van/look/` hull casing (`SideWindowCasing*`) | S1 |

Something above the rear roof line: `REAR_ROOF VanLook/Roof/Antenna0 top=5.762 z=4.675`,
`JunkCrate19 top=4.194`, `AntennaBase0`, `RackRailL/R`, `RackEndB`, `RackLeg2/5` (shot c31:
rack rails and the crate stand proud of the rear roof crown).

## All findings by kind

- **HEIGHT (43)**, cap 3.57 m (roof crown): every `VanLook/Roof/*` add-on: `Antenna0` 5.76 m
  (+2.19), `JunkTyre7` 4.44, `JunkStrap*` 4.24, `JunkTarp*` 4.22, `JunkCrate*` 4.19,
  `JunkTyre4/6` 4.18, then rack pieces at 3.66–3.69. Builder `scripts/van/look/` roof junk and
  rack. S2 (phase 5, add-ons height-capped).
- **REAR_ROOF (8)**: listed above. S2.
- **FLICKER (1,888; 1,786 closed, 49 half, 53 open)**:
  - `Interior/Shell/SideWalls/<Left,Right>Wall` vs `VanLook/Hull/SideSkin<L,R>` (3.4–4.0 m²,
    ~2,000 pairs each): interior wall and outer skin share a plane over large areas. S1 where
    visible through gaps, else S2.
  - 57 same-node exact duplicates (`a=b`): `SideWindows/*/Hinge/WindowGlass` and
    `.../ExteriorPane` (2.72 m² each), `SideDoors/*/RecessedPanel`. Probably double-sided built by
    re-emitting triangles with the same winding. S2.
  - `SideWindows/*/Hinge/CurvedFrame` vs hull casing and skin, `IronCross` vs `CurvedFrame`
    (picture 3). S1.
  - The long tail (rest of 1,786) is props and look pieces resting flush; triage per phase.
- **CLIP (229)**, all on moving parts: `SideDoors/<L,R>/CurvedBody` closed cuts
  `SideWalls/DoorJamb_<L,R>` (1,583 hits), `VanLook/Hull/SideDoorCasing<L,R>` (798),
  `SideSkin<L,R>` (533), `LeftWall` (509), `FloorSeal`, `SillL`, and forward into
  `Interior/FrontWall/Slab`, `VanLook/Cab/CabBackWall`, `CabLiner`, `CabBackLip`,
  `CornerPostFL` (z to -4.74): the leaf is longer than its opening and pushes into the cab
  wall. S1 for the door phase (phase 2).
- **OPENING (136)**: `door_left` 67, `door_right` 39, windows 3–11 each. The door hits are
  `Interior/FrontWall/Slab`, `Props/CabRelay/Rack/CabinetTop`, `Props/RequestBoard/PcRig/*`
  (desk, shelf, clock radio) inside the door's closed box; because that box reaches forward
  into the cab (see CLIP) part of this is the oversized leaf, not the props. Re-run after the
  leaf fix before moving any prop. S2/S3.
- **EDGE (23)**: `VanLook/Hull/Sill<L,R>` open edges 9.52 m long, `VanLook/Cab/CabLiner`
  (68 open, 5.0 m), `CabBackLip` (13, 4.9 m), wheel wells `Wheels/Well<L,R><0..2>`,
  `SideDoorCasing<L,R>` (68 short edges at the front bottom, z -4.77). Sill and cab edges S2
  (phases 3–4), wells S3 (underside is out of scope).
- **LEAK_OUT (109)**: side doors (picture 1), rear doors `RearWall/<Left,Right>Hinge/CurvedBody`
  (684/654 rays) and `WindowGlass` (418/417): the rear doors show the same missing inner face
  as the side doors; window `CurvedFrame` (picture 3). S1 for side, S2 for rear.
- **LEAK_IN (1)**: `through=nothing rays=13 at=(0.49, 2.39, 12.41)`: a ray from outside
  behind the van reaching the cabin untouched, probably through the rear door window gap.
  S2, check with shot c31 / v02 in the rear-door work.

## Shots read

c01 (left door inside closed: flat grey slab, no inner leaf detail, reads as a hole),
c02 (left door inside open: the opening is clean), c10 (left-rear window inside open: ragged
rust ring round the frame, the sawtooth), c31 (rear roof centre: rack rails, crate and
antenna base proud of the roof line).
