class_name VanKitFootprint
extends RefCounted
## The van's fixed footprint for kit pieces: door bays, mouths, free bands and the inward band.
## All metres in van-local space (x across, y up, z along).

## Both side doors: the z span the cable runs hop over.
const DOOR_Z_MIN := -4.655
const DOOR_Z_MAX := -2.185
## Kit pieces live in this z range.
const KIT_Z_MIN := -4.5
const KIT_Z_MAX := 4.55
## How far a wall piece may reach in from wall_x_at(y).
const INWARD_BAND := 0.25
## Raider lanes and climb gaps run from the liner to this x (the breach `Entry` markers).
const ENTRY_X := 1.7
## Outer x bound for wall-side volumes: past any liner x.
const WALL_X_OUT := 3.0
const AISLE_HALF_X := 0.6
const AISLE_Y := 2.2
const CLEAR_M := 0.02
## Window centre height and side window centres (wall z, metres).
const WINDOW_Y := 1.775
const WINDOW_ZC := {&"left_rear": 2.835, &"left_front": -0.375,
	&"right_rear": 2.835, &"right_front": -0.375}
## z ranges where a full-height cut fits between door bay, window pieces and the van ends.
const FREE_BANDS: Array[Vector2] = [
	Vector2(-2.085, -1.787), Vector2(1.037, 1.423), Vector2(4.247, 4.55),
]
## Side window piece zones (z) and their y range.
const PIECE_ZONES: Array[Vector2] = [Vector2(1.423, 4.247), Vector2(-1.787, 1.037)]
const PIECE_Y := Vector2(0.885, 2.665)


## Door bay z range, the same on both sides.
static func door_bay() -> Vector2:
	return Vector2(DOOR_Z_MIN, DOOR_Z_MAX)


## Mouths: the door bays plus the window pieces' zones, as z ranges.
static func mouths() -> Array[Vector2]:
	var out: Array[Vector2] = [door_bay()]
	out.append_array(PIECE_ZONES)
	return out


## True when the z span lies inside one free band.
static func in_free_band(z_min: float, z_max: float) -> bool:
	for band: Vector2 in FREE_BANDS:
		if z_min >= band.x and z_max <= band.y:
			return true
	return false


## The innermost x a wall piece may reach at height y (positive side).
static func inward_x(walls: VanSideWall, y: float) -> float:
	return walls.wall_x_at(y) - INWARD_BAND
