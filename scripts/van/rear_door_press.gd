class_name RearDoorPress
extends RefCounted
## Pressed-steel relief of a rear door leaf's cabin face: sweeps a short sloped profile along an
## opening outline so the beams between openings stand proud and their flanks roll down into the
## recess (owner's reference photo). Hinge-local XY, same space as rear_door_skin.gd.

const _Skin := preload("res://scripts/van/rear_door_skin.gd")

## How far the recessed panel sits behind the beam crests.
const DEPTH := 0.08
## Profile points from foot to crest, and how much of the slope is smoothstep (rounded creases)
## rather than straight.
const STEPS := 6
const ROUND := 0.25
## Profile points from this one on are crest (wear); the rest is the recess side (grime).
const CREST_FROM := 3


## Sweeps the flank from the opening outline (recess depth) out to `width` (beam crest, z_cab),
## smooth normals along the profile, crest points tagged wear and foot points tagged grime.
static func sweep(st: SurfaceTool, outline: PackedVector2Array, width: float,
		z_cab: float) -> void:
	var prof := profile(width)
	var norms := _profile_normals(prof)
	var count := outline.size()
	var far := _Skin._ring(outline, 1.0)
	var rings: Array[PackedVector2Array] = []
	for p in prof:
		rings.append(_Skin._ring(outline, p.x))
	for j in prof.size() - 1:
		for i in count:
			var n := (i + 1) % count
			var corners: Array[Vector2i] = [Vector2i(i, j), Vector2i(n, j), Vector2i(n, j + 1),
					Vector2i(i, j + 1)]
			var pos: Array[Vector3] = []
			var nrm: Array[Vector3] = []
			var tags: Array[int] = []
			for c in corners:
				var dir := (far[c.x] - outline[c.x]).normalized()
				var r := rings[c.y][c.x]
				pos.append(Vector3(r.x, r.y, z_cab + prof[c.y].y))
				nrm.append(Vector3(dir.x * norms[c.y].x, dir.y * norms[c.y].x, norms[c.y].y))
				tags.append(_Skin.TAG_CREST if c.y >= CREST_FROM else _Skin.TAG_VALLEY)
			_tri(st, [0, 1, 2], pos, nrm, tags)
			_tri(st, [0, 2, 3], pos, nrm, tags)


## The recessed panel behind an opening, flat at the profile's foot depth.
static func floor_panel(st: SurfaceTool, outline: PackedVector2Array, z_cab: float) -> void:
	_Skin.tag(st, _Skin.TAG_VALLEY)
	_Skin._poly(st, outline, z_cab + DEPTH, Vector3.FORWARD)


## The cross-section as (offset from the opening, depth behind the crest), foot to crest.
static func profile(width: float) -> Array[Vector2]:
	var pts: Array[Vector2] = []
	for k in STEPS:
		var t := float(k) / float(STEPS - 1)
		var s := lerpf(t, t * t * (3.0 - 2.0 * t), ROUND)
		pts.append(Vector2(width * t, DEPTH * (1.0 - s)))
	return pts


## Per profile point, the unit normal (offset, z) toward the cabin, averaged over neighbouring
## segments; the foot is flat so the flank meets the recess smoothly, the crest keeps a crisp edge.
static func _profile_normals(prof: Array[Vector2]) -> Array[Vector2]:
	var segs: Array[Vector2] = []
	for j in prof.size() - 1:
		var t := (prof[j + 1] - prof[j]).normalized()
		segs.append(Vector2(t.y, -t.x))
	var out: Array[Vector2] = []
	for j in prof.size():
		if j == 0:
			out.append(Vector2(0.0, -1.0))
		elif j == prof.size() - 1:
			# Keeping the last flank's own normal leaves a visible crease at the crest.
			out.append(segs[j - 1])
		else:
			out.append((segs[j - 1] + segs[j]).normalized())
	return out


## One triangle of the quad `pos` picked by `idx`, wound clockwise seen from its normals.
static func _tri(st: SurfaceTool, idx: Array, pos: Array[Vector3], nrm: Array[Vector3],
		tags: Array[int]) -> void:
	var order: Array = idx.duplicate()
	var a: Vector3 = pos[idx[0]]
	var b: Vector3 = pos[idx[1]]
	var c: Vector3 = pos[idx[2]]
	if (b - a).cross(c - a).dot(nrm[idx[0]] + nrm[idx[1]] + nrm[idx[2]]) > 0.0:
		order = [idx[0], idx[2], idx[1]]
	for k: int in order:
		st.set_color(Color(float(tags[k]) / 8.0, 0.0, 0.0, 1.0))
		st.set_normal(nrm[k])
		st.add_vertex(pos[k])


## Polygon through `corners`, each corner filleted with a circular arc of `radius`.
static func rounded(corners: Array[Vector2], radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in corners.size():
		var c := corners[i]
		var u := (corners[(i + corners.size() - 1) % corners.size()] - c).normalized()
		var v := (corners[(i + 1) % corners.size()] - c).normalized()
		var half_angle := absf(u.angle_to(v)) * 0.5
		var centre := c + (u + v).normalized() * (radius / sin(half_angle))
		var a1 := (c + u * (radius / tan(half_angle)) - centre).angle()
		var sweep_a := angle_difference(a1, (c + v * (radius / tan(half_angle)) - centre).angle())
		for k in 9:
			var a := a1 + sweep_a * float(k) / 8.0
			pts.append(centre + Vector2(cos(a), sin(a)) * radius)
	return pts
