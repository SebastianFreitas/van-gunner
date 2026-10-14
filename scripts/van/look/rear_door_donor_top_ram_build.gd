class_name RearDoorDonorTopRamBuild
extends RefCounted
## Builds the donor leaf's top ram (blockout): the arch bracket (plate on the rear arch header's
## cabin face, a hanger strap down to the pin's lugs), the door plate on the leaf's yellow crest
## by its free top corner, both pins with their lugs, and the aimed `RearDoorDonorTopRam` (rods
## and twin sleeve). Sweep numbers are in `RearDoorDonorTopRam`.

const _Hydraulic := preload("res://scripts/van/look/rear_door_donor_hydraulic.gd")
const _Panels := preload("res://scripts/van/look/rear_door_donor_panels.gd")
const _LeafBuild := preload("res://scripts/van/rear_door_leaf_build.gd")

const PLATE := Vector3(0.2, 0.18, 0.04)
## Arch bracket: back face on the frame's cabin face (-0.253), centre above the leaf top (3.6), so
## the plate hangs off the header and stays clear of the swinging leaf.
const PLATE_Z := -0.273
const PLATE_DY := 0.33
const HANGER := Vector3(0.05, 0.2, 0.016)
const DOOR_PLATE := Vector3(0.16, 0.22, 0.03)
## Door plate on the yellow crest above the window, clear of the edge beam: its back sits 2 mm into
## the cabin face (CABIN_Z -0.17, the pressed beams' crest).
const DOOR_PLATE_Z := -0.183
const DOOR_PLATE_X := 2.10
const LUG_Y := 0.068
const PIN_H := 0.18


## Builds the top ram for the leaf under `hinge`; returns every node added.
static func build(hinge: Node3D) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var frame := hinge.get_parent() as Node3D
	if frame == null:
		return out
	var base := hinge.position
	var ym := 0.5 * (VanOpenings.REAR_WINDOW_Y + RearDoorProfile.DONOR_WIN_HALF.y
			+ VanInteriorSize.REAR_DOOR_TOP) - base.y
	var steel := _Panels.flat(Color(0.11, 0.11, 0.12), 0.7, 0.3)
	var rod := _Panels.flat(Color(0.12, 0.12, 0.13), 0.6, 0.3)
	var sleeve := _Panels.flat(Color(0.36, 0.36, 0.35), 0.6, 0.3)
	var bolt := _Panels.flat(Color(0.07, 0.07, 0.08), 0.8, 0.3)
	var wall_xz := RearDoorDonorTopRam.WALL_XZ
	var door_xz := RearDoorDonorTopRam.DOOR_XZ
	# Arch bracket: plate with four bolt heads on the header, a hanger strap down to the two lugs
	# and the vertical body pin.
	var plate := base + Vector3(wall_xz.x, ym + PLATE_DY, PLATE_Z)
	_Hydraulic._box(frame, "ArchBracket", PLATE, steel, plate, out)
	var face_z := PLATE_Z - PLATE.z * 0.5
	for sx: float in [-0.07, 0.07]:
		for sy: float in [-0.06, 0.06]:
			_bolt(frame, plate + Vector3(sx, sy, -PLATE.z * 0.5 - 0.008), bolt, out)
	var hanger_top := ym + PLATE_DY - PLATE.y * 0.5 + 0.01
	var hanger_bottom := ym + LUG_Y - 0.008
	_Hydraulic._box(frame, "ArchBracketHanger",
			Vector3(HANGER.x, hanger_top - hanger_bottom, HANGER.z), steel,
			base + Vector3(wall_xz.x, (hanger_top + hanger_bottom) * 0.5, face_z - HANGER.z * 0.5 + 0.005),
			out)
	_pin_set(frame, "Body", base + Vector3(wall_xz.x, ym, 0.0), face_z, wall_xz.y, steel, bolt, out)
	# Door plate on the edge beam's cabin face, lugs and the vertical door pin.
	var pin_y := base.y + ym
	var door_face := DOOR_PLATE_Z - DOOR_PLATE.z * 0.5
	_Hydraulic._box(hinge, "DoorPlate", DOOR_PLATE, steel, Vector3(DOOR_PLATE_X, ym, DOOR_PLATE_Z), out)
	for sx: float in [-0.06, 0.06]:
		for sy: float in [-0.095, 0.095]:
			_bolt(hinge, Vector3(DOOR_PLATE_X + sx, ym + sy, door_face - 0.008), bolt, out)
	_pin_set(hinge, "Door", Vector3(door_xz.x, ym, 0.0), door_face, door_xz.y, steel, bolt, out)

	var ram := RearDoorDonorTopRam.new()
	ram.name = "TopRam"
	ram.position = Vector3(base.x + wall_xz.x, pin_y, base.z + wall_xz.y)
	frame.add_child(ram)
	out.append(ram)
	ram.setup(hinge, Vector3(door_xz.x, ym, door_xz.y), {"rod": rod, "sleeve": sleeve})
	out.append_array(RearDoorDonorTopRamPower.build(frame, base, ym))
	return out


## Two lugs from a plate face at `face_z` out to the vertical pin at `pin_z`, and the pin itself;
## `at` carries the pin's x and y.
static func _pin_set(parent: Node3D, label: String, at: Vector3, face_z: float, pin_z: float,
		lug_mat: Material, pin_mat: Material, out: Array[Node3D]) -> void:
	var z1 := pin_z + signf(pin_z - face_z) * 0.03
	for s: float in [-1.0, 1.0]:
		_Hydraulic._box(parent, "%sPinLug" % label, Vector3(0.05, 0.016, absf(z1 - face_z) + 0.005),
				lug_mat, at + Vector3(0.0, s * LUG_Y, (face_z + z1) * 0.5), out)
	_Hydraulic._part(parent, "%sPin" % label, _Hydraulic._cyl(0.016, 0.016, PIN_H, 8), pin_mat,
			at + Vector3(0.0, 0.0, pin_z), out)


## Hex bolt head of radius 0.018 on a vertical face.
static func _bolt(parent: Node3D, at: Vector3, mat: Material, out: Array[Node3D]) -> void:
	_Hydraulic._part(parent, "TopRamBolt", _Hydraulic._cyl(0.018, 0.018, 0.016, 6), mat, at, out,
			Vector3(PI * 0.5, 0.0, 0.0))
