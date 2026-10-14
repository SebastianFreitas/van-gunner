extends RefCounted
## Salvage piece 1, roof bow: a trapezoid hat section under the roof panel, flat top and crown, its
## +x end cut by the cant rail's quarter-round arc (grown by the sink) and its x 0 end cut flat.

const _Mesh := preload("res://scripts/van/look/van_salvage_piece1_mesh.gd")

const Z0 := 4.9
const Z1 := 5.4
## How far each web leans in from the flange to the crown.
const WEB_IN := 0.12
const ROWS := 4
## The top tucks this far into the roof panel's underside (y 3.73).
const SINK := 0.02
const TOP_Y := 3.73 + SINK
## The crown (bottom) is flush with the cant rail's underside.
const CROWN_Y := 3.47


## Writes the bow into `wall.mesh` and its one convex hull into `wall.hulls`.
func build(wall: RefCounted) -> void:
	var m: _Mesh = wall.mesh
	var c := Vector2(wall.ARC_CX, wall.ARC_Y)
	var r: float = wall.ARC_R + SINK
	var ys: Array[float] = []
	var xe: Array[float] = []
	var zl: Array[float] = []
	var zr: Array[float] = []
	var hull := PackedVector3Array()
	for j in ROWS + 1:
		var f := float(j) / float(ROWS)
		var y := lerpf(TOP_Y, CROWN_Y, f)
		ys.append(y)
		xe.append(c.x + sqrt(maxf(r * r - (y - c.y) * (y - c.y), 0.0)))
		zl.append(Z0 + WEB_IN * f)
		zr.append(Z1 - WEB_IN * f)
		for x in [0.0, xe[j]]:
			hull.append(Vector3(x, y, zl[j]))
			hull.append(Vector3(x, y, zr[j]))
	m.quad(Vector3(0.0, TOP_Y, zl[0]), Vector3(0.0, TOP_Y, zr[0]), Vector3(0.0, CROWN_Y, zr[ROWS]),
			Vector3(0.0, CROWN_Y, zl[ROWS]), Vector3.LEFT)
	m.quad(Vector3(0.0, CROWN_Y, zl[ROWS]), Vector3(xe[ROWS], CROWN_Y, zl[ROWS]),
			Vector3(xe[ROWS], CROWN_Y, zr[ROWS]), Vector3(0.0, CROWN_Y, zr[ROWS]), Vector3.DOWN)
	for j in ROWS:
		var k := j + 1
		m.quad(Vector3(0.0, ys[j], zl[j]), Vector3(xe[j], ys[j], zl[j]),
				Vector3(xe[k], ys[k], zl[k]), Vector3(0.0, ys[k], zl[k]),
				Vector3(0.0, -WEB_IN, -(TOP_Y - CROWN_Y)))
		m.quad(Vector3(0.0, ys[j], zr[j]), Vector3(xe[j], ys[j], zr[j]),
				Vector3(xe[k], ys[k], zr[k]), Vector3(0.0, ys[k], zr[k]),
				Vector3(0.0, -WEB_IN, TOP_Y - CROWN_Y))
		m.quad(Vector3(xe[j], ys[j], zl[j]), Vector3(xe[j], ys[j], zr[j]),
				Vector3(xe[k], ys[k], zr[k]), Vector3(xe[k], ys[k], zl[k]),
				Vector3((xe[j] + xe[k]) * 0.5 - c.x, (ys[j] + ys[k]) * 0.5 - c.y, 0.0))
	wall.hulls.append(hull)
