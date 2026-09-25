# Task: 3D art pass (procedural world, dark)

Owner brief (2026-09-25): make a pass on all the procedural 3D art (the
streets, the floors, the buildings, the stops) so the game has one
direction before it drifts into a mix. The road's shaders are right; where
the art file disagreed with them, the art file changed. The game is
supposed to be dark. The van is liked as it is. Pixel art (NPCs, raiders,
items, icons) is a later task: don't touch any sprite here.

The direction is `.claude/rules/art-style.md` (rewritten in step 0). Read
it before every step and copy its numbers into the spec.

## How this task runs: one step per prompt

The owner types "continue"; the session does **exactly one step** below,
start to finish, then ends the turn with the normal report and stops.
Never start the next step in the same turn, even with context left. Each
step is small on purpose: the more the work is split, the better each part
comes out.

Every step:

1. Re-read this file and `.claude/rules/art-style.md`, plus the area rules
   the step names.
2. Explore only the files the step names (narrow `Explore` prompts, `file:line`
   anchors).
3. Spec, implement, verify: `py -3 tools/check.py`, `py -3 tools/smoke.py`,
   `py -3 tools/smoke.py --shots <scratchpad>/shots`, then
   `py -3 tools/shot_stats.py <scratchpad>/shots` (from step 1 on). Read
   the before and after PNGs yourself. The owner plays games while this
   runs: `--shots` runs Godot on a hidden Windows desktop so it never
   steals focus. Never launch a windowed Godot any other way (no editor,
   no `try.py`, no hand-rolled `--position` window).
4. Record the step's shot stats in the log at the bottom, tick the box,
   commit (the task-file edit goes in the same commit).
5. Report with one or two PNGs, and stop.

A step that grows past its scope splits: finish the part that is done,
write the rest as a new lettered step (for example 5b) under it, commit,
stop.

Never touch in this task: sprites and their `Sprite3D` settings, HUD and
panel UI, `game_balance.tres` (the owner's), the facade keep-out geometry
(invariant 14: nothing may move into a bay mouth, the reverse-park approach
or the raider lane), the facade RNG call order (layouts are seeded per
run), and gameplay collision.

## What the screenshots showed (2026-09-25 baseline)

- Road and sidewalk: right. Dark, gritty, litter and cracks at the right
  scale. Nothing to do except share their noise library.
- Van interior: liked. Left alone.
- Combat street (`06-combat-outside`): far too bright. Lit windows are big
  white and blue-white panes that bloom, one whole wall glows yellow, the
  signs are fine. This is the biggest break of "dark".
- IDLE street (`03-idle-outside`): walls shimmer with fine moiré stripes at
  distance; walls read as flat dark planes with little of the road's grime.
- Stops (`09-elevator-stop-outside`, `12-rear-park-stop-outside`): mood is
  about right (dark, lit by their own fixtures); surfaces are a plain seam
  grid with red smudges, not the road's recipe; bay metals are shiny.

## Steps (one commit each; tick when the commit lands)

- [x] 0. Art direction: rewrite `.claude/rules/art-style.md` around the road
  and van references and a dark budget, update CLAUDE.md invariant 15, write
  this plan.

- [x] 1. **Darkness meter.** Add `tools/shot_stats.py`: takes a shots folder
  and prints, per PNG, mean linear luminance, 95th percentile, share of
  clipped pixels (any channel >= 250) and mean saturation, one line each,
  plus the HUD-free `*-outside` and `*-back` shots marked. PIL only, no
  game change. Run it on today's shots and write the baseline into the log
  below. Then set the targets in the art-style table: the stop shots as
  they are today are the "dark enough" line; the street shots must come
  down to it. Verify: run it twice on the same folder (same numbers);
  `py -3 .claude/hooks/gd-lint.py` does not apply (Python).

- [x] 2. **Night windows.** In `scenes/corridor/facade_surface.gdshader`,
  change only the lit-window emission and the glass colour: lit windows
  stay under the glow threshold (emission luminance about 0.9 or less at
  full flicker), warm amber or tungsten tints per window from the seed (a
  few dim fluorescent green), never white; find what makes the blue-white
  panes on glass-curtain (style 3) and storefront glass (lit ratio,
  specular, or the ground-floor zone) and bring them into the rule. Check
  the district `.tres` `lit_ratio` values against the rule (derelict lower).
  Signs, neon and marquee keep their bloom. Done when `06-combat-outside`
  is under its new target and still shows lit windows. Rules:
  `travel-and-stops.md` facades section.

- [x] 3. **Street lamps and light pools.** (Carries step 2's leftover: `06-combat-outside`
  must reach its target here; after step 2 its excess is lamp light on the walls and the
  big sign, not windows.) `scripts/travel/facades/facade_fixtures.gd`
  (wall lamps and their `OmniLight3D`): energies, range and colour so each
  lamp makes a pool with dark between pools; lamp heads may bloom. Keep the
  12-light cap, `light_cull_mask = 1` set before `add_child`, no light on a
  bay or side-street side. Do not touch the van's lights. Done when the
  street shots show pools and gaps, and raiders in `04-combat-*` still read.

- [x] 4. **Shared grime include.** Create `scenes/shaders/grime.gdshaderinc`
  with `hash21`, `hash22`, `noise21`, `fbm` and `crack_field` moved out of
  `asphalt_surface.gdshader`; the asphalt and sidewalk shaders
  `#include` it and lose their copies. Pure refactor: the road must look
  identical (compare shots and stats, both unchanged). Van shaders are not
  touched.

- [x] 5. **Facade walls, part 1: no shimmer.** In `facade_surface.gdshader`,
  fade every repeating pattern finer than about 0.25 m (brick courses and
  bricks, corrugation, glass mullions, panel grids, plank grain) to its
  average colour with `fwidth`, so distant walls stop moiréing. Nothing else
  changes. Done when `03-idle-outside` shows no stripes on the far walls.

- [x] 6. **Facade walls, part 2: the road's grime.** Same shader, switched
  to the grime include. Per style, base tones inside the albedo budget;
  layers in the road's order: grain, rain streaks down from sills and roof
  line, soot, a dirt band at the foot that matches the sidewalk's edge dirt,
  stains and cracks; existing `grime`, `soot`, `damage`, `overgrowth`
  uniforms drive them. Roughness 0.78..0.95, metallic 0..0.3. If the shader
  goes past about 600 lines, move the style functions into
  `scenes/shaders/facade_styles.gdshaderinc`. May split into 6a (brick,
  stone, plaster) and 6b (concrete panel, glass, corrugated, bare frame).

- [x] 7a. **Prop budget in one place.** `facade_materials.gd`: `prop_material()`
  caps non-emissive albedo at linear luminance 0.40 (hue kept), clamps
  roughness to >= 0.7 and metallic to <= 0.3, so every prop and set-piece
  is held to the rule; the named palette (iron, metal grey, rust pipe,
  awnings, street furniture) is retuned to already sit inside it; the phone
  booth glass is a dim fluorescent-green pane (1.25) instead of blue-white
  2.0; the unused `unshaded_material` is gone.

- [x] 7b. **Set-piece literals and light tints.** The set-piece scripts under
  `scripts/travel/facades/set_pieces/`: retune the `prop_material` literals
  the clamp now overrides (tape, laundry white and yellow, hazard, crane
  yellow, pump, net, plank; roughness and metallic) so source matches what
  renders. Lit panes go under the threshold, warm: `pedestrian_bridge`
  `bridge_glow` (blue-white 1.8), `chapel` `clock_face` (1.4 near-white).
  Sources keep their bloom but lose the white or blue-white tint: `gas_canopy`
  `canopy_glow`, `parking_deck` `fluoro` (to sick fluorescent green-white),
  `rooftop_billboard` `flood` (tungsten). `mural.gd`'s texture colours
  inside the albedo budget. Beacons, flame, neon, `glass_crown` cyan stay.

- [ ] 7c. **Large prop surfaces on grime.** Awnings, roll-up doors, loading
  docks and set-piece bodies over about 1 m move from flat `prop_material`
  colour to a grime shader material (a small shader on the grime include
  with a `surface_size_m` uniform and a base colour), in
  `facade_props_ground.gd` and the set-pieces that build big slabs.

- [ ] 8. **Industrial surface.** Rewrite `scenes/corridor/industrial_surface.gdshader`
  in the road's recipe on the grime include: metre-scale panels and seams
  (`surface_size_m` uniform as the sidewalk does), rivets, rust and oil
  stains, floor-level dirt, roughness and metallic in range. Every scene and
  script that uses it keeps working (garage, mechanic and shop bays, the
  vestibule, the shop booth, `garage_lounge.gd`, `mechanic_workshop.gd`,
  `warehouse_look.gd`); pass real sizes where they use it.

- [ ] 9. **Stops, part 1: vestibule, elevator, garage.** `stop_vestibule.gd` /
  `.tscn`, `stop_elevator.gd` / `.tscn`, `garage_bay.tscn`,
  `garage_lounge.gd`: materials to the budget (bay metallic 0.5..0.72 down
  to 0.3 or less), the stop lit by its own fixtures as pools. Rules:
  `travel-and-stops.md`, invariant 14 (`bay mouth clear:` in the smoke).

- [ ] 10. **Stops, part 2: shop.** `shop_bay.tscn`, `shop_booth_materials.gd`
  (steel, deck, grill, rivet metallic 0.78..0.92 down to 0.3 or less, grimed),
  keeping the booth's build order, flyer RNG order and every sprite as is.

- [ ] 11. **Stops, part 3: mechanic and warehouse.** `mechanic_bay.tscn`,
  `mechanic_workshop.gd`, `warehouse_bay.tscn`, `warehouse_look.gd`,
  `warehouse_interior.gd`: same treatment.

- [ ] 12. **Junctions, side streets, statue, overheads.** `corridor_t_junction`,
  `corridor_crossroads.tscn`, `side_street_branch`, `act_statue.tscn`,
  `facade_overheads.gd`: consistent with the street (grime shaders, budget,
  pools). The side street's `FarVoid` stays black.

- [ ] 13. **Van audit.** Read the van shots against the budget. Change only a
  clear break (and say which); expected result: no change, recorded here.
  Carries step 3's leftover: `06-combat-outside` (mean 0.036, target 0.015)
  did not move when the lamps changed, so its wall wash is the van's own
  mask-1 lights in `scenes/van/van.tscn` (`DoorSpill` energy 6.5, range
  18 m, shadowed; `RearCone` 5.5; the `ExteriorLight` directional "moon",
  which is light from nothing you can point at) plus big lit panes close to
  the camera. Decide with the owner before dimming them: the door spill is
  what lets the player see raiders at the doors.

- [ ] 14. **Wrap-up.** Clear the art-style "off-style today" 3D list of
  everything fixed, add what was learnt to `travel-and-stops.md` and
  `art-style.md`, regenerate `docs/PROJECT_MAP.md`, delete this file in the
  final commit.

## Log (shot stats per step)

Step 1 writes the baseline here; every later step appends its after-numbers
for the shots it changed.

### Step 1 baseline (2026-09-25, before any art change)

```
shot                           kind     mean    p95   clip%    sat
01-idle-front                  hud    0.0272 0.0896   0.134  0.369
02-idle-back                   clean  0.0091 0.0217   0.000  0.428
03-idle-outside                clean  0.0177 0.0242   1.007  0.360
04-combat-front                hud    0.0075 0.0098   0.000  0.192
05-combat-back                 clean  0.0091 0.0217   0.000  0.420
06-combat-outside              clean  0.0989 0.8520   7.359  0.286
07-elevator-stop-front         hud    0.0074 0.0071   0.000  0.202
08-elevator-stop-back          clean  0.0096 0.0237   0.000  0.429
09-elevator-stop-outside       clean  0.0052 0.0107   0.020  0.564
10-rear-park-stop-front        hud    0.0075 0.0073   0.000  0.211
11-rear-park-stop-back         clean  0.0091 0.0217   0.000  0.427
12-rear-park-stop-outside      clean  0.0123 0.0190   0.849  0.398
```

### Step 2 after (night windows, `window_emission` 0.5)

Lit panes: warm tungsten, amber, a few dim green, max channel 0.5 (fire windows keep
their bloom); dark glass rough 0.5, metal 0. `06` fell from 0.099 to 0.036 mean and
7.4 to 1.6% clipped but is still over its target: what is left is the wall lamps
(step 3) and the signs. The rest is unchanged within noise.

```
shot                           kind     mean    p95   clip%    sat
03-idle-outside                clean  0.0094 0.0208   0.244  0.363
06-combat-outside              clean  0.0357 0.1775   1.562  0.362
12-rear-park-stop-outside      clean  0.0045 0.0173   0.008  0.391
```

### Step 3 after (lamp pools: `SpotLight3D` straight down, 38°, range 8 m, energy 8 x district)

The wall halos round each lamp are gone and each lamp now lays a pool on the sidewalk and
the wall foot, dark between lamps. Commercial lamps are tungsten and industrial lamps
mercury green-grey instead of blue-white. `06` did not move: its excess is the van's own
lights and near lit panes (moved to step 13), not the lamps.

```
shot                           kind     mean    p95   clip%    sat
03-idle-outside                clean  0.0092 0.0230   0.237  0.401
06-combat-outside              clean  0.0358 0.1775   1.606  0.422
09-elevator-stop-outside       clean  0.0052 0.0107   0.020  0.564
12-rear-park-stop-outside      clean  0.0045 0.0173   0.008  0.391
```

### Step 4 after (shared grime include, pure refactor)

`scenes/shaders/grime.gdshaderinc` holds `hash21`, `hash22`, `noise21`, `fbm`,
`crack_field` (the asphalt's, `hash22` cells) and `crack_field_h21` (the sidewalk's
older seeding, kept so its crack layout does not move). The moved bodies were checked
verbatim against the old shaders. The shots are not pixel-deterministic between runs
(the untouched van interior `08` and `11` differ too), so the check is the stats: all
within run-to-run noise of step 3.

```
shot                           kind     mean    p95   clip%    sat
03-idle-outside                clean  0.0095 0.0234   0.236  0.403
06-combat-outside              clean  0.0360 0.1763   1.676  0.423
09-elevator-stop-outside       clean  0.0052 0.0107   0.020  0.564
12-rear-park-stop-outside      clean  0.0045 0.0176   0.008  0.392
```

### Step 5 after (fwidth fade of fine facade patterns)

`facade_surface.gdshader` gets `pattern_fade`, `line_fade` and `soft_line`: brick courses
and joints, stone joints, panel seams and bolts, corrugation, the corrugated 1 m line,
roll-up ribs, plank stripes, gaps and grain, and glass-curtain mullions fade per axis
(`fwidth(UV)`) to their average colour and flat relief as they go under a few pixels;
close up they are unchanged. The before run's `03` showed ring moiré on corrugated walls;
the after run shows none. Facade layouts differ between smoke runs (the run seed), so the
street numbers move with the buildings on screen, not with this change: `03`'s higher p95
is two big lit panes right next to the camera in this run's layout.

```
shot                           kind     mean    p95   clip%    sat
03-idle-outside  (before run)  clean  0.0135 0.0274   0.198  0.415
03-idle-outside                clean  0.0202 0.0955   0.281  0.449
06-combat-outside              clean  0.0275 0.1668   0.874  0.388
09-elevator-stop-outside       clean  0.0053 0.0107   0.025  0.564
12-rear-park-stop-outside      clean  0.0081 0.0222   0.007  0.436
```

### Step 6 after (road grime on facade walls)

`facade_surface.gdshader` includes `grime.gdshaderinc` instead of its own noise copies and
`apply_overlays` is the road's layer order: grain (faded with `fwidth`), a broad `grime`
wash, rain streaks down from the roof line and under each sill, roof-line and window-head
soot, a foot dirt band in the sidewalk's `dirt_color`, stains, `crack_field` cracks driven
by `grime` and `damage`, then the old overgrowth and damage patches; wall roughness clamps
to 0.78..0.95, frames 0.78/0.8, and non-emissive albedo is capped at luminance 0.4. Styles
kept their own structure, so no 6b was needed. Numbers are within run-to-run noise of
step 4; the change reads on close walls (`03` right side), not in the means.

```
shot                           kind     mean    p95   clip%    sat
03-idle-outside                clean  0.0094 0.0232   0.236  0.407
06-combat-outside              clean  0.0364 0.1783   1.673  0.422
09-elevator-stop-outside       clean  0.0052 0.0107   0.020  0.564
12-rear-park-stop-outside      clean  0.0043 0.0176   0.008  0.383
```

### Step 7a after (prop budget in `prop_material`)

`prop_material()` holds every flat prop to the budget (albedo <= 0.40 linear luminance,
roughness >= 0.7, metallic <= 0.3); the named palette is retuned and the phone booth glass is
a dim green pane. Props are a small share of the frame, so the means are step 6's: `06` stays
over its target on the big sign and lamp heads, not on props.

```
shot                           kind     mean    p95   clip%    sat
03-idle-outside                clean  0.0091 0.0230   0.237  0.407
06-combat-outside              clean  0.0354 0.1773   1.604  0.429
09-elevator-stop-outside       clean  0.0052 0.0107   0.020  0.564
12-rear-park-stop-outside      clean  0.0043 0.0176   0.008  0.383
```

### Step 7b after (set-piece literals and light tints)

Set-piece `prop_material` literals now sit inside the budget as written (tape, hazard, crane
yellow, laundry white and yellow, net desaturated; every roughness >= 0.7, beacons included,
consistent across their shared cache keys). `bridge_glow` and `clock_face` are warm panes
under the threshold (0.85 and 0.88 emission luminance); `canopy_glow`, its light and `flood`
are tungsten, `fluoro` sick green-white; the mural palettes are capped (base 0.20, the rest
0.30). No set-piece rolls in the smoke's shots, so the numbers are 7a's within noise.

```
shot                           kind     mean    p95   clip%    sat
03-idle-outside                clean  0.0089 0.0227   0.244  0.406
06-combat-outside              clean  0.0350 0.1783   1.560  0.430
09-elevator-stop-outside       clean  0.0052 0.0107   0.020  0.564
12-rear-park-stop-outside      clean  0.0043 0.0173   0.008  0.383
```
