extends RefCounted
## Redneck welded junk for the rear doors (spec 3): per leaf a heavy top hinge, a door-check strap,
## seam clamps, a header latch box and patch plates, plus a seam rod and a welded pull-handle frame
## on the left leaf; on the portal the pillar half of the top hinge, the check-strap bracket, the
## header striker and the floor striker. Oversized mismatched bolts, lumpy weld beads on every joint.

const _Hardware := preload("res://scripts/van/look/van_rear_door_hardware.gd")
const _RUST_MATERIAL := "res://scenes/van/van_rust_steel_material.tres"
const _WALL_MATERIAL := "res://scenes/van/van_wall_material.tres"
## Every front face stands 6 cm proud of its surface, every back sits at BACK_Z (inside the beams, clear of the skeleton planes at -0.12 and -0.09) so it clears the
## leaf's inner sheet (audit plane tolerance 0.01).
const T := 0.06
const BACK_Z := -0.14
const BEAD_R := 0.025
## Portal cabin face in hinge-local z; the pillars and header stand here.
const PILLAR_Z := -0.15
const LEAF_EDGE := 2.69
const _Flange := preload("res://scripts/van/rear_door_flange.gd")
const _Ramp := preload("res://scripts/van/rear_door_ramp.gd")
const _LeafBuild := preload("res://scripts/van/rear_door_leaf_build.gd")
## Body hinge plate: thickness, how far its back sinks into the ring, and the cabin-side z span
## (centre, depth) it covers; the leaf knuckle sits at FACE_Z - 0.10 and its outer edge 3 cm out.
const PLATE_T := 0.05
const PLATE_SINK := 0.025
const PLATE_Z := -0.3325
const PLATE_DEPTH := 0.135
const KNUCKLE_Z := -0.27


## Builds the scrap for one leaf under `parent` (`mirror` -1 for the right leaf), its body-mounted
## half under the portal, and returns every node it added.
static func build(parent: Node3D, mirror: float, rng: RandomNumberGenerator,
		_steel: Material, _dark: Material) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var steel := _grime(Color(0.22, 0.21, 0.19))
	var dark := _grime(Color(0.12, 0.115, 0.1))
	var skew := 1.0 if rng.randf() < 0.5 else -1.0
	# Heavy top hinge above the 1.79 strap: fat strap and knuckle on the leaf, mismatched bolts.
	# Lowered and slid in so it stays on the leaf's rounded top corner.
	_plate(parent, mirror, 0.21, 1.90, 0.28, 0.12, skew * 2.0, steel, "TopHingeStrap", out)
	_add(parent, "TopHingeKnuckle", _cyl(0.07, 0.07, 0.2), steel,
			Vector3(mirror * 0.04, 1.90, _Hardware.FACE_Z - 0.10), Vector3.ZERO, out)
	_bolts(parent, mirror, [0.19, 0.31], 1.90, rng, dark, out)
	_bead(parent, mirror, 0.21, 1.835, 0.28, 0.0, dark, out)
	_bead(parent, mirror, 0.35, 1.90, 0.12, 90.0, dark, out)
	_body_half(parent, mirror, rng, dark, out)
	# Side hinge welds: a lumpy bead across each existing strap's tip.
	for y: float in [1.79, -1.15]:
		_bead(parent, mirror, 0.40 + rng.randf_range(-0.02, 0.02), y, 0.07, 90.0, dark, out)
	# Door-check strap: flat bar on a skew with an angle-iron stop welded crooked at its far end.
	_plate(parent, mirror, 0.75, -0.85, 0.62, 0.04, skew * -11.0, steel, "CheckStrap", out)
	# The arm rides the leaf and swings with it; only a short stub stays on the pillar.
	_plate(parent, mirror, 0.22, -0.85, 0.40, 0.045, mirror * -3.0, steel, "CheckArm", out,
			_Hardware.FACE_Z - 0.03)
	_add(parent, "CheckPin", _cyl(0.05, 0.05, 0.12), dark,
			Vector3(mirror * 0.47, -0.85 - 0.03 * skew, _Hardware.FACE_Z - 0.12),
			Vector3(PI * 0.5, 0.0, 0.0), out)
	_plate(parent, mirror, 1.10, -0.95, 0.10, 0.12, 4.0, steel, "CheckAngleA", out)
	_plate(parent, mirror, 1.14, -0.91, 0.04, 0.12, -3.0, dark, "CheckAngleB", out)
	_bead(parent, mirror, 1.10, -1.01, 0.10, 0.0, dark, out)
	# Seam clamps: flat bars bolted over the centre seam, right edge on the seam and clear of the
	# locking rod (its right edge is at x 2.4825) at every roll.
	for y: float in [-1.30, -0.20, 0.55, 1.20]:
		var w := rng.randf_range(0.10, 0.14)
		_plate(parent, mirror, LEAF_EDGE - w * 0.5, y, w, 0.08, rng.randf_range(-4.0, 4.0),
				steel, "SeamClamp", out)
		_bolts(parent, mirror, [LEAF_EDGE - w * 0.5], y, rng, dark, out)
		_bead(parent, mirror, LEAF_EDGE - w, y, 0.08, 90.0, dark, out)
	if mirror > 0.0:
		_left_only(parent, rng, steel, dark, out)
	# Header latch box with a hasp tab.
	_plate(parent, mirror, 2.45, 1.38, 0.22, 0.14, skew * -2.0, steel, "LatchBox", out,
			_Hardware.FACE_Z - 0.003)
	_plate(parent, mirror, 2.30, 1.38, 0.10, 0.05, 9.0, dark, "LatchHasp", out)
	_bolts(parent, mirror, [2.36, 2.54], 1.38, rng, dark, out)
	_bead(parent, mirror, 2.45, 1.30, 0.22, 0.0, dark, out)
	# Patch plates over old holes, one welded round, one only bolted.
	_plate(parent, mirror, 0.30, 0.30, 0.18, 0.22, skew * 7.0, dark, "PatchPlateA", out)
	_bolts(parent, mirror, [0.24, 0.36], 0.38, rng, steel, out)
	_bead(parent, mirror, 0.30, 0.185, 0.18, 0.0, dark, out)
	return out


## Left leaf only: a vertical seam rod welded over the astragal and a welded frame round the pull.
static func _left_only(parent: Node3D, rng: RandomNumberGenerator, steel: Material,
		dark: Material, out: Array[Node3D]) -> void:
	_add(parent, "SeamRod", _cyl(0.035, 0.035, 2.7), steel,
			Vector3(LEAF_EDGE - 0.036, 0.0, _Hardware.FACE_Z - 0.04), Vector3.ZERO, out)
	var cx := _Hardware.HANDLE_X - 0.02
	var cy := _Hardware.HANDLE_Y
	# Narrow enough that its right edge stays 3 cm clear of the leaf's end face.
	# Three sides only: the right side would share the handle plate's and astragal's planes. Stands
	# 2.5 cm proud of the handle plate's face.
	var fz := _Hardware.FACE_Z - 0.03
	_plate(parent, 1.0, cx, cy + 0.14, 0.20, 0.05, 0.0, dark, "PullFrameTop", out, fz)
	_plate(parent, 1.0, cx, cy - 0.14, 0.20, 0.05, 0.0, dark, "PullFrameBottom", out, fz)
	_plate(parent, 1.0, cx - 0.0825, cy, 0.05, 0.28, 0.0, dark, "PullFrameLeft", out, fz - 0.015)
	_bolts(parent, 1.0, [cx - 0.0825, cx + 0.04], cy + 0.14, rng, steel, out, fz)
	_bead(parent, 1.0, cx, cy + 0.16, 0.20, 0.0, steel, out, fz)


## Body-mounted half: pillar top-hinge plate and knuckle, check-strap bracket and arm, header
## striker, floor striker. Parts live under the portal in hinge-local coordinates.
static func _body_half(hinge: Node3D, mirror: float, rng: RandomNumberGenerator,
		dark: Material, out: Array[Node3D]) -> void:
	# Bolted to the rust-steel ramp, so it shares the ramp's material, not the painted wall's.
	var steel := load(_RUST_MATERIAL) as Material
	var body := hinge.get_parent() as Node3D
	var host := body.get_node_or_null("Portal") as Node3D
	var anchor := Node3D.new()
	anchor.name = "ScrapBody" + ("L" if mirror > 0.0 else "R")
	anchor.position = hinge.position
	(host if host != null else body).add_child(anchor)
	out.append(anchor)
	_ring_hinge(anchor, mirror, rng, steel, dark, out)
	_header_striker(anchor, mirror, rng, steel, dark, out)
	# Floor striker: 6 cm slab on the cabin side of the leaf's bottom edge (z -0.275..-0.105), its top
	# 2 cm above the sill strip, its bottom sunk 1 cm into the floor (top at y 0).
	var rod_x := _Hardware.ROD_X
	_add(anchor, "FloorStriker", _box(Vector3(0.28, 0.06, 0.17)), steel,
			Vector3(mirror * rod_x, -1.53, -0.19), Vector3.ZERO, out)
	_add(anchor, "FloorStrikerSlot", _box(Vector3(0.07, 0.004, 0.07)), dark,
			Vector3(mirror * rod_x, -1.498, -0.17), Vector3.ZERO, out)
	for dx: float in [-0.09, 0.09]:
		var bolt := _cyl(0.035, 0.035, 0.02)
		bolt.radial_segments = 6
		_add(anchor, "FloorStrikerBolt", bolt, dark,
				Vector3(mirror * (rod_x + dx), -1.49, -0.22), Vector3.ZERO, out)
	_add(anchor, "FloorStrikerBead", _cyl(BEAD_R, BEAD_R * 1.3, 0.28), dark,
			Vector3(mirror * rod_x, -1.50, -0.25), Vector3(0.0, 0.0, PI * 0.5), out)


## Pillar half of the top hinge: a plate bolted to the deep ring's opening-side face (round at this
## height, so tilted to follow it) with a welded knuckle 3 mm outside the leaf's knuckle.
static func _ring_hinge(anchor: Node3D, mirror: float, rng: RandomNumberGenerator,
		steel: Material, dark: Material, out: Array[Node3D]) -> void:
	# The top hinge and one half for each leaf strap (1.79 and -1.15), so every strap meets a plate.
	_ring_plate(anchor, mirror, 1.90, 0.14, rng, steel, dark, out)
	_ring_plate(anchor, mirror, 1.78, 0.09, rng, steel, dark, out)
	_ring_plate(anchor, mirror, -1.15, 0.20, rng, steel, dark, out)


## One body hinge half at height `hy`: a plate lying on the ramp's slope at the knuckle's depth
## (tilted to follow it, round at this height) with a knuckle 3 mm outside the leaf's knuckle.
static func _ring_plate(anchor: Node3D, mirror: float, hy: float, ph: float,
		rng: RandomNumberGenerator, steel: Material, dark: Material, out: Array[Node3D]) -> void:
	var so := -mirror
	var r := _Flange.RADIUS_TOP
	var top := VanInteriorSize.REAR_DOOR_TOP - anchor.position.y
	var z_in := _LeafBuild.CABIN_Z
	var z_deep := _Ramp.z_deep_rel()
	var d := _Ramp.d_at(KNUCKLE_Z, z_in, z_deep)
	var a := asin(clampf((hy - (top - r)) / (r + d), -1.0, 1.0))
	var away := Vector2(so * cos(a), sin(a))
	var xy := Vector2(-so * r, top - r) + away * (r + d)
	if hy < top - r:
		away = Vector2(so, 0.0)
		xy = Vector2(so * d, hy)
	var f := _Ramp.frame(xy, away, KNUCKLE_Z, z_in, z_deep)
	_add_on(anchor, "PillarHingePlate", _box(Vector3(PLATE_DEPTH, ph, PLATE_T)), steel, f, out)
	_add(anchor, "PillarKnuckle", _cyl(0.045, 0.045, ph + 0.024), steel,
			Vector3(so * (d - 0.0045), hy, KNUCKLE_Z), Vector3.ZERO, out)
	var turn := Basis(f.basis.x, -f.basis.z, f.basis.y)
	for k: float in [-1.0, 1.0]:
		var rb := rng.randf_range(0.028, 0.034)
		var bolt := _cyl(rb, rb, 0.045)
		bolt.radial_segments = 6
		var bx := Transform3D(turn, f * Vector3(0.0, 0.075 * k * minf(ph / 0.14, 1.0), -0.0435))
		_add_on(anchor, "ScrapBolt", bolt, dark, bx, out)
		var wx := Transform3D(Basis(f.basis.y, f.basis.x, -f.basis.z),
				f * Vector3(0.0, 0.10 * k * minf(ph / 0.14, 1.0), -PLATE_T * 0.5))
		_add_on(anchor, "WeldBead", _cyl(BEAD_R, BEAD_R * 1.3, 0.08), dark, wx, out)


## `_add` with a full transform.
static func _add_on(parent: Node3D, node_name: String, mesh: Mesh, mat: Material,
		xf: Transform3D, out: Array[Node3D]) -> void:
	_add(parent, node_name, mesh, mat, xf.origin, Vector3.ZERO, out)
	out.back().transform = xf


## Header striker on the ring's underside at the street end, above where the leaves close: a plate
## with a bent-rod keeper welded under it.
static func _header_striker(anchor: Node3D, mirror: float, rng: RandomNumberGenerator,
		steel: Material, dark: Material, out: Array[Node3D]) -> void:
	var z_in := _LeafBuild.CABIN_Z
	var z_deep := _Ramp.z_deep_rel()
	var top := VanInteriorSize.REAR_DOOR_TOP - anchor.position.y
	var d := _Ramp.d_at(-0.30, z_in, z_deep)
	var f := _Ramp.frame(Vector2(mirror * 2.45, top + d), Vector2(0.0, 1.0), -0.30, z_in, z_deep)
	# Local x runs down the slope, local y across the doorway (the plate's long side).
	var lay := Basis(f.basis.x, f.basis.y, f.basis.z) * Basis.from_euler(
			Vector3(0.0, 0.0, rng.randf_range(-3.0, 3.0) * PI / 180.0))
	_add_on(anchor, "HeaderStriker", _box(Vector3(0.18, 0.24, PLATE_T)), steel,
			Transform3D(lay, f.origin), out)
	var along := Transform3D(Basis(f.basis.x, f.basis.z, -f.basis.y), f * Vector3(0.0, 0.0, -0.046))
	_add_on(anchor, "HeaderKeeper", _cyl(0.024, 0.024, 0.10), dark,
			Transform3D(Basis(f.basis.z, f.basis.y, -f.basis.x), along.origin), out)
	for dy: float in [-0.05, 0.05]:
		_add_on(anchor, "HeaderKeeperLeg", _cyl(0.02, 0.02, 0.03), dark,
				Transform3D(Basis(f.basis.x, -f.basis.z, f.basis.y), f * Vector3(0.0, dy, -0.0285)), out)
	for dy: float in [-0.10, 0.10]:
		var rb := rng.randf_range(0.03, 0.045)
		var bolt := _cyl(rb, rb, 0.045)
		bolt.radial_segments = 6
		_add_on(anchor, "ScrapBolt", bolt, dark,
				Transform3D(Basis(f.basis.x, -f.basis.z, f.basis.y),
				f * Vector3(0.04, dy, -0.0435)), out)
	_add_on(anchor, "WeldBead", _cyl(BEAD_R, BEAD_R * 1.3, 0.24), dark,
			Transform3D(Basis(f.basis.x, f.basis.y, f.basis.z), f * Vector3(0.09, 0.0, -0.025)), out)


## The van wall's grime shader, resized to small hardware so its panel seams read at part scale.
static func _grime(color: Color) -> Material:
	var mat := (load(_WALL_MATERIAL) as ShaderMaterial).duplicate() as ShaderMaterial
	mat.set_shader_parameter(&"base_color", color)
	mat.set_shader_parameter(&"wall_size_m", Vector2(0.8, 0.8))
	mat.set_shader_parameter(&"kick_height_m", 0.15)
	return mat


static func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


static func _add(parent: Node3D, node_name: String, mesh: Mesh, mat: Material, pos: Vector3,
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


static func _cyl(top: float, bottom: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 1
	return mesh


## Flat piece centred at (cx, cy), rotated `deg` about z, front 2 cm proud of `face_z`, back buried.
static func _plate(parent: Node3D, mirror: float, cx: float, cy: float, w: float, h: float,
		deg: float, mat: Material, node_name: String, out: Array[Node3D],
		face_z: float = _Hardware.FACE_Z, back_z: float = BACK_Z) -> void:
	var depth := back_z - (face_z - T)
	_add(parent, node_name, _box(Vector3(w, h, depth)), mat,
			Vector3(mirror * cx, cy, face_z - T + depth * 0.5),
			Vector3(0.0, 0.0, mirror * deg_to_rad(deg)), out)


## Oversized hex bolt heads of mixed size, each standing 4 cm clear of the plate it holds.
static func _bolts(parent: Node3D, mirror: float, xs: Array, y: float,
		rng: RandomNumberGenerator, mat: Material, out: Array[Node3D],
		face_z: float = _Hardware.FACE_Z) -> void:
	for x: float in xs:
		var r := rng.randf_range(0.03, 0.05)
		var h := 0.045
		var z := face_z - T - h * 0.5 + 0.004
		var jitter := Vector2(rng.randf_range(-0.012, 0.012), rng.randf_range(-0.012, 0.012))
		var inst_pos := Vector3(mirror * x + jitter.x, y + jitter.y, z)
		var mesh := _cyl(r, r, h)
		mesh.radial_segments = 6
		_add(parent, "ScrapBolt", mesh, mat, inst_pos, Vector3(PI * 0.5, 0.0, 0.0), out)


## Lumpy weld bead lying on a plate edge: a fat cylinder along x (`deg` 0) or y (90) whose centre
## sits on the plate's front plane.
static func _bead(parent: Node3D, mirror: float, cx: float, cy: float, length: float, deg: float,
		mat: Material, out: Array[Node3D], face_z: float = _Hardware.FACE_Z) -> void:
	var rot := Vector3(0.0, 0.0, deg_to_rad(90.0 - deg))
	_add(parent, "WeldBead", _cyl(BEAD_R, BEAD_R * 1.3, length), mat,
			Vector3(mirror * cx, cy, face_z - T), rot, out)
