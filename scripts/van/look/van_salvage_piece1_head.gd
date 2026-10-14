extends RefCounted
## Salvage piece 1, head panel outline: the ring's outer-arc angle list shared with the post's ring clip.

const _Flange := preload("res://scripts/van/rear_door_flange.gd")

## Where the head panel's flat top ends (the ring clip's end), x.
const TAB_X := 2.0


## The ring arc's angles, 0..PI/2 in ARC_STEPS steps plus `a_s` (the head arc's start), so the head
## arc's vertices are vertices of the ring clip and the two share every edge.
static func angles(a_s: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var inserted := false
	for k in range(_Flange.ARC_STEPS + 1):
		var a := PI * 0.5 * float(k) / float(_Flange.ARC_STEPS)
		if not inserted and a_s <= a + 0.0001:
			inserted = true
			if a_s < a - 0.0001:
				out.append(a_s)
		out.append(a)
	return out


## Nose, base, top corner, the arc from `a_s` up to the ring's top (angles >= a_s of `angs`,
## on the circle about `c` of radius `r`), then the room face's arc `arc` down to the flat face.
static func outline(arc: PackedVector2Array, back_x: float, angs: PackedFloat32Array, a_s: float,
		c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(3.053, 2.54), Vector2(3.273, 2.54),
			Vector2(back_x, arc[0].y)])
	for a in angs:
		if a >= a_s - 0.0001:
			pts.append(c + Vector2(cos(a), sin(a)) * r)
	# On past the ring's top along its flat top to TAB_X, then down to the room arc's top level.
	pts.append(Vector2(TAB_X, c.y + r))
	pts.append(Vector2(TAB_X, arc[0].y))
	pts.append_array(arc)
	return pts
