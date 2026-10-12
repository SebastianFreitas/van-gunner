class_name RearDoorDonorBeam
extends RefCounted
## The donor rear leaf's foundation (spec 2): one big fresh-steel rectangular box beam, level along
## the door bottom from the latch corner to the hinge corner, through the leaf's thickness and a
## few cm proud of both faces. Weld beads on its top edges and bolt heads on both faces make the
## door's other parts read as attached to it. The roofing sheet sits on its top. Hinge-local metres.

const _LeafBuild := preload("res://scripts/van/rear_door_leaf_build.gd")
const _Panels := preload("res://scripts/van/look/rear_door_donor_panels.gd")
const _Welds := preload("res://scripts/van/look/rear_door_donor_welds.gd")

## Beam bottom above the leaf rect's bottom and overall height.
const LIFT := 0.08
const HEIGHT := 0.175
## Street face (3.5 cm proud of the leaf's street skin, clear of the jamb ring's 2 cm plane; FRONT_Z is the
## hydraulic's lug reference) and cabin face (6 cm proud of its cabin skin).
const FRONT_Z := _LeafBuild.STREET_HALF + 0.02
const BEAM_FRONT_Z := _LeafBuild.STREET_HALF + 0.065
const BACK_Z := _LeafBuild.CABIN_Z - 0.06
## Hinge-local y of the beam's top, relative to the leaf rect's bottom.
const TOP := LIFT + HEIGHT
## The beam is part of the door: each end sits this far in from the leaf's corner, so with the end
## caps' 1 cm overhang it never passes the hinge edge (pillars) or the latch edge (other leaf).
const END_SET := 0.04
const CAP_T := 0.015
const BOLT_R := 0.016
const BOLT_H := 0.014
## The hydraulic's mount (spec 3): the hinge-end cap's hinge face (never past the door edge), the
## beam's mid height above the leaf rect's bottom, and the hinge axis' z.
const MOUNT := Vector3(END_SET - 0.005, LIFT + HEIGHT * 0.5, 0.0)


## The hinge-end mount the hydraulic fits to: the hinge end cap's hinge-side face.
static func hinge_mount(rect: Rect2) -> Vector3:
	return Vector3(MOUNT.x, rect.position.y + MOUNT.y, MOUNT.z)


## Builds the beam under `hinge`; `rect` is the leaf rect. Returns every node added.
static func build(hinge: Node3D, rect: Rect2) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var y0 := rect.position.y + LIFT
	var y1 := y0 + HEIGHT
	var x0 := rect.position.x + END_SET
	var x1 := rect.end.x - END_SET
	var xm := (x0 + x1) * 0.5
	var depth := BEAM_FRONT_Z - BACK_Z
	var zc := (BEAM_FRONT_Z + BACK_Z) * 0.5
	var steel := SurfaceTool.new()
	steel.begin(Mesh.PRIMITIVE_TRIANGLES)
	_Welds.add_box(steel, Vector3(x1 - x0, HEIGHT, depth), Vector3(xm, (y0 + y1) * 0.5, zc), 0.0)
	# End caps, a cm larger all round so the open ends of the tube read as welded-on plates.
	for x: float in [x0 + CAP_T * 0.5 - 0.005, x1 - CAP_T * 0.5 + 0.005]:
		_Welds.add_box(steel, Vector3(CAP_T + 0.01, HEIGHT, depth + 0.02),
				Vector3(x, (y0 + y1) * 0.5, zc), 0.0)
	var mat := _Panels.grime(Color(0.17, 0.17, 0.18)) as ShaderMaterial
	mat.set_shader_parameter(&"wall_size_m", Vector2(0.5, 0.25))
	mat.set_shader_parameter(&"panel_spacing_m", 40.0)
	mat.set_shader_parameter(&"belt_y_m", 90.0)
	mat.set_shader_parameter(&"waist_y_m", 90.0)
	mat.set_shader_parameter(&"roughness_value", 0.8)
	mat.set_shader_parameter(&"metallic_value", 0.25)
	mat.set_shader_parameter(&"kick_height_m", 0.05)
	mat.set_shader_parameter(&"kick_color", Color(0.2, 0.15, 0.12))
	_Panels.add(hinge, "DonorBeam", steel.commit(), mat, Vector3.ZERO, Vector3.ZERO, out)
	_street(out.back())
	var beads := SurfaceTool.new()
	beads.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Diamond beads sunk into the joins (no bead face parallel to a beam face): the top face to
	# the leaf's street skin and to its cabin skin, and the street edge of the hinge-side cap.
	_corner(beads, Vector3(0.03, y1, _LeafBuild.STREET_HALF),
			Vector3(x1 - 0.04, y1, _LeafBuild.STREET_HALF))
	_corner(beads, Vector3(0.03, y1, _LeafBuild.CABIN_Z), Vector3(x1 - 0.04, y1, _LeafBuild.CABIN_Z))
	_Panels.add(hinge, "DonorBeamWeld", beads.commit(), _Welds.weld_steel(), Vector3.ZERO,
			Vector3.ZERO, out)
	_street(out.back())
	_bolts(hinge, (y0 + y1) * 0.5, x0, x1, out)
	return out


## Hex bolt heads: a row on each of the beam's two long faces, so it shows as bolted on both sides.
static func _bolts(hinge: Node3D, ym: float, x0: float, x1: float, out: Array[Node3D]) -> void:
	var head := CylinderMesh.new()
	head.top_radius = BOLT_R
	head.bottom_radius = BOLT_R
	head.height = BOLT_H
	head.radial_segments = 6
	head.rings = 1
	var rust := _Panels.flat(Color(0.2, 0.17, 0.15), 0.8, 0.3)
	var pitch := 0.42
	for k in int((x1 - x0 - 0.2) / pitch) + 1:
		var x := x0 + 0.12 + k * pitch
		for s: float in [1.0, -1.0]:
			var z := (BEAM_FRONT_Z if s > 0.0 else BACK_Z) + s * (BOLT_H * 0.5 - 0.002)
			_Panels.add(hinge, "DonorBeamBolt", head, rust, Vector3(x, ym, z),
					Vector3(PI * 0.5, 0.0, 0.0), out)
			_street(out.back())


## A square-section bead a -> b (axis-aligned) turned 45 degrees about its run so it shows only
## diagonal faces: sunk into the join, nothing parallel to a beam face.
static func _corner(st: SurfaceTool, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var box := BoxMesh.new()
	box.size = Vector3(d.length(), 0.02, 0.02)
	st.append_from(box, 0, Transform3D(Basis(Vector3.RIGHT, PI * 0.25), (a + b) * 0.5))


static func _street(node: Node3D) -> void:
	node.add_to_group(VanLighting.GROUP_EXTERIOR_LAYER)
	VanLighting.retarget_layers(node as VisualInstance3D, VanLighting.LAYER_STREET_AND_INTERIOR)
