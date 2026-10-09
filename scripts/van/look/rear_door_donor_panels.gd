extends RefCounted
## The donor leaf's cabin-face fittings (spec 3): a slotted vent plate in the top bay, a molle
## panel with a brick grid of recessed slots and two worn tie-down rails in the bottom bay.
## Everything is hinge-local, on layer 2, bolted to the pressed bay floor.

const _LeafBuild := preload("res://scripts/van/rear_door_leaf_build.gd")
const _Press := preload("res://scripts/van/rear_door_press.gd")
const _WALL_MATERIAL := "res://scenes/van/van_wall_material.tres"

## The pressed bay floor, hinge-local z (the cabin crest is _LeafBuild.CABIN_Z).
const PANEL_Z := _LeafBuild.CABIN_Z + _Press.DEPTH
const PLATE_T := 0.02
const PLATE_FACE_Z := PANEL_Z - PLATE_T
## Molle plate inset from the pressed beams, slot size and the staggered grid pitch.
const MOLLE_INSET := 0.03
const SLOT := Vector2(0.14, 0.045)
const SLOT_PITCH := Vector2(0.20, 0.185)
const SLOT_ROWS := 7
## Slot boxes stand this far proud of the plate (the audit wants >= 15 mm).
const SLOT_T := 0.016
const RAIL_Z := PANEL_Z - 0.026
const RAIL_T := 0.012
const RAIL_H := 0.04
## Rail centres below the plate top: each sits between two slot rows so no slot is covered.
const RAIL_DROP: Array[float] = [0.1825, 0.3675]
const RAIL_X0 := 0.45
const RAIL_X1 := 2.15
const ANCHOR_X: Array[float] = [0.75, 1.85]


## The molle plate's rect (hinge-local XY) inside the bottom bay.
static func molle_plate(bay: Rect2) -> Rect2:
	return bay.grow(-MOLLE_INSET)


## Vent plate in the top bay: raised rim, recessed slot pocket, eight screw heads.
static func build_vent(parent: Node3D, bay: Rect2, out: Array[Node3D]) -> void:
	var dark := grime(Color(0.09, 0.09, 0.1))
	var rim_mat := grime(Color(0.14, 0.13, 0.12))
	var pocket := flat(Color(0.02, 0.02, 0.025), 0.9, 0.0)
	var plate := bay.grow(-0.02)
	var c := plate.get_center()
	add(parent, "VentPlate", box(Vector3(plate.size.x, plate.size.y, PLATE_T)), dark,
			Vector3(c.x, c.y, PANEL_Z - PLATE_T * 0.5), Vector3.ZERO, out)
	var rim := 0.03
	var rim_z := PLATE_FACE_Z - 0.006
	for sy: float in [-1.0, 1.0]:
		add(parent, "VentRimH", box(Vector3(plate.size.x, rim, 0.012)), rim_mat,
				Vector3(c.x, c.y + sy * (plate.size.y - rim) * 0.5, rim_z), Vector3.ZERO, out)
	for sx: float in [-1.0, 1.0]:
		add(parent, "VentRimV", box(Vector3(rim, plate.size.y - 2.0 * rim, 0.012)), rim_mat,
				Vector3(c.x + sx * (plate.size.x - rim) * 0.5, c.y, rim_z), Vector3.ZERO, out)
	add(parent, "VentSlot", box(Vector3(plate.size.x * 0.6, 0.05, SLOT_T)), pocket,
			Vector3(c.x, c.y, PLATE_FACE_Z - SLOT_T * 0.5), Vector3.ZERO, out)
	var screw := CylinderMesh.new()
	screw.top_radius = 0.011
	screw.bottom_radius = 0.011
	screw.height = 0.008
	screw.radial_segments = 6
	screw.rings = 1
	var steel := flat(Color(0.3, 0.29, 0.27), 0.75, 0.3)
	for ix: int in 3:
		for sy: float in [-1.0, 1.0]:
			var x := c.x + (float(ix) - 1.0) * (plate.size.x - rim) * 0.5
			add(parent, "VentScrew", screw, steel,
					Vector3(x, c.y + sy * (plate.size.y - rim) * 0.5, rim_z - 0.01),
					Vector3(PI * 0.5, 0.0, 0.0), out)
	for sx: float in [-1.0, 1.0]:
		add(parent, "VentScrew", screw, steel,
				Vector3(c.x + sx * (plate.size.x - rim) * 0.5, c.y, rim_z - 0.01),
				Vector3(PI * 0.5, 0.0, 0.0), out)


## Molle plate: near-black steel, corner bolts, the recessed slot grid minus `skip` rects (where
## the can and its straps cover it), a couple of torn slots, and the two tie-down rails.
static func build_molle(parent: Node3D, bay: Rect2, skip: Array[Rect2],
		rng: RandomNumberGenerator, out: Array[Node3D]) -> void:
	var plate := molle_plate(bay)
	var c := plate.get_center()
	add(parent, "MollePlate", box(Vector3(plate.size.x, plate.size.y, PLATE_T)),
			grime(Color(0.07, 0.07, 0.075)),
			Vector3(c.x, c.y, PANEL_Z - PLATE_T * 0.5), Vector3.ZERO, out)
	var steel := flat(Color(0.3, 0.29, 0.27), 0.75, 0.3)
	var bolt := CylinderMesh.new()
	bolt.top_radius = 0.02
	bolt.bottom_radius = 0.02
	bolt.height = 0.015
	bolt.radial_segments = 6
	bolt.rings = 1
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			add(parent, "MolleBolt", bolt, steel, Vector3(c.x + sx * (plate.size.x * 0.5 - 0.05),
					c.y + sy * (plate.size.y * 0.5 - 0.05), PLATE_FACE_Z - 0.007),
					Vector3(PI * 0.5, 0.0, 0.0), out)
	_slots(parent, plate, skip, rng, out)
	_rails(parent, plate, steel, out)


## One merged mesh of dark slot boxes standing proud of the plate, plus two torn slots built as
## their own tilted, longer boxes in place of two of the grid slots.
static func _slots(parent: Node3D, plate: Rect2, skip: Array[Rect2],
		rng: RandomNumberGenerator, out: Array[Node3D]) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var z := PLATE_FACE_Z - SLOT_T * 0.5
	var kept: Array[Vector2] = []
	for r: int in SLOT_ROWS:
		var y := plate.end.y - 0.09 - float(r) * SLOT_PITCH.y
		var x := plate.position.x + 0.12 + (SLOT_PITCH.x * 0.5 if r % 2 == 1 else 0.0)
		while x + SLOT.x * 0.5 < plate.end.x - 0.08:
			var rect := Rect2(Vector2(x, y) - SLOT * 0.5, SLOT).grow(0.02)
			var covered := false
			for s: Rect2 in skip:
				covered = covered or rect.intersects(s)
			if not covered:
				kept.append(Vector2(x, y))
			x += SLOT_PITCH.x
	var torn: Array[Vector2] = []
	for i: int in 2:
		if kept.is_empty():
			break
		torn.append(kept.pop_at(rng.randi_range(0, kept.size() - 1)))
	var slot_mesh := box(Vector3(SLOT.x, SLOT.y, SLOT_T))
	for p: Vector2 in kept:
		st.append_from(slot_mesh, 0, Transform3D(Basis.IDENTITY, Vector3(p.x, p.y, z)))
	var inst := MeshInstance3D.new()
	inst.name = "MolleSlots"
	inst.mesh = st.commit()
	var mat := flat(Color(0.015, 0.015, 0.02), 0.95, 0.0)
	inst.material_override = mat
	inst.layers = 2
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(inst)
	out.append(inst)
	for p: Vector2 in torn:
		add(parent, "TornSlot", box(Vector3(SLOT.x * 1.2, SLOT.y * 1.5, SLOT_T + 0.004)),
				flat(Color(0.015, 0.015, 0.02), 0.95, 0.0),
				Vector3(p.x, p.y, z - 0.002), Vector3(0.0, 0.0, deg_to_rad(rng.randf_range(
				-25.0, 25.0))), out)


static func _rails(parent: Node3D, plate: Rect2, steel: Material,
		out: Array[Node3D]) -> void:
	var worn := flat(Color(0.34, 0.33, 0.31), 0.7, 0.3)
	var rust := flat(Color(0.3, 0.14, 0.06), 0.95, 0.0)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.016
	ring.outer_radius = 0.034
	ring.rings = 8
	ring.ring_segments = 5
	var bolt := CylinderMesh.new()
	bolt.top_radius = 0.012
	bolt.bottom_radius = 0.012
	bolt.height = 0.01
	bolt.radial_segments = 6
	bolt.rings = 1
	for drop: float in RAIL_DROP:
		var y := plate.end.y - drop
		add(parent, "TieRail", box(Vector3(RAIL_X1 - RAIL_X0, RAIL_H, RAIL_T)), worn,
				Vector3((RAIL_X0 + RAIL_X1) * 0.5, y, RAIL_Z), Vector3.ZERO, out)
		for x: float in [RAIL_X0 + 0.03, RAIL_X1 - 0.03]:
			add(parent, "RailRust", box(Vector3(0.07, 0.034, 0.002)), rust,
					Vector3(x, y, RAIL_Z - RAIL_T * 0.5 - 0.001), Vector3.ZERO, out)
			add(parent, "RailBolt", bolt, steel, Vector3(x, y, RAIL_Z - RAIL_T * 0.5 - 0.006),
					Vector3(PI * 0.5, 0.0, 0.0), out)
		for ax: float in ANCHOR_X:
			add(parent, "AnchorBase", box(Vector3(0.09, 0.07, 0.007)), steel,
					Vector3(ax, y, RAIL_Z - RAIL_T * 0.5 - 0.0035), Vector3.ZERO, out)
			add(parent, "DRing", ring, worn, Vector3(ax, y, RAIL_Z - RAIL_T * 0.5 - 0.012),
					Vector3(PI * 0.5, 0.0, 0.0), out)
			for sx: float in [-1.0, 1.0]:
				add(parent, "AnchorBolt", bolt, rust, Vector3(ax + sx * 0.036, y,
						RAIL_Z - RAIL_T * 0.5 - 0.012), Vector3(PI * 0.5, 0.0, 0.0), out)


static func add(parent: Node3D, node_name: String, mesh: Mesh, mat: Material, pos: Vector3,
		rot: Vector3, out: Array[Node3D]) -> void:
	var inst := MeshInstance3D.new()
	inst.name = "%s%d" % [node_name, out.size()]
	inst.mesh = mesh
	inst.material_override = mat
	inst.layers = 2
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.position = pos
	inst.rotation = rot
	parent.add_child(inst)
	out.append(inst)


static func box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


static func flat(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	return mat


static func grime(color: Color) -> Material:
	var mat := (load(_WALL_MATERIAL) as ShaderMaterial).duplicate() as ShaderMaterial
	mat.set_shader_parameter(&"base_color", color)
	mat.set_shader_parameter(&"wall_size_m", Vector2(0.8, 0.8))
	mat.set_shader_parameter(&"kick_height_m", 0.15)
	return mat
