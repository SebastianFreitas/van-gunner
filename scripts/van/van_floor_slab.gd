class_name VanFloorSlab
extends RefCounted
## Closed meshes for the raised mid-room slab (with its side-door step well) and the two stand-in stair treads.

const SLAB_X := 3.33
const SLAB_Z0 := -4.73
const SLAB_Z1 := 1.00
const SLAB_Y0 := -0.25
const SLAB_Y1 := 0.30
const WELL_X1 := -2.46
const WELL_Z0 := -4.40
const WELL_Z1 := -1.93
const WELL_Y := 0.0


## The slab as one closed mesh: the step well is cut into its top and -X side.
static func build_mid_slab() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var xl := -SLAB_X
	var xr := SLAB_X
	var xw := WELL_X1
	var zs := [SLAB_Z0, WELL_Z0, WELL_Z1, SLAB_Z1]
	# Top: three z bands across the main part, outer strips beside the well.
	VanFloorSkin.set_tag(st, &"top")
	for i in 3:
		_xz(st, SLAB_Y1, xw, xr, zs[i], zs[i + 1], true)
	_xz(st, SLAB_Y1, xl, xw, zs[0], zs[1], true)
	_xz(st, SLAB_Y1, xl, xw, zs[2], zs[3], true)
	# Well floor and its three inner walls.
	_xz(st, WELL_Y, xl, xw, WELL_Z0, WELL_Z1, true)
	VanFloorSkin.set_tag(st, &"cavity")
	_yz(st, xw, WELL_Y, SLAB_Y1, WELL_Z0, WELL_Z1, -1.0)
	_xy(st, WELL_Z0, xl, xw, WELL_Y, SLAB_Y1, 1.0)
	_xy(st, WELL_Z1, xl, xw, WELL_Y, SLAB_Y1, -1.0)
	# Bottom, sides and end faces.
	VanFloorSkin.set_tag(st, &"edge")
	_xz(st, SLAB_Y0, xl, xr, SLAB_Z0, SLAB_Z1, false)
	# -X side: full height outside the well, below the well floor inside it.
	_yz(st, xl, SLAB_Y0, SLAB_Y1, zs[0], zs[1], -1.0)
	_yz(st, xl, SLAB_Y0, WELL_Y, zs[1], zs[2], -1.0)
	_yz(st, xl, SLAB_Y0, SLAB_Y1, zs[2], zs[3], -1.0)
	# +X side and the two end faces (split at the well edge to match the top).
	_yz(st, xr, SLAB_Y0, SLAB_Y1, SLAB_Z0, SLAB_Z1, 1.0)
	_xy(st, SLAB_Z0, xl, xw, SLAB_Y0, SLAB_Y1, -1.0)
	_xy(st, SLAB_Z0, xw, xr, SLAB_Y0, SLAB_Y1, -1.0)
	_xy(st, SLAB_Z1, xl, xw, SLAB_Y0, SLAB_Y1, 1.0)
	_xy(st, SLAB_Z1, xw, xr, SLAB_Y0, SLAB_Y1, 1.0)
	return _commit(st)


## A closed box between two corners.
static func build_box(lo: Vector3, hi: Vector3, top_tag: StringName = &"top") -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	VanFloorSkin.set_tag(st, top_tag)
	_xz(st, hi.y, lo.x, hi.x, lo.z, hi.z, true)
	VanFloorSkin.set_tag(st, &"edge")
	_xz(st, lo.y, lo.x, hi.x, lo.z, hi.z, false)
	_yz(st, lo.x, lo.y, hi.y, lo.z, hi.z, -1.0)
	_yz(st, hi.x, lo.y, hi.y, lo.z, hi.z, 1.0)
	_xy(st, lo.z, lo.x, hi.x, lo.y, hi.y, -1.0)
	_xy(st, hi.z, lo.x, hi.x, lo.y, hi.y, 1.0)
	return _commit(st)


static func _commit(st: SurfaceTool) -> ArrayMesh:
	st.generate_tangents()
	return st.commit()


static func _xz(st: SurfaceTool, y: float, x0: float, x1: float, z0: float, z1: float,
		up: bool) -> void:
	_quad(st, Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1),
			Vector3.UP if up else Vector3.DOWN)


static func _yz(st: SurfaceTool, x: float, y0: float, y1: float, z0: float, z1: float,
		sign_x: float) -> void:
	_quad(st, Vector3(x, y0, z0), Vector3(x, y1, z0), Vector3(x, y1, z1), Vector3(x, y0, z1),
			Vector3(sign_x, 0.0, 0.0))


static func _xy(st: SurfaceTool, z: float, x0: float, x1: float, y0: float, y1: float,
		sign_z: float) -> void:
	_quad(st, Vector3(x0, y0, z), Vector3(x1, y0, z), Vector3(x1, y1, z), Vector3(x0, y1, z),
			Vector3(0.0, 0.0, sign_z))


## Adds a quad facing n; Godot front faces wind clockwise, so the order flips to match.
static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		n: Vector3) -> void:
	var pts: Array[Vector3] = [a, b, c, d]
	if (c - b).cross(b - a).dot(n) < 0.0:
		pts = [d, c, b, a]
	var uvs: Array[Vector2] = []
	for p in pts:
		uvs.append(Vector2(p.x + p.z, p.y + p.z * 0.5))
	for k in [0, 1, 2, 0, 2, 3]:
		st.set_normal(n)
		st.set_uv(uvs[k])
		st.add_vertex(pts[k])
