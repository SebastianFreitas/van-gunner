class_name VanFloorHeight
extends RefCounted
## Floor top height (rig-local metres) anywhere in the cabin: the raised mid slab, the side-door step well and the stairs to the rear floor.

const RAISE := 0.30
const WELL_X := -2.46        ## left bay: floor stays at 0 for x <= this
const WELL_RAMP := 0.30      ## raiders have no physics, so the well lip is a smooth ramp 0 -> RAISE
const DOOR_X0 := -3.30       ## bulkhead doorway, stairs span
const DOOR_X1 := -1.92
const STAIR_END_Z := 1.66
const SLAB_Z0 := -4.60
const SLAB_Z1 := 1.00
const _CABIN_HALF_X := 3.36
const _CABIN_Z1 := 6.58
const _WELL_Z0 := -4.40
const _WELL_Z1 := -1.93


static func at(x: float, z: float) -> float:
	if absf(x) >= _CABIN_HALF_X or z < SLAB_Z0 or z > _CABIN_Z1:
		return 0.0
	if z < SLAB_Z1:
		if z >= _WELL_Z0 and z <= _WELL_Z1 and x < WELL_X + WELL_RAMP:
			return RAISE * clampf((x - WELL_X) / WELL_RAMP, 0.0, 1.0)
		return RAISE
	if z <= STAIR_END_Z and x >= DOOR_X0 and x <= DOOR_X1:
		return RAISE * (STAIR_END_Z - z) / (STAIR_END_Z - SLAB_Z1)
	return 0.0
