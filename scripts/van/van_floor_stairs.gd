class_name VanFloorStairs
extends RefCounted
## The doorway's welded scrap stairs: two angle-iron stringers, a ribbed low tread, a checker high tread and weld beads.

## The stringers' top edge: (z, y) at the foot and at the head, 2 cm inside MidSlab's end face.
const LINE_Z0 := 1.68
const LINE_Y0 := 0.04
const LINE_Z1 := 0.98
const LINE_Y1 := 0.30
const WEB_T := 0.02
const WEB_H := 0.08
const FLANGE_W := 0.06
const FLANGE_T := 0.02
## Outer (jamb side) web x and the direction the flange points, per stringer.
const _STRINGERS := [[&"StringerL", -3.28, 1.0, 10.0], [&"StringerR", -1.94, -1.0, 11.0]]
const TREAD_X0 := -3.26
const TREAD_X1 := -1.96
const LOW_Z0 := 1.36
const LOW_Z1 := 1.66
const LOW_Y0 := 0.115
const LOW_Y1 := 0.165
const HIGH_Z0 := 0.98
const HIGH_Z1 := 1.36
const HIGH_Y0 := 0.275
const HIGH_Y1 := 0.335
const BEAD_W := 0.04
const BEAD_LEN := 0.06
const BEAD_GAP := 0.01
const BEAD_CORNER := 0.05
const BEAD_SINK := 0.02
const BEAD_RISE := 0.015
const BEAD_YAW := deg_to_rad(8.0)


## Adds `StringerL`, `StringerR`, `TreadLow`, `TreadHigh` and `StairBeads` under `parent`.
static func add(parent: Node3D) -> void:
	for s in _STRINGERS:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_add_stringer(st, float(s[1]), float(s[2]))
		_add_mesh(parent, String(s[0]), st, VanFloorSkin.material(VanFloorSkin.TINT_D, s[3], 0.95, 1.0))
	var low := SurfaceTool.new()
	low.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_box(low, LOW_Y0, LOW_Y1, LOW_Z0, LOW_Z1, &"top")
	# One transverse rib, its base ends 2 cm inside the tread's ends.
	var rib_z := (LOW_Z0 + LOW_Z1) * 0.5
	VanFloorSheet.add_rib(low, Vector2(TREAD_X0 + 0.02, rib_z), Vector2(TREAD_X1 - 0.02, rib_z), LOW_Y1)
	_add_mesh(parent, "TreadLow", low, VanFloorSkin.material(VanFloorSkin.TINT_B, 12.0, 0.95, 1.0))
	var high := SurfaceTool.new()
	high.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_box(high, HIGH_Y0, HIGH_Y1, HIGH_Z0, HIGH_Z1, &"checker")
	_add_mesh(parent, "TreadHigh", high, VanFloorSkin.material(VanFloorSkin.TINT_D, 13.0, 0.95, 1.0))
	var beads := SurfaceTool.new()
	beads.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_beads(beads)
	_add_mesh(parent, "StairBeads", beads, VanFloorSkin.material(VanFloorSkin.TINT_D, 14.0, 0.95, 1.0))


## Height of the stringers' top edge at `z`.
static func line_y(z: float) -> float:
	return lerpf(LINE_Y0, LINE_Y1, (z - LINE_Z0) / (LINE_Z1 - LINE_Z0))


## One closed L-section bar swept along the sloped line: web on x `web_x` (`dir` points the flange
## inward), a flange along its top edge.
static func _add_stringer(st: SurfaceTool, web_x: float, dir: float) -> void:
	var prof: Array[Vector2] = [
		Vector2(web_x, -WEB_H), Vector2(web_x + dir * WEB_T, -WEB_H),
		Vector2(web_x + dir * WEB_T, -FLANGE_T), Vector2(web_x + dir * FLANGE_W, -FLANGE_T),
		Vector2(web_x + dir * FLANGE_W, 0.0), Vector2(web_x, 0.0)]
	var hints: Array[Vector3] = [Vector3.DOWN, Vector3(dir, 0.0, 0.0), Vector3.DOWN,
			Vector3(dir, 0.0, 0.0), Vector3.UP, Vector3(-dir, 0.0, 0.0)]
	VanFloorSkin.set_tag(st, &"edge")
	for i in prof.size():
		var a := prof[i]
		var b := prof[(i + 1) % prof.size()]
		VanFloorSheet._quad(st, _at(a, LINE_Z1), _at(b, LINE_Z1), _at(b, LINE_Z0), _at(a, LINE_Z0),
				hints[i])
	# End caps as the web and flange rectangles.
	for z in [LINE_Z0, LINE_Z1]:
		var out := Vector3(0.0, 0.0, 1.0 if z == LINE_Z0 else -1.0)
		VanFloorSheet._quad(st, _at(prof[0], z), _at(prof[1], z), _at(Vector2(prof[1].x, 0.0), z),
				_at(Vector2(prof[0].x, 0.0), z), out)
		VanFloorSheet._quad(st, _at(prof[2], z), _at(prof[3], z), _at(prof[4], z),
				_at(Vector2(prof[2].x, 0.0), z), out)


## A profile point (x, offset below the top edge) at depth `z`.
static func _at(p: Vector2, z: float) -> Vector3:
	return Vector3(p.x, line_y(z) + p.y, z)


## A closed tread box over the doorway width; only the top carries `top_tag`.
static func _add_box(st: SurfaceTool, y0: float, y1: float, z0: float, z1: float,
		top_tag: StringName) -> void:
	var lo := Vector3(TREAD_X0, y0, z0)
	var hi := Vector3(TREAD_X1, y1, z1)
	VanFloorSkin.set_tag(st, top_tag)
	VanFloorSheet._quad(st, Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z),
			Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z), Vector3.UP)
	VanFloorSkin.set_tag(st, &"edge")
	VanFloorSheet._quad(st, Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z),
			Vector3(hi.x, lo.y, hi.z), Vector3(lo.x, lo.y, hi.z), Vector3.DOWN)
	VanFloorSheet._quad(st, Vector3(lo.x, lo.y, lo.z), Vector3(lo.x, lo.y, hi.z),
			Vector3(lo.x, hi.y, hi.z), Vector3(lo.x, hi.y, lo.z), Vector3.LEFT)
	VanFloorSheet._quad(st, Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, lo.y, hi.z),
			Vector3(hi.x, hi.y, hi.z), Vector3(hi.x, hi.y, lo.z), Vector3.RIGHT)
	VanFloorSheet._quad(st, Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z),
			Vector3(hi.x, hi.y, lo.z), Vector3(lo.x, hi.y, lo.z), Vector3.FORWARD)
	VanFloorSheet._quad(st, Vector3(lo.x, lo.y, hi.z), Vector3(hi.x, lo.y, hi.z),
			Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z), Vector3.BACK)


## Beads along both ends of each tread, and on the sheet at each stringer's foot.
static func _add_beads(st: SurfaceTool) -> void:
	var flip := 1.0
	for tread in [[LOW_Z0, LOW_Z1, LOW_Y1], [HIGH_Z0, HIGH_Z1, HIGH_Y1]]:
		for x in [TREAD_X0, TREAD_X1]:
			var span: float = float(tread[1]) - float(tread[0])
			var count := int((span - 2.0 * BEAD_CORNER + BEAD_GAP) / (BEAD_LEN + BEAD_GAP))
			var used := count * (BEAD_LEN + BEAD_GAP) - BEAD_GAP
			for j in count:
				flip = -flip
				var z: float = float(tread[0]) + (span - used) * 0.5 + BEAD_LEN * 0.5 \
						+ j * (BEAD_LEN + BEAD_GAP)
				_add_bead(st, Vector2(x, z), Vector2(0.0, 1.0), flip, float(tread[2]))
	for s in _STRINGERS:
		var web_x: float = s[1]
		var inner: float = web_x + float(s[2]) * WEB_T
		flip = -flip
		_add_bead(st, Vector2(inner, 1.62), Vector2(0.0, 1.0), flip, 0.0)
		flip = -flip
		_add_bead(st, Vector2(web_x + float(s[2]) * FLANGE_W * 0.5, LINE_Z0), Vector2(1.0, 0.0), flip, 0.0)


## One bead segment centred on `mid` (xz) running along `u`, from `top` - 0.02 to + 0.015.
static func _add_bead(st: SurfaceTool, mid: Vector2, u: Vector2, flip: float, top: float) -> void:
	var ua := u.rotated(BEAD_YAW * flip)
	var na := Vector2(ua.y, -ua.x)
	var y0 := top - BEAD_SINK
	var y1 := top + BEAD_RISE
	var ring: Array[Vector2] = [mid - ua * BEAD_LEN * 0.5 - na * BEAD_W * 0.5,
			mid + ua * BEAD_LEN * 0.5 - na * BEAD_W * 0.5,
			mid + ua * BEAD_LEN * 0.5 + na * BEAD_W * 0.5,
			mid - ua * BEAD_LEN * 0.5 + na * BEAD_W * 0.5]
	var c := (ring[0] + ring[2]) * 0.5
	VanFloorSkin.set_tag(st, &"weld")
	for i in 4:
		var a := ring[i]
		var b := ring[(i + 1) % 4]
		var out3 := Vector3((a + b).x * 0.5 - c.x, 0.0, (a + b).y * 0.5 - c.y)
		VanFloorSheet._quad(st, Vector3(a.x, y0, a.y), Vector3(b.x, y0, b.y),
				Vector3(b.x, y1, b.y), Vector3(a.x, y1, a.y), out3)
	VanFloorSheet._quad(st, Vector3(ring[0].x, y1, ring[0].y), Vector3(ring[1].x, y1, ring[1].y),
			Vector3(ring[2].x, y1, ring[2].y), Vector3(ring[3].x, y1, ring[3].y), Vector3.UP)
	VanFloorSheet._quad(st, Vector3(ring[0].x, y0, ring[0].y), Vector3(ring[1].x, y0, ring[1].y),
			Vector3(ring[2].x, y0, ring[2].y), Vector3(ring[3].x, y0, ring[3].y), Vector3.DOWN)


static func _add_mesh(parent: Node3D, node_name: String, st: SurfaceTool, mat: Material) -> void:
	st.generate_tangents()
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.layers = VanLighting.LAYER_VAN_INTERIOR
	parent.add_child(mi)
