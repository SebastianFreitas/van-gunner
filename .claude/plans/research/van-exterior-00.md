# van-exterior P0 audit (in progress)

Shots: scratchpad `shots_p0/` (v04-v07 added by smoke_shots.gd `_save_van_view` target param).

- v04 front wall (z=2 looking -Z): the front end is a diamond-mesh cage (Bulkhead) filling the
  centre, a flat dark-grey slab (CabDoor/FrontPartition panel) on the left standing proud of the
  cage, a lit wooden frame (bench/pegboard) at far left. The cage bars are thick and cut straight
  through the shot; the slab doesn't meet the bowed wall or ceiling arc. The player capsule sits in
  view (the camera is inside the player's spot) — move v04 off the capsule or hide the player.
- v07 ceiling-front ended up facing the REAR doors (the rear arch and PC rig). Its target is being
  mirrored; fix it to face -Z.
- Old outside shots (shots_cables2 v01-v03): the exterior reads as a black bus tube with no cab
  silhouette.

## Correction (shots_p0b)
- The diamond cage in v04 is the MID bulkhead (`van_bulkhead.gd`, "Mid/rear cargo bulkhead"), not
  the front end. The cab end is the flat panelled wall behind the PC rig and relay rack (v07,
  01-idle-front's far end is the rear). v07 is correct as-is; the player capsule is now hidden.
- So the owner's "3 assets" at the front end are FrontPartition LeftPanel/RightPanel + CabDoor
  (+ possibly the ceiling edge). Confirm by reading `front_partition.gd` / `cab_door.gd` shaping.

## Front end root causes (Explore of front_partition.gd, cab_door.gd, van_hull_mesh.gd)
Built as three slabs at z=-4.65 (PARTITION_Z): FrontPartition LeftPanel + RightPanel
(`scripts/van/front_partition.gd`, 0.20 m thick, x_inset 0.02, 12x28 grid) and CabDoor
(`scripts/interactions/cab_door.gd`, 0.22 m thick, fixed half-width 0.775, x_inset 0.0, 14x28
grid, plus 6 BoxMesh trims at z≈-4.51). Both use `VanHullMesh.build_vaulted_xy_slab()`
(`scripts/van/van_hull_mesh.gd` ~l.81 clamps vertices above the vault). Ceiling is
`van_ceiling.gd` `vault_y_at(x) = 3.05 + 0.38*(1-(x/2.04)^2)`; wall is `van_side_wall.gd`
`wall_x_at` ~l.368.
1. Flat BoxShape3D collision on curved meshes (front_partition.gd ~l.70, cab_door.gd ~l.78).
2. Inset mismatch 0.02 vs 0.0 → step/gap at the panel/door seams; thicknesses differ (0.20/0.22).
3. Coarse grids + the vault clamp → a stepped/jagged top edge where the pieces meet the arc.
4. Trims stick out to z≈-4.51, into the PC rig (z≈-4.55) and relay rack (z≈-4.20) zone.
5. Different `wall_size_m` shader params per piece → texture scale jumps at the seams.
Fix direction (P2): ONE `VanFrontWall` mesh from one closed section outline (floor, `wall_x_at`,
the ceiling vault, the same inset), with the doorway cut as a hole, the door as a leaf inside the
hole, a single material scale, collision from convex strips that follow the outline, and trims
flush.
