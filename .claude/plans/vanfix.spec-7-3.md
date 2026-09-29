## Spec 7-3: bulkhead frame joints stop z-fighting (vanfix phase 7)

Audit rows (all state closed): `TopRail_n vs TopRail_n+1` (0.00124 each, the 0.008 m joint
overlap: both segments' z faces at ±frame_depth/2 overlap there), `TopRail_4/5 vs MidPost_1`
(post top face at `_vault_y(x)` within 4 mm of the rail's top face), `BottomRail vs MidPost_1`
(post bottom face at `kick_height` = rail bottom face), `RightWallPost_13 vs TopRail_9` and
`OpeningInnerPost vs TopRail_0` (z faces at 0.92, both 0.16 deep).

### Target files
`scripts/van/van_bulkhead_mesh.gd` (`add_panel_post`, `add_curved_header`). Read
`scripts/van/van_bulkhead.gd` lines 100-160 for the callers; do not edit it unless step 3 needs
the rail depth there.

### Logic steps
1. `add_panel_post` (MidPost_*): the post runs from the BottomRail's centre to the top rail's
   centre so both end faces are buried 4 cm inside the rails:
   `var y0: float = bulkhead.kick_height + bulkhead.frame_thickness * 0.5`,
   `var y1: float = bulkhead._vault_y(x) - bulkhead.frame_thickness * 0.45`,
   `height = y1 - y0` (skip if < 0.05 as today), centre `(y0 + y1) * 0.5`. Depth and width
   unchanged (0.85 / 0.75 of frame).
2. `add_curved_header` (TopRail_*): depth `bulkhead.frame_depth - 0.04` (z faces 2 cm inside
   every post's z faces, D12), so posts and the door header (0.16 deep) never share a z plane
   with a rail segment. Add a `##`-documented const `RAIL_DEPTH_INSET := 0.04` at the top of
   the file.
3. Joints: consecutive segments of equal depth overlap by 0.008 m and their z faces coincide.
   Alternate the depth: even `i` uses `frame_depth - RAIL_DEPTH_INSET`, odd `i` uses
   `frame_depth - RAIL_DEPTH_INSET - 0.04` (2 cm shallower each side), so at every joint the z
   faces are 2 cm apart. Keep the `length + 0.008` overlap and the names `TopRail_%d`.
   Check the door header box in `van_bulkhead.gd` (~line 115, depth `frame_depth`): its z
   faces are then 2 cm off the even segments' and 4 cm off the odd ones', fine.

### Do not touch
Node names and count (the scene dump must stay identical), wall posts, the diagonal mesh
netting (`MESH_WEAVE_Z`), collision.

### Verification
`py -3 tools/check.py`, `py -3 tools/smoke.py`, `py -3 tools/scene_dump.py` (identical, no
bless), `py -3 tools/van_audit.py`; then
`grep "^FLICKER" .godot/van_audit/report.txt | grep "Bulkhead/"` must show no TopRail/MidPost/
BottomRail/WallPost/OpeningInnerPost pair among themselves. Rows against Generator/Hub are
phase 8.
