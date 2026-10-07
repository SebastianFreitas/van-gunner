class_name VanKitRulesPatches
extends RefCounted
## The patch pass's rules: three to six per van, one telling, centre in a zone, 1.2 cm face step.

const _BREAK := "VAN KIT RULE BREAK: "


static func _patches(placed: Array[VanKitPlaced]) -> Array[VanKitPlaced]:
	var out: Array[VanKitPlaced] = []
	for p in placed:
		if String(p.def_id).begins_with("patch/"):
			out.append(p)
	return out


## `patches N telling <def>` (the first telling patch's def, `none` for no telling one).
static func summary(placed: Array[VanKitPlaced]) -> String:
	var list := _patches(placed)
	return "patches %d telling %s" % [list.size(), _telling(list)]


static func _telling(list: Array[VanKitPlaced]) -> String:
	for p in list:
		if VanKitPatchCut.TELLING.has(p.origin_id):
			return String(p.def_id).trim_prefix("patch/")
	return "none"


static func check(placed: Array[VanKitPlaced]) -> PackedStringArray:
	var out := PackedStringArray()
	var list := _patches(placed)
	if list.size() < 3:
		out.append(_BREAK + "patches %d under 3" % list.size())
	if _telling(list) == "none":
		out.append(_BREAK + "patches have no telling one (road sign, car door, fridge door)")
	for i in list.size():
		var p := list[i]
		var b := VanKitSkin._bounds(p.outline)
		if not VanKitPatchZones.in_zone(p.surface, (b[0] + b[1]) * 0.5, p.reason,
				VanKitPatches.axles):
			out.append(_BREAK + "zone %s %s: centre outside its %s zone" % [
				p.def_id, p.surface, p.reason])
		for j in i:
			var q := list[j]
			if q.surface != p.surface or absf(p.size.y - q.size.y) >= VanKitPatches.STEP_M - 0.0005:
				continue
			for part in Geometry2D.intersect_polygons(p.outline, q.outline):
				if absf(VanKitPatchCut._area(part)) > 1.0:
					out.append(_BREAK + "face step %s over %s on %s: %.3f under 0.012" % [
						p.def_id, q.def_id, p.surface, absf(p.size.y - q.size.y)])
					break
	return out
