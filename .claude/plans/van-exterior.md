# Van exterior: one shell, inside and out

Stage: running
Started: 2026-09-26
Procedure: `.claude/skills/plan/SKILL.md` (running phases, one commit each).

## Brief (owner's words, verbatim)

> make the van real on the outside, this game was just a room that looked like the inside van that moved torught streets, could you soemhow try to procedurally create the actual van without destroying what we have an actually fuse them togheter into a van? this plan should start wiith like understanding what we have, cuz theres a lot of current issues that we might as well fix now before this overhail than after, specially the wall agaisnt the driver side , its all fcuked,

> (on the driver wall) its deformed, i think they are 3 assets, when i tier to shape them aorudn the cieling and walls, it go all fcuked, just this part should be a giant plan, we really need to get behind all of this

## Decisions

- D1: the broken wall is the FRONT END (FrontPartition + CabDoor + Bulkhead cage); owner confirmed "Yes, the front end". Its own big stage.
- D2: "Big war-rig truck": keep the room exactly, build a box-truck body, cab, hood, chassis and wheels around it.
- D3: "Visual only": no new exterior collision.
- D4: "Phased, all in one go": one commit per phase, shots each phase, run straight through.

## Progress

| # | Phase | Kind | Rests on | Status |
|---|---|---|---|---|
| P0 | Audit + shots views | research/code | D1 | todo |
| P1 | Profile API in VanSideWall | code | D2 | todo |
| P2 | Front end as one VanFrontWall | code | D1 | todo |
| P3 | Side walls conform to bow | code | D1 | todo |
| P4 | Outer body skin + reveals | code | D2 D3 | todo |
| P5 | Real cab and nose | code | D2 | todo |
| P6 | Chassis and wheels | code | D2 | todo |
| P7 | Lighting/readability | code | D2 | todo |
| P8 | Docs, map, delete plan | doc | D4 | todo |

## Carry forward

- Old reference shots (pre-plan): `C:/Users/Traff/AppData/Local/Temp/claude/C--Users-Traff-Documents-van-gunner/b635f655-5925-41bb-a507-19d6ddf53660/scratchpad/shots_cables2/` (v01-v03 outside views, 01/02 inside).

---

## Context

The van is a room (4.84 m wide at the floor, 3.08 m tall, 9.4 m cargo, a bowed wall profile in
`VanSideWall._profile_x`) with a seeded exterior bolted on afterwards: `VanLook` builds the hull
(`van_hull.gd`, the side-liner mesh pushed 6 cm outward), cab, wheels, armour, roof and markings.
From outside it reads as a black bus-shaped tube (see the old shots `v01`/`v02`/`03-outside`).
There's no van silhouette, the cab is just two headlights on a dark lump, and the openings are
paper-thin because the "outside" is just the liner moved out 6 cm.

The front end of the cargo room, the wall between the player and the driver, is broken (the owner
confirmed it). It's three separately shaped pieces fighting the curved shell: `FrontPartition`
(`front_partition.gd`, LeftPanel/RightPanel from `SideWalls` + `Ceiling`), `CabDoor`
(`cab_door.gd`) and the mesh cage `Bulkhead` (`van_bulkhead.gd` + `van_bulkhead_mesh.gd`, whose
nodes are at `van.tscn` about l.117-150). The side windows are also flat `CSGBox3D` WallPanels
and the pillars and rails are flat boxes on a bowed wall (`van_shell.tscn` l.153-609).

The owner's decisions:
- **D1:** the front end is the broken wall. Fix it first, as its own large stage.
- **D2:** a big war-rig truck. The room keeps its exact size and a box-truck / step-van body,
  cab, hood, chassis and wheels are built around it. Gameplay doesn't change.
- **D3:** the exterior stays visual only, with no new collision. Raiders keep using breach points.
- **D4:** phased, straight through, one commit per phase, shots each phase.

## Approach: one profile, two skins

The central idea is that **one body profile drives everything**. `VanSideWall` already owns
`wall_x_at(y)` and the curved builders (`build_curved_shell_mesh`,
`build_curved_pane_from_poly`, `build_curved_frame_ring_mesh`). Extend it with a closed
**cross-section**: floor, bowed sides and roof arc as one curve, plus an **outer offset**
(wall thickness about 0.12 m). Every inner piece (liner, front end, pillars, window reveals)
and every outer piece (hull, cab back, arches) samples that one profile, so inside and outside
are the same object and can't drift.

Openings (side windows, gun port, side doors, rear doors) become **tunnels**. A reveal mesh joins
the inner cut to the outer cut, so a window has real depth from both sides.

Invariants kept: doors, windows, breach points, machine positions, walk space and every node path
in the "referenced by path" list (`Interior/Shell/SideWalls`, `Interior/Bulkhead`, the
RearWall/*Hinge/IronCross paths in `van_breach_points.tscn`) stay fixed. Only geometry changes.
Van footprint for parking/keep-out (`smoke_shots.gd:20`, x ±2.6, z ±4.7 plus the cab) is
re-checked against `FacadeKeepOut` and the stop-bay constants in `scripts/travel/`.

## Phases (one commit each; mirror into `.claude/plans/van-exterior.md` from TEMPLATE.md at start)

**P0: Audit and baseline (research, no code).**
- Add smoke `--shots` views aimed at the front end, the driver-side wall and the passenger-side
  wall. The views come from the player cam; this is a small `tools/smoke/smoke_shots.gd` spec.
  Use the `ghost` debug command's framing for outside angles.
- Write `.claude/plans/research/van-exterior-00.md`: every gap, clip, z-fight and flat-on-bowed
  piece, with file:line and a screenshot name.
- Record the constants any later phase must not break: breach Outside markers x ±2.65-3.16,
  raider lane x ±7.6, bay mouth, and the cable router bound `wall_x_at(y) - 0.10`.

**P1: The profile API.** In `van_side_wall.gd` (plus a `RefCounted` helper if it would pass 300
lines), add `section_points(steps) -> PackedVector2Array`, `outer_x_at(y)`, `roof_y_at(x)`,
`outer_roof_y_at(x)` and `build_reveal_mesh(poly, side)`. No visual change. check + smoke +
scene_dump stay unblessed.

**P2: The front end as one piece (the big stage, D1).** Replace FrontPartition + CabDoor + the
front face of the Bulkhead's shaping with one procedural `VanFrontWall`. It is built from
`section_points` so its outline is the exact inside of the shell (no gaps at the floor, the
corners or the ceiling arc). It has a framed doorway for the cab door, a pass-through window
into the cab, and the cage mesh set inside that frame. It uses the shared `van_wall_material.tres`.
- Keep the `Interior/Bulkhead` path and `BulkheadPassage` nav marker working; `CabRelay` keeps
  its `vital_id`.
- Collision matches the mesh (boxes along the profile).
- Split if it runs long: P2a frame + panels, P2b door + cage, P2c remove the old nodes, with a
  `git grep` proving `front_partition.gd` references are gone.
- Verify with check, smoke, scene_dump `--bless` (the tree changes on purpose), and shots of the
  front view.

**P3: The side walls conform.** Rebuild the flat CSG window WallPanels, pillars and rails on the
curved builders so they follow the bow. Keep the node names, the BreakableGlass/Interact bodies,
and the positions. Blessing scene_dump is expected.

**P4: The outer body.** `van_hull.gd` stops pushing the liner out 6 cm and instead builds the
outer skin from `outer_x_at`/`outer_roof_y_at`, plus reveals through every opening. It adds the
body lines a box truck has: belt line, drip rail, corner posts, rear header, sills and seams.
Albedo is 0.08-0.22 with edge wear up to 0.35, so it stops reading as black (art-style.md
large-surface budget 0.02-0.25). `van_armour.gd` and `van_markings.gd` re-anchor from FACE_X 2.6
to `outer_x_at(y)`.

**P5: A real cab and nose.** Rebuild `van_cab.gd` as a truck cab ahead of the front wall. The
cab's back face uses the same section, so the cab and cargo box meet at a seam, not a gap.
It gets a raised hood, a grille, a bumper, A-pillars, doors, a windshield with depth, mirrors,
and the existing two headlights. Its dim interior shows through the P2 pass-through window,
with a sprite driver behind the wheel if cheap (art-style pixel rules, `pixel_size 0.024`).

**P6: Chassis and wheels.** Frame rails, fuel tank, steps and a rear bumper/underride bar.
`van_wheels.gd` puts the wheels under arches cut into the P4 skin, sitting on the road
(y ≤ 0), and drops `side exhaust` as a stack behind the cab.

**P7: Lighting and readability pass.** Add marker and clearance lights along the roof edge and
tail lights with fixtures you can point at. Keep the mask-1 DoorSpill, RearCone and ExteriorLight
exactly as they are (art-style.md deliberate exception). Calibrate `*-outside` shots to mean
≤0.015 / p95 ≤0.030 (art-style.md:72-89). Use `VanLighting.retarget_layers()` for any layer
change; set layers and `light_cull_mask` before `add_child`.

**P8: Docs.** Update `.claude/rules/van-shell-and-hud.md` (the profile API, the front-wall
contract, the outer skin) and `art-style.md` (the exterior values). Regenerate the PROJECT_MAP,
delete the plan mirror, and write the final report.

## Rules copied into every spec

- Invariants 14 (FacadeKeepOut) and 15 (art style). Read `art-style.md` values into each spec.
- The Godot 4.7 light-pairing crash (van-shell-and-hud.md:59-61).
- Van look: each part gets its own `look.rng_for(&"part")` stream; openings and walk space never
  vary.
- Scripts stay under 300 lines, with `RefCounted` helpers and no `class_name` on them. Each
  implementer call covers one file.
- Shared mode: stage by path only. Never stage `resources/balance/game_balance.tres` or
  `export_presets.cfg`.

## Verification per phase

- `py -3 tools/check.py` and `py -3 tools/smoke.py` (no fingerprint change expected).
- `py -3 tools/scene_dump.py` (`--bless` only in P2/P3/P4, and say so in the report).
- `py -3 tools/smoke.py --shots <scratchpad>/shots`, then read the front, back, outside and
  v01-v03 PNGs myself.
- The reviewer subagent on every phase over about 150 lines.

End with the CLAUDE.md report. Try is
`py -3 C:/Users/Traff/Documents/van-gunner/tools/try.py main`, with exact steps: NEW → at IDLE,
turn to the front wall; `H` → `ghost` to fly outside.
