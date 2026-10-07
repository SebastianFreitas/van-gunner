---
paths:
  - "scripts/van/look/**"
---

# Van look (the war-rig)

Render layers and light pairing are in `van-render-layers.md`; the art rules are `art-3d.md`.

`VanLook` (`scripts/van/look/van_look.gd`, node `VanRig/VanLook`) owns the look seed: `seed_for_run(run_seed)` hashes the run seed, but with no run or in the smoke sandbox it is `DEFAULT_VAN_SEED` (1337), so the scene dump and smoke fingerprint stay stable. Its children (hull, cab, wheels, armour, roof, markings, cables, inner shell, rear dressing) each implement `rebuild_look(look)` and take their randomness from `look.rng_for(&"part")`, one RNG stream per part, so adding a part never reshuffles the others. It rebuilds on a run-seed change and on `session_loaded`; a debug reroll pins the seed until the run changes. Doors, windows, breach points, machine positions and the walk space never vary; only the dressing does.

Machine looks (`van_generator.gd`, `van_relay_rack.gd`, `van_welding_bench.gd`, `van_scrap_hopper.gd`, `van_pc_rig.gd`, each with a `*_parts.gd` RefCounted helper) hide the original mesh in `_ready`, rebuild it from `MachineParts.*` primitives, wire `MachineMotion` (spin, pump, wobble, `add_flicker`) and `MachineDamage`, keep the collision box matched to the visible footprint, and hang an `OmniLight3D` (energy 0.35 to 0.9, range 1.6 to 2.4, shadow off, `light_cull_mask` = `VanLighting.LAYER_VAN_INTERIOR`) under a visible lamp housing. Set `layers` and `light_cull_mask` before `add_child`.

Power ports: each machine adds a `Marker3D` `PowerPort` to group `&"machine_power_ports"` with meta `machine` (`generator`, `relay_rack`, `welding_bench`, `scrap_hopper`, `pc_rig`) and `role` (`source` generator, `hub` relay rack, `out` the relay rack's `LoadPort`, `load` the rest). `van_cable_runs.gd` reads those markers at rebuild time, so cables always end at a real plug; never hard-code a machine's port position. `van_cable_router.gd` keeps every cable vertex inside `wall_x_at(y) - 0.10` and out of the machines' collision AABBs and the aisle (|x| < 0.6 below y 2.2). Ceiling trunks sit at `min(2.2, wall_x_at(2.95) - 0.14)`: the wall bows in with height, so a fixed x clips it.

Wheels (`van_wheels.gd`) are radius 0.8, 0.5 wide, with the hub at `ROAD_Y + R` (y -0.1), above `HULL_BOTTOM_Y` (-0.25), so the axle beams sit mostly inside the body and the diffs and driveshaft (`van_axles.gd`) carry the underside look. The rear arches (`van_chassis.gd`) are circles around the hub, clipped at `HULL_BOTTOM_Y`. The front wheels tuck 22 cm under the cab fenders (`FENDER_BOT_Y` 0.92, fenders in `van_cab_body.gd`). Each wheel is three merged meshes (tyre, rim, steel) from `van_wheel_mesh.gd`, cached per radius and side. Rear axles sit at [3.2] (four-wheel look) and [1.95, 3.75] (six-wheel look), so the six-wheel look has room only for the 0.84 spare between them.

The DoorSpill, RearCone and moon lights are a deliberate exception (see `art-style.md`); the look never dims or replaces them.
