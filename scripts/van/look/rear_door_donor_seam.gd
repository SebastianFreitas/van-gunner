class_name RearDoorDonorSeam
extends RefCounted
## The welded, bolted seam along the donor leaf's cut (spec 6): one lumpy bead filling the gap on
## the street face, and on the cabin face a flat steel bar in two sections bolted across the cut
## (packed out on offcuts over the recessed patches), stitch welds between and a bead round each
## bar end. Hinge-local metres, x 0 at the hinge.

const _LeafBuild := preload("res://scripts/van/rear_door_leaf_build.gd")
const _Skin := preload("res://scripts/van/rear_door_skin.gd")
const _Panels := preload("res://scripts/van/look/rear_door_donor_panels.gd")
const _Welds := preload("res://scripts/van/look/rear_door_donor_welds.gd")

const BAR_HALF_W := 0.025
const BAR_T := 0.006
## The bar's cabin face stands 1 cm clear of the leaf's cabin crest (the audit's FLICKER rule).
const BAR_Z := _LeafBuild.CABIN_Z - 0.015
## Where the packers end: the cabin faces of the tread plate's backing and of the roofing sheet.
const PATCH_Z_TOP := 0.009
const PATCH_Z_BOTTOM := 0.01
## The bar sections' margins from the leaf top, the split, the leaf bottom.
const TOP_MARGIN := 0.06
const SPLIT_MARGIN := 0.03
const BOTTOM_MARGIN := 0.05
## Street bead: centred on the street plane, 3 cm tall so its top clears the plane by 1.5 cm.
const STREET_TOP := 0.055
const STREET_BOTTOM := -0.05
const BEAD_INSET := 0.03
const WASHER_R:= 0.02
const WASHER_H := 0.012
const NUT_R := 0.015
const NUT_H := 0.012
const STUB_R := 0.006
const STUB_H := 0.012
## Stitch welds and bar-end beads: 3.4 cm tall so their tops clear the bar and the crest by 1 cm.
const STITCH_H := 0.034
const STITCH_Z := _LeafBuild.CABIN_Z - 0.005


## Builds the seam under `hinge`; `rect` is the leaf rect the skin was pressed from. Returns every
## node added.
static func build(hinge: Node3D, rect: Rect2, profile: RearDoorProfile) -> Array[Node3D]:
	var out: Array[Node3D] = []
	# A fixed stream, so the seam never reshuffles the dressing's own rolls.
	var rng := RandomNumberGenerator.new()
	rng.seed = 6606
	var split_y := profile.donor_split_y(rect)
	var top: Array[float] = [rect.end.y - TOP_MARGIN, split_y + SPLIT_MARGIN]
	var bottom: Array[float] = [split_y - SPLIT_MARGIN, rect.position.y + BOTTOM_MARGIN]
	_street_bead(hinge, rect, profile, rng, out)
	var steel := _Welds.rust_steel()
	var bar := SurfaceTool.new()
	bar.begin(Mesh.PRIMITIVE_TRIANGLES)
	var packers := SurfaceTool.new()
	packers.begin(Mesh.PRIMITIVE_TRIANGLES)
	for section: Array[float] in [top, bottom]:
		var line := _line(rect, profile, section[0], section[1])
		_ribbon(bar, line, -BAR_HALF_W, BAR_HALF_W, BAR_Z, BAR_Z + BAR_T, true)
		var patch_z := PATCH_Z_TOP if section == top else PATCH_Z_BOTTOM
		_ribbon(packers, line, -BAR_HALF_W, -0.004, BAR_Z + BAR_T, patch_z, false)
	_Panels.add(hinge, "DonorSeamBar", bar.commit(), steel, Vector3.ZERO, Vector3.ZERO, out)
	_Panels.add(hinge, "DonorSeamPacker", packers.commit(), steel, Vector3.ZERO, Vector3.ZERO, out)
	var bolts := SurfaceTool.new()
	bolts.begin(Mesh.PRIMITIVE_TRIANGLES)
	var welds := SurfaceTool.new()
	welds.begin(Mesh.PRIMITIVE_TRIANGLES)
	for section: Array[float] in [top, bottom]:
		# One bolt into the leaf (bar's leaf side), one through the packer into the patch.
		for k: int in 2:
			var y := lerpf(section[0], section[1], 0.25 + 0.5 * float(k))
			var x := profile.cut_x(rect, y) + (0.004 if k == 0 else -0.004)
			_bolt(bolts, Vector3(x, y, BAR_Z))
		_end_bead(welds, rect, profile, section[0], 1.0, rng)
		_end_bead(welds, rect, profile, section[1], -1.0, rng)
	var gaps: Array = [[rect.end.y, top[0]], [top[1], bottom[0]], [bottom[1], rect.position.y]]
	for g: Array in gaps:
		_stitch(welds, rect, profile, g[0], g[1], rng)
	_Panels.add(hinge, "DonorSeamBolt", bolts.commit(), _Welds.rust_steel(), Vector3.ZERO,
			Vector3.ZERO, out)
	_Panels.add(hinge, "DonorSeamStitch", welds.commit(), _Welds.weld_steel(), Vector3.ZERO,
			Vector3.ZERO, out)
	return out


## The cut's centre line from `y_hi` down to `y_lo`, with a point at every corner between.
static func _line(rect: Rect2, profile: RearDoorProfile, y_hi: float, y_lo: float) \
		-> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(Vector2(profile.cut_x(rect, y_hi), y_hi))
	for p in profile.donor_cut(rect):
		if p.y < y_hi - 0.005 and p.y > y_lo + 0.005:
			pts.append(p)
	pts.append(Vector2(profile.cut_x(rect, y_lo), y_lo))
	return pts


## A strip along `line` between lateral offsets `lo` and `hi` (+ is the leaf side), z0 to z1,
## mitred at the corners. The cabin cap (z0) is left off when `cap` is false: a packer hides it.
static func _ribbon(st: SurfaceTool, line: PackedVector2Array, lo: float, hi: float, z0: float,
		z1: float, cap: bool) -> void:
	var n := line.size()
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in n:
		var d_prev := (line[i] - line[maxi(i - 1, 0)]).normalized()
		var d_next := (line[mini(i + 1, n - 1)] - line[i]).normalized()
		if i == 0:
			d_prev = d_next
		if i == n - 1:
			d_next = d_prev
		var np := Vector2(-d_prev.y, d_prev.x)
		var nn := Vector2(-d_next.y, d_next.x)
		var m := (np + nn).normalized()
		var k := 1.0 / maxf(m.dot(np), 0.3)
		left.append(line[i] + m * hi * k)
		right.append(line[i] + m * lo * k)
	for i in n - 1:
		if cap:
			_quad(st, _v(left[i], z0), _v(left[i + 1], z0), _v(right[i + 1], z0),
					_v(right[i], z0), Vector3(0.0, 0.0, -1.0))
			_quad(st, _v(left[i], z1), _v(right[i], z1), _v(right[i + 1], z1),
					_v(left[i + 1], z1), Vector3(0.0, 0.0, 1.0))
		var nl := (left[i + 1] - left[i]).normalized()
		var nr := (right[i + 1] - right[i]).normalized()
		_quad(st, _v(left[i], z0), _v(left[i], z1), _v(left[i + 1], z1), _v(left[i + 1], z0),
				Vector3(-nl.y, nl.x, 0.0))
		_quad(st, _v(right[i], z0), _v(right[i + 1], z0), _v(right[i + 1], z1),
				_v(right[i], z1), Vector3(nr.y, -nr.x, 0.0))
	for e: int in [0, n - 1]:
		var out_sign := -1.0 if e == 0 else 1.0
		var o := Vector3(0.0, out_sign, 0.0)
		_quad(st, _v(left[e], z0), _v(right[e], z0), _v(right[e], z1), _v(left[e], z1), o)


static func _v(p: Vector2, z: float) -> Vector3:
	return Vector3(p.x, p.y, z)


## Two triangles a-b-c, a-c-d facing `out`; RearDoorSkin._tri fixes the winding.
static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		out: Vector3) -> void:
	_Skin._tri(st, a, b, c, out)
	_Skin._tri(st, a, c, d, out)


## A hex bolt head's worth of hardware on the bar's cabin face at `at`: washer, nut, bolt end.
static func _bolt(st: SurfaceTool, at: Vector3) -> void:
	var z := at.z - WASHER_H * 0.5
	_cyl(st, Vector2(at.x, at.y), z, WASHER_R, WASHER_H, 8)
	z -= WASHER_H * 0.5 + NUT_H * 0.5
	_cyl(st, Vector2(at.x, at.y), z, NUT_R, NUT_H, 6)
	z -= NUT_H * 0.5 + STUB_H * 0.5
	_cyl(st, Vector2(at.x, at.y), z, STUB_R, STUB_H, 6)


static func _cyl(st: SurfaceTool, at: Vector2, z: float, r: float, h: float, sides: int) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = r
	mesh.bottom_radius = r
	mesh.height = h
	mesh.radial_segments = sides
	mesh.rings = 1
	st.append_from(mesh, 0, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(at.x, at.y, z)))


## The street-face bead along the whole cut: segments of jittered width and height, plus a few
## blobs where the welder paused.
static func _street_bead(hinge: Node3D, rect: Rect2, profile: RearDoorProfile,
		rng: RandomNumberGenerator, out: Array[Node3D]) -> void:
	var line := profile.donor_cut(rect)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var blobs: Array[float] = []
	for k: int in rng.randi_range(2, 3):
		blobs.append(rng.randf())
	var total := 0.0
	for i in line.size() - 1:
		total += line[i].distance_to(line[i + 1])
	var run := 0.0
	for i in line.size() - 1:
		var a := line[i]
		var b := line[i + 1]
		var length := a.distance_to(b)
		var dir := (b - a) / length
		# Every run stops short of its ends, so corners and the cut's ends never double up.
		var t := BEAD_INSET
		while t < length - BEAD_INSET:
			var seg := minf(rng.randf_range(_Welds.SEG_MIN, _Welds.SEG_MAX),
					length - BEAD_INSET - t)
			if seg < 0.005:
				break
			var mid := a + dir * (t + seg * 0.5)
			var w := _Welds.BEAD_W * rng.randf_range(0.8, 1.4)
			var h := (STREET_TOP - STREET_BOTTOM) * rng.randf_range(0.95, 1.05)
			_ridge(st, Vector3(seg, w, h), Vector3(mid.x, mid.y, STREET_BOTTOM + h * 0.5),
					dir.angle() + _skew(rng.randf_range(-0.15, 0.15)))
			for f: float in blobs:
				if f * total >= run + t and f * total < run + t + seg:
					_ridge(st, Vector3(0.04, 0.05, 0.07), Vector3(mid.x, mid.y, 0.07),
							dir.angle() + 1.0)
					# One blob per segment: two would be the same triangles twice.
					break
			# A 4 mm gap between segments, so no two ridges overlap face to face.
			t += seg + 0.004
		run += length
	_Panels.add(hinge, "DonorSeamBead", st.commit(), _Welds.weld_steel(), Vector3.ZERO,
			Vector3.ZERO, out)
	var node: Node3D = out.back()
	node.add_to_group(VanLighting.GROUP_EXTERIOR_LAYER)
	VanLighting.retarget_layers(node as VisualInstance3D, VanLighting.LAYER_STREET_AND_INTERIOR)


## Pushes a jitter at least 0.15 rad from zero, so no ridge face lines up with the cut's edge face.
static func _skew(j: float) -> float:
	return j + (0.15 if j >= 0.0 else -0.15)


## A diamond-section ridge of `size` (length, width, height) centred at `at`, turned `angle`
## about z: a box rolled 45 degrees about its length and stretched in z, so none of its long faces
## is parallel to the flat backings and packers around it.
static func _ridge(st: SurfaceTool, size: Vector3, at: Vector3, angle: float) -> void:
	var mesh := BoxMesh.new()
	var s := size.y / sqrt(2.0)
	mesh.size = Vector3(size.x, s, s)
	var stretch := Basis.from_scale(Vector3(1.0, 1.0, size.z / size.y))
	var basis := Basis(Vector3.BACK, angle) * stretch * Basis(Vector3.RIGHT, PI * 0.25)
	st.append_from(mesh, 0, Transform3D(basis, at))


## A bead round a bar end at height `y`: a cross piece beyond the end and one up each side.
## `away` is +1 when the bar lies below the end, -1 when above.
static func _end_bead(st: SurfaceTool, rect: Rect2, profile: RearDoorProfile, y: float,
		away: float, rng: RandomNumberGenerator) -> void:
	var x := profile.cut_x(rect, y)
	var w := _Welds.BEAD_W * rng.randf_range(0.8, 1.2)
	var half := BAR_HALF_W + w
	_Welds.add_box(st, Vector3(half * 2.0, w, STITCH_H),
			Vector3(x, y + away * w * 0.5, STITCH_Z), 0.0)
	for s: float in [-1.0, 1.0]:
		_Welds.add_box(st, Vector3(w, 0.03, STITCH_H),
				Vector3(x + s * (BAR_HALF_W + w * 0.5), y - away * 0.015, STITCH_Z), 0.0)


## Stitch welds down the cut from `y_hi` to `y_lo`: 6 to 9 cm runs with 10 to 15 cm gaps.
static func _stitch(st: SurfaceTool, rect: Rect2, profile: RearDoorProfile, y_hi: float,
		y_lo: float, rng: RandomNumberGenerator) -> void:
	var y := y_hi - rng.randf_range(0.03, 0.06)
	while true:
		var run := rng.randf_range(_Welds.SEG_MIN, _Welds.SEG_MAX)
		if y - run < y_lo + 0.02:
			break
		var a := Vector2(profile.cut_x(rect, y), y)
		var b := Vector2(profile.cut_x(rect, y - run), y - run)
		_Welds.add_bead(st, a, b, STITCH_Z, Vector2(0.012, 0.0), rng, STITCH_H)
		y -= run + rng.randf_range(0.10, 0.15)
