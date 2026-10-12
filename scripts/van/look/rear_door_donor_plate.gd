class_name RearDoorDonorPlate
extends RefCounted
## The tread-plate offcut that closes the top of the donor rear leaf's hole (spec 3): thick, bare
## steel with the lozenges facing the cabin, flame-cut edges, too big here and too small there.
## Hinge-local metres, x 0 at the hinge.

const _LeafBuild := preload("res://scripts/van/rear_door_leaf_build.gd")
const _Skin := preload("res://scripts/van/rear_door_skin.gd")
const _Welds := preload("res://scripts/van/look/rear_door_donor_welds.gd")
const _Panels := preload("res://scripts/van/look/rear_door_donor_panels.gd")

const THICK := 0.008
## The plate stops this far short of the leaf's cut edge.
const CUT_CLEAR := 0.003
## The ragged flame-cut hinge edge wanders between these x (the leaf swings: never under the first).
const HINGE_MIN := 0.015
const HINGE_MAX := 0.04
## The bottom edge climbs this much from the cut side to the hinge side.
const SLOPE := 0.02
const TOP_GAP := 0.01
const HINGE_PTS := 6
## The flame cut leaves slits along the hinge and cut sides: a rust plate behind the tread plate
## (tucked 1 cm under the leaf's cut edge) covers them, its street face 11 mm behind the plate's back (the audit's 1 cm FLICKER rule).
const BACKING_T := 0.012
const SHADER_PATH := "res://scenes/van/van_tread_plate.gdshader"


## The bottom seam, hinge end then cut end: the roofing sheet below tops out on this same line.
static func seam(r: Rect2, profile: RearDoorProfile) -> PackedVector2Array:
	var split_y := profile.donor_split_y(r)
	var cut := profile.donor_cut(r)
	return PackedVector2Array([Vector2(0.03, split_y + SLOPE),
			Vector2(cut[1].x - CUT_CLEAR, split_y)])


## Builds the plate under `hinge`; returns the node added.
static func build(hinge: Node3D, rect: Rect2, profile: RearDoorProfile,
		rng: RandomNumberGenerator) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var cut := profile.donor_cut(rect)
	var s := seam(rect, profile)
	var top := rect.end.y - TOP_GAP
	var t := (cut[0].y - top) / (cut[0].y - cut[1].y)
	var top_right := Vector2(lerpf(cut[0].x, cut[1].x, t) - CUT_CLEAR, top)
	var poly := PackedVector2Array()
	for k in HINGE_PTS - 1:
		var y := lerpf(top, s[0].y, float(k) / float(HINGE_PTS - 1))
		poly.append(Vector2(rng.randf_range(HINGE_MIN, HINGE_MAX), y))
	poly.append(s[0])
	poly.append(s[1])
	poly.append(top_right)
	var z_front := _LeafBuild.STREET_HALF - _Skin.STREET_SETBACK
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_Skin._poly(st, poly, z_front, Vector3.BACK)
	_Skin._poly(st, poly, z_front - THICK, Vector3.FORWARD)
	_Skin._walls(st, poly, z_front - THICK, z_front, false)
	_Panels.add(hinge, "DonorTreadPlate", st.commit(), _material(poly, rng), Vector3.ZERO,
			Vector3.ZERO, out)
	var node: Node3D = out.back()
	_backing(hinge, PackedVector2Array([Vector2(-0.01, top),
			Vector2(top_right.x + 0.013, top), Vector2(s[1].x + 0.013, s[1].y),
			s[0], Vector2(-0.01, s[0].y)]), out)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	node.add_to_group(VanLighting.GROUP_EXTERIOR_LAYER)
	VanLighting.retarget_layers(node as VisualInstance3D, VanLighting.LAYER_STREET_AND_INTERIOR)
	return out


static func _backing(hinge: Node3D, poly: PackedVector2Array, out: Array[Node3D]) -> void:
	var z_front := _LeafBuild.STREET_HALF - _Skin.STREET_SETBACK - THICK - 0.011
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_Skin._poly(st, poly, z_front, Vector3.BACK)
	_Skin._poly(st, poly, z_front - BACKING_T, Vector3.FORWARD)
	_Skin._walls(st, poly, z_front - BACKING_T, z_front, false)
	_Panels.add(hinge, "DonorTreadBacking", st.commit(), _Welds.rust_steel(), Vector3.ZERO,
			Vector3.ZERO, out)
	var node: Node3D = out.back()
	node.add_to_group(VanLighting.GROUP_EXTERIOR_LAYER)
	VanLighting.retarget_layers(node as VisualInstance3D, VanLighting.LAYER_STREET_AND_INTERIOR)


static func _material(poly: PackedVector2Array, rng: RandomNumberGenerator) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load(SHADER_PATH) as Shader
	mat.set_shader_parameter("seed", rng.randf() * 50.0)
	var pts := PackedVector2Array(poly)
	pts.resize(16)
	for i in range(poly.size(), 16):
		pts[i] = poly[poly.size() - 1]
	mat.set_shader_parameter("outline", pts)
	mat.set_shader_parameter("outline_count", poly.size())
	return mat
