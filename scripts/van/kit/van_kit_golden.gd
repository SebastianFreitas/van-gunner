class_name VanKitGolden
extends RefCounted
## Text dump of every kit piece placed per seed, pinned by tools/smoke/van_kit_golden.txt.


static func lines(seeds: Array[int]) -> PackedStringArray:
	var out := PackedStringArray()
	for g in range(1, VanKit.GEN + 1):
		for s in seeds:
			out.append("# gen %d seed %d" % [g, s])
			var pieces: Array[VanKitPlaced] = []
			for piece in VanKit.place(s):
				if piece.gen == g:
					pieces.append(piece)
			pieces.sort_custom(_before)
			for piece in pieces:
				out.append(_row(piece))
	return out


static func _pass_of(p: VanKitPlaced) -> String:
	var reason := String(p.reason)
	return reason.get_slice(":", 0) if reason != "" else "-"


## Order of the spec: (gen, pass, def, surface, pos z, pos v).
static func _before(a: VanKitPlaced, b: VanKitPlaced) -> bool:
	var ka: Array = [a.gen, _pass_of(a), String(a.def_id), String(a.surface),
		roundi(a.transform.origin.z * 100.0), roundi(a.transform.origin.y * 100.0)]
	var kb: Array = [b.gen, _pass_of(b), String(b.def_id), String(b.surface),
		roundi(b.transform.origin.z * 100.0), roundi(b.transform.origin.y * 100.0)]
	return ka < kb


static func _row(p: VanKitPlaced) -> String:
	var reason := String(p.reason)
	var pass_name := _pass_of(p)
	var tilt := snappedf(VanKitRules.tilt_deg(p), 0.1)
	var o := p.transform.origin * 100.0
	var sz := p.size * 100.0
	return "%d %s %s %s:%s %s %s (%d,%d,%d) (%d,%d,%d) %.1f" % [
		p.gen, pass_name, p.def_id, p.origin_kind, p.origin_id, reason, p.surface,
		roundi(o.x), roundi(o.y), roundi(o.z), roundi(sz.x), roundi(sz.y), roundi(sz.z), tilt,
	]
