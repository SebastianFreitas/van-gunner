## Spec 7-2: inner shell patches clear of plates and the bulkhead (vanfix phase 7)

Context: c00ca93 moved plates and patches off the ribs (`_clear_of_ribs`) and stood each patch
2 cm proud of its ring. The audit now shows the patches landing on plates and on the bulkhead's
top rail, and one plate on the generator:
`PlateL1 vs PatchWall2(_Ring)`, `PlateR6 vs PatchWall6(_Ring)`, `PlateR4 vs PatchWall6_Ring`,
`Bulkhead/TopRail_0 vs PatchCeil0`, `TopRail_1 vs PatchCeil0_Ring`,
`FuseBox/Generator/RadiatorTank vs PlateR3`.

### Target file
`scripts/van/look/van_inner_shell.gd` only (`_build_plates`, `_place_plate`, `_build_patches`,
`_build_wall_patch`, `_build_ceiling_patch`, `_clear_of_ribs`).

### Symbols
- `var _plate_rects: Array[Array] = []` is not wanted; instead add
  `var _placed_plates: Dictionary = {}` ## side (float) -> Array[Rect2] of plate rects (z, y)
  filled by `_build_plates` (store each side's `placed` array under key `side`), reset at the
  top of `rebuild_look`.
- `const BULKHEAD_Z := 1.0` ## bulkhead frame plane; its posts and rails are 0.16 deep
- `const BULKHEAD_HALF := 0.08`
- `const GENERATOR_ZONE := Rect2(0.35, 0.0, 1.45, 1.3)` ## (z, y) span of the fuse box
  generator on the right wall; plates on side +1 stay out of it. The implementer must confirm
  the generator's z/y extent by grepping `Interior/Props/FuseBox` in `scenes/van/van.tscn`
  (its transform origin) and `scripts/van/look/van_generator.gd`/`van_generator_parts.gd`
  for its footprint size, and set the Rect2 to that footprint grown by 0.02; report the values.
- `func _clear_of_plates(side: float, rect: Rect2) -> bool:` false when `rect.grow(RIB_CLEAR)`
  intersects any rect in `_placed_plates.get(side, [])`.

### Logic steps
1. `_clear_of_ribs(z0, z1)`: also return false when the span comes within
   `BULKHEAD_HALF + RIB_CLEAR` of `BULKHEAD_Z` (same test as a rib with half depth
   `BULKHEAD_HALF`). This covers plates, wall patches and ceiling patches at once.
2. `_place_plate`: for `side > 0.0` also `continue` when `rect.grow(RIB_CLEAR)` intersects
   `GENERATOR_ZONE`.
3. `_build_wall_patch`: in each try, build `var prect := Rect2(z - (r + 0.015), y - (r + 0.015),
   2.0 * (r + 0.015), 2.0 * (r + 0.015))` and `continue` when `not _clear_of_plates(side,
   prect)`. (Patches are built after plates, as today.)
4. Nothing else changes (RNG draw order inside a try stays y, z).

### Edge cases
- `_build_plates` must store the arrays before `_build_patches` runs (it already runs first).
- A patch or plate that finds no spot is not built (D6).

### Rules
GDScript conventions (tabs, typed, `##` on new fields and constants). The file is 311 lines:
if it passes 330, move `_clear_of_ribs`, `_clear_of_plates` and the zone constants into a new
RefCounted helper `scripts/van/look/van_inner_shell_fit.gd` (no `class_name`, `extends
RefCounted`, `##` summary line) taking the shell in `_init`, and keep the shell under 300.

### Verification
`py -3 tools/check.py`, `py -3 tools/smoke.py`, `py -3 tools/scene_dump.py` (must stay
identical, no bless), then `py -3 tools/van_audit.py` and
`grep "^FLICKER" .godot/van_audit/report.txt | grep InnerShell`: no row may pair two
InnerShell meshes, or an InnerShell mesh with Bulkhead, Generator or RearWall. Rows against
`VanLook/Cables` and `Generator/@Node3D@264/FlangeA vs WallRibR4_4` are phase 8/cables, ignore.
