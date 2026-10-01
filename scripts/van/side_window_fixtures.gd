extends RefCounted
## Side window hardware: the fixed stop ring and hinge rail on the wall, and the two gooseneck strap hinges riding each sash.

## Strap hinge centres along the window (z from the window centre); clear of the cross's centre bar.
const STRAP_Z: Array[float] = [-0.70, 0.70]
const STRAP_WIDTH := 0.05
const KNUCKLE_RADIUS := 0.024
const KNUCKLE_LEN := 0.07
const KNUCKLE_GAP := 0.004
## Rail plate on the skin: sunk RAIL_SINK into it, RAIL_PROUD out of it.
const RAIL_SINK := 0.02
const RAIL_PROUD := 0.015
const RAIL_Y0 := -0.012
const RAIL_Y1 := 0.07
const RAIL_HALF_Z := 0.85
const BOLT_RADIUS := 0.009

## Window stop: static ring covering the 2 cm frame-to-cut slot (D12 gap); its outboard face sits
## STOP_LIFT inboard of the liner. Polys: the cut offset 4 cm out / 5 cm in (3 cm over the frame).
const STOP_LIFT := 0.015
const STOP_THICKNESS := 0.008
static var STOP_OUTER_POLY: PackedVector2Array = PackedVector2Array([
	Vector2(-0.992, -0.747), Vector2(-1.169, -0.668), Vector2(-1.262, -0.531), Vector2(-1.262, 0.531),
	Vector2(-1.169, 0.668), Vector2(-0.992, 0.747), Vector2(0.992, 0.747), Vector2(1.169, 0.668),
	Vector2(1.262, 0.531), Vector2(1.262, -0.531), Vector2(1.169, -0.668), Vector2(0.992, -0.747),
])
static var STOP_INNER_POLY: PackedVector2Array = PackedVector2Array([
	Vector2(-0.972, -0.657), Vector2(-1.109, -0.596), Vector2(-1.172, -0.504), Vector2(-1.172, 0.504),
	Vector2(-1.109, 0.596), Vector2(-0.972, 0.657), Vector2(0.972, 0.657), Vector2(1.109, 0.596),
	Vector2(1.172, 0.504), Vector2(1.172, -0.504), Vector2(1.109, -0.596), Vector2(0.972, -0.657),
])

static var _steel: StandardMaterial3D = null
static var _bolt: StandardMaterial3D = null


## The static stop ring on the window root (moved verbatim from SideWindows._fit_window_root).
static func add_stop(root: Node3D, walls: VanSideWall, wall_sign: float, x_ref: float,
		y_hinge: float, z_center: float, mid_y: float, material: Material) -> void:
	var stop := MeshInstance3D.new()
	stop.name = "WindowStop"
	stop.mesh = walls.build_curved_frame_ring_mesh(
		wall_sign, STOP_OUTER_POLY, STOP_INNER_POLY, x_ref, y_hinge, z_center, mid_y, STOP_THICKNESS,
		-wall_sign * (STOP_LIFT + STOP_THICKNESS), VanSideWall.WINDOW_EDGE_SUBDIV
	)
	stop.material_override = material
	stop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	stop.layers = VanLighting.LAYER_STREET_AND_INTERIOR
	stop.add_to_group(VanLighting.GROUP_EXTERIOR_LAYER)
	root.add_child(stop)


## The fixed hinge rail on `root` and the two strap hinges on `hinge`; call after the pivot shift.
static func add_hinges(root: Node3D, hinge: Node3D, walls: VanSideWall, wall_sign: float,
		x_ref: float, y_hinge: float, pivot_o: float) -> void:
	# The skin panel offsets its faces along x, so no tilt correction.
	var skin_o := VanHull.SIDE_SKIN_OUTER_M
	var rail := Node3D.new()
	rail.name = "HingeRail"
	root.add_child(rail)
	_box(rail, "RailPlate", wall_sign, skin_o - RAIL_SINK, skin_o + RAIL_PROUD,
		RAIL_Y0, RAIL_Y1, -RAIL_HALF_Z, RAIL_HALF_Z, Vector3.ZERO, _steel_material())
	var standoff_z: Array[float] = []
	for z_s in STRAP_Z:
		for side in [-1.0, 1.0]:
			var zk: float = z_s + side * (KNUCKLE_LEN + KNUCKLE_GAP)
			standoff_z.append(zk)
			_knuckle(rail, "FixedKnuckle", wall_sign, pivot_o, zk, Vector3.ZERO)
			_box(rail, "Standoff", wall_sign, skin_o - RAIL_SINK, pivot_o, 0.0, 0.034,
				zk - KNUCKLE_LEN * 0.5, zk + KNUCKLE_LEN * 0.5, Vector3.ZERO, _steel_material())
	for bz in [-0.82, -0.40, 0.0, 0.40, 0.82]:
		var clear := true
		for zk in standoff_z:
			if absf(bz - zk) < 0.12:
				clear = false
		if clear:
			_bolt_head(rail, "RailBolt", wall_sign, skin_o + RAIL_PROUD, 0.045, bz, Vector3.ZERO)

	var p := Vector3(wall_sign * pivot_o, 0.0, 0.0)
	var leaf_o: float = wall_sign * walls.local_x_on_wall(wall_sign, y_hinge - 0.078, x_ref)
	var arm_o: float = wall_sign * walls.local_x_on_wall(wall_sign, y_hinge - 0.065, x_ref)
	for i in range(STRAP_Z.size()):
		var z_s := STRAP_Z[i]
		var strap := Node3D.new()
		strap.name = "StrapHinge%d" % i
		hinge.add_child(strap)
		var half_w := STRAP_WIDTH * 0.5
		_box(strap, "Leaf", wall_sign, leaf_o + 0.025, leaf_o + 0.045,
			-0.098, -0.058, z_s - 0.035, z_s + 0.035, p, _steel_material())
		_box(strap, "Arm", wall_sign, arm_o + 0.025, 0.300,
			-0.073, -0.058, z_s - half_w, z_s + half_w, p, _steel_material())
		_box(strap, "Riser", wall_sign, 0.284, 0.300,
			-0.073, 0.0, z_s - half_w, z_s + half_w, p, _steel_material())
		_knuckle(strap, "Knuckle", wall_sign, pivot_o, z_s, p)
		for bside in [-1.0, 1.0]:
			_bolt_head(strap, "LeafBolt", wall_sign, leaf_o + 0.045, -0.078, z_s + bside * 0.022, p)


## Shows or hides a window root's HingeRail and its sash's StrapHinge* nodes (null root: no-op).
static func set_hinges_visible(root: Node, on: bool) -> void:
	if root == null:
		return
	var nodes: Array[Node] = [root.get_node_or_null(^"HingeRail")]
	var hinge := root.get_node_or_null(^"Hinge")
	if hinge != null:
		nodes.append_array(hinge.find_children("StrapHinge*", "Node3D", false, false))
	for node in nodes:
		if node != null:
			node.set(&"visible", on)


static func _steel_material() -> StandardMaterial3D:
	if _steel == null:
		_steel = StandardMaterial3D.new()
		_steel.albedo_color = Color(0.075, 0.07, 0.065)
		_steel.metallic = 0.3
		_steel.roughness = 0.78
	return _steel


static func _bolt_material() -> StandardMaterial3D:
	if _bolt == null:
		_bolt = StandardMaterial3D.new()
		_bolt.albedo_color = Color(0.15, 0.14, 0.12)
		_bolt.metallic = 0.3
		_bolt.roughness = 0.72
	return _bolt


## Exterior layer set before add_child, like the frame (never change layers once in the tree).
static func _place(parent: Node3D, node_name: String, mesh: Mesh, pos: Vector3,
		rot: Vector3, material: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mi.layers = VanLighting.LAYER_STREET_AND_INTERIOR
	mi.add_to_group(VanLighting.GROUP_EXTERIOR_LAYER)
	parent.add_child(mi)


## A box from outward/y/z min to max corners (outward distances), placed under `parent` with
## `offset` subtracted from its root-local centre (zero for the rail, the pivot for the straps).
static func _box(parent: Node3D, node_name: String, wall_sign: float, o0: float, o1: float,
		y0: float, y1: float, z0: float, z1: float, offset: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(o1 - o0, y1 - y0, z1 - z0)
	var centre := Vector3(wall_sign * (o0 + o1) * 0.5, (y0 + y1) * 0.5, (z0 + z1) * 0.5)
	_place(parent, node_name, mesh, centre - offset, Vector3.ZERO, material)


static func _knuckle(parent: Node3D, node_name: String, wall_sign: float, pivot_o: float,
		z_mid: float, offset: Vector3) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = KNUCKLE_RADIUS
	mesh.bottom_radius = KNUCKLE_RADIUS
	mesh.height = KNUCKLE_LEN
	mesh.radial_segments = 10
	mesh.rings = 0
	_place(parent, node_name, mesh, Vector3(wall_sign * pivot_o, 0.0, z_mid) - offset,
		Vector3(deg_to_rad(90.0), 0.0, 0.0), _steel_material())


static func _bolt_head(parent: Node3D, node_name: String, wall_sign: float, face_o: float,
		y: float, z: float, offset: Vector3) -> void:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = BOLT_RADIUS
	mesh.top_radius = 0.004
	mesh.height = 0.006
	mesh.radial_segments = 6
	mesh.rings = 0
	# Rotation about z by -90 deg * sign sends the mesh's +Y to +wall_sign on x (outward).
	_place(parent, node_name, mesh, Vector3(wall_sign * (face_o + 0.002), y, z) - offset,
		Vector3(0.0, 0.0, deg_to_rad(-90.0) * wall_sign), _bolt_material())
