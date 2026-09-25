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
   the before and after PNGs yourself.
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

- [ ] 2. **Night windows.** In `scenes/corridor/facade_surface.gdshader`,
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

- [ ] 3. **Street lamps and light pools.** `scripts/travel/facades/facade_fixtures.gd`
  (wall lamps and their `OmniLight3D`): energies, range and colour so each
  lamp makes a pool with dark between pools; lamp heads may bloom. Keep the
  12-light cap, `light_cull_mask = 1` set before `add_child`, no light on a
  bay or side-street side. Do not touch the van's lights. Done when the
  street shots show pools and gaps, and raiders in `04-combat-*` still read.

- [ ] 4. **Shared grime include.** Create `scenes/shaders/grime.gdshaderinc`
  with `hash21`, `hash22`, `noise21`, `fbm` and `crack_field` moved out of
  `asphalt_surface.gdshader`; the asphalt and sidewalk shaders
  `#include` it and lose their copies. Pure refactor: the road must look
  identical (compare shots and stats, both unchanged). Van shaders are not
  touched.

- [ ] 5. **Facade walls, part 1: no shimmer.** In `facade_surface.gdshader`,
  fade every repeating pattern finer than about 0.25 m (brick courses and
  bricks, corrugation, glass mullions, panel grids, plank grain) to its
  average colour with `fwidth`, so distant walls stop moiréing. Nothing else
  changes. Done when `03-idle-outside` shows no stripes on the far walls.

- [ ] 6. **Facade walls, part 2: the road's grime.** Same shader, switched
  to the grime include. Per style, base tones inside the albedo budget;
  layers in the road's order: grain, rain streaks down from sills and roof
  line, soot, a dirt band at the foot that matches the sidewalk's edge dirt,
  stains and cracks; existing `grime`, `soot`, `damage`, `overgrowth`
  uniforms drive them. Roughness 0.78..0.95, metallic 0..0.3. If the shader
  goes past about 600 lines, move the style functions into
  `scenes/shaders/facade_styles.gdshaderinc`. May split into 6a (brick,
  stone, plaster) and 6b (concrete panel, glass, corrugated, bare frame).

- [ ] 7. **Facade props and set-pieces.** `scripts/travel/facades/facade_materials.gd`
  (`prop_material`, `unshaded_material`) and the set-piece scripts under
  `scripts/travel/facades/set_pieces/`: every flat prop colour inside the
  albedo budget, roughness >= 0.7, metallic <= 0.3; emissive parts follow
  the emission rule (windows under the threshold, lamps and neon may
  bloom). Large prop surfaces (over about 1 m: awnings, roll-up doors,
  loading docks, set-piece bodies) move to a grime shader material instead
  of flat colour. Split by family if large (7a ground props, 7b upper props,
  7c set-pieces).

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
