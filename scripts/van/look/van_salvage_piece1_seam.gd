extends RefCounted
## Salvage piece 1, seam: the ring-inside upper post's room face fillets into the rear arch.

## The run before F0 over which the room face's normals blend into the seam's.
const BLEND := 0.10

var _o: RefCounted


func _init(owner: RefCounted) -> void:
	_o = owner


## Emits the strips for the room-face polyline `line` (top end first, down to the flat face), and
## `top`, the skipped upper-prism quad [a0, b0, b1, a1] that ends at line[0] (empty if none).
func build(line: PackedVector2Array, top: Array) -> void:
	var fil_pts: PackedVector2Array = _o.fil_pts
	var fil_n: PackedVector2Array = _o.fil_n
	var front_z: float = _o.FRONT_Z
	var close_z: float = _o.rear_in_z
	var centre := Vector2(_o.ARC_CX, _o.ARC_Y)
	var room_x: float = _o.ROOM_X
	var dirs := PackedVector2Array()
	for p in line:
		dirs.append((p - centre).normalized() if p.y > centre.y + 0.0001 else Vector2.RIGHT)
	# rows[r][i]: [position, normal]; r 0 is F0, then F1, F2, F4, then the close row.
	var rows: Array = []
	for r in range(3, -1, -1):
		var row: Array = []
		var off := fil_pts[r].x - room_x
		for i in line.size():
			var n2 := fil_n[r]
			row.append([_pt(line[i] + dirs[i] * off, fil_pts[r].y),
					Vector3(dirs[i].x * n2.x, dirs[i].y * n2.x, n2.y)])
		rows.append(row)
	var close: Array = []
	for i in line.size():
		close.append([_pt(line[i], close_z), rows[3][i][1]])
	rows.append(close)
	for i in line.size() - 1:
		var j := i + 1
		var e := line[j] - line[i]
		if not (is_equal_approx(line[i].x, room_x) and is_equal_approx(line[j].x, room_x)):
			# An arc edge: its front strip is flat-shaded, as the skipped quads were.
			var nrm := Vector3(-e.y, e.x, 0.0).normalized()
			if nrm.dot(Vector3(centre.x - line[i].x, centre.y - line[i].y, 0.0)) < 0.0:
				nrm = -nrm
			var f0: Array = rows[0][i]
			var g0: Array = rows[0][j]
			var a := _pt(line[i], front_z)
			var b := _pt(line[j], front_z)
			# Over the last BLEND before F0 the normal turns from the flat one to F0's.
			var mi := _pt(line[i], f0[0].z - BLEND)
			var mj := _pt(line[j], g0[0].z - BLEND)
			_o.mesh.tri(a, b, mj, nrm)
			_o.mesh.tri(a, mj, mi, nrm)
			_o.mesh.tri_n(mi, mj, g0[0], nrm, nrm, g0[1])
			_o.mesh.tri_n(mi, g0[0], f0[0], nrm, g0[1], f0[1])
		for r in rows.size() - 1:
			var a0: Array = rows[r][i]
			var b0: Array = rows[r][j]
			var b1: Array = rows[r + 1][j]
			var a1: Array = rows[r + 1][i]
			_o.mesh.tri_n(a0[0], b0[0], b1[0], a0[1], b0[1], b1[1])
			_o.mesh.tri_n(a0[0], b1[0], a1[0], a0[1], b1[1], a1[1])
	# The top end's lens between the chord F0-close and the rows: a fan out along the polyline.
	for r in range(1, rows.size() - 1):
		_o.mesh.tri_n(rows[0][0][0], rows[r][0][0], rows[r + 1][0][0],
				rows[0][0][1], rows[r][0][1], rows[r + 1][0][1])
	if not top.is_empty():
		_top_quad(top, line[0], rows)


## The top quad re-emitted as a fan whose edge at `end` carries every row vertex lying on it.
func _top_quad(q: Array, end: Vector2, rows: Array) -> void:
	var first := Vector2(q[0].x, q[0].y).distance_to(end) < 0.0005
	var e_f: Vector3 = q[0] if first else q[1]
	var e_r: Vector3 = q[3] if first else q[2]
	var o_f: Vector3 = q[1] if first else q[0]
	var o_r: Vector3 = q[2] if first else q[3]
	var span := e_r.z - e_f.z
	var ts: Array[float] = []
	for row: Array in rows:
		var p: Vector3 = row[0][0]
		var t := (p.z - e_f.z) / span
		if Vector2(p.x, p.y).distance_to(end) < 0.0005 and t > 0.0001 and t < 0.9999:
			ts.append(t)
			# The blend row's vertex on the same edge (the front strip's, BLEND before F0).
			if row == rows[0]:
				ts.append((p.z - BLEND - e_f.z) / span)
	ts.sort()
	var chain: Array[Vector3] = [e_f]
	for t in ts:
		chain.append(Vector3(e_f.x, e_f.y, e_f.z + span * t))
	chain.append(e_r)
	var e := Vector2(o_f.x - e_f.x, o_f.y - e_f.y)
	var out := Vector3(-e.y, e.x, 0.0).normalized()
	if out.y < 0.0:
		out = -out
	for k in chain.size() - 1:
		_o.mesh.tri(o_f, chain[k], chain[k + 1], out)
	_o.mesh.tri(o_f, e_r, o_r, out)


func _pt(p: Vector2, z: float) -> Vector3:
	return Vector3(p.x, p.y, z)
