class_name RailgunPivots
extends RefCounted
## The railgun's three moving parts as named pivots (breech, two vent flaps, charge cell), each origin on its hinge or slide line with its meshes as children.


## Builds the pivots under `body` (gun space, -Z forward). Units are palm lengths `p`, y above the
## guard top `ya`. Shape never reads `rng`; only the materials do.
static func build(body: Node3D, p: float, rng: RandomNumberGenerator, ya: float) -> void:
	var rust := ArmMaterials.rust(rng.randf_range(0.0, 100.0))
	var steel := ArmMaterials.steel(rng.randf_range(0.0, 100.0))
	var alu := ArmMaterials.dull_alu(rng.randf_range(0.0, 100.0))
	_breech(body, p, ya, steel)
	_vents(body, p, ya, rust)
	_cell(body, p, ya, alu, steel)


## The breech block: slides +0.30 z later. Its top ya+1.06 is under the rails (ya+1.07), 0.01 proud of
## the panels, over the slug rod, with 0.01 side play in the channel.
static func _breech(body: Node3D, p: float, ya: float, steel: Material) -> void:
	var breech := _pivot(body, "Breech", Vector3(0.0, ya + 0.99 * p, 0.10 * p))
	ArmParts.mesh(breech, "BreechBlock", ArmParts.box(Vector3(0.28, 0.07, 0.45) * p), steel,
			Vector3(0.0, 0.035 * p, 0.0))
	# Wear rides the block; fixed material seeds, no rng draw.
	ArmParts.mesh(breech, "BreechRust", ArmParts.box(Vector3(0.12, 0.004, 0.10) * p),
			ArmMaterials.heavy_rust(17.0), Vector3(-0.06, 0.072, 0.12) * p)
	ArmParts.mesh(breech, "BreechScorch", ArmParts.box(Vector3(0.18, 0.05, 0.004) * p),
			ArmMaterials.scorched_steel(19.0), Vector3(0.04, 0.03, 0.227) * p)
	# Soot on the block's top at its rear end, seen from the player's view.
	ArmParts.mesh(breech, "BreechScorchTop", ArmParts.box(Vector3(0.12, 0.004, 0.14) * p),
			ArmMaterials.scorched_steel(37.0), Vector3(0.07, 0.072, 0.14) * p)


## Two vent flaps hinged on their outer long edge (the pivot's Z axis), so a later rotation about
## Z lifts the inner edge in a V.
static func _vents(body: Node3D, p: float, ya: float, rust: Material) -> void:
	for side: float in [-1.0, 1.0]:
		var tag := "L" if side < 0.0 else "R"
		var vent := _pivot(body, "Vent" + tag, Vector3(side * 0.20 * p, ya + 1.06 * p, -0.80 * p))
		# The right flap is a mismatched heavy-rust panel; the left carries a paint flake.
		ArmParts.mesh(vent, "VentFlap" + tag, ArmParts.box(Vector3(0.13, 0.012, 0.39) * p),
				ArmMaterials.heavy_rust(23.0) if side > 0.0 else rust,
				Vector3(-side * 0.07 * p, -0.006 * p, 0.0))
		if side < 0.0:
			ArmParts.mesh(vent, "VentFlake", ArmParts.box(Vector3(0.06, 0.004, 0.12) * p),
					ArmMaterials.gun_paint(29.0), Vector3(0.07, 0.002, -0.10) * p)


## The charge cell, hinged on its rear vertical edge (the pivot's Y axis) so a later rotation about
## Y swings its front out toward the player. Its lamp and two rear bolts ride along.
static func _cell(body: Node3D, p: float, ya: float, alu: Material, steel: Material) -> void:
	var cell := _pivot(body, "ChargeCell", Vector3(-0.22 * p, ya + 0.55 * p, -0.20 * p))
	ArmParts.mesh(cell, "ChargeCellBox", ArmParts.box(Vector3(0.06, 0.30, 0.40) * p), alu,
			Vector3(-0.03 * p, 0.0, -0.20 * p))
	# Half sunk in the outer face, reaching x -0.289.
	ArmParts.mesh(cell, "Lamp1", ArmParts.box(Vector3(0.012, 0.16, 0.03) * p),
			ArmMaterials.ember(0.0), Vector3(-0.063 * p, 0.0, -0.20 * p))
	for k: int in range(2):
		ArmParts.mesh(cell, "CellBolt%d" % k, ArmParts.cyl(0.02 * p, 0.03 * p, 0.02 * p, 6), steel,
				Vector3(-0.03 * p, (0.10 - 0.20 * k) * p, 0.005 * p),
				ArmParts.along(Vector3.BACK))
	ArmParts.mesh(cell, "CellRust", ArmParts.box(Vector3(0.004, 0.10, 0.12) * p),
			ArmMaterials.heavy_rust(31.0), Vector3(-0.062, -0.08, -0.08) * p)
	_cables(cell, p)


## Three cables riding the cell, in pivot-local coordinates: two bowed runs ending in dark holes
## on the hinge line (x 0, so a swing leaves their ends put) and one taped sag under the cell.
## Fixed material seeds: no rng draw, so later seeds do not shift.
static func _cables(cell: Node3D, p: float) -> void:
	var cable := ArmMaterials.surface(Color(0.04, 0.04, 0.035), Color(0.02, 0.02, 0.02),
			Color(0.03, 0.03, 0.02), 60.0, 6.0, 0.0, 0.6, 0.9, 0.0, 37.0)
	var dark := ArmMaterials.surface(Color(0.03, 0.03, 0.03), Color(0.02, 0.02, 0.02),
			Color(0.02, 0.02, 0.02), 60.0, 6.0, 0.0, 0.6, 0.9, 0.2, 53.0)
	var tape := MachineParts.dark(Color(0.08, 0.08, 0.08))
	var ends := {"CableUpper": 0.43, "CableLower": -0.49}
	for node_name: String in ends:
		var y_end: float = ends[node_name]
		var y_start := 0.15 if y_end > 0.0 else -0.15
		var a := Vector3(-0.03, y_start, 0.0) * p
		var b := Vector3(0.0, y_end, 0.01) * p
		var bow := Vector3(-0.04 * p, 0.0, 0.0)
		_run(cell, node_name, [a, a.lerp(b, 0.5) + bow, b], cable, p)
		# Hole disc on the flank, facing -x, 0.002 thick and sunk into it.
		ArmParts.mesh(cell, node_name + "Hole", ArmParts.cyl(0.015 * p, 0.002 * p, 0.015 * p, 8),
				dark, Vector3(-0.001 * p, y_end * p, 0.01 * p), ArmParts.along(Vector3.LEFT))
	var pts: Array[Vector3] = []
	for i: int in range(5):
		var t := i / 4.0
		pts.append(Vector3(-0.04, -0.15 - 0.06 * sin(PI * t), lerpf(-0.35, -0.02, t)) * p)
	_run(cell, "CableSag", pts, cable, p)
	for k: int in range(2):
		var from := pts[0] if k == 0 else pts[4]
		var toward := pts[1] if k == 0 else pts[3]
		ArmParts.mesh(cell, "CableSagClamp%d" % k, ArmParts.cyl(0.03 * p, 0.03 * p, 0.03 * p, 8),
				tape, from, ArmParts.along(toward - from))


## A polyline of cable limbs; the first segment keeps `node_name`, the rest get a number.
static func _run(cell: Node3D, node_name: String, pts: Array, cable: Material, p: float) -> void:
	for i: int in range(pts.size() - 1):
		var seg_name := node_name if i == 0 else "%s%d" % [node_name, i]
		ArmParts.limb(cell, seg_name, pts[i], pts[i + 1], 0.02 * p, 0.02 * p, cable, 6)


## An empty named pivot under `parent` at `at`.
static func _pivot(parent: Node3D, node_name: String, at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = node_name
	n.position = at
	parent.add_child(n)
	return n
