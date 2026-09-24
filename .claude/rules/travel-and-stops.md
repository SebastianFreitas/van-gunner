---
paths:
  - "scripts/travel/**"
  - "scripts/stops/**"
  - "resources/side_stops/**"
  - "scenes/corridor/**"
  - "scenes/shop/**"
---

# Travel, turns and side stops

## World model

The van rig is parented to a `PathFollow3D`; the world (corridor segments, junctions, side stops) is spawned ahead and culled behind. The player never steers.

## How TravelController is split

`travel_controller.gd` keeps its state header, every method other files call (speed orders, stop and act queries, `leave_stop`, debug speed), the `_sequence_id` await chains (intro, act resume, elevator ride) and the lifecycle. It stays over 400 lines on purpose. Helpers take the controller as `tc` (untyped: `TravelController` and `ActDeckController` avoid naming each other's class): `travel_world.gd` (corridor tiles, junctions, statues, pruning), `travel_routes.gd` (turn, park and leave curves; `route_chosen` connects straight to it), `travel_stops.gd` (stop fork, placement, elevator pad, cleanup).

## Side stops

Every offered road at a fork gets a stop (shop, garage, … from `resources/side_stops/`), blessing and DANGER alike, straight included. The card is only that street's combat modifier; taking a road commits the card and visits the stop. While docked (`STOP`) the rear doors stay open so you can walk the room.

How the van arrives is data on the stop: a stop is `arrival(content)`. `Arrival.REAR_PARK` reverse-parks into the shared vestibule; `Arrival.ELEVATOR` halts on the road and drops a pad to the same vestibule and roll-up door. Content scenes mount just behind the door (no dock markers). Swap `arrival` on the `.tres` (and optionally `spawn_weight`) to put any interior on the lift; debug `stop elevator shop` composes the same pairing without a new file.

`SideStopRegistry` scans `res://resources/side_stops/` with `DirAccess`. Arrival hosts (`stop_vestibule.tscn`, `stop_elevator.tscn`) expose `DockPoint` and `ExitPoint`. Content scenes start just inside the roll-up (`ContentMount` at the door, +X inward) and must not include those markers. `DockPoint.x` is negative so the rear bumper sits in the vestibule, not inside the door.

## Pitfalls

- **Stop attach ignores leftover tiles after a curve swap.** Left/right turns replace `travel_path.curve` and reset progress to 0. Old tiles keep their `route_progress`, so a naive "first tile ahead" pick can parent the garage to the street you just left and the van reverse-parks with the building on its side. `TravelController` stamps `_route_gen` and only attaches to tiles still on the live curve.
- **Elevator stops ride `PathFollow3D.v_offset`.** The van stays on the road curve; the pad is a sibling in the corridor, not a new parent. Don't reparent `VanRig` onto the platform. Open the shaft (hide collision as well as the mesh) as the ride starts, or a street-height `StaticBody` holds the player at grade while the van drops. Keep the pad below the van deck and inside the shaft so it doesn't z-fight the interior floor. Vestibule yaw is `-PI/2` so shop `+X` faces the van rear (`+Z`); `+PI/2` puts the door at the nose and walking out the back falls into the shaft. Don't place the shop slab under the van deck.
- **Van speed is tree-written.** `van_speed_level` feeds the chase formula (`closing = mob_world_speed - live_van_speed`). Only allocated schematic nodes change it; pending requests wait until the next run (or apply in `IDLE`). Don't buy speed with gold at the bench, and pending node buys must not emit `van_speed_changed` or the chase window jumps mid-street.

## Shop booth

`shop_counter_booth.gd` keeps its exports, build order, lights and box primitives; materials, flyers (and the block-letter glyph table), frame and trim are helpers beside it. Flyer placement is seeded: keep RNG call order when touching it.

## Testing

The smoke test drives two forks in `speed` mode: an elevator stop (shop) and a rear-park stop (garage), docking and leaving each. `speed` skips panels, so it doesn't test the reveal or boon UI.
