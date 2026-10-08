extends RefCounted
## Scrap-built door hardware on the cabin face of one rear leaf: two strap hinges, a locking rod
## with guide brackets, cam lever and tip, and a bolted backing plate behind the handle.

const _LeafBuild := preload("res://scripts/van/rear_door_leaf_build.gd")
## Skeleton beam faces (the leaf's cabin face) in hinge-local z; hardware stands at z < this.
const FACE_Z := _LeafBuild.CABIN_Z
## Strap and plate front faces stand 6 and 3.5 cm proud of the beams.
const STRAP_T := 0.06
const PLATE_T := 0.035
const BOLT_H := 0.03
## Backs sink 3 cm into the beams so no hardware face sits in the beam face plane.
const SINK := 0.03
## Strap backs end 3 cm past the skeleton panel back plane (-0.09), clear of the scrap and plate backs.
const STRAP_SINK := 0.03
## Strap and knuckle start inboard of the hinge edge so nothing shows past the wall line.
const STRAP_X0 := 0.05
## Hinge x (the leaf node sits there) minus the rod and handle offsets.
const HINGE_X := VanInteriorSize.REAR_DOOR_HALF
const ROD_X := HINGE_X - 0.23
const ROD_Z := FACE_Z - 0.05
const ROD_TOP_Y := -1.0
## Upper lock rod runs from above the handle plate up toward the header.
const ROD_UP_BOTTOM_Y := -0.60
const ROD_UP_TOP_Y := 0.95
const ROD_BOTTOM_Y := -1.5
const TIP_LEN := 0.08
const HANDLE_X := HINGE_X - 0.11
const HANDLE_Y := -0.82


## Builds the hardware for one leaf under `parent` (`mirror` -1 for the right leaf) and returns
## every node it added.
static func build(parent: Node3D, mirror: float, rng: RandomNumberGenerator,
		steel: Material, dark: Material) -> Array[Node3D]:
	var out: Array[Node3D] = []
	_strap_hinge(parent, mirror, 1.79, 3, rng, steel, dark, out)
	_strap_hinge(parent, mirror, -1.17, rng.randi_range(2, 3), rng, steel, dark, out)
	_locking_rod(parent, mirror, steel, dark, out)
	_handle_plate(parent, mirror, steel, out)
	return out


static func _add(parent: Node3D, node_name: String, mesh: Mesh, mat: Material, pos: Vector3,
		rot: Vector3, out: Array[Node3D]) -> void:
	var inst := MeshInstance3D.new()
	inst.name = node_name
	inst.mesh = mesh
	inst.material_override = mat
	inst.layers = 2
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.position = pos
	inst.rotation = rot
	parent.add_child(inst)
	out.append(inst)


static func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


static func _cyl(top: float, bottom: float, height: float, sides: int) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	return mesh


## Hex bolt head whose back is sunk 2 mm into the surface whose front face is at `face_z`.
static func _bolt(parent: Node3D, node_name: String, x: float, y: float, face_z: float,
		mat: Material, out: Array[Node3D]) -> void:
	_add(parent, node_name, _cyl(0.032, 0.032, BOLT_H, 6), mat,
			Vector3(x, y, face_z - BOLT_H * 0.5 + 0.002), Vector3(PI * 0.5, 0.0, 0.0), out)


static func _strap_hinge(parent: Node3D, mirror: float, y: float, bolts: int,
		rng: RandomNumberGenerator, steel: Material, dark: Material, out: Array[Node3D]) -> void:
	var length := 0.34 + rng.randf_range(-0.03, 0.03)
	var strap_z := FACE_Z - STRAP_T * 0.5
	var front_z := FACE_Z - STRAP_T
	_add(parent, "StrapPlate%d" % out.size(), _box(Vector3(length, 0.11, STRAP_T + STRAP_SINK)), steel,
			Vector3(mirror * (STRAP_X0 + length * 0.5), y, strap_z + STRAP_SINK * 0.5), Vector3.ZERO, out)
	# Fat knuckle welded on the stile, 8 cm out from the beam face.
	_add(parent, "StrapKnuckle%d" % out.size(), _cyl(0.05, 0.05, 0.16, 8), steel,
			Vector3(mirror * 0.08, y, FACE_Z - 0.08), Vector3.ZERO, out)
	for i: int in range(bolts):
		var bx := 0.11 + 0.085 * float(i) + (0.0 if bolts == 3 else 0.04)
		_bolt(parent, "StrapBolt%d" % out.size(), mirror * bx, y, front_z, dark, out)
	if rng.randf() < 0.6:
		_add(parent, "StrapTip%d" % out.size(), _box(Vector3(0.04, 0.12, 0.03)), dark,
				Vector3(mirror * (STRAP_X0 + length), y, front_z - 0.015 + 0.002), Vector3.ZERO, out)


static func _locking_rod(parent: Node3D, mirror: float, steel: Material, dark: Material,
		out: Array[Node3D]) -> void:
	_rod(parent, mirror, ROD_TOP_Y, ROD_BOTTOM_Y, [-1.05, -1.40], steel, dark, out)
	_rod(parent, mirror, ROD_UP_TOP_Y, ROD_UP_BOTTOM_Y, [0.80, -0.45], steel, dark, out)
	# Cam lever from the lower rod top up to the handle mount, in front of the plate's face.
	_add(parent, "CamLever", _box(Vector3(0.16, 0.04, 0.04)), steel,
			Vector3(mirror * (ROD_X + 0.08), ROD_TOP_Y + 0.03, FACE_Z - PLATE_T - 0.02),
			Vector3(0.0, 0.0, mirror * deg_to_rad(20.0)), out)


## One 6 cm-thick-guide lock rod from `top_y` down to `bottom_y`, tapered at the bottom, in welded
## U guides at `guides_y` that stand on the skeleton beams.
static func _rod(parent: Node3D, mirror: float, top_y: float, bottom_y: float,
		guides_y: Array, steel: Material, dark: Material, out: Array[Node3D]) -> void:
	var rod_len := top_y - bottom_y - TIP_LEN
	_add(parent, "LockRod%d" % out.size(), _cyl(0.03, 0.03, rod_len, 8), steel,
			Vector3(mirror * ROD_X, top_y - rod_len * 0.5, ROD_Z), Vector3.ZERO, out)
	_add(parent, "LockRodTip%d" % out.size(), _cyl(0.03, 0.015, TIP_LEN, 8), steel,
			Vector3(mirror * ROD_X, bottom_y + TIP_LEN * 0.5, ROD_Z), Vector3.ZERO, out)
	for guide_y: float in guides_y:
		# U: back plate sunk into the beam, two cheeks reaching past the rod.
		_add(parent, "LockRodGuideBack%d" % out.size(), _box(Vector3(0.12, 0.06, 0.035 + SINK)), dark,
				Vector3(mirror * ROD_X, guide_y, FACE_Z - 0.0175 + SINK * 0.5), Vector3.ZERO, out)
		for side: float in [-1.0, 1.0]:
			_add(parent, "LockRodGuideCheek%d" % out.size(), _box(Vector3(0.03, 0.06, 0.08)), dark,
					Vector3(mirror * (ROD_X + side * 0.045), guide_y, FACE_Z - 0.04),
					Vector3.ZERO, out)


## Backing plate behind the handle mount. Centred 1 cm toward the hinge so it stops at x 3.33.
static func _handle_plate(parent: Node3D, mirror: float, steel: Material,
		out: Array[Node3D]) -> void:
	var cx := HANDLE_X - 0.01
	var front_z := FACE_Z - 0.02
	# Front 3 cm clear of the scene grip, back 3 cm past the scene mount (clear of its faces and
	# the skeleton planes).
	var depth := 0.125
	_add(parent, "HandlePlate", _box(Vector3(0.18, 0.24, depth)), steel,
			Vector3(mirror * cx, HANDLE_Y, front_z + depth * 0.5), Vector3.ZERO, out)
	# The mount hides the plate except a 3 cm strip on its hinge side, so the bolts line up there.
	for dy: float in [-0.09, -0.03, 0.03, 0.09]:
		_bolt(parent, "HandleBolt%d" % out.size(), mirror * (cx - 0.075), HANDLE_Y + dy, front_z, steel, out)
