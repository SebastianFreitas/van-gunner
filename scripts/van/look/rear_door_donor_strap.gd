class_name RearDoorDonorStrap
extends RefCounted
## The bent angle-iron cap welded over the donor leaf's dented roofing sheet's top edge (spec 1).
## The lower strap hinge went to tag archive/donor-lower-strap-hinge. Hinge-local metres, layer 2.

const _Panels := preload("res://scripts/van/look/rear_door_donor_panels.gd")
const _Welds := preload("res://scripts/van/look/rear_door_donor_welds.gd")

## The cabin face of the sheet's ribs where it is not dented.
const SHEET_Z := RearDoorDonorSheet.Z_FACE - 0.018 - 0.004


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


## A box turned `spin` about z, then the whole bar turned `tilt` about `pivot` (XY).
static func _box(st: SurfaceTool, size: Vector3, at: Vector3, pivot: Vector2, tilt: float,
		spin: float) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var rel := Vector2(at.x, at.y) - pivot
	var p := pivot + rel.rotated(tilt)
	st.append_from(mesh, 0, Transform3D(Basis(Vector3.BACK, tilt + spin), Vector3(p.x, p.y, at.z)))
