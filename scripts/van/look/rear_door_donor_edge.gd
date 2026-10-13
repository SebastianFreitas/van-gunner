extends RefCounted
## The donor leaf's inner-edge steel beam (the bottom beam's copy, upright and bent along the latch
## cut) and the straps holding the yellow sheet to it.
## Hinge-local metres, cabin face only; z negative is toward the cabin.

const _LeafBuild := preload("res://scripts/van/rear_door_leaf_build.gd")
const _Panels := preload("res://scripts/van/look/rear_door_donor_panels.gd")
const _Welds := preload("res://scripts/van/look/rear_door_donor_welds.gd")
const _Beam := preload("res://scripts/van/look/rear_door_donor_beam.gd")

## Each strap is three bars 1.2 cm thick and 5 cm tall: a face leg across the beam's cabin face
## (z -0.284..-0.272, 2 mm proud of the beam's cabin face at BACK_Z -0.27), a side leg wrapping the
## beam's seam-side edge (x 2.473) with a 4 mm gap for the strap's few degrees of turn, and a foot
## on the yellow crest. Nothing enters the beam. Boxes as [x0, x1, z0, z1].
const STRAP_H := 0.05
const STRAP_BARS: Array[Vector4] = [
	Vector4(2.469, 2.633, -0.284, -0.272),
	Vector4(2.457, 2.469, -0.284, -0.17),
	Vector4(2.356, 2.457, -0.182, -0.17),
]
const STRAP_Y: Array[float] = [0.09, 0.495, 0.90, 1.305, 1.71]
## Straps turn about the face leg's beam-side end.
const STRAP_PIVOT_X := 2.633
## Two hex screws per foot, standing on its cabin face (z -0.182), and two on each face leg.
const SCREW_X: Array[float] = [2.376, 2.436]
const SCREW_R := 0.015
const SCREW_H := 0.012
const SCREW_Z := -0.182 - SCREW_H * 0.5 + 0.002
## Face-leg screws: x on the leg, standing on its cabin face (z -0.284).
const FACE_SCREW_X: Array[float] = [2.50, 2.60]
const FACE_SCREW_Z := -0.284 - SCREW_H * 0.5 + 0.002


## Builds the beam and straps under `hinge` and appends every node to `out`.
static func build(hinge: Node3D, rng: RandomNumberGenerator, out: Array[Node3D]) -> void:
	var rect := Rect2(0.0, _LeafBuild.Y_MIN - hinge.position.y, VanInteriorSize.REAR_DOOR_HALF
			- _LeafBuild.CENTER_GAP, VanInteriorSize.REAR_DOOR_TOP - _LeafBuild.Y_MIN)
	out.append_array(_Beam.build_edge(hinge, rect))
	# Each strap sits midway between two upright bolts, in consecutive gaps from the one nearest
	# the first STRAP_Y, so no bolt is ever covered.
	var bolts := _Beam.upright_bolt_ys(rect)
	var first := 0
	for k in bolts.size() - 1:
		if absf((bolts[k] + bolts[k + 1]) * 0.5 - STRAP_Y[0]) < absf(
				(bolts[first] + bolts[first + 1]) * 0.5 - STRAP_Y[0]):
			first = k
	first = mini(first, bolts.size() - 1 - STRAP_Y.size())
	# Straps alternate rust and weld steel; each turns a few degrees about its beam-side end.
	var rust := SurfaceTool.new()
	rust.begin(Mesh.PRIMITIVE_TRIANGLES)
	var weld := SurfaceTool.new()
	weld.begin(Mesh.PRIMITIVE_TRIANGLES)
	var screws := SurfaceTool.new()
	screws.begin(Mesh.PRIMITIVE_TRIANGLES)
	var head := CylinderMesh.new()
	head.top_radius = SCREW_R
	head.bottom_radius = SCREW_R
	head.height = SCREW_H
	head.radial_segments = 6
	head.rings = 1
	var bead := BoxMesh.new()
	bead.size = Vector3(0.02, STRAP_H, 0.02)
	var sign_k := 1.0
	for i in STRAP_Y.size():
		var pivot := Vector3(STRAP_PIVOT_X, (bolts[first + i] + bolts[first + i + 1]) * 0.5, 0.0)
		var turn := Transform3D(Basis(Vector3.BACK, deg_to_rad(sign_k * rng.randf_range(1.0, 4.0))),
				pivot)
		sign_k = -sign_k
		var steel := rust if i % 2 == 0 else weld
		for bar: Vector4 in STRAP_BARS:
			var box := BoxMesh.new()
			box.size = Vector3(bar.y - bar.x, STRAP_H, bar.w - bar.z)
			steel.append_from(box, 0, turn * Transform3D(Basis.IDENTITY,
					Vector3((bar.x + bar.y) * 0.5 - pivot.x, 0.0, (bar.z + bar.w) * 0.5)))
		weld.append_from(bead, 0, turn * Transform3D(Basis(Vector3.UP, PI * 0.25),
				Vector3(0.0, 0.0, -0.29)))
		for sx: float in SCREW_X:
			screws.append_from(head, 0, turn * Transform3D(Basis(Vector3.RIGHT, PI * 0.5),
					Vector3(sx - pivot.x, 0.0, SCREW_Z)))
		for sx: float in FACE_SCREW_X:
			screws.append_from(head, 0, turn * Transform3D(Basis(Vector3.RIGHT, PI * 0.5),
					Vector3(sx - pivot.x, 0.0, FACE_SCREW_Z)))
	_Panels.add(hinge, "DonorEdgeStrap", rust.commit(), _Welds.rust_steel(), Vector3.ZERO,
			Vector3.ZERO, out)
	_Panels.add(hinge, "DonorEdgeStrapWeld", weld.commit(), _Welds.weld_steel(), Vector3.ZERO,
			Vector3.ZERO, out)
	_Panels.add(hinge, "DonorEdgeScrew", screws.commit(),
			_Panels.flat(Color(0.12, 0.08, 0.06), 0.8, 0.3), Vector3.ZERO, Vector3.ZERO, out)
