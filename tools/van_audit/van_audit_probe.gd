extends RefCounted
## Brute-force ray probe for the van audit: lists every triangle a given rig-local ray crosses.

const REACH := 20.0
const OFFSETS := {
	"u+1": [0, 0.01], "u-1": [0, -0.01], "u+2": [0, 0.02], "u-2": [0, -0.02],
	"v+1": [1, 0.01], "v-1": [1, -0.01], "v+2": [1, 0.02], "v-2": [1, -0.02],
}


static func run(tris: RefCounted, rays: Array) -> void:
	for i in range(rays.size()):
		var ray: Dictionary = rays[i]
		var from: Vector3 = ray["from"]
		var dir: Vector3 = (ray["dir"] as Vector3).normalized()
		print("AUDIT PROBE ray=%d from=%s dir=%s" % [i, from, dir])
		var hits := _hits(tris, from, dir)
		for h in hits:
			var tri: int = h["tri"]
			var at: Vector3 = h["at"]
			var n: Vector3 = tris.n[tri]
			print("AUDIT PROBE ray=%d t=%.3f node=%s at=(%.3f, %.3f, %.3f) "
				% [i, h["t"], tris.path_of(tri), at.x, at.y, at.z]
				+ "n=(%.2f, %.2f, %.2f) side=%s"
				% [n.x, n.y, n.z, "F" if n.dot(dir) < 0.0 else "B"])
		var u1 := dir.cross(Vector3.UP)
		if u1.length() < 0.001:
			u1 = dir.cross(Vector3.RIGHT)
		u1 = u1.normalized()
		var axes: Array[Vector3] = [u1, dir.cross(u1).normalized()]
		for off_name in OFFSETS:
			var spec: Array = OFFSETS[off_name]
			var origin: Vector3 = from + axes[spec[0]] * float(spec[1])
			var oh := _hits(tris, origin, dir)
			var parts := PackedStringArray()
			for k in range(mini(4, oh.size())):
				parts.append("%s@%.3f" % [tris.path_of(oh[k]["tri"]), oh[k]["t"]])
			print("AUDIT PROBE ray=%d off=%s hits=%d%s" % [
				i, off_name, oh.size(),
				" first=" + " > ".join(parts) if not parts.is_empty() else "",
			])


static func _hits(tris: RefCounted, from: Vector3, dir: Vector3) -> Array:
	var to := from + dir * REACH
	var lo := from.min(to)
	var hi := from.max(to)
	var out: Array = []
	for t in range(tris.count()):
		var tl: Vector3 = tris.tri_lo[t]
		var th: Vector3 = tris.tri_hi[t]
		if tl.x > hi.x or tl.y > hi.y or tl.z > hi.z:
			continue
		if th.x < lo.x or th.y < lo.y or th.z < lo.z:
			continue
		var hit: Variant = Geometry3D.segment_intersects_triangle(
			from, to, tris.a[t], tris.b[t], tris.c[t])
		if hit is Vector3:
			out.append({"tri": t, "at": hit, "t": from.distance_to(hit as Vector3)})
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return x["t"] < y["t"])
	return out
