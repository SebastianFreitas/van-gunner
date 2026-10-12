class_name RearDoorDonorBeam
extends RefCounted
## A scavenged structural steel I-beam welded across the bottom of the donor rear leaf as a sill
## (spec 1): wide flanges toward the cabin, a deep web, weld beads along its seams, bolt heads on
## the web and a bolted end plate at the hinge end. The roofing sheet sits on its upper flange.
## Hinge-local metres.

const _LeafBuild := preload("res://scripts/van/rear_door_leaf_build.gd")
const _Panels := preload("res://scripts/van/look/rear_door_donor_panels.gd")
const _Welds := preload("res://scripts/van/look/rear_door_donor_welds.gd")

## Beam bottom above the leaf rect's bottom, overall height, flange and web thickness.
const LIFT := 0.02
const HEIGHT := 0.2
const FLANGE_T := 0.045
const WEB_T := 0.02
## Flange depth (z), its street edge and the web's centre z (hinge-local). The front stands 2 cm
## proud of the leaf's street skin (STREET_HALF 0.08) so the beam reads across the full width
## instead of hiding in the slab past the donor hole.
const DEPTH := 0.11
const FRONT_Z := _LeafBuild.STREET_HALF + 0.02
const WEB_Z := FRONT_Z - DEPTH * 0.5
## Hinge-local y of the upper flange's top, relative to the leaf rect's bottom.
const TOP := LIFT + HEIGHT
## The end plate's thickness and x; the beam starts on its inner face.
const PLATE_T := 0.02
const PLATE_X := 0.005
const RUN_X0 := PLATE_X + PLATE_T
## The latch end stops this far short of the leaf's edge, clear of the astragal's 0.20 m half.
const LATCH_STOP := 0.22
const BOLT_R := 0.016
const BOLT_H := 0.014


## The hinge-end mount: the centre of the end plate's hinge-side face (spec 2 mounts there).
static func hinge_mount(rect: Rect2) -> Vector3:
	return Vector3(PLATE_X, rect.position.y + LIFT + HEIGHT * 0.5, WEB_Z)


## Builds the beam under `hinge`; `rect` is the leaf rect. Returns every node added.
static func build(hinge: Node3D, rect: Rect2) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var y0 := rect.position.y + LIFT
	var y1 := y0 + HEIGHT
	var x1 := rect.end.x - LATCH_STOP
	var run := x1 - RUN_X0
	var xm := (RUN_X0 + x1) * 0.5
	var steel := SurfaceTool.new()
	steel.begin(Mesh.PRIMITIVE_TRIANGLES)
	var zc := FRONT_Z - DEPTH * 0.5
	_Welds.add_box(steel, Vector3(run, FLANGE_T, DEPTH), Vector3(xm, y0 + FLANGE_T * 0.5, zc), 0.0)
	_Welds.add_box(steel, Vector3(run, FLANGE_T, DEPTH), Vector3(xm, y1 - FLANGE_T * 0.5, zc), 0.0)
	_Welds.add_box(steel, Vector3(run, HEIGHT - FLANGE_T * 2.0 + 0.01, WEB_T),
			Vector3(xm, (y0 + y1) * 0.5, WEB_Z), 0.0)
	_Welds.add_box(steel, Vector3(PLATE_T, HEIGHT, DEPTH + 0.04),
			Vector3(PLATE_X + PLATE_T * 0.5, (y0 + y1) * 0.5, zc), 0.0)
	var mat := _Panels.grime(Color(0.19, 0.19, 0.2)) as ShaderMaterial
	mat.set_shader_parameter(&"wall_size_m", Vector2(0.5, 0.25))
	mat.set_shader_parameter(&"panel_spacing_m", 40.0)
	mat.set_shader_parameter(&"belt_y_m", 90.0)
	mat.set_shader_parameter(&"waist_y_m", 90.0)
	mat.set_shader_parameter(&"roughness_value", 0.7)
	mat.set_shader_parameter(&"metallic_value", 0.5)
	mat.set_shader_parameter(&"kick_height_m", 0.12)
	mat.set_shader_parameter(&"kick_color", Color(0.26, 0.11, 0.05))
	_Panels.add(hinge, "DonorBeam", steel.commit(), mat, Vector3.ZERO, Vector3.ZERO, out)
	_street(out.back())
	var beads := SurfaceTool.new()
	beads.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Diamond beads sunk into the joins (no bead face parallel to a beam face): web to each
	# flange, the top flange to the leaf skin, and the end plate to the web.
	var web_front := WEB_Z + WEB_T * 0.5
	for y: float in [y0 + FLANGE_T, y1 - FLANGE_T]:
		_corner(beads, Vector3(RUN_X0 + 0.02, y, web_front), Vector3(x1 - 0.02, y, web_front))
	_corner(beads, Vector3(RUN_X0 + 0.02, y1, _LeafBuild.STREET_HALF),
			Vector3(x1 - 0.02, y1, _LeafBuild.STREET_HALF))
	_corner(beads, Vector3(RUN_X0, y0 + FLANGE_T + 0.02, web_front),
			Vector3(RUN_X0, y1 - FLANGE_T - 0.02, web_front))
	_Panels.add(hinge, "DonorBeamWeld", beads.commit(), _Welds.weld_steel(), Vector3.ZERO,
			Vector3.ZERO, out)
	_street(out.back())
	_bolts(hinge, y0, y1, x1, out)
	return out


## Hex bolt heads: a row on the web's street face (none on the end plate, they would poke past
## the hinge line).
static func _bolts(hinge: Node3D, y0: float, y1: float, x1: float, out: Array[Node3D]) -> void:
	var head := CylinderMesh.new()
	head.top_radius = BOLT_R
	head.bottom_radius = BOLT_R
	head.height = BOLT_H
	head.radial_segments = 6
	head.rings = 1
	var rust := _Panels.flat(Color(0.27, 0.15, 0.09), 0.85, 0.3)
	var ym := (y0 + y1) * 0.5
	var pitch := 0.42
	for k in int((x1 - RUN_X0 - 0.2) / pitch) + 1:
		var x := RUN_X0 + 0.12 + k * pitch
		_Panels.add(hinge, "DonorBeamBolt", head, rust, Vector3(x, ym,
				WEB_Z + WEB_T * 0.5 + BOLT_H * 0.5 - 0.002), Vector3(PI * 0.5, 0.0, 0.0), out)
		_street(out.back())



## A square-section bead a -> b (axis-aligned) turned 45 degrees about its run so it shows only
## diagonal faces: sunk into the join, nothing parallel to a beam face.
static func _corner(st: SurfaceTool, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var box := BoxMesh.new()
	if absf(d.x) > absf(d.y):
		box.size = Vector3(d.length(), 0.02, 0.02)
		st.append_from(box, 0, Transform3D(Basis(Vector3.RIGHT, PI * 0.25), (a + b) * 0.5))
	else:
		box.size = Vector3(0.02, d.length(), 0.02)
		st.append_from(box, 0, Transform3D(Basis(Vector3.UP, PI * 0.25), (a + b) * 0.5))


static func _street(node: Node3D) -> void:
	node.add_to_group(VanLighting.GROUP_EXTERIOR_LAYER)
	VanLighting.retarget_layers(node as VisualInstance3D, VanLighting.LAYER_STREET_AND_INTERIOR)
