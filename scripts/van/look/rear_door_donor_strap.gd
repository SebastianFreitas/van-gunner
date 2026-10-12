class_name RearDoorDonorStrap
extends RefCounted
## Two crude iron fittings on the donor leaf's dented roofing sheet (spec 1): a bent angle-iron cap
## welded over its top edge, and the lower hinge, a long strap welded across the dent out to a
## mismatched pipe-sleeve knuckle with a bent bolt for a pin. Hinge-local metres, layer 2.

const _LeafBuild := preload("res://scripts/van/rear_door_leaf_build.gd")
const _Panels := preload("res://scripts/van/look/rear_door_donor_panels.gd")
const _Welds := preload("res://scripts/van/look/rear_door_donor_welds.gd")
const _Iron := preload("res://scripts/van/look/rear_door_donor_iron.gd")

## The cabin face of the sheet's ribs where it is not dented.
const SHEET_Z := RearDoorDonorSheet.Z_FACE - 0.018 - 0.004
const STRAP_T := 0.012
const STRAP_W := 0.07
## The knuckle stands on the same vertical axis as the stock hinge arms'.
const KNUCKLE_X := 0.078
const KNUCKLE_Z := _LeafBuild.CABIN_Z - 0.06
const SLEEVE_R := 0.034
const SLEEVE_H := 0.2


## The angle-iron cap: one leg over the sheet's top edge, one down its cabin face, the whole bar
## turned a degree or two, stitch-welded along its lower edge, the cut end torched off rough.
static func cap(hinge: Node3D, rect: Rect2, profile: RearDoorProfile,
		rng: RandomNumberGenerator, out: Array[Node3D]) -> void:
	var y1 := RearDoorDonorPlate.seam(rect, profile)[0].y + RearDoorDonorSheet.LAP
	var x0 := 0.035
	var x1 := profile.cut_x(rect, y1) - RearDoorDonorSheet.CUT_GAP
	var pivot := Vector2(x0, y1)
	var tilt := deg_to_rad(1.6)
	var iron := SurfaceTool.new()
	iron.begin(Mesh.PRIMITIVE_TRIANGLES)
	var beads := SurfaceTool.new()
	beads.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tuck_z := SHEET_Z
	var leg_z := tuck_z - 0.003
	# Top leg stops short; the hanging leg runs on and ends in an angled torch cut.
	_box(iron, Vector3(x1 - x0 - 0.07, 0.006, 0.022), Vector3((x0 + x1 - 0.07) * 0.5, y1 + 0.003,
			tuck_z + 0.011), pivot, tilt, 0.0)
	_box(iron, Vector3(x1 - x0 - 0.05, 0.06, 0.006), Vector3((x0 + x1 - 0.05) * 0.5, y1 - 0.027,
			leg_z), pivot, tilt, 0.0)
	_box(iron, Vector3(0.05, 0.06, 0.006), Vector3(x1 - 0.03, y1 - 0.027, leg_z), pivot, tilt,
			0.45)
	var x := x0 + 0.06
	while x < x1 - 0.12:
		_box(beads, Vector3(rng.randf_range(0.03, 0.045), 0.012, 0.012),
				Vector3(x, y1 - 0.056, leg_z - 0.002), pivot, tilt, 0.0)
		x += rng.randf_range(0.09, 0.13)
	_Panels.add(hinge, "SheetCap", iron.commit(), _Welds.rust_steel(), Vector3.ZERO,
			Vector3.ZERO, out)
	_Panels.add(hinge, "SheetCapWeld", beads.commit(), _Welds.weld_steel(), Vector3.ZERO,
			Vector3.ZERO, out)


## The lower hinge: the strap follows the dent from near the cut out to x 0.11, cranks cabin-ward
## to the sleeve, and the sleeve's pin shows its bent shank and its washers.
static func strap_hinge(parent: Node3D, rect: Rect2, profile: RearDoorProfile, y: float,
		rng: RandomNumberGenerator, out: Array[Node3D]) -> void:
	var strap := SurfaceTool.new()
	strap.begin(Mesh.PRIMITIVE_TRIANGLES)
	var beads := SurfaceTool.new()
	beads.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array[Vector2] = []
	for k in 6:
		var x := 0.36 - 0.05 * k
		pts.append(Vector2(x, SHEET_Z - RearDoorDonorSheet.dent_at(rect, profile, x, y)
				- STRAP_T * 0.5))
	pts.append(Vector2(KNUCKLE_X + SLEEVE_R * 0.8, KNUCKLE_Z))
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var mid := (a + b) * 0.5
		var ang := (b - a).angle()
		var size := Vector3(a.distance_to(b) + 0.01, STRAP_W, STRAP_T)
		_flat(strap, size, Vector3(mid.x, y, mid.y), ang)
		for s: float in [-1.0, 1.0]:
			var t := rng.randf_range(0.15, 0.4)
			_flat(beads, Vector3(0.035, 0.01, STRAP_T + 0.026), Vector3(
					lerpf(a.x, b.x, t), y + s * STRAP_W * 0.5, lerpf(a.y, b.y, t)), ang)
	# Heavy welds where the strap meets the sleeve.
	var end: Vector2 = pts.back()
	var last := (end - pts[pts.size() - 2]).angle()
	for oy: float in [-0.045, 0.0, 0.045]:
		_flat(beads, Vector3(0.04, 0.03, 0.045), Vector3(end.x, y + oy, end.y - 0.004), last)
	_Panels.add(parent, "StrapHinge", strap.commit(), _Iron.iron(), Vector3.ZERO, Vector3.ZERO,
			out)
	_street(out.back())
	_Panels.add(parent, "StrapWeld", beads.commit(), _Welds.weld_steel(), Vector3.ZERO,
			Vector3.ZERO, out)
	_street(out.back())
	_knuckle(parent, y, out)


## Pipe sleeve (ten sides, shorter and thinner than the stock knuckles) with the bolt through it.
static func _knuckle(parent: Node3D, y: float, out: Array[Node3D]) -> void:
	var sleeve := CylinderMesh.new()
	sleeve.top_radius = SLEEVE_R
	sleeve.bottom_radius = SLEEVE_R
	sleeve.height = SLEEVE_H
	sleeve.radial_segments = 10
	sleeve.rings = 1
	_Panels.add(parent, "StrapSleeve", sleeve, _Welds.rust_steel(),
			Vector3(KNUCKLE_X, y + 0.01, KNUCKLE_Z), Vector3.ZERO, out)
	_street(out.back())
	var pin := SurfaceTool.new()
	pin.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := y + 0.01 + SLEEVE_H * 0.5
	var at := Vector3(KNUCKLE_X, 0.0, KNUCKLE_Z)
	# Three stacked washers of different size, then the hex head.
	var h := top
	for r: float in [0.03, 0.024, 0.033]:
		_cyl(pin, r, 0.005, at + Vector3(0.0, h + 0.0025, 0.0), Vector3.ZERO, 12)
		h += 0.006
	_cyl(pin, 0.02, 0.014, at + Vector3(0.0, h + 0.007, 0.0), Vector3.ZERO, 6)
	# The shank below the sleeve is straight for 3 cm, then bent.
	var bot := y + 0.01 - SLEEVE_H * 0.5
	_cyl(pin, 0.009, 0.03, at + Vector3(0.0, bot - 0.015, 0.0), Vector3.ZERO, 6)
	_cyl(pin, 0.009, 0.05, at + Vector3(0.012, bot - 0.052, 0.0), Vector3(0.0, 0.0, 0.25), 6)
	_Panels.add(parent, "StrapPin", pin.commit(), _Panels.flat(Color(0.12, 0.08, 0.06), 0.9, 0.25),
			Vector3.ZERO, Vector3.ZERO, out)
	_street(out.back())


## A box spun about hinge-local y by `ang` (the angle of an (x, z) run) and appended to `st`.
static func _flat(st: SurfaceTool, size: Vector3, at: Vector3, ang: float) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	st.append_from(mesh, 0, Transform3D(Basis(Vector3.UP, -ang), at))


## A box turned `spin` about z, then the whole bar turned `tilt` about `pivot` (XY).
static func _box(st: SurfaceTool, size: Vector3, at: Vector3, pivot: Vector2, tilt: float,
		spin: float) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var rel := Vector2(at.x, at.y) - pivot
	var p := pivot + rel.rotated(tilt)
	st.append_from(mesh, 0, Transform3D(Basis(Vector3.BACK, tilt + spin), Vector3(p.x, p.y, at.z)))


static func _cyl(st: SurfaceTool, radius: float, height: float, at: Vector3, rot: Vector3,
		sides: int) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	st.append_from(mesh, 0, Transform3D(Basis.from_euler(rot), at))


## Layers 1+2 like the stock hinge straps, so the street lights it.
static func _street(node: Node3D) -> void:
	node.add_to_group(VanLighting.GROUP_EXTERIOR_LAYER)
	VanLighting.retarget_layers(node as VisualInstance3D, VanLighting.LAYER_STREET_AND_INTERIOR)
