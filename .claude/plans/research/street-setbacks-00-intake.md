# Handoff: street setbacks (explored and decided, nothing built)

**Goal:** owner: "our exterior is purely on a line, the sidewalks never grow larger with buildings pushed behind, the road is always the same size. I want to push buildings back, randomly ... making the surroundings adjust ... bars over the road would float in the air if we don't update them ... include the current destruction system ... sidewalks are a lot of objects so be careful." Later, not now: a European city (new shapes, curves, sloped ground).

**Done:** no commits. One wide and three narrow Explore passes, two question rounds.

**In progress:** nothing written, no spec sent. Tree clean.

**Next:**
1. Plan-sized (about 20 specs, nearly all visible): the owner starts `/plan new street-setbacks`. The interview takes Decisions and Gotchas below as settled and does not re-ask or re-explore them.
2. Phases I would cut: (a) recess in the plan + district data + body tile-edge fix + new audit; (b) road widens: piecewise walk, asphalt fill, gutter, kerb returns, bed collision; (c) plaza flagstones; (d) followers (infill, furniture, rubble, utility boxes, gap weeds); (e) overheads and span set pieces stretch; (f) wall collision per span; (g) rules and glossary.
3. Not explored yet: `road_floor.gd` `_build` 212-258 (carriageway, asphalt mesh, gutters, drains), `road_floor_wreck_curb.gd` internals, `side_street_branch.gd:44-52`, rear-park content interior widths, whether the shot run pins `run_seed` (`tools/smoke/smoke_fingerprint.gd:64` sets 12345).
4. `docs/glossary.md`: add "bars over the road / overheads" = `facade_overheads.gd` (pipe bridge, catwalk, truss, ribs) + set pieces `pedestrian_bridge.gd`, `pipe_bridge.gd`.

**Decisions:**
- Depth (owner): mixed, mostly mild. About 4 in 10 lots back 1-3 m, 1 in 10 back 4-6 m, rest on the line; terraced (joined) lots move together; now and then a whole side together. Ranges are `FacadeDistrict` exports. Forward stays today's `SETBACKS` 0-0.3: lane 7.6 and the kerb leave no more.
- Ground (owner, confirmed): an ordinary stepped-back building WIDENS THE ROAD: kerb and sidewalk keep their width and move back with the building, asphalt fills. Only a big or expensive building gets a plaza: kerb stays, big worn flagstones (about 1 m) up to the wall, broken by the same wreck map. Which buildings count as big is open (my guess: tall rolls, civic, commercial).
- Overheads (owner): stretch each end to the real wall at its z.
- Taken, not asked: collision follows so the player can walk there when halted; recess 0 where `opening != OPENING_NONE`, on mouth plans, on `FacadeSpans` walls, on rare/set-piece plans; max 6 m.
- The roll uses its own rng (like `gap_rng`), never the plan rng, so no existing draw shifts.
- Open: a tile cannot know its neighbour's recess (bays open at runtime). Either the ground notch closes inside each tile (a kerb build-out about 0.75 m at tile ends) or edge lots share a per-boundary hash.

**Task file:** none.

**Gotchas (anchors, `scripts/travel/facades/` unless pathed):**
- `facade_plan.gd`: `FACE_X` 8.8 :12, `SETBACKS` :20, `plan_length` :88-164 (setback draw :126, terrace copy :127-130, `depth`/`gap_lo`/`gap_hi` only `with_gaps` :153-156), `face_x` :246.
- Already follow `face_x`: props ground/upper, signs, fixtures (lamp pool moves with the wall), street art, ruin body/debris, ivy, about 16 set pieces.
- Fixed, will NOT follow: `facade_infill.gd:138,176` and `PARTY_X` 12.8 :163 (ends up in front of a deep recess); `facade_infill_wall.gd:19,87`; `facade_infill_extra.gd:33,76,92`; `facade_overgrowth.gd:69`; `facade_props_ground.gd:16` `STRIP_X` 8.25 (:229); `facade_ruin_debris.gd:101` lo 7.75; `scripts/travel/road_floor_details.gd:145` utility boxes, :172 bollards; `corridor_facades.gd:141` `wreck_at`.
- `facade_body.gd` `_add_ends` :151-162 draws face to 9.6 then 9.6 to back at a tile edge: inverts once the face passes 9.6. Non-deep back is 9.6 (:22, `facade_ruin_body.gd:47`).
- `facade_overheads.gd`: `_LENGTH` 18.4 :12, gets both plan arrays unused :18, rib posts ±8.3 :131,134, beam 18.0 :140. `set_pieces/pedestrian_bridge.gd:24-43` (18.4, portals ±9.2), `pipe_bridge.gd:29`. The span ctx holds `plans_left`/`plans_right` (`corridor_facades.gd:245-262`).
- Walk: `scripts/travel/road_floor_wreck.gd` `build` :53 is one rectangle `_inner`..`_inner + _width`; `_layout` :123, `_build_columns` :187, `_emit` :275 takes any stone width, commits :82-91 (5 merged meshes per side, about 320 stones, no node per stone). `road_floor_wreck_ground.gd` grid :30-43, ramp :57, scatter :122. Bed box `road_floor.gd:259-280`. Spans arrive through `scenes/corridor/corridor_segment.gd:201` to `road_floor.gd:108` as `Vector3(z0, z1, ruin)`.
- Wall collision: `scenes/corridor/corridor_segment.tscn:7-31`, boxes at x ±9, layer 1; the player (mask 17) walks the street when halted (`scripts/van/van_halt.gd:24`).
- Stops: vestibule is tile |x| 9-14.6, |z| under 4.5, bay side only; elevator is under the road; statue at x 4.5. Nothing else sits at |x| 9-20.
- `facade_audit.gd` :18, :32, :69 check only mouth and lane, so stress passes whatever floats: add an audit, hook at `scripts/debug/debug_facade_commands.gd:328`.
- An Explore asked about more than about 6 files under `scripts/travel/` passes 100k (the rules file is injected on every read): keep them narrow.

**Verified:** nothing to verify. No screenshots.

**Foreign edits:** none.
