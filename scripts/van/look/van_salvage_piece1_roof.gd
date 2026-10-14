extends RefCounted
## Salvage piece 1, roof pieces: the cant rail (the head panel's outline above RAIL_Y, run on forward
## to z 4.2) and the roof panel over the head's tab, both continuing the rear arch's section.

const _Surround := preload("res://scripts/van/rear_door_surround.gd")
const _Mesh := preload("res://scripts/van/look/van_salvage_piece1_mesh.gd")
const _Head := preload("res://scripts/van/look/van_salvage_piece1_head.gd")
const _Bow := preload("res://scripts/van/look/van_salvage_piece1_bow.gd")
const _Bead := preload("res://scripts/van/look/van_salvage_piece1_bead.gd")

## The rail's lowest y and its forward end z.
const RAIL_Y := 3.47
const RAIL_Z0 := 4.2
## The section: the underside (the arch's room-face top), the step where the ring's top ends, the
## top's lift over the vault.
const UNDER_Y := 3.73
const STEP_Y := 3.91
const TOP_LIFT := 0.02
## The underside pockets: width and pitch in x, first x, z range, depth.
const POCKET_W := 0.255
const POCKET_PITCH := 0.451
const POCKET_X0 := 0.196
const POCKET_Z0 := 5.50
const POCKET_DEPTH := 0.12
const POCKET_COUNT := 4


## Writes both pieces into `wall.mesh` and their hulls into `wall.hulls`; `head` is the head
## panel's final outline, so the rail's back face has the head's own vertices.
func build(wall: RefCounted, head: PackedVector2Array, profile: VanBodyProfile) -> void:
	_rail(wall, _clip(head))
	_panel(wall, profile)
	_Bow.new().build(wall)
	_Bead.new().build(wall)


## `poly` with a vertex added where an edge crosses RAIL_Y, so the head panel and the rail's cut
## share every vertex of the z 4.9 join.
static func split(poly: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		out.append(a)
		if (a.y - RAIL_Y) * (b.y - RAIL_Y) < 0.0:
			out.append(a.lerp(b, (RAIL_Y - a.y) / (b.y - a.y)))
	return out


## `poly` cut to y >= RAIL_Y (Sutherland-Hodgman against the one line).
func _clip(poly: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var a_in := a.y >= RAIL_Y
		if a_in:
			out.append(a)
		if a_in != (b.y >= RAIL_Y):
			out.append(a.lerp(b, (RAIL_Y - a.y) / (b.y - a.y)))
	return out


## `poly` extruded from RAIL_Z0 to the head's front cap at KICK_Z0: bevelled forward end, side
## quads only at the back, so no cap lies between rail and head.
func _rail(wall: RefCounted, poly: PackedVector2Array) -> void:
	var m: _Mesh = wall.mesh
	var z1: float = wall.KICK_Z0
	var bev := _Surround.BEVEL
	var steps := _Surround.BEVEL_STEPS
	var sign_a := 1.0 if m._area(poly) > 0.0 else -1.0
	var rings: Array = []
	for k in range(steps + 1):
		var th := PI * 0.5 * float(k) / float(steps)
		rings.append([m._inset(poly, bev * (1.0 - sin(th))), RAIL_Z0 + bev * (1.0 - cos(th))])
	rings.append([poly, z1])
	var cap: PackedVector2Array = rings[0][0]
	var idx := Geometry2D.triangulate_polygon(cap)
	for i in range(0, idx.size(), 3):
		m.tri(m.pt(wall.XY_Z, cap[idx[i]], RAIL_Z0), m.pt(wall.XY_Z, cap[idx[i + 1]], RAIL_Z0),
				m.pt(wall.XY_Z, cap[idx[i + 2]], RAIL_Z0), Vector3(0, 0, -1))
	for r in range(rings.size() - 1):
		var pa: PackedVector2Array = rings[r][0]
		var pb: PackedVector2Array = rings[r + 1][0]
		for i in pa.size():
			var j := (i + 1) % pa.size()
			var e := poly[j] - poly[i]
			if e.length() < 0.0001:
				continue
			m.quad(m.pt(wall.XY_Z, pa[i], rings[r][1]), m.pt(wall.XY_Z, pa[j], rings[r][1]),
					m.pt(wall.XY_Z, pb[j], rings[r + 1][1]), m.pt(wall.XY_Z, pb[i], rings[r + 1][1]),
					Vector3(e.y, -e.x, 0.0) * sign_a)
	var hull := PackedVector3Array()
	for p in poly:
		hull.append(Vector3(p.x, p.y, RAIL_Z0))
		hull.append(Vector3(p.x, p.y, z1))
	wall.hulls.append(hull)


## The roof panel, x 0..TAB_X: flat underside with its pockets, the vault-following top, the
## stepped rear end. Cell edges in x are shared by every face, so no face has a T-junction.
func _panel(wall: RefCounted, profile: VanBodyProfile) -> void:
	var m: _Mesh = wall.mesh
	var z0: float = wall.KICK_Z0
	var zi: float = wall.rear_in_z
	var zo: float = wall.rear_out_z
	var xs: Array[float] = [0.0]
	for k in POCKET_COUNT:
		xs.append(POCKET_X0 + POCKET_PITCH * float(k))
		xs.append(POCKET_X0 + POCKET_PITCH * float(k) + POCKET_W)
	xs.append(_Head.TAB_X)
	var pz1: float = wall.pocket_z1
	var py := UNDER_Y + POCKET_DEPTH
	var tab_z: float = wall.FRONT_Z + wall.SINK
	var hull := PackedVector3Array()
	for c in xs.size() - 1:
		var xa := xs[c]
		var xb := xs[c + 1]
		var ya := profile.ceiling.vault_y_at(xa) + TOP_LIFT
		var yb := profile.ceiling.vault_y_at(xb) + TOP_LIFT
		var pocket := c % 2 == 1
		m.quad(Vector3(xa, ya, z0), Vector3(xb, yb, z0), Vector3(xb, yb, zo), Vector3(xa, ya, zo),
				Vector3.UP)
		m.quad(Vector3(xa, UNDER_Y, z0), Vector3(xb, UNDER_Y, z0), Vector3(xb, yb, z0),
				Vector3(xa, ya, z0), Vector3.FORWARD)
		m.quad(Vector3(xa, STEP_Y, zo), Vector3(xb, STEP_Y, zo), Vector3(xb, yb, zo),
				Vector3(xa, ya, zo), Vector3.BACK)
		m.quad(Vector3(xa, UNDER_Y, zi), Vector3(xb, UNDER_Y, zi), Vector3(xb, STEP_Y, zi),
				Vector3(xa, STEP_Y, zi), Vector3.BACK)
		m.quad(Vector3(xa, STEP_Y, zi), Vector3(xb, STEP_Y, zi), Vector3(xb, STEP_Y, zo),
				Vector3(xa, STEP_Y, zo), Vector3.DOWN)
		if pocket:
			m.quad(Vector3(xa, UNDER_Y, z0), Vector3(xb, UNDER_Y, z0),
					Vector3(xb, UNDER_Y, POCKET_Z0), Vector3(xa, UNDER_Y, POCKET_Z0), Vector3.DOWN)
			m.quad(Vector3(xa, UNDER_Y, pz1), Vector3(xb, UNDER_Y, pz1),
					Vector3(xb, UNDER_Y, zi), Vector3(xa, UNDER_Y, zi), Vector3.DOWN)
			m.quad(Vector3(xa, py, POCKET_Z0), Vector3(xb, py, POCKET_Z0), Vector3(xb, py, pz1),
					Vector3(xa, py, pz1), Vector3.DOWN)
			m.quad(Vector3(xa, UNDER_Y, POCKET_Z0), Vector3(xb, UNDER_Y, POCKET_Z0),
					Vector3(xb, py, POCKET_Z0), Vector3(xa, py, POCKET_Z0), Vector3.BACK)
			m.quad(Vector3(xa, UNDER_Y, pz1), Vector3(xb, UNDER_Y, pz1), Vector3(xb, py, pz1),
					Vector3(xa, py, pz1), Vector3.FORWARD)
			m.quad(Vector3(xa, UNDER_Y, POCKET_Z0), Vector3(xa, UNDER_Y, pz1),
					Vector3(xa, py, pz1), Vector3(xa, py, POCKET_Z0), Vector3.RIGHT)
			m.quad(Vector3(xb, UNDER_Y, POCKET_Z0), Vector3(xb, UNDER_Y, pz1),
					Vector3(xb, py, pz1), Vector3(xb, py, POCKET_Z0), Vector3.LEFT)
		else:
			# The last cell splits at the head's tab end row, so the tab's x 2.0 edge has no T-junction.
			var zm := tab_z if xb == _Head.TAB_X else z0
			if zm > z0:
				m.quad(Vector3(xa, UNDER_Y, z0), Vector3(xb, UNDER_Y, z0), Vector3(xb, UNDER_Y, zm),
						Vector3(xa, UNDER_Y, zm), Vector3.DOWN)
			m.quad(Vector3(xa, UNDER_Y, zm), Vector3(xb, UNDER_Y, zm), Vector3(xb, UNDER_Y, zi),
					Vector3(xa, UNDER_Y, zi), Vector3.DOWN)
	for x in [0.0, _Head.TAB_X]:
		var y: float = profile.ceiling.vault_y_at(x) + TOP_LIFT
		hull.append(Vector3(x, UNDER_Y, z0))
		hull.append(Vector3(x, UNDER_Y, zi))
		hull.append(Vector3(x, y, z0))
		hull.append(Vector3(x, y, zo))
	wall.hulls.append(hull)
	# End faces: x = 0 whole; x = TAB_X above the step, and below it only behind the tab.
	var y0 := profile.ceiling.vault_y_at(0.0) + TOP_LIFT
	var y2 := profile.ceiling.vault_y_at(_Head.TAB_X) + TOP_LIFT
	_end(m, 0.0, y0, z0, zi, zo, z0, Vector3.LEFT)
	_end(m, _Head.TAB_X, y2, z0, zi, zo, tab_z, Vector3.RIGHT)


## One end face of the panel on plane x: the lower part (UNDER_Y..STEP_Y, z `za`..`zi`) and the upper
## (STEP_Y..`y`, z `z0`..`zo`, split at `zi`). `za` > `z0` leaves out the lower part in front of it.
func _end(m: _Mesh, x: float, y: float, z0: float, zi: float, zo: float, za: float,
		n: Vector3) -> void:
	m.quad(Vector3(x, UNDER_Y, za), Vector3(x, UNDER_Y, zi), Vector3(x, STEP_Y, zi),
			Vector3(x, STEP_Y, za), n)
	if za > z0:
		m.quad(Vector3(x, STEP_Y, z0), Vector3(x, STEP_Y, za), Vector3(x, y, za), Vector3(x, y, z0), n)
	m.quad(Vector3(x, STEP_Y, maxf(z0, za)), Vector3(x, STEP_Y, zi), Vector3(x, y, zi),
			Vector3(x, y, maxf(z0, za)), n)
	m.quad(Vector3(x, STEP_Y, zi), Vector3(x, STEP_Y, zo), Vector3(x, y, zo), Vector3(x, y, zi), n)
