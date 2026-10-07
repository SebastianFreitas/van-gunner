class_name VanKitGaps
extends RefCounted
## The skin pass's stripped gaps per wall, kept for the patch and brace passes.

## surface -> Array of {z: Vector2, y: Vector2, poly: PackedVector2Array}, all in cm.
static var _by_surface := {}


static func reset() -> void:
	_by_surface.clear()


static func record(surface: StringName, gaps: Array[PackedVector2Array]) -> void:
	var list: Array[Dictionary] = []
	for poly in gaps:
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for p in poly:
			lo = lo.min(p)
			hi = hi.max(p)
		list.append({&"z": Vector2(lo.x, hi.x), &"y": Vector2(lo.y, hi.y), &"poly": poly})
	_by_surface[surface] = list


## The gaps recorded on a surface (empty for none).
static func of(surface: StringName) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	list.assign(_by_surface.get(surface, []))
	return list
