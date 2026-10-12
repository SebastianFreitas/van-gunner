class_name RearDoorDonorHydraulic
extends RefCounted
## Heavy lift-top hinge that carries the donor leaf's beam (spec 2): thick plates bolted to the
## beam's hinge-end plate and to the van's fixed rear edge, a fat pin on the leaf's hinge axis and
## a gas strut between a frame-side lug and a beam-side lug. Leaf parts sit under `hinge`, frame
## parts under its parent (hinge position added), so only the strut moves on its own.

const _Panels := preload("res://scripts/van/look/rear_door_donor_panels.gd")
const _Beam := preload("res://scripts/van/look/rear_door_donor_beam.gd")
const _Strut := preload("res://scripts/van/look/rear_door_donor_strut.gd")

const PIN_R := 0.028
const BARREL_R := 0.055
const BARREL_H := 0.33
## Frame lug and beam lug (hinge-local, y relative to the beam's mid height).
const FRAME_LUG := Vector3(-0.4, 0.14, 0.17)
const BEAM_LUG := Vector3(0.15, 0.0, 0.19)
## Length of each telescoping sleeve: three of them cover 0.24 m closed to 0.57 m open.
const BODY_LEN := 0.216


## Builds the hinge and strut for the leaf under `hinge`; returns every node added.
static func build(hinge: Node3D, rect: Rect2) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var frame := hinge.get_parent() as Node3D
	if frame == null:
		return out
	var base := hinge.position
	var mount := _Beam.hinge_mount(rect)
	var ym := mount.y
	var steel := _Panels.flat(Color(0.11, 0.11, 0.12), 0.7, 0.55)
	var worn := _Panels.flat(Color(0.2, 0.17, 0.14), 0.6, 0.65)
	var bolt := _Panels.flat(Color(0.07, 0.07, 0.08), 0.8, 0.4)
	# Leaf side: plate on the end plate's hinge face, the barrel on the axis, the pin through it.
	_box(hinge, "HingeLeafPlate", Vector3(0.04, 0.3, 0.15), steel,
			Vector3(mount.x - 0.02, ym, mount.z), out)
	_part(hinge, "HingeBarrel", _cyl(BARREL_R, BARREL_R, BARREL_H, 14), steel,
			Vector3(0.0, ym, 0.0), out)
	_part(hinge, "HingePin", _cyl(PIN_R, PIN_R, 0.4, 12), worn, Vector3(0.0, ym, 0.0), out)
	for s: float in [-1.0, 1.0]:
		_part(hinge, "HingeNut", _cyl(0.04, 0.04, 0.028, 6), bolt,
				Vector3(0.0, ym + s * 0.2, 0.0), out)
		_part(hinge, "HingeLeafBolt", _cyl(0.017, 0.017, 0.016, 6), bolt,
				Vector3(mount.x - 0.02, ym + s * 0.09, mount.z + 0.075 + 0.006), out,
				Vector3(PI * 0.5, 0.0, 0.0))
	# Frame side: base plate on the fixed edge, two clevis ears over and under the barrel.
	_box(frame, "HingeFramePlate", Vector3(0.4, 0.46, 0.03), steel,
			base + Vector3(-0.28, ym, -0.015), out)
	for sx: float in [-0.4, -0.16]:
		for s: float in [-1.0, 1.0]:
			_part(frame, "HingeFrameBolt", _cyl(0.02, 0.02, 0.018, 6), bolt,
					base + Vector3(sx, ym + s * 0.19, 0.009), out, Vector3(PI * 0.5, 0.0, 0.0))
	for s: float in [-1.0, 1.0]:
		var ey := ym + s * 0.145
		_box(frame, "HingeEar", Vector3(0.1, 0.04, 0.14), steel, base + Vector3(-0.09, ey, 0.0),
				out)
		_part(frame, "HingeEarDisc", _cyl(0.07, 0.07, 0.08, 14), steel,
				base + Vector3(0.0, ey, 0.0), out)
	# Strut lugs and eyes.
	var f := Vector3(FRAME_LUG.x, ym + FRAME_LUG.y, FRAME_LUG.z)
	var b := Vector3(BEAM_LUG.x, ym + BEAM_LUG.y, BEAM_LUG.z)
	_lug(frame, base + f, Vector3(0.09, 0.012, 0.17), 0.0, steel, bolt, out)
	_box(frame, "FrameLugWeb", Vector3(0.09, 0.09, 0.03), steel,
			base + Vector3(f.x, f.y, 0.015), out)
	_lug(hinge, b, Vector3(0.09, 0.012, 0.09), 0.1, steel, bolt, out)
	_box(hinge, "BeamLugBack", Vector3(0.09, 0.09, 0.03), steel,
			Vector3(b.x, b.y, _Beam.FRONT_Z + 0.015), out)
	var strut := _Strut.new()
	strut.name = "DonorStrut"
	frame.add_child(strut)
	out.append(strut)
	strut.setup(hinge, base + f, b, BODY_LEN)
	return out


## Fork of two plates around an eye at `at`, a pin through them. `back` shifts the plates in z.
static func _lug(parent: Node3D, at: Vector3, plate: Vector3, back: float, steel: Material,
		bolt: Material, out: Array[Node3D]) -> void:
	for s: float in [-1.0, 1.0]:
		_box(parent, "LugPlate", plate, steel,
				at + Vector3(0.0, s * 0.036, -plate.z * 0.5 + 0.045 + back), out)
	_part(parent, "LugPin", _cyl(0.01, 0.01, 0.1, 8), bolt, at, out)
	_part(parent, "LugBolt", _cyl(0.02, 0.02, 0.014, 6), bolt, at + Vector3(0.0, 0.056, 0.0), out)


static func _cyl(top: float, bottom: float, height: float, sides: int) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = maxi(sides, 3)
	mesh.rings = 1
	return mesh


static func _box(parent: Node3D, node_name: String, size: Vector3, mat: Material, pos: Vector3,
		out: Array[Node3D]) -> void:
	_part(parent, node_name, _Panels.box(size), mat, pos, out)


static func _part(parent: Node3D, node_name: String, mesh: Mesh, mat: Material, pos: Vector3,
		out: Array[Node3D], rot: Vector3 = Vector3.ZERO) -> void:
	_Panels.add(parent, node_name, mesh, mat, pos, rot, out)
	var node := out.back() as Node3D
	node.add_to_group(VanLighting.GROUP_EXTERIOR_LAYER)
	VanLighting.retarget_layers(node as VisualInstance3D, VanLighting.LAYER_STREET_AND_INTERIOR)
