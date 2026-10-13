class_name RearDoorDonorBox
extends RefCounted
## The welded iron box that replaces the bottom of the donor leaf's green sheet: a cut stub of
## square steel box section stood on the beam's top, as wide as the sheet's hole, its top a
## flame-cut edge that leaves the wall thickness open, a stitch weld bead along its floor seam.
## It reaches inward to the beam's cabin face (BACK_Z), so the cast spring hanger the ram's door
## end pins to (`RearDoorDonorHydraulicCabin`) sits flush on its cabin face. Hinge-local metres.

const _Panels := preload("res://scripts/van/look/rear_door_donor_panels.gd")
const _Beam := preload("res://scripts/van/look/rear_door_donor_beam.gd")
const _Hydraulic := preload("res://scripts/van/look/rear_door_donor_hydraulic.gd")

## Height of the box's top above the leaf rect's bottom, and the street-side face's z.
const TOP := 0.62
const FRONT_Z := -0.03
const WALL := 0.014
## Hinge-side x of the box (the sheet's EDGE_X), the gap kept to the cut (the sheet's CUT_GAP) and
## the 45 degree cut-off of the hinge-end cabin corner.
const X0 := 0.02
const CUT_GAP := 0.003
const BEVEL := 0.04
## Stitch weld bead pitch along the floor seam.
const STITCH := 0.09


## Builds the box under `hinge`; returns every node added.
static func build(hinge: Node3D, rect: Rect2, profile: RearDoorProfile) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var y0 := rect.position.y + _Beam.TOP
	var y1 := rect.position.y + TOP
	var x1 := minf(profile.cut_x(rect, y0), profile.cut_x(rect, y1)) - CUT_GAP
	var back := _Beam.BACK_Z
	var size := Vector3(x1 - X0, y1 - y0, FRONT_Z - back)
	var c := Vector3((X0 + x1) * 0.5, (y0 + y1) * 0.5, (FRONT_Z + back) * 0.5)
	var iron := _Panels.grime(Color(0.12, 0.115, 0.11)) as ShaderMaterial
	# Belt and seam lines pushed off the box; rust only low down.
	iron.set_shader_parameter(&"wall_size_m", Vector2(1.0, 50.0))
	iron.set_shader_parameter(&"panel_spacing_m", 40.0)
	iron.set_shader_parameter(&"belt_y_m", 90.0)
	iron.set_shader_parameter(&"waist_y_m", 90.0)
	iron.set_shader_parameter(&"roughness_value", 0.7)
	iron.set_shader_parameter(&"metallic_value", 0.3)
	iron.set_shader_parameter(&"kick_height_m", 0.3)
	iron.set_shader_parameter(&"kick_color", Color(0.2, 0.09, 0.05))
	var bead := _Panels.flat(Color(0.09, 0.085, 0.08), 0.9, 0.3)
	var bolt := _Panels.flat(Color(0.07, 0.07, 0.08), 0.8, 0.3)
	# Four walls on the beam, which is the floor: the top stays open, the cut wall edge showing its thickness.
	# The hinge-end cabin corner is flame-cut off at 45 degrees so the ram's swing clears it.
	_Hydraulic._box(hinge, "DonorBoxWall", Vector3(size.x, size.y, WALL), iron,
			c + Vector3(0.0, 0.0, (size.z - WALL) * 0.5), out)
	_Hydraulic._box(hinge, "DonorBoxWall", Vector3(size.x - BEVEL, size.y, WALL), iron,
			c + Vector3(BEVEL * 0.5, 0.0, -(size.z - WALL) * 0.5), out)
	_Hydraulic._box(hinge, "DonorBoxEnd", Vector3(WALL, size.y, size.z - 2.0 * WALL), iron,
			c + Vector3((size.x - WALL) * 0.5, 0.0, 0.0), out)
	var end_len := size.z - WALL - BEVEL
	_Hydraulic._box(hinge, "DonorBoxEnd", Vector3(WALL, size.y, end_len), iron,
			Vector3(X0 + WALL * 0.5, c.y, FRONT_Z - WALL - end_len * 0.5), out)
	var bevel_mid := Vector3(X0 + BEVEL * 0.5, c.y, back + BEVEL * 0.5)
	var inward := Vector3(1.0, 0.0, 1.0).normalized() * WALL * 0.5
	_Hydraulic._part(hinge, "DonorBoxBevel", _Panels.box(Vector3(BEVEL * 1.414 + 0.01, size.y, WALL)),
			iron, bevel_mid + inward, out, Vector3(0.0, PI * 0.25, 0.0))
	# Stitch weld along the floor seam on the cabin side, each bead a little off its neighbour.
	var k := 0
	var x := X0 + 0.06
	while x < x1 - 0.06:
		_Hydraulic._box(hinge, "DonorBoxBead", Vector3(STITCH * 0.7, 0.02, 0.02 + 0.006 * (k % 2)),
				bead, Vector3(x, y0 + 0.005, back - 0.006), out)
		x += STITCH
		k += 1
	# Welded corner bead up the bevel, and three plug bolts on the cabin face.
	var outward := Vector3(-1.0, 0.0, -1.0).normalized() * 0.002
	_Hydraulic._part(hinge, "DonorBoxBead", _Panels.box(Vector3(0.016, size.y * 0.8, 0.016)), bead,
			bevel_mid + outward, out, Vector3(0.0, PI * 0.25, 0.0))
	for bx: float in [0.25, 0.5, 0.75]:
		_Hydraulic._part(hinge, "DonorBoxBolt", _Hydraulic._cyl(0.02, 0.02, 0.014, 6), bolt,
				Vector3(lerpf(X0, x1, bx), y1 - 0.06, back - 0.007), out, Vector3(PI * 0.5, 0.0, 0.0))
	return out
