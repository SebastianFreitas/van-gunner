class_name BrokenIronCross
extends Node3D

## Blown-out rebar bars after a window breach. Same local frame as IronCross: XY = glass face,
## +Z = outward. The four ends stay welded on; each carries a stub of torn rebar bent into the cabin.
## Optional side-wall curve: the stubs follow VanSideWall (via IronCrossGeo).

const IronCrossGeo := preload("res://scripts/van/iron_cross_geo.gd")
const IronCrossBuild := preload("res://scripts/van/iron_cross_build.gd")

## Hook: bend over the frame ring's outer edge (side windows, which swing open).
## Skin: step off the lip and weld onto the door skin (rear doors).
@export_enum("Hook", "Skin") var end_style := 0
## Outer edge of what the ends stand on.
@export var frame_half := Vector2(1.202, 0.687)
## The bar stays in its straight plane inside this; just past the pane edge.
@export var clear_half := Vector2(1.125, 0.642)
## Skin ends only: the door skin's z and how far the bar runs along it.
@export var skin_z := 0.05
@export var skin_reach := Vector2(1.12, 0.90)
## Local z of the surface the ends stand on: the side frame ring's front.
@export var mount_z := 0.03
@export var curve_segments := 14
@export var rebuild_on_ready := true

## 0 = fresh RNG each rebuild. Non-zero = stable look for that seed.
@export var break_seed := 0

## Stub length in metres, past the clear edge.
@export_range(0.12, 0.55, 0.01) var stub_length_min := 0.18
@export_range(0.12, 0.55, 0.01) var stub_length_max := 0.42

## Max bend toward the cabin (degrees); the least is 10.
@export_range(5.0, 50.0, 1.0) var bend_out_max_deg := 32.0

var _built := false
var _rng := RandomNumberGenerator.new()
var _curve_walls: VanSideWall = null
var _curve_mid_y := 0.0
var _geo: RefCounted = null


func _ready() -> void:
	if rebuild_on_ready:
		rebuild()


## Bend remaining stubs to match a bowed side wall.
func follow_side_wall_curve(walls: VanSideWall, mid_y: float) -> void:
	_curve_walls = walls
	_curve_mid_y = mid_y
	rebuild()


func rebuild() -> void:
	for child in get_children():
		child.queue_free()
	_built = false
	_build()


func _build() -> void:
	if _built:
		return
	_built = true

	if break_seed != 0:
		_rng.seed = break_seed
	else:
		_rng.randomize()

	_geo = IronCrossGeo.new(_curve_walls, _curve_mid_y, frame_half.x, frame_half.y)
	_geo.segments = curve_segments
	_geo.dent = 0.0
	var radii := IronCross.REBAR_RADII
	var rv := radii[_rng.randi_range(0, 2)]
	var rh := radii[_rng.randi_range(0, 2)]
	var zv := IronCross.BAR_BACK_Z + rv
	var zh := zv + rv + rh + 0.002
	# Each end is [suffix, vertical bar, side along the bar, radius, bar z].
	var ends := [
		["T", true, 1.0, rv, zv], ["B", true, -1.0, rv, zv],
		["R", false, 1.0, rh, zh], ["L", false, -1.0, rh, zh],
	]
	var stubs: Array = []
	for end in ends:
		stubs.append(_add_end(end[0] as String, end[1] as bool, end[2] as float, end[3] as float, end[4] as float))
	_add_wreckage(stubs)


func _map(vert: bool, side: float, a: float, u: float, z: float) -> Vector3:
	return Vector3(u, side * a, z) if vert else Vector3(side * a, u, z)


## One end: the welded hook or skin step, then a torn stub bent into the cabin. Returns
## {"pts", "r", "root", "sfx"} so the wreckage can sit on it.
func _add_end(sfx: String, vert: bool, side: float, r: float, z_bar: float) -> Dictionary:
	var c := clear_half.y if vert else clear_half.x
	var f := frame_half.y if vert else frame_half.x
	var reach := skin_reach.y if vert else skin_reach.x
	var ep := IronCrossBuild.end_path(end_style, c, f, z_bar, r, mount_z, skin_z, reach)
	var src := ep["points"] as PackedVector3Array
	var src_r := ep["radii"] as PackedFloat32Array
	var pts := PackedVector3Array()
	var rads := PackedFloat32Array()
	# From the frame edge inward.
	for k in range(src.size() - 1, -1, -1):
		pts.append(_map(vert, side, src[k].y, 0.0, src[k].z))
		rads.append(src_r[k])
	var root := pts.size() - 1

	var n := _rng.randi_range(4, 6)
	var length := _rng.randf_range(stub_length_min, stub_length_max)
	var theta := deg_to_rad(_rng.randf_range(10.0, bend_out_max_deg))
	var curls := _rng.randf() < 0.18
	var drift := _rng.randf_range(-0.03, 0.03)
	var kink_at := _rng.randi_range(1, n)
	var kink := 0.012 * (1.0 if _rng.randf() < 0.5 else -1.0)
	var seg := length / float(n)
	var a := src[0].y
	var z := src[0].z
	for i in range(1, n + 1):
		var phi := theta * float(i) / float(n)
		var dz := -sin(phi) * seg
		if curls and float(i) > float(n) * 2.0 / 3.0:
			dz = -dz
		a -= cos(phi) * seg
		z += dz
		var u := drift * float(i) / float(n) + (kink if i >= kink_at else 0.0)
		pts.append(_map(vert, side, a, u, z))
		rads.append(r)
	# The last 3 cm taper to a torn tip.
	var tip := pts[pts.size() - 1]
	var seg_len := pts[pts.size() - 2].distance_to(tip)
	if seg_len > 0.03:
		pts.insert(pts.size() - 1, pts[pts.size() - 2].lerp(tip, 1.0 - 0.03 / seg_len))
		rads.insert(rads.size() - 1, r)
	rads[rads.size() - 1] = 0.45 * r
	_geo.add_rod(self, "Stub" + sfx, pts, rads, 6, IronCross.RIB_STEP, IronCross.rebar_material())

	var weld := IronCross.weld_material()
	for k in 3:
		var wa := (ep["touch"] as float) + _rng.randf_range(-0.015, 0.015)
		var at := _map(vert, side, wa, 0.0, ep["weld_z"] as float)
		_geo.add_blob(self, "EndWeld%s%d" % [sfx, k], at, Vector3(2.4 * r, 2.4 * r, 1.6 * r), _rng, weld)
	if _rng.randf() < 0.4:
		for k in 1 + _rng.randi_range(0, 1):
			var jitter := Vector3(
				_rng.randf_range(-0.006, 0.006), _rng.randf_range(-0.006, 0.006),
				_rng.randf_range(-0.006, 0.006)
			)
			_geo.add_blob(
				self, "TornWeld%s%d" % [sfx, k], tip + jitter, Vector3(1.8 * r, 1.8 * r, 1.5 * r),
				_rng, weld
			)
	return {"pts": pts, "r": r, "root": root, "sfx": sfx}


## At most one wire tangle and one slid pipe fragment, on different random stubs.
func _add_wreckage(stubs: Array) -> void:
	var order: Array[int] = [0, 1, 2, 3]
	for k in range(3, 0, -1):
		var j := _rng.randi_range(0, k)
		var tmp := order[k]
		order[k] = order[j]
		order[j] = tmp
	var wire_on := _rng.randf() < 0.6
	var pipe_on := _rng.randf() < 0.4
	if wire_on:
		_add_wire(stubs[order[0]] as Dictionary)
	if pipe_on:
		_add_pipe(stubs[order[1]] as Dictionary)


## A slack wire wound round the outer 0.12 m of a stub, its loose end drooping.
func _add_wire(stub: Dictionary) -> void:
	var pts := stub["pts"] as PackedVector3Array
	var tip := pts[pts.size() - 1]
	var dir := (tip - pts[pts.size() - 2]).normalized()
	var path := IronCrossGeo.helix_path(
		tip - dir * 0.12, tip - dir * 0.01, (stub["r"] as float) + 0.01, 3.0, 12,
		_rng.randf_range(0.0, TAU)
	)
	var end := path[path.size() - 1]
	path.append(end + Vector3(0.0, -0.04, 0.0))
	path.append(end + Vector3(0.0, -0.08, 0.0))
	var rads := PackedFloat32Array()
	rads.resize(path.size())
	rads.fill(IronCross.WIRE_RADIUS)
	_geo.add_rod(self, "Wire" + (stub["sfx"] as String), path, rads, 4, 0.0, IronCross.wire_material())


## A short pipe slid down a stub to its root, with one hose clamp still on it.
func _add_pipe(stub: Dictionary) -> void:
	var pts := stub["pts"] as PackedVector3Array
	var root := stub["root"] as int
	var dir := (pts[root + 1] - pts[root]).normalized()
	var length := _rng.randf_range(0.12, 0.22)
	var p0 := pts[root] + dir * 0.03
	var path := PackedVector3Array([p0, p0 + dir * length])
	var rads := PackedFloat32Array([IronCross.PIPE_RADIUS, IronCross.PIPE_RADIUS])
	var sfx := stub["sfx"] as String
	_geo.add_rod(self, "Pipe" + sfx, path, rads, 8, 0.0, IronCross.pipe_material())
	var band := IronCrossGeo.ring_path(p0 + dir * 0.03, dir, IronCross.PIPE_RADIUS + 0.002, 10)
	var band_r := PackedFloat32Array()
	band_r.resize(band.size())
	band_r.fill(0.003)
	_geo.add_rod(self, "Clamp" + sfx, band, band_r, 4, 0.0, IronCross.iron_material(), true)
