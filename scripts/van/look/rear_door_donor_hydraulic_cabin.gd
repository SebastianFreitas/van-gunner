class_name RearDoorDonorHydraulicCabin
extends RefCounted
## Cabin-side hinge of the donor leaf: one 3-stage telescoping hydraulic ram
## (`RearDoorDonorCabinArm`) from a welded bracket on the rear wall beside the hinge pillar to a
## cast spring hanger (a base plate bolted to the welded iron box's cabin face, `RearDoorDonorBox`,
## with two thick cheeks standing the door pin out to the ram's low line). The slab and its bars ride the leaf under `hinge`; the wall bracket and
## the ram stay under its parent.
##
## Layout found by a sweep in the hinge-local xz plane, leaf angle 0..110 deg in 5 deg steps: the
## ram's axis segment (wall pin to the leaf pin rotated by the angle) against two keep-outs, the
## leaf (x 0..1.4, z -0.27..0.145, the beam's and the box's back being -0.27) and the hinge pillar's
## deep ring (x <= -0.1, z >= -0.45; the ring's real x extent is -0.30..-0.14 plus its 0.16 ramp),
## and against the hinge axis. Worst clearance 0.065 m at 110 deg (also with the 0.15 m beyond the
## pin), so the outermost parts (collar 1 and the base cap, r 0.047) keep their 1 cm. Pin distance
## 0.365 m closed to 1.217 m open, ratio 3.3. Three tubes (cylinder 0.49, stages 0.52), stage 3
## ending in a yoke whose tines straddle the cylinder to the leaf pin, so the closed cylinder's
## overrun past the pin hangs between the tines; stage overlap at full stretch is 0.084 m. The
## wall pin is 8 cm off its plate so the base cap clears it at every heading.
## The strut rides at KNEE above the leaf rect's bottom (about 0.52 m above the cabin floor); the
## slab is narrow enough to stay clear of the jerry can (x >= 0.42, bottom 0.20 above the rect).
## The box (x 0.02.., z -0.27..-0.03, y up to 0.62) stands at the ram's height, so it is in the sweep:
## with its hinge-end cabin corner cut off 4 cm at 45 degrees (`RearDoorDonorBox.BEVEL`) the worst
## clearance against it is 0.065 m at 110 deg (0.0448 m with a square corner), over the collar's 1 cm.
## Its closing top plate (same top, hinge-end corner notched square past the bevel) stays inside that outline.

const _Panels := preload("res://scripts/van/look/rear_door_donor_panels.gd")
const _Beam := preload("res://scripts/van/look/rear_door_donor_beam.gd")
const _Hydraulic := preload("res://scripts/van/look/rear_door_donor_hydraulic.gd")

## Door slab: centre x along the leaf, size; its street face sits on the box's and the beam's cabin face.
const SLAB_X := 0.30
const SLAB := Vector3(0.2, 0.42, 0.06)
## The slab reaches 9 cm lower than the strut centre: its foot overlaps the beam (top 0.255) and its
## head ends at the box's top (0.62).
const SLAB_DY := -0.09
## Hinge-local height of the whole strut (pins, slab, bracket) above the leaf rect's bottom.
const KNEE := 0.50
## Standoff bars and wall lugs stand this far off the ram's axis.
const BAR_Y := 0.08
const WALL_LUG_Y := 0.062
## The ram pins to the slab's standoff bars at this z, 41 cm cabin-ward of the beam.
const ARM_Z := -0.64
## Wall bracket: plate on the rear wall (at -0.69) beside the hinge pillar, pin 9 cm out of it,
## cabin-ward of the pillar surround's deep ring (face at -0.45).
const WALL_X := -0.06
const WALL_PLATE_Z := -0.675
const WALL_PIN_Z := -0.58
const WALL_PLATE := Vector3(0.2, 0.26, 0.03)


## Builds the cabin hinge for the leaf under `hinge`; returns every node added.
static func build(hinge: Node3D, rect: Rect2) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var frame := hinge.get_parent() as Node3D
	if frame == null:
		return out
	var base := hinge.position
	var ym := rect.position.y + KNEE
	var steel := _Panels.flat(Color(0.11, 0.11, 0.12), 0.7, 0.3)
	var ram_steel := _Panels.flat(Color(0.12, 0.12, 0.13), 0.6, 0.3)
	var worn := _Panels.flat(Color(0.2, 0.17, 0.14), 0.6, 0.3)
	var bolt := _Panels.flat(Color(0.07, 0.07, 0.08), 0.8, 0.3)
	# Polished: metallic at the art cap (0.3) so diffuse light lands on it,
	# light albedo, low roughness.
	var chrome := _Panels.flat(Color(0.85, 0.86, 0.88), 0.15, 0.3)
	var collar := _Panels.flat(Color(0.5, 0.48, 0.45), 0.35, 0.3)
	var ring := _Panels.flat(Color(1.0, 1.0, 1.0), 0.15, 0.3)
	# Door slab against the beam's cabin face with four bolt heads, and two lugs holding the pin.
	var slab_z := _Beam.BACK_Z - SLAB.z * 0.5
	_Hydraulic._box(hinge, "CabinHingeSlab", SLAB, steel, Vector3(SLAB_X, ym + SLAB_DY, slab_z), out)
	for sx: float in [-0.06, 0.06]:
		for sy: float in [-0.12, 0.12]:
			_bolt(hinge, Vector3(SLAB_X + sx, ym + SLAB_DY + sy, slab_z - SLAB.z * 0.5 - 0.008), 0.034,
					bolt, out)
	# Two flat standoff bars from the slab out to the pin, 16 cm apart so the yoke's tines pass between them and the bars.
	var bar_z0 := slab_z - SLAB.z * 0.5 + 0.005
	var bar_z1 := ARM_Z - 0.04
	for s: float in [-1.0, 1.0]:
		_Hydraulic._box(hinge, "CabinHingeLug", Vector3(0.07, 0.025, bar_z0 - bar_z1), worn,
				Vector3(SLAB_X, ym + s * BAR_Y, (bar_z0 + bar_z1) * 0.5), out)
		# Cast taper: a thick outer rib along the cheek's slab half, and a big boss round the pin.
		_Hydraulic._box(hinge, "CabinHingeCast", Vector3(0.11, 0.04, (bar_z0 - bar_z1) * 0.5), worn,
				Vector3(SLAB_X, ym + s * (BAR_Y + 0.03), bar_z0 - (bar_z0 - bar_z1) * 0.25), out)
		_Hydraulic._part(hinge, "CabinHingeBoss", _Hydraulic._cyl(0.042, 0.042, 0.032, 8), worn,
				Vector3(SLAB_X, ym + s * (BAR_Y + 0.014), ARM_Z), out)
	# Two pin stubs through the yoke tines and the bars, none through the tubes between them,
	# a hex head proud of each cheek and the threaded end proud of one nut.
	for s: float in [-1.0, 1.0]:
		_Hydraulic._part(hinge, "CabinHingePin", _Hydraulic._cyl(0.016, 0.016, 0.077, 8), bolt,
				Vector3(SLAB_X, ym + s * 0.0855, ARM_Z), out)
		_Hydraulic._part(hinge, "CabinHingePinHead", _Hydraulic._cyl(0.03, 0.03, 0.016, 6), bolt,
				Vector3(SLAB_X, ym + s * 0.116, ARM_Z), out)
	_Hydraulic._part(hinge, "CabinHingePinEnd", _Hydraulic._cyl(0.013, 0.013, 0.02, 8), bolt,
			Vector3(SLAB_X, ym - 0.134, ARM_Z), out)
	# Wall bracket on the pillar: plate with four bolts, two lugs and the vertical pin.
	var wall := base + Vector3(WALL_X, ym, WALL_PLATE_Z)
	_Hydraulic._box(frame, "CabinHingeWallPlate", WALL_PLATE, steel, wall, out)
	for sx: float in [-0.07, 0.07]:
		for sy: float in [-0.09, 0.09]:
			_bolt(frame, wall + Vector3(sx, sy, WALL_PLATE.z * 0.5 + 0.008), 0.026, bolt, out)
	# The cylinder's cap sits between the lugs, which stand 6.2 cm out from the axis.
	var lug_z0 := WALL_PLATE_Z + WALL_PLATE.z * 0.5 - 0.005
	var lug_z1 := WALL_PIN_Z + 0.04
	for s: float in [-1.0, 1.0]:
		_Hydraulic._box(frame, "CabinHingeWallLug", Vector3(0.07, 0.02, lug_z1 - lug_z0), worn,
				base + Vector3(WALL_X, ym + s * WALL_LUG_Y, (lug_z0 + lug_z1) * 0.5), out)
	_Hydraulic._part(frame, "CabinHingeWallPin", _Hydraulic._cyl(0.016, 0.016, 0.16, 8), bolt,
			base + Vector3(WALL_X, ym, WALL_PIN_Z), out)
	# The strut itself: dark cylinder, chrome stages sliding out of it.
	var arm := RearDoorDonorCabinArm.new()
	arm.name = "CabinHingeStrut"
	arm.position = base + Vector3(WALL_X, ym, WALL_PIN_Z)
	frame.add_child(arm)
	out.append(arm)
	arm.setup(hinge, Vector3(SLAB_X, ym, ARM_Z), {"body": ram_steel, "chrome": chrome,
			"collar": collar, "ring": ring, "weld": worn})
	return out


## Hex bolt head of radius `r` on a vertical face.
static func _bolt(parent: Node3D, at: Vector3, r: float, mat: Material, out: Array[Node3D]) -> void:
	_Hydraulic._part(parent, "CabinHingeBolt", _Hydraulic._cyl(r, r, 0.016, 6), mat, at, out,
			Vector3(PI * 0.5, 0.0, 0.0))
