extends RefCounted
## Front-edge flange on a side door leaf: laps the bay's edge seal so street rays can't slip past.

## Reach forward of the leaf edge (2 cm gap to the seal + 2.5 cm lap; the audit's opening box,
## the closed leaf shrunk 3 cm, must stay clear of the seal) and back onto the leaf.
const FLANGE_LAP := 0.045
const FLANGE_BACK := 0.06
## Plate depths inboard of the outer skin face less its thickness (negative = street side): 2 cm clear of the
## edge seal's outer face at -0.195 (D4).
const FLANGE_D_IN := -0.215
const FLANGE_D_OUT := -0.23
## Web tying the plate to the leaf: sunk into the body and into the plate, so no face is shared.
const WEB_D_IN := -0.115
const WEB_D_OUT := -0.22
## Top flange lap over the jamb lip above the leaf (over 2.5 cm grows the leaf into the audit's
## opening box past the lip).
const TOP_LAP := 0.02
## Top plate depths: in the hull skin's hole, 0.5 cm street side
## of the front flange's plate, so the two never share a face where they cross at the corner.
const TOP_D_IN := -0.235
const TOP_D_OUT := -0.25
## Top web: cabin end inside the outer skin, rows well under the skin's and body's top faces.
const TOP_WEB_D_IN := -0.16
const TOP_WEB_D_OUT := -0.24
const TOP_WEB_Y0 := 0.10
const TOP_WEB_Y1 := 0.06
const TOP_PLATE_DROP := 0.12

var _walls: VanSideWall


func _init(walls: VanSideWall) -> void:
	_walls = walls


func add_front_flange(
	leaf: Node3D,
	wall_sign: float,
	x_ref: float,
	mid_y: float,
	z_ref: float,
	z0: float,
	y_min: float,
	y_max: float,
	trim_mat: Material
) -> void:
	var walls := _walls
	var p := func(d: float, y: float, z: float) -> Vector3:
		return Vector3(wall_sign * (VanHull.skin_outer_x_at(walls, y) - VanHull.SIDE_SKIN_OUTER_M - d
				- x_ref), y - mid_y, z - z_ref)
	var ya := y_min + 0.03
	var yb := y_max - 0.03
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box(st, p, wall_sign, FLANGE_D_OUT, FLANGE_D_IN, ya, yb, z0 - FLANGE_LAP, z0 + FLANGE_BACK)
	# Web front 1.2 cm behind the outer skin's edge face and back 1.5 cm short of the plate's.
	_box(st, p, wall_sign, WEB_D_OUT, WEB_D_IN, ya + 0.005, yb - 0.005, z0 + 0.032,
		z0 + FLANGE_BACK - 0.015)
	st.generate_tangents()
	var flange := MeshInstance3D.new()
	flange.name = "FrontFlange"
	flange.mesh = st.commit()
	flange.material_override = trim_mat
	flange.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	flange.layers = VanLighting.LAYER_STREET_AND_INTERIOR
	flange.add_to_group(VanLighting.GROUP_EXTERIOR_LAYER)
	leaf.add_child(flange)


## Top-edge flange: laps TOP_LAP over the jamb lip above the leaf, so rays can't slip in over
## the leaf's top gap. It runs from just behind the front flange's lap to 2 cm past the rear edge.
func add_top_flange(
	leaf: Node3D,
	wall_sign: float,
	x_ref: float,
	mid_y: float,
	z_ref: float,
	z0: float,
	z1: float,
	y_max: float,
	trim_mat: Material
) -> void:
	var walls := _walls
	var p := func(d: float, y: float, z: float) -> Vector3:
		return Vector3(wall_sign * (VanHull.skin_outer_x_at(walls, y) - VanHull.SIDE_SKIN_OUTER_M - d
				- x_ref), y - mid_y, z - z_ref)
	var ya := y_max - TOP_PLATE_DROP
	var yb := walls.door_y_max - walls.door_jamb_inset + TOP_LAP
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box(st, p, wall_sign, TOP_D_OUT, TOP_D_IN, ya, yb, z0 - 0.03, z1 + 0.02)
	# Web z kept 1 cm behind the front flange's plate.
	_box(st, p, wall_sign, TOP_WEB_D_OUT, TOP_WEB_D_IN, y_max - TOP_WEB_Y0, y_max - TOP_WEB_Y1,
		z0 + FLANGE_BACK + 0.01, z1 - 0.05)
	st.generate_tangents()
	var flange := MeshInstance3D.new()
	flange.name = "TopFlange"
	flange.mesh = st.commit()
	flange.material_override = trim_mat
	flange.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	flange.layers = VanLighting.LAYER_STREET_AND_INTERIOR
	flange.add_to_group(VanLighting.GROUP_EXTERIOR_LAYER)
	leaf.add_child(flange)


## Closed box between depths d0..d1, rows ya..yb, z za..zb, stepped in y to follow the bow.
func _box(st: SurfaceTool, p: Callable, s: float, d0: float, d1: float, ya: float, yb: float,
		za: float, zb: float) -> void:
	var street := Vector3(s, 0.0, 0.0)
	var steps := 8
	for k in steps:
		var y0 := ya + (yb - ya) * float(k) / float(steps)
		var y1 := ya + (yb - ya) * float(k + 1) / float(steps)
		for d: float in [d0, d1]:
			var out := street if d == d0 else -street
			_quad(st, p.call(d, y0, za), p.call(d, y0, zb), p.call(d, y1, zb), p.call(d, y1, za),
				out)
		for z: float in [za, zb]:
			var out_z := Vector3(0.0, 0.0, -1.0 if z == za else 1.0)
			_quad(st, p.call(d0, y0, z), p.call(d1, y0, z), p.call(d1, y1, z), p.call(d0, y1, z),
				out_z)
	for y: float in [ya, yb]:
		var out_y := Vector3.DOWN if y == ya else Vector3.UP
		_quad(st, p.call(d0, y, za), p.call(d1, y, za), p.call(d1, y, zb), p.call(d0, y, zb),
			out_y)


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		out: Vector3) -> void:
	_tri(st, a, b, c, out)
	_tri(st, a, c, d, out)


## Godot front faces are clockwise seen from outside, so flip any triangle that isn't.
func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, out: Vector3) -> void:
	var second := b
	var third := c
	if (c - a).cross(b - a).dot(out) < 0.0:
		second = c
		third = b
	var n := (third - a).cross(second - a).normalized()
	for v: Vector3 in [a, second, third]:
		st.set_normal(n)
		st.set_uv(Vector2(v.z, v.y))
		st.add_vertex(v)
