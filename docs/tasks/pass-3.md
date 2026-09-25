# Pass 3: split van.tscn

This is the active task. Work the steps in order, tick each box when its commit lands, and delete this file in the final commit.

## Goal

`scenes/van/van.tscn` is 87 KB and 312 nodes, and every van change touches it. Split its three big subtrees into their own scenes so each can be read and diffed on its own, without changing what the game does. No gameplay, balance, UI or content changes. If something looks like a bug, put it in the final report instead of fixing it.

## Rules for the whole pass

- Behaviour-identical, proven three ways after every step: the headless check is clean, the smoke test passes with an unchanged fingerprint, and the new scene dump (step 1) of the instantiated van is byte-identical to its baseline. Never `--bless` either baseline after step 1.
- Node names, node paths from the van root, node order, groups, scripts, properties and signal connections stay exactly as they are. Only which file declares a node changes.
- Existing `unique_id=` values move with their node into the new file unchanged. The instance node left in `van.tscn` keeps the unique_id the subtree root had.
- Out of scope: `scenes/corridor/corridor_segment.tscn`. Its four `Structure/VariantN` subtrees share seven meshes and materials (BrokenPlatformMesh, CrossBeamMesh, LampMaterial, LampMesh, PipeMaterial, RibMaterial, VerticalRibMesh), so splitting them means extracting all of those to `.tres` for a 20 KB scene. And the segment is instanced over and over at runtime, where nested instancing costs something on every spawn. It isn't worth it.

## What the mapping found (2026-09-25)

- No `editable` instances, no overridden instance children, 21 `instance=` nodes, 45 ext_resources, 37 sub_resources.
- **Shell** (`TravelPath/VanFollow/VanRig/Interior/Shell`, StaticBody3D, 184 nodes incl. root): uses 28 sub_resources and 11 ext_resources. Only `WallMaterial` is shared with nodes outside it: `Interior/FrontPartition/LeftPanel`, `RightPanel` and `Interior/CabDoor/Mesh`. `cab_door.gd`, `front_partition.gd` and `rear_doors.gd` also read `walls.wall_material` at runtime, so the material must stay one shared instance.
- **BreachController** (`TravelPath/VanFollow/VanRig/EnemyContainer/BreachController`, 32 nodes): no sub_resources, 2 ext_resources. Six children carry `bars_path = NodePath("../../../Interior/Shell/.../IronCross")`, plain NodePaths into the Shell that `breach_point.gd` resolves at runtime. They stay valid verbatim because the tree is unchanged.
- **HUD** (`HUD`, CanvasLayer, 43 nodes): no sub_resources, 6 ext_resources. All 25 `unique_name_in_owner` nodes in `van.tscn` are in it, and `van.gd` finds every one of them by `%Name` (its `@onready` block, lines 24–51); no other script does. Once HUD is its own scene their owner is the HUD root, so `%Name` from the van root stops resolving: those lookups become `$HUD/%Name`. Its 8 `[connection]` lines go from HUD buttons to the van root (`.`), so they stay in `van.tscn` unchanged. `van_overlays.gd` adds overlays to `van.get_node("HUD")`, which still works.
- `cab_door.gd` uses `owner` to reach the van root. CabDoor isn't in any moved subtree; no script in a moved subtree uses `owner`.

## Steps

- [x] 1. Scene dump guard. A tools-only headless dump of the instantiated `van.tscn` (not added to the tree, so no `_ready`), written deterministically and diffed against a committed baseline: every node's path, class, script, groups, persistent signal connections and stored properties, with embedded resources printed by content and a sharing id so a split that duplicates a shared resource shows up as a diff. `py -3 tools/scene_dump.py`, `--bless` only in this step. If the untouched tree logs errors, stop and report.
- [ ] 2. Extract `WallMaterial` to `scenes/van/van_wall_material.tres`, referenced from `van.tscn` as an ext_resource everywhere it was a SubResource. Dump identical.
- [ ] 3. Shell → `scenes/van/van_shell.tscn`, instanced at the same place. Dump identical.
- [ ] 4. BreachController → `scenes/van/van_breach_points.tscn`. Dump identical.
- [ ] 5. HUD → `scenes/ui/run_hud.tscn`; `van.gd`'s `%Name` lookups become `$HUD/%Name`. Dump identical.
- [ ] 6. Docs: the `van.tscn` size note in CLAUDE.md and `.claude/agents/implementer.md`, the scene dump command in CLAUDE.md's Commands, the HUD `%` rule in `.claude/rules/van-shell-and-hud.md`, the `bars_path` crossing in `.claude/rules/enemies-and-breaching.md`, regenerate PROJECT_MAP, delete this file.
- [ ] 7. Final report to the owner: before and after sizes of `van.tscn`, the new scenes, anything that looked like a bug.
