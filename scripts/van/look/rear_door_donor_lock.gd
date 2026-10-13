extends RefCounted
## The donor leaf's scrap lock rod on the edge beam's cabin face: a rebar held by six welded
## flat-bar U guides and a crude keeper at each end. Static, hinge-local metres, z negative is
## toward the cabin; the beam's cabin face is z -0.23.

const _Geo := preload("res://scripts/van/iron_cross_geo.gd")
const _Panels := preload("res://scripts/van/look/rear_door_donor_panels.gd")
const _Welds := preload("res://scripts/van/look/rear_door_donor_welds.gd")

const ROD_X := 2.5005
const ROD_Z := -0.26
const ROD_R := 0.0125
const ROD_Y0 := -1.25
const ROD_Y1 := 1.78
## The U profile: x span, leg x spans, and the z of the beam face, leg ends and front bar's face.
const U_X0 := 2.476
const U_X1 := 2.525
const LEG_W := 0.012
const Z_BEAM := -0.23
const Z_LEG := -0.2725
const Z_FRONT := -0.2845
const GUIDE_H := 0.03
const GUIDE_Y: Array[float] = [-1.15, -0.55, 0.29, 0.70, 1.10, 1.51]
## Keepers: the U runs from the plate's inner face to its open end, the plate closes the rod's end.
const PLATE_T := 0.012
const KEEP_BOT_Y0 := -1.27
const KEEP_BOT_Y1 := -1.21
const KEEP_TOP_Y0 := 1.745
const KEEP_TOP_Y1 := 1.80
## The donor Handle's place on the beam's cabin face; its Mount sits 0.5 cm back into the beam.
const HANDLE_X := 2.5605
const HANDLE_Z := -0.25


## Builds the rod, guides and keepers under `hinge`, places its Handle, appends every node to `out`.
static func build(hinge: Node3D, rng: RandomNumberGenerator, out: Array[Node3D]) -> void:
	var rust := SurfaceTool.new()
	rust.begin(Mesh.PRIMITIVE_TRIANGLES)
	var weld := SurfaceTool.new()
	weld.begin(Mesh.PRIMITIVE_TRIANGLES)
	var feet: Array[Vector2] = []
	for i in GUIDE_Y.size():
		var y := GUIDE_Y[i]
		_u(rust if i % 2 == 0 else weld, y - GUIDE_H * 0.5, y + GUIDE_H * 0.5)
		feet.append(Vector2(y, GUIDE_H))
	# Bottom keeper: rust U, weld-steel plate. Top keeper: the other way round.
	_u(rust, KEEP_BOT_Y0 + PLATE_T, KEEP_BOT_Y1)
	_plate(weld, KEEP_BOT_Y0, KEEP_BOT_Y0 + PLATE_T)
	feet.append(Vector2((KEEP_BOT_Y0 + PLATE_T + KEEP_BOT_Y1) * 0.5, KEEP_BOT_Y1 - KEEP_BOT_Y0
			- PLATE_T))
	_u(weld, KEEP_TOP_Y0, KEEP_TOP_Y1 - PLATE_T)
	_plate(rust, KEEP_TOP_Y1 - PLATE_T, KEEP_TOP_Y1)
	feet.append(Vector2((KEEP_TOP_Y0 + KEEP_TOP_Y1 - PLATE_T) * 0.5, KEEP_TOP_Y1 - PLATE_T
			- KEEP_TOP_Y0))
	_Panels.add(hinge, "DonorLockSteel", rust.commit(), _Welds.rust_steel(), Vector3.ZERO,
			Vector3.ZERO, out)
	_Panels.add(hinge, "DonorLockSteelWeld", weld.commit(), _Welds.weld_steel(), Vector3.ZERO,
			Vector3.ZERO, out)
	var geo := _Geo.new(null, 0.0, 1.0, 1.0)
	# Like _Panels.add: cabin layer, no shadow.
	geo.on_mesh = func(mi: MeshInstance3D) -> void:
		mi.layers = 2
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		out.append(mi)
	# Flat steel colour and a swept 8-sided rebar mesh: no grime shader on a 2.5 cm mesh.
	geo.add_rod(hinge, "DonorLockRod", PackedVector3Array([Vector3(ROD_X, ROD_Y0, ROD_Z),
			Vector3(ROD_X, ROD_Y1, ROD_Z)]), PackedFloat32Array([ROD_R, ROD_R]), 8,
			IronCross.RIB_STEP, _Welds.rust_steel())
	var bead := _Welds.weld_steel()
	var n := 0
	for foot: Vector2 in feet:
		for leg_x: float in [U_X0 + LEG_W * 0.5, U_X1 - LEG_W * 0.5]:
			geo.add_blob(hinge, "DonorLockBead%d" % n, Vector3(leg_x, foot.x, Z_BEAM - 0.006),
					Vector3(0.022, minf(foot.y, 0.03), 0.016), rng, bead)
			n += 1
	var handle := hinge.get_node_or_null("Handle") as Node3D
	if handle:
		handle.position.x = HANDLE_X
		handle.position.z = HANDLE_Z


## A U guide from y0 to y1: two legs standing off the beam face and the front bar across them.
static func _u(st: SurfaceTool, y0: float, y1: float) -> void:
	var h := y1 - y0
	var yc := (y0 + y1) * 0.5
	var leg_z := (Z_BEAM + Z_LEG) * 0.5
	_box(st, Vector3(LEG_W, h, Z_BEAM - Z_LEG), Vector3(U_X0 + LEG_W * 0.5, yc, leg_z))
	_box(st, Vector3(LEG_W, h, Z_BEAM - Z_LEG), Vector3(U_X1 - LEG_W * 0.5, yc, leg_z))
	_box(st, Vector3(U_X1 - U_X0, h, Z_LEG - Z_FRONT), Vector3((U_X0 + U_X1) * 0.5, yc,
			(Z_LEG + Z_FRONT) * 0.5))


## The keeper plate closing a U's outer end, full width and depth.
static func _plate(st: SurfaceTool, y0: float, y1: float) -> void:
	_box(st, Vector3(U_X1 - U_X0, y1 - y0, Z_BEAM - Z_FRONT), Vector3((U_X0 + U_X1) * 0.5,
			(y0 + y1) * 0.5, (Z_BEAM + Z_FRONT) * 0.5))


static func _box(st: SurfaceTool, size: Vector3, at: Vector3) -> void:
	_Welds.add_box(st, size, at, 0.0)
