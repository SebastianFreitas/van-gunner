class_name VanKitPatchZones
extends RefCounted
## Where a salvage patch's centre may sit: beside a rear axle's arch, low on the wall, by a door
## bay or the rear opening, or over a stripped gap. Surface cm: (z, y) on walls, (x, y) on leaves.

const LOW_Y_M := 0.9
const AXLE_Z_M := 0.4
const ARCH_TOP_M := 1.9
const EDGE_M := 0.5
const _PANEL_HALF_CM := Vector2(119.0, 155.0)
## Wall patches stay between these heights (cm); on leaves, inside the Panel less the margin.
const WALL_Y_CM := Vector2(5.0, 260.0)
const LEAF_MARGIN_CM := 3.0
const KIT_Z_CM := Vector2(VanKitFootprint.KIT_Z_MIN * 100.0, VanKitFootprint.KIT_Z_MAX * 100.0)


## The zones a surface offers, in a fixed order; `axle` and `gap_cover` only when there is one.
static func available(surface: StringName, axles: Array[float]) -> Array[StringName]:
	var out: Array[StringName] = [&"low_wall", &"rear_edge"]
	if VanKitSurface.is_leaf(surface):
		return out
	out.append(&"door_edge")
	if not axles.is_empty():
		out.append(&"axle")
	if not VanKitGaps.of(surface).is_empty():
		out.append(&"gap_cover")
	return out


## True when the centre lies in `zone`.
static func in_zone(surface: StringName, centre: Vector2, zone: StringName,
		axles: Array[float]) -> bool:
	var leaf := VanKitSurface.is_leaf(surface)
	var a := centre.x * 0.01
	var y := centre.y * 0.01
	if leaf:
		y += VanKitSurface.hinge_origin(surface).y
	match zone:
		&"low_wall":
			return y < LOW_Y_M
		&"rear_edge":
			if leaf:
				return absf(centre.x) >= _PANEL_HALF_CM.x - EDGE_M * 100.0 \
						or absf(centre.y) >= _PANEL_HALF_CM.y - EDGE_M * 100.0
			return a >= VanKitFootprint.KIT_Z_MAX - EDGE_M
		&"door_edge":
			var bay := VanKitFootprint.door_bay()
			return not leaf and a >= bay.x - EDGE_M and a <= bay.y + EDGE_M
		&"axle":
			if leaf or y >= ARCH_TOP_M:
				return false
			for z in axles:
				if absf(a - z) <= AXLE_Z_M:
					return true
			return false
		&"gap_cover":
			for gap in VanKitGaps.of(surface):
				if Geometry2D.is_point_in_polygon(centre, gap[&"poly"]):
					return true
			return false
	return false


## The first zone (in `available` order) holding the centre, or &"".
static func zone_of(surface: StringName, centre: Vector2, axles: Array[float]) -> StringName:
	for zone in available(surface, axles):
		if in_zone(surface, centre, zone, axles):
			return zone
	return &""


## A random centre (cm) to try for `zone`; `in_zone` still decides.
static func sample(surface: StringName, zone: StringName, axles: Array[float],
		rng: RandomNumberGenerator) -> Vector2:
	if VanKitSurface.is_leaf(surface):
		return Vector2(rng.randf_range(-110.0, 110.0), rng.randf_range(-150.0, 150.0))
	match zone:
		&"axle":
			var z := axles[rng.randi_range(0, axles.size() - 1)] + rng.randf_range(
					-AXLE_Z_M, AXLE_Z_M)
			return Vector2(z * 100.0, rng.randf_range(10.0, 100.0))
		&"gap_cover":
			var gaps := VanKitGaps.of(surface)
			var gap := gaps[rng.randi_range(0, gaps.size() - 1)]
			var zr: Vector2 = gap[&"z"]
			var yr: Vector2 = gap[&"y"]
			return Vector2(rng.randf_range(zr.x, zr.y), rng.randf_range(yr.x, yr.y))
		&"door_edge":
			var bay := VanKitFootprint.door_bay()
			# The bay itself is keep-out: the centre sits in the strip beside it.
			var beside := rng.randf_range(0.1, EDGE_M)
			var dz := bay.x - beside if rng.randi_range(0, 1) == 0 else bay.y + beside
			return Vector2(dz * 100.0, rng.randf_range(20.0, 200.0))
		&"rear_edge":
			return Vector2(rng.randf_range(VanKitFootprint.KIT_Z_MAX - EDGE_M,
					VanKitFootprint.KIT_Z_MAX) * 100.0, rng.randf_range(20.0, 220.0))
	return Vector2(rng.randf_range(VanKitFootprint.KIT_Z_MIN, VanKitFootprint.KIT_Z_MAX) * 100.0,
			rng.randf_range(5.0, LOW_Y_M * 100.0))


## True when the outline's bounds (cm) stay on the surface.
static func fits(surface: StringName, lo: Vector2, hi: Vector2) -> bool:
	if VanKitSurface.is_leaf(surface):
		var h := _PANEL_HALF_CM - Vector2.ONE * LEAF_MARGIN_CM
		return lo.x >= -h.x and hi.x <= h.x and lo.y >= -h.y and hi.y <= h.y
	return lo.x >= VanKitFootprint.KIT_Z_MIN * 100.0 and hi.x <= VanKitFootprint.KIT_Z_MAX * 100.0 \
			and lo.y >= WALL_Y_CM.x and hi.y <= WALL_Y_CM.y


## True when a wall centre (cm) lies inside the door bay, which the keep-out refuses.
static func in_bay(surface: StringName, centre: Vector2) -> bool:
	var bay := VanKitFootprint.door_bay()
	return not VanKitSurface.is_leaf(surface) and centre.x >= bay.x * 100.0 			and centre.x <= bay.y * 100.0


## The shift (cm) that brings bounds back onto the surface; zero when they already fit.
static func nudge(surface: StringName, lo: Vector2, hi: Vector2) -> Vector2:
	var min_c := Vector2(KIT_Z_CM.x, WALL_Y_CM.x)
	var max_c := Vector2(KIT_Z_CM.y, WALL_Y_CM.y)
	if VanKitSurface.is_leaf(surface):
		max_c = _PANEL_HALF_CM - Vector2.ONE * LEAF_MARGIN_CM
		min_c = -max_c
	var out := Vector2.ZERO
	if lo.x < min_c.x:
		out.x = min_c.x - lo.x
	elif hi.x > max_c.x:
		out.x = max_c.x - hi.x
	if lo.y < min_c.y:
		out.y = min_c.y - lo.y
	elif hi.y > max_c.y:
		out.y = max_c.y - hi.y
	return out
