extends RefCounted
## Home-made hardware of the donor rear leaf (spec 4): two box-section hinge arms on thick shim
## plates (the donor's hinge spacing never matched the pillar), a slotted door-check arm and a
## scrap latch with a bent flat-bar handle and a padlocked hasp. All on the cabin face, layer 2,
## all rusty; the only fresh steel is the weld beads. Heights come from the leaf rect.

const _LeafBuild := preload("res://scripts/van/rear_door_leaf_build.gd")
const _Panels := preload("res://scripts/van/look/rear_door_donor_panels.gd")
const _Welds := preload("res://scripts/van/look/rear_door_donor_welds.gd")

const FACE := _LeafBuild.CABIN_Z
## Everything stays this far inboard of the hinge edge, inside where the stock straps reach.
const X0 := 0.03
const SHIM := Vector3(0.37, 0.22, 0.025)
const ARM := 0.08
const BOLT_R := 0.02
const BOLT_H := 0.02
## Hinge arm centres: below the rounded corner, and above the bottom edge strip.
const ARM_TOP_DROP := 0.3
const ARM_BOTTOM_RISE := 0.4
## Latch height as a fraction of the leaf's height.
const LATCH_AT := 0.36


static func build(hinge: Node3D, rect: Rect2, rng: RandomNumberGenerator,
		out: Array[Node3D]) -> void:
	var rust := _Welds.rust_steel()
	var dark := _Panels.flat(Color(0.12, 0.08, 0.06), 0.9, 0.25)
	var weld := _Welds.weld_steel()
	var top := rect.end.y - RearDoorProfile.DONOR_HINGE_ROUND - ARM_TOP_DROP
	var bottom := rect.position.y + ARM_BOTTOM_RISE
	for y: float in [top, bottom]:
		_hinge_arm(hinge, y, rust, dark, weld, rng, out)
	_check_arm(hinge, (top + bottom) * 0.5, rust, dark, out)
	_latch(hinge, Vector2(rect.end.x - 0.2, rect.position.y + rect.size.y * LATCH_AT),
			rust, dark, out)


## Arms, shims and their bolts sit on the outer edge: layers 1+2 like the stock hinge straps.
static func _street(node: Node3D) -> void:
	node.add_to_group(VanLighting.GROUP_EXTERIOR_LAYER)
	VanLighting.retarget_layers(node as VisualInstance3D, VanLighting.LAYER_STREET_AND_INTERIOR)


static func _hex_bolt(parent: Node3D, x: float, y: float, face_z: float, mat: Material,
		out: Array[Node3D]) -> void:
	var bolt := CylinderMesh.new()
	bolt.top_radius = BOLT_R
	bolt.bottom_radius = BOLT_R
	bolt.height = BOLT_H
	bolt.radial_segments = 6
	bolt.rings = 1
	_Panels.add(parent, "DonorBolt", bolt, mat, Vector3(x, y, face_z - BOLT_H * 0.5 + 0.002),
			Vector3(PI * 0.5, 0.0, 0.0), out)


static func _hinge_arm(parent: Node3D, y: float, rust: Material, dark: Material, weld: Material,
		rng: RandomNumberGenerator, out: Array[Node3D]) -> void:
	var shim_front := FACE - SHIM.z + 0.005
	_Panels.add(parent, "HingeShim", _Panels.box(SHIM + Vector3(0.0, 0.0, 0.01)), dark,
			Vector3(X0 + SHIM.x * 0.5, y, FACE + 0.005 - SHIM.z * 0.5 + 0.005), Vector3.ZERO, out)
	_street(out.back())
	var arm_z := shim_front - ARM * 0.5
	var arm_len := SHIM.x * rng.randf_range(0.94, 1.0)
	_Panels.add(parent, "HingeArm", _Panels.box(Vector3(arm_len, ARM, ARM)), rust,
			Vector3(X0 + arm_len * 0.5, y, arm_z), Vector3.ZERO, out)
	_street(out.back())
	var knuckle := CylinderMesh.new()
	knuckle.top_radius = ARM * 0.6
	knuckle.bottom_radius = ARM * 0.6
	knuckle.height = SHIM.y
	knuckle.radial_segments = 8
	knuckle.rings = 1
	_Panels.add(parent, "HingeKnuckle", knuckle, rust,
			Vector3(X0 + ARM * 0.6, y, arm_z), Vector3.ZERO, out)
	_street(out.back())
	# Four bolts through the shim, two each side of the arm, off its centre line.
	for sx: float in [0.3, 0.9]:
		for sy: float in [-1.0, 1.0]:
			_hex_bolt(parent, X0 + SHIM.x * sx, y + sy * (SHIM.y * 0.5 - 0.035), shim_front,
					dark, out)
			_street(out.back())
	# Beads where the arm's end meets the pillar side: two vertical runs on its front face.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x: float in [X0 + 0.005, X0 + ARM * 1.2 + 0.005]:
		_Welds.add_bead(st, Vector2(x, y - ARM * 0.5), Vector2(x, y + ARM * 0.5),
				arm_z - ARM * 0.5, Vector2.ZERO, rng)
	_Panels.add(parent, "PillarWeld", st.commit(), weld, Vector3.ZERO, Vector3.ZERO, out)


## Flat bar from a pivot bolt on a standoff, with a slot a pin rides in.
static func _check_arm(parent: Node3D, y: float, rust: Material, dark: Material,
		out: Array[Node3D]) -> void:
	var bar_z := FACE - 0.03
	var bar := Vector3(0.5, 0.05, 0.008)
	# The slot is a real gap between two rails, 14 mm wide, spanning x 0.2..0.4 of the bar.
	var x_bar := X0 + 0.04
	for piece: Array in [[0.0, 0.2, 0.0, 0.05], [0.4, 0.5, 0.0, 0.05],
			[0.2, 0.4, 0.016, 0.018], [0.2, 0.4, -0.016, 0.018]]:
		var w: float = piece[1] - piece[0]
		_Panels.add(parent, "CheckBar", _Panels.box(Vector3(w, piece[3], bar.z)), rust,
				Vector3(x_bar + piece[0] + w * 0.5, y + piece[2], bar_z), Vector3.ZERO, out)
	var post := CylinderMesh.new()
	post.top_radius = 0.025
	post.bottom_radius = 0.025
	post.height = 0.03
	post.radial_segments = 8
	post.rings = 1
	_Panels.add(parent, "CheckPivot", post, rust, Vector3(X0 + 0.08, y, FACE - 0.015),
			Vector3(PI * 0.5, 0.0, 0.0), out)
	_Panels.add(parent, "CheckBracket", _Panels.box(Vector3(0.09, 0.09, 0.02)), dark,
			Vector3(X0 + 0.34, y, FACE - 0.002), Vector3.ZERO, out)
	var pin := CylinderMesh.new()
	pin.top_radius = 0.011
	pin.bottom_radius = 0.011
	pin.height = 0.04
	pin.radial_segments = 6
	pin.rings = 1
	_Panels.add(parent, "CheckPin", pin, rust, Vector3(X0 + 0.34, y, FACE - 0.025),
			Vector3(PI * 0.5, 0.0, 0.0), out)
	_hex_bolt(parent, X0 + 0.08, y, bar_z - bar.z * 0.5, dark, out)
	_hex_bolt(parent, X0 + 0.34, y, FACE - 0.03, dark, out)


## Cut-down striker plate, a bent flat-bar handle bolted through it, and a padlocked hasp.
static func _latch(parent: Node3D, at: Vector2, rust: Material, dark: Material,
		out: Array[Node3D]) -> void:
	_Panels.add(parent, "StrikerPlate", _Panels.box(Vector3(0.1, 0.22, 0.02)), rust,
			Vector3(at.x, at.y, FACE - 0.002), Vector3.ZERO, out)
	_Panels.add(parent, "StrikerNotch", _Panels.box(Vector3(0.05, 0.05, 0.002)), dark,
			Vector3(at.x + 0.015, at.y + 0.05, FACE - 0.0125), Vector3.ZERO, out)
	var stand := FACE - 0.044
	# Handle: a vertical bar on two stubs bent back to the plate, the lower one cranked.
	_Panels.add(parent, "HandleBar", _Panels.box(Vector3(0.03, 0.2, 0.008)), rust,
			Vector3(at.x, at.y - 0.02, stand), Vector3.ZERO, out)
	for sy: float in [-1.0, 1.0]:
		_Panels.add(parent, "HandleStub", _Panels.box(Vector3(0.03, 0.008, 0.04)), rust,
				Vector3(at.x, at.y - 0.02 + sy * 0.096, FACE - 0.025), Vector3.ZERO, out)
		_hex_bolt(parent, at.x, at.y + sy * 0.09, FACE - 0.012, dark, out)
	_Panels.add(parent, "HandleCrank", _Panels.box(Vector3(0.03, 0.09, 0.008)), rust,
			Vector3(at.x, at.y - 0.12, FACE - 0.038), Vector3(deg_to_rad(8.0), 0.0, 0.0), out)
	# Hasp below it: plate, staple and a padlock hanging on the staple.
	var hasp_y := at.y - 0.3
	_Panels.add(parent, "HaspPlate", _Panels.box(Vector3(0.07, 0.12, 0.02)), rust,
			Vector3(at.x, hasp_y, FACE - 0.002), Vector3.ZERO, out)
	var staple := TorusMesh.new()
	staple.inner_radius = 0.008
	staple.outer_radius = 0.02
	staple.rings = 6
	staple.ring_segments = 4
	_Panels.add(parent, "HaspStaple", staple, rust, Vector3(at.x, hasp_y, FACE - 0.02),
			Vector3.ZERO, out)
	_Panels.add(parent, "Padlock", _Panels.box(Vector3(0.05, 0.06, 0.03)), dark,
			Vector3(at.x, hasp_y - 0.06, FACE - 0.025), Vector3.ZERO, out)
