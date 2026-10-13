class_name ArmVeinField
extends RefCounted
## Vein height and centreline distance at a chart point, from a packed ArmVeinSet.

## Width of the smooth max that blends overlapping veins, in height units (0..1).
const BLEND := 0.3

## Distance past which `sample` reports only "far" (INF or any value above this); no vein is this
## wide. `exact_dist` is the full scan for the few callers that need more.
const FAR := 0.03
## Side of a grid cell, in chart units.
const CELL := 0.01

var _pts := PackedVector4Array()
## Per grid cell, the ascending segment indices that can come within FAR of the cell.
var _cells: Array[PackedInt32Array] = []
var _path_of := PackedInt32Array()
var _origin := Vector2.ZERO
var _cols := 0
var _rows := 0


func _init(packed: PackedVector4Array) -> void:
	_pts = packed
	_build_grid()


## Sample the chart point (x, v): returns (height, distance). Height is 0..1 (1 = a vein
## MAX_R thick), a rounded tube cross-section that is zero outside the vein; distance is to the
## nearest centreline in chart units, exact below FAR and INF or above FAR beyond it.
func sample(chart: Vector2) -> Vector2:
	var cx := int(floorf((chart.x - _origin.x) / CELL))
	var cy := int(floorf((chart.y - _origin.y) / CELL))
	if cx < 0 or cy < 0 or cx >= _cols or cy >= _rows:
		return Vector2(0.0, INF)
	var total := 0.0
	var dist := INF
	var path_best := 0.0
	var cur_path := -1
	var segs := _cells[cy * _cols + cx]
	for i in segs:
		if _path_of[i] != cur_path:
			total = _smax(total, path_best)
			path_best = 0.0
			cur_path = _path_of[i]
		var a := _pts[i]
		var b := _pts[i + 1]
		var ab := Vector2(b.x - a.x, b.y - a.y)
		var t := clampf((chart - Vector2(a.x, a.y)).dot(ab) / maxf(ab.length_squared(), 0.0000001),
				0.0, 1.0)
		var d := (chart - (Vector2(a.x, a.y) + ab * t)).length()
		dist = minf(dist, d)
		var r := lerpf(a.z, b.z, t)
		var q := d / maxf(r, 0.00001)
		if q < 1.0:
			var h := lerpf(a.w, b.w, t) * (r / ArmVeinSet.MAX_R) * sqrt(1.0 - q * q)
			path_best = maxf(path_best, h)
	total = _smax(total, path_best)
	return Vector2(minf(total, 1.0), dist)


## Distance to the nearest centreline by scanning every live segment.
func exact_dist(chart: Vector2) -> float:
	var dist := INF
	for i in range(_pts.size() - 1):
		var a := _pts[i]
		var b := _pts[i + 1]
		if a.z < 0.0 or b.z < 0.0:
			continue
		var ab := Vector2(b.x - a.x, b.y - a.y)
		var t := clampf((chart - Vector2(a.x, a.y)).dot(ab) / maxf(ab.length_squared(), 0.0000001),
				0.0, 1.0)
		dist = minf(dist, (chart - (Vector2(a.x, a.y) + ab * t)).length())
	return dist


## Buckets every live segment into the cells within FAR of it.
func _build_grid() -> void:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var path := 0
	_path_of.resize(maxi(_pts.size() - 1, 0))
	for i in range(_pts.size()):
		var a := _pts[i]
		if a.z < 0.0:
			path += 1
			continue
		lo = lo.min(Vector2(a.x, a.y))
		hi = hi.max(Vector2(a.x, a.y))
		if i < _path_of.size():
			_path_of[i] = path
	if lo.x == INF:
		return
	_origin = lo - Vector2(FAR, FAR)
	_cols = int(ceilf((hi.x - lo.x + 2.0 * FAR) / CELL)) + 1
	_rows = int(ceilf((hi.y - lo.y + 2.0 * FAR) / CELL)) + 1
	_cells.resize(_cols * _rows)
	for i in range(_pts.size() - 1):
		var a := _pts[i]
		var b := _pts[i + 1]
		if a.z < 0.0 or b.z < 0.0:
			continue
		var pa := Vector2(a.x, a.y)
		var ab := Vector2(b.x - a.x, b.y - a.y)
		var x0 := maxi(int(floorf((minf(a.x, b.x) - FAR - _origin.x) / CELL)), 0)
		var x1 := mini(int(floorf((maxf(a.x, b.x) + FAR - _origin.x) / CELL)), _cols - 1)
		var y0 := maxi(int(floorf((minf(a.y, b.y) - FAR - _origin.y) / CELL)), 0)
		var y1 := mini(int(floorf((maxf(a.y, b.y) + FAR - _origin.y) / CELL)), _rows - 1)
		for cy in range(y0, y1 + 1):
			for cx in range(x0, x1 + 1):
				var centre := _origin + Vector2(cx + 0.5, cy + 0.5) * CELL
				var t := clampf((centre - pa).dot(ab) / maxf(ab.length_squared(), 0.0000001),
						0.0, 1.0)
				# The cell's half diagonal is 0.7072 CELL: a segment within FAR of any point of
				# the cell is within FAR + that of its centre.
				if (centre - (pa + ab * t)).length() <= FAR + 0.7072 * CELL:
					_cells[cy * _cols + cx].append(i)


## Polynomial smooth max; a zero input adds nothing, so empty paths never raise the result.
func _smax(a: float, b: float) -> float:
	if a <= 0.0:
		return b
	if b <= 0.0:
		return a
	var gap := maxf(BLEND - absf(a - b), 0.0)
	return maxf(a, b) + gap * gap / (4.0 * BLEND)
