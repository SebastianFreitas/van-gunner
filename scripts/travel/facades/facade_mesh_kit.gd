extends RefCounted
## Box-and-quad helpers shared by every facade prop builder: gated boxes into a SurfaceTool,
## committing an ArrayMesh node, and single BoxMesh nodes for props that need a rotation.


const _FacadeKeepOut := preload("res://scripts/travel/facades/facade_keep_out.gd")
const _FacadeBody := preload("res://scripts/travel/facades/facade_body.gd")

## Props start this far off the face so they never z-fight the body wall.
const FACE_GAP := 0.02
const SHADOW_OFF := GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
const SHADOW_ON := GeometryInstance3D.SHADOW_CASTING_SETTING_ON
## Fog ends well before this; every prop mesh stops rendering at the same range.
const VISIBILITY_RANGE := 64.0

## The six box faces as corner-index quads (see add_box's bit-encoded corners) plus normal.
const _BOX_FACES := [
	[4, 6, 7, 5, 1.0, 0.0, 0.0], [0, 2, 3, 1, -1.0, 0.0, 0.0],
	[2, 6, 7, 3, 0.0, 1.0, 0.0], [0, 4, 5, 1, 0.0, -1.0, 0.0],
	[1, 5, 7, 3, 0.0, 0.0, 1.0], [0, 4, 6, 2, 0.0, 0.0, -1.0],
]


## Emits an axis-aligned box as six quads into st if it clears the keep-out.
static func add_box(st: SurfaceTool, center: Vector3, size: Vector3, keep_out: RefCounted) -> bool:
	if not keep_out.allows(_FacadeKeepOut.box_aabb(center, size)):
		return false
	add_box_ungated(st, center, size)
	return true


## For sub-parts whose parent box already passed the gate (rails on a landing, rungs on a
## ladder): emits without a keep-out check so a part never straddles the boundary alone.
static func add_box_ungated(st: SurfaceTool, center: Vector3, size: Vector3) -> void:
	var h := size * 0.5
	var pts: Array[Vector3] = []
	for i in 8:
		pts.append(center + Vector3(
			h.x * (2.0 * float((i >> 2) & 1) - 1.0), h.y * (2.0 * float((i >> 1) & 1) - 1.0),
			h.z * (2.0 * float(i & 1) - 1.0)
		))
	var uv := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for f: Array in _BOX_FACES:
		_FacadeBody.add_quad(
			st, pts[f[0]], pts[f[1]], pts[f[2]], pts[f[3]], uv[0], uv[1], uv[2], uv[3],
			Vector3(f[4], f[5], f[6])
		)


## Commits a SurfaceTool into a shadow-tagged, range-culled MeshInstance3D under host.
static func commit(
	host: Node3D, st: SurfaceTool, node_name: String, material: Material, shadows: bool
) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = st.commit()
	mi.material_override = material
	mi.cast_shadow = SHADOW_ON if shadows else SHADOW_OFF
	mi.visibility_range_end = VISIBILITY_RANGE
	host.add_child(mi)
	return mi


## A single BoxMesh node for a prop that needs its own rotation (an awning's pitch). A pitch
## about Z swaps the box's x/y extents, so the gate AABB is widened conservatively for that case.
static func add_box_node(
	host: Node3D, node_name: String, size: Vector3, center: Vector3, rotation_rad: Vector3,
	material: Material, shadows: bool, keep_out: RefCounted
) -> MeshInstance3D:
	var gate_size := size
	if rotation_rad.z != 0.0:
		var xy := maxf(size.x, size.y)
		gate_size = Vector3(xy, xy, size.z)
	if not keep_out.allows(_FacadeKeepOut.box_aabb(center, gate_size)):
		return null
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.position = center
	mi.rotation = rotation_rad
	mi.material_override = material
	mi.cast_shadow = SHADOW_ON if shadows else SHADOW_OFF
	mi.visibility_range_end = VISIBILITY_RANGE
	host.add_child(mi)
	return mi
