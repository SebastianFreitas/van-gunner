extends RefCounted
## Pressed relief on a rear door leaf's street face: a raised doubler ring around the window and two
## horizontal swage beads, swept with smooth normals. Hinge-local XY, same space as rear_door_skin.gd.

const _Skin := preload("res://scripts/van/rear_door_skin.gd")
const _Press := preload("res://scripts/van/rear_door_press.gd")

## Doubler: starts under the dark window lip's edge, stays flat to FLAT, then rolls down by WIDTH.
const DOUBLER_START := 0.05
const DOUBLER_FLAT := 0.11
const DOUBLER_WIDTH := 0.14
const DOUBLER_H := 0.025
## Swage beads: 4 cm wide at the foot, 1.5 cm proud, 1.5 cm sloped flanks round a 1 cm crest.
const BEAD_HALF_W := 0.02
const BEAD_SLOPE := 0.015
const BEAD_H := 0.015
## Bead heights above the window's bottom edge and above the leaf's bottom, and how far they stop
## short of the leaf's hinge and seam edges.
const BEAD_BELOW_WINDOW := 0.26
const BEAD_ABOVE_FLOOR := 0.74
const BEAD_END_INSET := 0.2
const SLOPE_STEPS := 5
## Profile points at least this share of the full height take the crest tag, the rest the valley tag.
const CREST_FRAC := 0.85


## Adds the doubler ring around `win` and the swage beads across `rect` into `st`, on the street
## face at `z_street`.
static func build(st: SurfaceTool, rect: Rect2, win: PackedVector2Array, z_street: float,
		profile: RearDoorProfile) -> void:
	var lo := Vector2(INF, INF)
	for p in win:
		lo = lo.min(p)
	var half_w := BEAD_HALF_W
	var bead_ys: Array[float] = [lo.y - BEAD_BELOW_WINDOW, rect.position.y + BEAD_ABOVE_FLOOR]
	if profile.wide_street_bead():
		half_w = RearDoorProfile.WIDE_BEAD_HALF_W
		bead_ys = [rect.position.y + rect.size.y * RearDoorProfile.WIDE_BEAD_AT]
	if not profile.wide_street_bead():
		var doubler: Array[Vector2] = [Vector2(DOUBLER_START, DOUBLER_H)]
		doubler.append_array(_slope(DOUBLER_FLAT, DOUBLER_WIDTH, DOUBLER_H))
		_Skin.tag(st, _Skin.TAG_STREET)
		# The ring's inner edge is a wall that closes against the dark lip.
		_Skin._walls(st, _Skin._ring(win, DOUBLER_START), z_street, z_street + DOUBLER_H, true)
		_sweep(st, win, doubler, z_street)
	var x0 := rect.position.x + BEAD_END_INSET
	var x1 := rect.end.x - BEAD_END_INSET
	for y in bead_ys:
		var bead := _Press.rounded([Vector2(x0, y - half_w), Vector2(x0, y + half_w),
				Vector2(x1, y + half_w), Vector2(x1, y - half_w)], half_w * 0.98)
		var prof: Array[Vector2] = _slope(-BEAD_SLOPE, 0.0, BEAD_H)
		_sweep(st, bead, prof, z_street)
		var crest := _Skin._ring(bead, -BEAD_SLOPE)
		_Skin.tag(st, _Skin.TAG_CREST)
		_Skin._poly(st, crest, z_street + BEAD_H, Vector3.BACK)


## Smoothstep slope from offset `a` to `b`, height falling from `h` to 0, flat at both ends.
static func _slope(a: float, b: float, h: float) -> Array[Vector2]:
	var pts: Array[Vector2] = []
	for k in SLOPE_STEPS + 1:
		var t := float(k) / float(SLOPE_STEPS)
		var s := t * t * (3.0 - 2.0 * t)
		pts.append(Vector2(lerpf(a, b, t), h * (1.0 - s)))
	return pts


## Sweeps `prof` (offset from `outline`, height over `z0`) along the outline, travelling toward
## growing offset so the normal (-dh, d_offset) points up and away.
static func _sweep(st: SurfaceTool, outline: PackedVector2Array, prof: Array[Vector2],
		z0: float) -> void:
	var segs: Array[Vector2] = []
	for j in prof.size() - 1:
		var t := (prof[j + 1] - prof[j]).normalized()
		segs.append(Vector2(-t.y, t.x))
	var norms: Array[Vector2] = []
	for j in prof.size():
		if j == 0:
			norms.append(segs[0])
		elif j == prof.size() - 1:
			norms.append(segs[j - 1])
		else:
			norms.append((segs[j - 1] + segs[j]).normalized())
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
				pos.append(Vector3(r.x, r.y, z0 + prof[c.y].y))
				nrm.append(Vector3(dir.x * norms[c.y].x, dir.y * norms[c.y].x, norms[c.y].y))
				tags.append(_Skin.TAG_CREST if prof[c.y].y >= prof[0].y * CREST_FRAC
						else _Skin.TAG_VALLEY)
			_Press._tri(st, [0, 1, 2], pos, nrm, tags)
			_Press._tri(st, [0, 2, 3], pos, nrm, tags)
