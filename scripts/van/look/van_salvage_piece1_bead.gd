extends RefCounted
## Salvage piece 1, return bead: a half-round pressed lip along the room face's corner arc, just behind
## the head panel, so the long flat face between panel and arch has a lit edge and a shadow line.

## The bead's centre z, half-width along z, and height off the face.
const Z_C := 5.70
const HALF_W := 0.05
const HEIGHT := 0.03
const STEPS := 4


## Writes the bead into `wall.mesh`: one strip per arc segment of `wall._room_line` (its points
## before the flat face), smooth-shaded, with a fan cap at each end.
func build(wall: RefCounted) -> void:
	var m: RefCounted = wall.mesh
	var line: PackedVector2Array = wall._room_line
	var room_x: float = wall.ROOM_X
	var centre := Vector2(wall.ARC_CX, wall.ARC_Y)
	var arc := PackedVector2Array()
	for p in line:
		if is_equal_approx(p.x, room_x):
			break
		arc.append(p)
	var prof: Array = []
	for k in range(STEPS + 1):
		var th := PI * float(k) / float(STEPS)
		prof.append([HEIGHT * sin(th), Z_C - HALF_W * cos(th),
				Vector2(HALF_W * sin(th), -HEIGHT * cos(th)).normalized()])
	for i in arc.size() - 1:
		for k in STEPS:
			var q: Array = [_v(arc[i], centre, prof[k]), _v(arc[i + 1], centre, prof[k]),
					_v(arc[i + 1], centre, prof[k + 1]), _v(arc[i], centre, prof[k + 1])]
			m.tri_n(q[0][0], q[1][0], q[2][0], q[0][1], q[1][1], q[2][1])
			m.tri_n(q[0][0], q[2][0], q[3][0], q[0][1], q[2][1], q[3][1])
	for end in [0, arc.size() - 1]:
		var side := 1.0 if end == 0 else -1.0
		var dir := (arc[end] - centre).normalized() if arc[end].y > centre.y + 0.0001 \
				else Vector2.RIGHT
		var t := Vector2(-dir.y, dir.x) * side
		var out := Vector3(t.x, t.y, 0.0)
		for k in STEPS:
			var a: Array = _v(arc[end], centre, prof[k])
			var b: Array = _v(arc[end], centre, prof[k + 1])
			m.tri(a[0], b[0], Vector3(arc[end].x, arc[end].y, Z_C), out)


## The bead's vertex over arc point `p` for profile row `r` ([height, z, normal]), and its normal.
## The bead rises toward the room, against the arc's outward direction.
func _v(p: Vector2, centre: Vector2, r: Array) -> Array:
	var dir := (p - centre).normalized() if p.y > centre.y + 0.0001 else Vector2.RIGHT
	var h: float = r[0]
	var nrm: Vector2 = r[2]
	return [Vector3(p.x - dir.x * h, p.y - dir.y * h, r[1]),
			Vector3(-dir.x * nrm.x, -dir.y * nrm.x, nrm.y)]
