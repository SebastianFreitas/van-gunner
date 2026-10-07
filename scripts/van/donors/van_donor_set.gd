class_name VanDonorSet
extends RefCounted
## The donor vans chosen for one interior and how they split the walls.
##
## Polys are PackedVector2Array in surface cm (z, v): v is y on walls and x on
## floor and ceiling. Surfaces are &"left_wall", &"right_wall", &"floor" and
## &"ceiling".

## Front-to-back order.
var donors: Array[VanDonor] = []
## {surface, outline, donor_id}
var regions: Array[Dictionary] = []
## {surface, kind, parts, donor_a, donor_b, z_band}. A HORIZONTAL cut with no turned ends has
## the empty z_band Vector2(INF, -INF) (x > y): every Lines check treats it as never conflicting.
var boundaries: Array[Dictionary] = []
## {window_id, surface, asset_id, opening, piece_outline, glazing}; rear entries add hole_grow
## (Vector3 metres: x hinge side, y top, z bottom, each 0..0.04)
var windows: Array[Dictionary] = []
var dropped_cuts := 0
