class_name RearDoorDonorHydraulicCabin
extends RefCounted
## Cabin-side hinge of the donor leaf (owner drawing 2026-10-13): a thick slab welded and bolted to the
## beam's cabin face a third along the leaf, two fat bent tubes running low across to a collar, and a
## steel post standing on a floor slab in front of the rear wall beside the pillar, with a second
## pillar under the tube elbows. The slab and the sleeve pins ride the leaf under `hinge`; floor
## slab, post, collar, elbow pillar, elbows and post tubes stay under its parent, and each moving
## rod (`RearDoorDonorCabinArm`) follows the swing.

const _Panels := preload("res://scripts/van/look/rear_door_donor_panels.gd")
const _Beam := preload("res://scripts/van/look/rear_door_donor_beam.gd")
const _Hydraulic := preload("res://scripts/van/look/rear_door_donor_hydraulic.gd")

## Door slab: centre x along the leaf, size; its back sinks 1 cm into the beam's cabin face.
const SLAB_X := 0.9
const SLAB := Vector3(0.36, 0.3, 0.06)
## The sliding rods pin to the slab at this z, clear of the beam (4 cm).
const ARM_Z := _Beam.BACK_Z - 0.07
## Fixed parts (post, elbow pillar, tubes) stand at this z, cabin-ward of the pillar surround's
## deep ring (face at -0.45), and at these x: the post in front of the rear wall beside the pillar
## (the wall is at -0.69), the elbow pillar out in the opening, past every swing of the rods.
const FIXED_Z := -0.62
const POST_X := -0.40
const ELBOW_X := 0.7
const TUBE_R := 0.029
const POST_R := 0.05
const POST_H := 0.5
const COLLAR_R := 0.085
## Floor slab under the post (its pillar-side edge is the surround's ring face) and the elbow
## pillar's small floor plate.
const FLOOR_SLAB := Vector3(0.32, 0.07, 0.44)
const PLATE := Vector3(0.22, 0.04, 0.22)
const PILLAR_R := 0.045


## Builds the cabin hinge for the leaf under `hinge`; returns every node added.
static func build(hinge: Node3D, rect: Rect2) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var frame := hinge.get_parent() as Node3D
	if frame == null:
		return out
	var base := hinge.position
	var ym := _Beam.hinge_mount(rect).y
	var floor_y := -base.y
	var steel := _Panels.flat(Color(0.11, 0.11, 0.12), 0.7, 0.55)
	var worn := _Panels.flat(Color(0.2, 0.17, 0.14), 0.6, 0.65)
	var bolt := _Panels.flat(Color(0.07, 0.07, 0.08), 0.8, 0.4)
	# Door slab against the beam's cabin face, with four bolt heads and a welded rib along the top.
	var slab_z := _Beam.BACK_Z - SLAB.z * 0.5 + 0.01
	_Hydraulic._box(hinge, "CabinHingeSlab", SLAB, steel, Vector3(SLAB_X, ym, slab_z), out)
	for sx: float in [-0.12, 0.12]:
		for sy: float in [-0.09, 0.09]:
			_bolt(hinge, Vector3(SLAB_X + sx, ym + sy, slab_z - SLAB.z * 0.5 - 0.008), 0.03, bolt, out)
	# Tubes: a sliding rod from the slab to the elbow on its pillar, then a fixed tube on to the collar
	# so they meet the post above the floor slab. Elbows get a ball so the bend reads welded.
	var cy := floor_y + FLOOR_SLAB.y + 0.13
	for k: int in 2:
		var y0 := ym + (0.075 if k == 0 else -0.075)
		var y1 := cy + (0.05 if k == 0 else -0.04)
		var elbow := Vector3(ELBOW_X, y0, FIXED_Z)
		# The post side is fixed: post tube, elbow and collar stay under the frame. The door side is
		# a rod turning about the elbow and sliding in a sleeve pinned to the slab.
		_tube(frame, "CabinHingeTube", base + elbow, base + Vector3(POST_X, y1, FIXED_Z), steel, out)
		var ball := SphereMesh.new()
		ball.radius = TUBE_R * 1.15
		ball.height = ball.radius * 2.0
		ball.radial_segments = 8
		ball.rings = 4
		_Hydraulic._part(frame, "CabinHingeElbow", ball, steel, base + elbow, out)
		var arm := RearDoorDonorCabinArm.new()
		arm.name = "CabinHingeArm%d" % k
		arm.position = base + elbow
		frame.add_child(arm)
		out.append(arm)
		arm.setup(hinge, Vector3(SLAB_X, y0, ARM_Z), TUBE_R, steel, worn)
		# Vertical pin through the sleeve's end.
		_Hydraulic._part(hinge, "CabinHingePin", _Hydraulic._cyl(0.022, 0.022, 0.14, 8), bolt,
				Vector3(SLAB_X, y0, ARM_Z), out)
	# Collar wrapping the post, with a nut on each end.
	_Hydraulic._part(frame, "CabinHingeCollar", _Hydraulic._cyl(COLLAR_R, COLLAR_R, 0.2, 12), worn,
			base + Vector3(POST_X, cy, FIXED_Z), out)
	for s: float in [-1.0, 1.0]:
		_Hydraulic._part(frame, "CabinHingeCollarNut", _Hydraulic._cyl(0.06, 0.06, 0.03, 6), bolt,
				base + Vector3(POST_X, cy + s * 0.105, FIXED_Z), out)
	# Floor slab bolted to the floor in front of the rear wall, the post, and the elbow pillar on its
	# own bolted plate holding both elbows up.
	var slab_top := floor_y + FLOOR_SLAB.y - 0.01
	var slab_c := Vector3(POST_X, 0.0, FIXED_Z - 0.07)
	_Hydraulic._box(frame, "CabinHingeFloorSlab", FLOOR_SLAB, steel,
			base + slab_c + Vector3(0.0, slab_top - FLOOR_SLAB.y * 0.5, 0.0), out)
	for sx: float in [-0.1, 0.1]:
		for sz: float in [-0.14, 0.14]:
			_bolt(frame, base + slab_c + Vector3(sx, slab_top + 0.008, sz), 0.035, bolt, out, true)
	_Hydraulic._part(frame, "CabinHingePost", _Hydraulic._cyl(POST_R, POST_R, POST_H, 12), steel,
			base + Vector3(POST_X, slab_top + POST_H * 0.5 - 0.01, FIXED_Z), out)
	_Hydraulic._part(frame, "CabinHingePostNut", _Hydraulic._cyl(0.07, 0.07, 0.04, 6), bolt,
			base + Vector3(POST_X, slab_top + POST_H - 0.01, FIXED_Z), out)
	var plate_top := floor_y + PLATE.y
	_Hydraulic._box(frame, "CabinHingeElbowPlate", PLATE, steel,
			base + Vector3(ELBOW_X, floor_y + PLATE.y * 0.5, FIXED_Z), out)
	for sx: float in [-0.07, 0.07]:
		for sz: float in [-0.07, 0.07]:
			_bolt(frame, base + Vector3(ELBOW_X + sx, plate_top + 0.008, FIXED_Z + sz), 0.025, bolt,
					out, true)
	var top_y := ym + 0.075 + 0.04
	_Hydraulic._part(frame, "CabinHingeElbowPillar",
			_Hydraulic._cyl(PILLAR_R, PILLAR_R, top_y - plate_top, 10), steel,
			base + Vector3(ELBOW_X, (top_y + plate_top) * 0.5, FIXED_Z), out)
	return out


## Hex bolt head of radius `r`; `up` stands it on a horizontal face instead of a vertical one.
static func _bolt(parent: Node3D, at: Vector3, r: float, mat: Material, out: Array[Node3D],
		up: bool = false) -> void:
	_Hydraulic._part(parent, "CabinHingeBolt", _Hydraulic._cyl(r, r, 0.016, 6), mat, at, out,
			Vector3.ZERO if up else Vector3(PI * 0.5, 0.0, 0.0))


## Round tube from `a` to `b` (both at one z, so the run lies in the xy plane).
static func _tube(parent: Node3D, node_name: String, a: Vector3, b: Vector3, mat: Material,
		out: Array[Node3D]) -> void:
	var d := b - a
	_Hydraulic._part(parent, node_name, _Hydraulic._cyl(TUBE_R, TUBE_R, d.length(), 10), mat,
			(a + b) * 0.5, out, Vector3(0.0, 0.0, atan2(-d.x, d.y)))
