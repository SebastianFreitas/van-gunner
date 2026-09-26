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
