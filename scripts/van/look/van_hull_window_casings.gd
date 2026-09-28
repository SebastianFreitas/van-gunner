extends RefCounted
## Body-coloured casing ring around each side cargo window opening, modeled on
## VanHullPatches' side door casing ring.

var _hull: VanHull

## Casing ring width grown outward from the window cut outline.
const CASING_WIDTH_M := 0.07
## Casing outer face distance from the wall liner.
const CASING_PROUD_M := 0.13
## Casing inner face distance from the wall liner.
const CASING_BACK_M := 0.04


func _init(hull: VanHull) -> void:
	_hull = hull


## Builds all 4 casing rings (2 windows per side).
func build(walls: VanSideWall) -> void:
	for s: float in [-1.0, 1.0]:
		for i in range(walls.window_centers_z.size()):
			_build_casing(walls, s, walls.window_centers_z[i], i)


func _build_casing(walls: VanSideWall, s: float, z_center: float, index: int) -> void:
	var mid_y := walls.window_center_y
	var x_ref := walls.wall_x_at(mid_y)

	var inner_poly := walls.WINDOW_CUT_POLY
	var outer_poly := _grow_poly(inner_poly, CASING_WIDTH_M)

	var mesh := walls.build_curved_frame_ring_mesh(
		s, outer_poly, inner_poly, x_ref, mid_y, z_center, mid_y,
		CASING_PROUD_M - CASING_BACK_M, s * CASING_BACK_M, 8
	)
	var pos := Vector3(s * x_ref, mid_y, z_center)
	var side_letter := "L" if s < 0.0 else "R"
	_hull._add_mesh("SideWindowCasing%s%d" % [side_letter, index], mesh, pos)


## Grows a poly outward from its own centre by `amount`, along each vertex's direction
## from the centre (same treatment as the door casing ring width).
func _grow_poly(poly: PackedVector2Array, amount: float) -> PackedVector2Array:
	var center := Vector2.ZERO
	for p in poly:
		center += p
	center /= float(poly.size())

	var grown := PackedVector2Array()
	for p in poly:
		var dir := (p - center).normalized()
		grown.append(p + dir * amount)
	return grown
