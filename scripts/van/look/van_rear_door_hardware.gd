extends RefCounted
## Scrap-built door hardware on the cabin face of one rear leaf: two strap hinges, a locking rod
## with guide brackets, cam lever and tip, and a bolted backing plate behind the handle.

## Leaf cabin face in hinge-local z; hardware stands at z < this.
const FACE_Z := -0.08
## Strap and plate front faces stand 1.2 to 1.5 cm proud of the leaf (audit FLICKER).
const STRAP_T := 0.012
const PLATE_T := 0.015
const BOLT_H := 0.008
## Backs sink 5 mm into the leaf so no hardware face sits in the leaf's cabin face plane.
const SINK := 0.005
## The right leaf reads the straps as same-facing within 1 cm of its body face, so they sink deeper.
const STRAP_SINK := 0.02
## Strap and knuckle start inboard of the hinge edge so nothing shows past the wall line.
const STRAP_X0 := 0.05
## Hinge x (the leaf node sits there) minus the rod and handle offsets.
const HINGE_X := VanInteriorSize.REAR_DOOR_HALF
const ROD_X := HINGE_X - 0.23
const ROD_Z := -0.108
const ROD_TOP_Y := -1.0
const ROD_BOTTOM_Y := -1.5
const TIP_LEN := 0.04
const HANDLE_X := HINGE_X - 0.11
const HANDLE_Y := -0.82


## Builds the hardware for one leaf under `parent` (`mirror` -1 for the right leaf) and returns
## every node it added.
static func build(parent: Node3D, mirror: float, rng: RandomNumberGenerator,
		steel: Material, dark: Material) -> Array[Node3D]:
	var out: Array[Node3D] = []
	_strap_hinge(parent, mirror, 1.28, 3, rng, steel, dark, out)
	_strap_hinge(parent, mirror, -1.15, rng.randi_range(2, 3), rng, steel, dark, out)
	_locking_rod(parent, mirror, steel, dark, out)
	_handle_plate(parent, mirror, steel, out)
	return out


static func _add(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot: Vector3,
		out: Array[Node3D]) -> void:
	var inst := MeshInstance3D.new()
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
static func _bolt(parent: Node3D, x: float, y: float, face_z: float, mat: Material,
		out: Array[Node3D]) -> void:
	_add(parent, _cyl(0.014, 0.014, BOLT_H, 6), mat,
			Vector3(x, y, face_z - BOLT_H * 0.5 + 0.002), Vector3(PI * 0.5, 0.0, 0.0), out)


static func _strap_hinge(parent: Node3D, mirror: float, y: float, bolts: int,
		rng: RandomNumberGenerator, steel: Material, dark: Material, out: Array[Node3D]) -> void:
	var length := 0.34 + rng.randf_range(-0.03, 0.03)
	var strap_z := FACE_Z - STRAP_T * 0.5
	var front_z := FACE_Z - STRAP_T
	_add(parent, _box(Vector3(length, 0.07, STRAP_T + STRAP_SINK)), steel,
			Vector3(mirror * (STRAP_X0 + length * 0.5), y, strap_z + STRAP_SINK * 0.5), Vector3.ZERO, out)
	# Knuckle stands 3 cm out from the leaf so the strap slides under the frame, not into it.
	_add(parent, _cyl(0.03, 0.03, 0.10, 8), steel,
			Vector3(mirror * 0.08, y, FACE_Z - 0.03), Vector3.ZERO, out)
	for i: int in range(bolts):
		var bx := 0.11 + 0.085 * float(i) + (0.0 if bolts == 3 else 0.04)
		_bolt(parent, mirror * bx, y, front_z, dark, out)
	if rng.randf() < 0.6:
		_add(parent, _box(Vector3(0.02, 0.08, 0.01)), dark,
				Vector3(mirror * (STRAP_X0 + length), y, front_z - 0.005 + 0.002), Vector3.ZERO, out)


static func _locking_rod(parent: Node3D, mirror: float, steel: Material, dark: Material,
		out: Array[Node3D]) -> void:
	var rod_len := ROD_TOP_Y - ROD_BOTTOM_Y - TIP_LEN
	_add(parent, _cyl(0.0125, 0.0125, rod_len, 8), steel,
			Vector3(mirror * ROD_X, ROD_TOP_Y - rod_len * 0.5, ROD_Z), Vector3.ZERO, out)
	_add(parent, _cyl(0.0125, 0.006, TIP_LEN, 8), steel,
			Vector3(mirror * ROD_X, ROD_BOTTOM_Y + TIP_LEN * 0.5, ROD_Z), Vector3.ZERO, out)
	for bracket_y: float in [-1.05, -1.40]:
		# U: back plate on the leaf, two cheeks reaching past the rod.
		_add(parent, _box(Vector3(0.05, 0.03, 0.013 + SINK)), dark,
				Vector3(mirror * ROD_X, bracket_y, FACE_Z - 0.0065 + SINK * 0.5), Vector3.ZERO, out)
		for side: float in [-1.0, 1.0]:
			_add(parent, _box(Vector3(0.008, 0.03, 0.03)), dark,
					Vector3(mirror * (ROD_X + side * 0.021), bracket_y, ROD_Z), Vector3.ZERO, out)
	# Cam lever from the rod top up to the handle mount, in front of the mount's face.
	_add(parent, _box(Vector3(0.16, 0.025, 0.015)), steel,
			Vector3(mirror * (ROD_X + 0.08), ROD_TOP_Y + 0.03, -0.1275),
			Vector3(0.0, 0.0, mirror * deg_to_rad(20.0)), out)


## Backing plate behind the handle mount. Centred 1 cm toward the hinge so it stops at x 3.33.
static func _handle_plate(parent: Node3D, mirror: float, steel: Material,
		out: Array[Node3D]) -> void:
	var cx := HANDLE_X - 0.01
	var front_z := FACE_Z - 0.015
	# The back is buried 2.5 cm more than the front's sink so it clears the leaf's inner sheet back.
	var depth := PLATE_T + SINK + 0.025
	_add(parent, _box(Vector3(0.18, 0.24, depth)), steel,
			Vector3(mirror * cx, HANDLE_Y, front_z + depth * 0.5), Vector3.ZERO, out)
	out[out.size() - 1].name = "HandlePlate"
	# The mount hides the plate except a 3 cm strip on its hinge side, so the bolts line up there.
	for dy: float in [-0.09, -0.03, 0.03, 0.09]:
		_bolt(parent, mirror * (cx - 0.075), HANDLE_Y + dy, front_z, steel, out)
