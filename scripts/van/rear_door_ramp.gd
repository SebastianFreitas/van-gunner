extends RefCounted
## Rear door ramp: the pressed-steel funnel around the door opening. A straight slope runs from the
## closed leaves' cabin face back and outward to the deep face, then a drop steps out to the wall
## ledge; every crease is rounded. Also owns the frame collision that follows the slope.

const _Flange := preload("res://scripts/van/rear_door_flange.gd")
const _Surround := preload("res://scripts/van/rear_door_surround.gd")
const _LeafBuild := preload("res://scripts/van/rear_door_leaf_build.gd")
## Collision steps along the slope.
const SLOPE_STEPS := 4


## Sweeps the funnel profile along the opening outline. `z_in` is the leaves' cabin face, `z0` the
## portal's cabin face.
static func build(portal: Node3D, mat: Material, half: float, top: float, y_a: float,
		z_in: float, z0: float) -> void:
	var prof := _profile(z_in, z0 - _Surround.DEPTH, z0 - _Surround.LEDGE_DEPTH)
	var pn := _profile_normals(prof)
	var base: PackedVector2Array = _Surround._opening(half, top, 0.0)
	var probe: PackedVector2Array = _Surround._opening(half, top, 0.1)
	var rows: Array[PackedVector2Array] = []
	for v in prof:
		rows.append(_Surround._opening(half, top, v.x))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := base.size()
	for i in range(n - 1):
		for j in range(prof.size() - 1):
			# The flat deep band is the portal's own deep prisms (pocket and holes); skip it here
			# so no two faces share its plane.
			var z_deep := z0 - _Surround.DEPTH
			if is_equal_approx(prof[j].y, z_deep) and is_equal_approx(prof[j + 1].y, z_deep):
				continue
			var quad: Array[Vector3] = []
			var norms: Array[Vector3] = []
			for ij: Vector2i in [Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i, j + 1),
					Vector2i(i + 1, j + 1)]:
				var p2: Vector2 = rows[ij.y][ij.x]
				p2.y = y_a if (ij.x == 0 or ij.x == n - 1) else p2.y
				quad.append(Vector3(p2.x, p2.y, prof[ij.y].y))
				var dir: Vector2 = (probe[ij.x] - base[ij.x]).normalized()
				norms.append(Vector3(dir.x * pn[ij.y].x, dir.y * pn[ij.y].x, pn[ij.y].y).normalized())
			_tri(st, quad[0], quad[1], quad[3], norms[0], norms[1], norms[3])
			_tri(st, quad[0], quad[3], quad[2], norms[0], norms[3], norms[2])
	var m := MeshInstance3D.new()
	m.name = "RampLoft"
	m.mesh = st.commit()
	m.material_override = mat
	portal.add_child(m)


## The cross-section as (offset from the opening, z) points: slope, deep face, drop and ledge
## start, each crease rounded.
static func _profile(z_in: float, z_deep: float, z_ledge: float) -> Array[Vector2]:
	var ring_o := _Flange.WALL_OFFSET + _Surround.RING_W
	var a := Vector2(_Surround.RAMP_IN, z_in)
	var c1 := Vector2(_Surround.RAMP_OUT, z_deep)
	var c2 := Vector2(ring_o, z_deep)
	var c3 := Vector2(ring_o, z_ledge)
	var e := Vector2(ring_o + _Surround.BEVEL, z_ledge)
	var pts: Array[Vector2] = [a]
	pts.append_array(_round(a, c1, c2))
	pts.append_array(_round(c1, c2, c3))
	pts.append_array(_round(c2, c3, e))
	return pts


## A quadratic arc that cuts the corner `c` between `prev` and `next` by BEVEL along each side.
static func _round(prev: Vector2, c: Vector2, next: Vector2) -> Array[Vector2]:
	var t1 := c + (prev - c).normalized() * _Surround.BEVEL
	var t2 := c + (next - c).normalized() * _Surround.BEVEL
	var out: Array[Vector2] = []
	for k in range(_Surround.BEVEL_STEPS + 1):
		var t := float(k) / float(_Surround.BEVEL_STEPS)
		out.append(t1 * (1.0 - t) * (1.0 - t) + c * 2.0 * (1.0 - t) * t + t2 * t * t)
	return out


## Per profile point, the unit normal toward the cabin side (offset, z), smoothed over the bevels.
static func _profile_normals(prof: Array[Vector2]) -> Array[Vector2]:
	var segs: Array[Vector2] = []
	for j in range(prof.size() - 1):
		var t := (prof[j + 1] - prof[j]).normalized()
		segs.append(Vector2(t.y, -t.x))
	var out: Array[Vector2] = []
	for j in range(prof.size()):
		var s := Vector2.ZERO
		if j > 0:
			s += segs[j - 1]
		if j < segs.size():
			s += segs[j]
		out.append(s.normalized())
	return out


## One triangle with per-vertex normals, wound clockwise seen from its normals (Godot's front).
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3,
		nc: Vector3) -> void:
	var v: Array[Vector3] = [a, b, c]
	var nn: Array[Vector3] = [na, nb, nc]
	if (b - a).cross(c - a).dot(na + nb + nc) > 0.0:
		v = [a, c, b]
		nn = [na, nc, nb]
	for k in range(3):
		st.set_normal(nn[k])
		st.set_uv(Vector2(v[k].x / VanInteriorSize.LENGTH + 0.5, v[k].y / VanInteriorSize.WALL_HEIGHT))
		st.add_vertex(v[k])


## Frame collision: per pillar a collar, stepped boxes down the slope, the deep ring and the ledge
## beyond it, in height bands that follow the leaning wall; over the top the same steps.
static func frame_blocker(doors: Node3D, profile: VanBodyProfile, z_in: float, z0: float) -> void:
	var half := VanInteriorSize.REAR_DOOR_HALF
	var top := VanInteriorSize.REAR_DOOR_TOP
	var ring := _Flange.WALL_OFFSET + _Surround.RING_W
	# The slope (now narrower than the flange band) starts right outside the opening.
	var band := _Surround.RAMP_IN
	var out_d := _Surround.RAMP_OUT
	var blocker := doors.get_node("Blocker")
	for old in blocker.get_children():
		if old.name.begins_with("Frame"):
			old.free()
	var bands: Array[float] = [0.0, 1.0, 2.0, top]
	for s: float in [-1.0, 1.0]:
		for b in range(bands.size() - 1):
			var wall := profile.inner_x_at(bands[b + 1])
			var h := bands[b + 1] - bands[b]
			var y := bands[b] + h * 0.5
			# The strip under the flange band is only the thin collar; the slope starts beyond it.
			_frame_box(blocker, "FrameCollar%d_%d" % [b, int(s)],
					Vector3(s * (half + band * 0.5), y, 0.0), Vector3(band, h, 0.10), z0)
			var step := (out_d - band) / float(SLOPE_STEPS)
			for k in range(SLOPE_STEPS):
				var d0 := band + step * float(k)
				_frame_box(blocker, "FrameSlope%d_%d_%d" % [b, k, int(s)],
						Vector3(s * (half + d0 + step * 0.5), y, 0.0),
						Vector3(step, h, _slope_depth(d0, z_in, z0)), z0)
			_frame_box(blocker, "FrameRing%d_%d" % [b, int(s)],
					Vector3(s * (half + out_d + (ring - out_d) * 0.5), y, 0.0),
					Vector3(ring - out_d, h, _Surround.DEPTH), z0)
			var ledge := wall - half - ring
			if ledge > 0.02:
				_frame_box(blocker, "FrameLedge%d_%d" % [b, int(s)],
						Vector3(s * (half + ring + ledge * 0.5), y, 0.0),
						Vector3(ledge, h, _Surround.LEDGE_DEPTH), z0)
	var step_t := out_d / float(SLOPE_STEPS)
	for k in range(SLOPE_STEPS):
		var d0 := step_t * float(k)
		_frame_box(blocker, "FrameTopSlope%d" % k,
				Vector3(0.0, top + d0 + step_t * 0.5, 0.0),
				Vector3((half + d0 + step_t) * 2.0, step_t, maxf(0.1, _slope_depth(d0, z_in, z0))), z0)
	_frame_box(blocker, "FrameTop", Vector3(0.0, top + out_d + (ring - out_d) * 0.5, 0.0),
			Vector3((half + ring) * 2.0, ring - out_d, _Surround.DEPTH), z0)


## The deep face's z in a leaf hinge's local frame (the portal's cabin face is 5 cm plus half its
## thickness cabin-ward of the hinge, as in `RearDoorPortal.build`).
static func z_deep_rel() -> float:
	return -0.05 - _LeafBuild.STREET_HALF - 0.02 - _Surround.DEPTH


## The slope's z at offset `d` from the opening.
static func z_at(d: float, z_in: float, z_deep: float) -> float:
	return z_in + (d - _Surround.RAMP_IN) / (_Surround.RAMP_OUT - _Surround.RAMP_IN) * (z_deep - z_in)


## The slope's offset from the opening at depth `z`.
static func d_at(z: float, z_in: float, z_deep: float) -> float:
	return _Surround.RAMP_IN + (z - z_in) / (z_deep - z_in) * (_Surround.RAMP_OUT - _Surround.RAMP_IN)


## A frame lying on the slope at the point (`xy`, `z`), where `away` is the unit xy direction from
## the opening outward there. Local x runs down the slope (outward, cabin-ward), local z points
## into the steel (so the face is at local z 0 and parts stand out along -z), local y completes it.
static func frame(xy: Vector2, away: Vector2, z: float, z_in: float, z_deep: float) -> Transform3D:
	var span := _Surround.RAMP_OUT - _Surround.RAMP_IN
	var drop := z_in - z_deep
	var norm := sqrt(span * span + drop * drop)
	var into := Vector3(away.x * drop / norm, away.y * drop / norm, span / norm)
	var down := Vector3(away.x * span / norm, away.y * span / norm, -drop / norm)
	return Transform3D(Basis(down, into.cross(down), into), Vector3(xy.x, xy.y, z))


## How far cabin-ward of the portal face `z0` the slope surface is at offset `d`.
static func _slope_depth(d: float, z_in: float, z0: float) -> float:
	var f := (d - _Surround.RAMP_IN) / (_Surround.RAMP_OUT - _Surround.RAMP_IN)
	var z := z_in + f * ((z0 - _Surround.DEPTH) - z_in)
	return maxf(z0 - z, 0.1)


## One box of frame collision, reaching `size.z` cabin-ward from the portal's cabin face `z0`.
static func _frame_box(blocker: Node, node_name: String, pos: Vector3, size: Vector3,
		z0: float) -> void:
	var node := CollisionShape3D.new()
	node.name = node_name
	var shape := BoxShape3D.new()
	shape.size = size
	node.shape = shape
	node.position = Vector3(pos.x, pos.y, z0 - size.z * 0.5)
	blocker.add_child(node)
