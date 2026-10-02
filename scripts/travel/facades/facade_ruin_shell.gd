extends RefCounted
## Back wall and inner end walls of a deep ruined body, seen through its holes and collapsed tops.


const _FacadeBody := preload("res://scripts/travel/facades/facade_body.gd")
const _FacadeMeshKit := preload("res://scripts/travel/facades/facade_mesh_kit.gd")
const _FacadeMaterials := preload("res://scripts/travel/facades/facade_materials.gd")
const _FacadeGrimeMaterials := preload("res://scripts/travel/facades/facade_grime_materials.gd")
const _FacadePlan := preload("res://scripts/travel/facades/facade_plan.gd")
const _FacadeRuinDebris := preload("res://scripts/travel/facades/facade_ruin_debris.gd")

const WALL_T := 0.35
const ROOFED_DROP := _FacadeRuinDebris.ROOFED_DROP
const MIN_H := 0.01
## A collapsed column's back wall stands at least this far above its front stub, and drops from
## the full height by up to RISE_SHARE of the fall, so a broken top shows the building behind it.
const RISE_MIN := 0.6
const RISE_SHARE := 0.5
## Cross walls between columns next to a collapse: thickness, chance per boundary, and how far
## behind the front wall's inner face they start.
const PARTITION_T := 0.2
const PARTITION_CHANCE := 0.5
const PARTITION_SETBACK := 0.3


## Builds the shell mesh under host and stores `ruin_back_tops` (one back-wall top y per column)
## on the plan. Own rng, so no other family's draws move.
static func build(
	host: Node3D, plan: Dictionary, side_sign: float, index: int, x_face: float, x_back: float,
	y0: float, shadows: bool, y_cut: float
) -> void:
	var cols: Array = plan.get(&"ruin_cols", [])
	var s := side_sign
	var z0 := float(plan[&"z0"])
	var z1 := float(plan[&"z1"])
	var full := y0 + float(plan[&"height"])
	var floor_y := y0 + float(plan[&"params"].get(&"ground_height", _FacadePlan.GROUND_HEIGHT))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([float(plan[&"params"][&"seed"]), &"ruin_back"])
	var tops: Array[float] = []
	for c: Vector3 in cols:
		if full - c.z < ROOFED_DROP:
			tops.append(c.z)
		else:
			var raised := full - rng.randf_range(0.0, RISE_SHARE) * (full - c.z)
			tops.append(clampf(raised, c.z + RISE_MIN, full))
	plan[&"ruin_back_tops"] = tops

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var x_in := x_back - s * WALL_T
	# Below the cut nothing can be seen; v keeps counting from y0 so the texture doesn't move.
	var y_b := maxf(y0, y_cut)
	for i in cols.size():
		var c: Vector3 = cols[i]
		var top: float = tops[i]
		if top - y_b > MIN_H:
			_quad(st, Vector3(x_in, y_b, c.x), Vector3(x_in, y_b, c.y), Vector3(x_in, top, c.y),
				Vector3(x_in, top, c.x), Vector3(-s, 0.0, 0.0), c.x - z0, c.y - z0, y_b - y0,
				top - y0)
			# A roofed column's roof plate already covers its top: no coplanar cap.
			if full - c.z >= ROOFED_DROP:
				_quad(st, Vector3(x_in, top, c.x), Vector3(x_in, top, c.y),
					Vector3(x_back, top, c.y), Vector3(x_back, top, c.x), Vector3.UP,
					c.x - z0, c.y - z0, 0.0, WALL_T)
		if i + 1 < cols.size():
			_step(st, x_in, x_back, y0, y_b, full, c, cols[i + 1] as Vector3, top, tops[i + 1])
	if not cols.is_empty():
		var first: Vector3 = cols[0]
		var last: Vector3 = cols[cols.size() - 1]
		var edge_0 := 0.05 if absf(z0) >= 9.99 else 0.0
		var edge_1 := 0.05 if absf(z1) >= 9.99 else 0.0
		_end_wall(st, x_face, x_in, s, y0, y_b, full, first.z, tops[0], z0 + WALL_T + edge_0, -1.0)
		_end_wall(st, x_face, x_in, s, y0, y_b, full, last.z, tops[cols.size() - 1],
			z1 - WALL_T - edge_1, 1.0)
	# Own rng, drawn twice per boundary even when skipped, so edits never move the others.
	var prng := RandomNumberGenerator.new()
	prng.seed = hash([float(plan[&"params"][&"seed"]), &"ruin_partition"])
	var y_lo := maxf(y_b, floor_y)
	for i in range(1, cols.size()):
		var chance := prng.randf()
		var drop := prng.randf_range(0.0, 0.8)
		var a: Vector3 = cols[i - 1]
		var b: Vector3 = cols[i]
		if full - a.z < ROOFED_DROP and full - b.z < ROOFED_DROP:
			continue
		if chance >= PARTITION_CHANCE:
			continue
		var y_hi := minf(tops[i - 1], tops[i]) - drop
		if y_hi - y_lo < 1.0:
			continue
		_partition(st, x_face, x_in, s, b.x, y_lo, y_hi)
	var material := _FacadeGrimeMaterials.from_prop(_FacadeMaterials.prop_material(
		&"ruin_interior_wall", Color(0.085, 0.08, 0.072), 0.92, 0.0, Color.BLACK, 0.0
	))
	if _FacadeMeshKit.has_geometry(st):
		_FacadeMeshKit.commit(host, st, "Body%dShell" % index, material, shadows)


## The back wall's step between two columns, facing the lower one; when the taller column is
## roofed its front step face already reaches the back, so only the part below the lower
## column's front top is added.
static func _step(
	st: SurfaceTool, x_in: float, x_back: float, y0: float, y_b: float, full: float, c: Vector3,
	nx: Vector3, top_a: float, top_b: float
) -> void:
	var lo := maxf(minf(top_a, top_b), y_b)
	var hi := maxf(top_a, top_b)
	var taller_front := maxf(c.z, nx.z)
	if full - taller_front < ROOFED_DROP:
		hi = minf(hi, minf(c.z, nx.z))
	if hi - lo <= MIN_H:
		return
	var normal := Vector3.FORWARD if top_a < top_b else Vector3.BACK
	_quad(st, Vector3(x_in, lo, c.y), Vector3(x_back, lo, c.y), Vector3(x_back, hi, c.y),
		Vector3(x_in, hi, c.y), normal, 0.0, WALL_T, lo - y0, hi - y0)


## An inner end wall at z_in, facing into the room (normal_z is the outward end's), up to the end
## column's front top, with a WALL_T cap over it unless a roof plate covers the column.
static func _end_wall(
	st: SurfaceTool, x_face: float, x_in: float, s: float, y0: float, y_b: float, full: float,
	top: float, top_back: float, z_in: float, normal_z: float
) -> void:
	if top - y_b <= MIN_H:
		return
	var xa := x_face + s * WALL_T
	var reach := absf(x_in - xa)
	var inward := Vector3(0.0, 0.0, -normal_z)
	if top_back > top + 0.05:
		# The back wall stands above the fallen front: the end wall slopes up to meet it, and its
		# outer face closes the wedge above the front top.
		_FacadeBody.add_quad(st, Vector3(xa, y_b, z_in), Vector3(x_in, y_b, z_in),
			Vector3(x_in, top_back, z_in), Vector3(xa, top, z_in), Vector2(0.0, y_b - y0),
			Vector2(reach, y_b - y0), Vector2(reach, top_back - y0), Vector2(0.0, top - y0),
			inward)
		var z_out := z_in + normal_z * WALL_T
		_FacadeBody.add_quad(st, Vector3(xa, top, z_out), Vector3(x_in, top_back, z_out),
			Vector3(x_in, top, z_out), Vector3(xa, top, z_out), Vector2(0.0, top - y0),
			Vector2(reach, top_back - y0), Vector2(reach, top - y0), Vector2(0.0, top - y0),
			Vector3(0.0, 0.0, normal_z))
		return
	_quad(st, Vector3(xa, y_b, z_in), Vector3(x_in, y_b, z_in), Vector3(x_in, top, z_in),
		Vector3(xa, top, z_in), inward, 0.0, reach, y_b - y0, top - y0)
	if full - top >= ROOFED_DROP:
		var z_out := z_in + normal_z * WALL_T
		_quad(st, Vector3(xa, top, z_in), Vector3(x_in, top, z_in), Vector3(x_in, top, z_out),
			Vector3(xa, top, z_out), Vector3.UP, 0.0, reach, 0.0, WALL_T)


## A thin cross wall at z from y_lo to y_hi, set back from the front wall, with both faces and the
## narrow edge facing the road.
static func _partition(
	st: SurfaceTool, x_face: float, x_in: float, s: float, z: float, y_lo: float, y_hi: float
) -> void:
	var xa := x_face + s * (WALL_T + PARTITION_SETBACK)
	var reach := absf(x_in - xa)
	var z_a := z - PARTITION_T * 0.5
	var z_b := z + PARTITION_T * 0.5
	_quad(st, Vector3(xa, y_lo, z_a), Vector3(x_in, y_lo, z_a), Vector3(x_in, y_hi, z_a),
		Vector3(xa, y_hi, z_a), Vector3.FORWARD, 0.0, reach, y_lo, y_hi)
	_quad(st, Vector3(xa, y_lo, z_b), Vector3(x_in, y_lo, z_b), Vector3(x_in, y_hi, z_b),
		Vector3(xa, y_hi, z_b), Vector3.BACK, 0.0, reach, y_lo, y_hi)
	_quad(st, Vector3(xa, y_lo, z_a), Vector3(xa, y_lo, z_b), Vector3(xa, y_hi, z_b),
		Vector3(xa, y_hi, z_a), Vector3(-s, 0.0, 0.0), 0.0, PARTITION_T, y_lo, y_hi)


## add_quad with UV (u_a, v_a) at a, (u_b, v_a) at b, (u_b, v_b) at c and (u_a, v_b) at d.
static func _quad(
	st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3,
	u_a: float, u_b: float, v_a: float, v_b: float
) -> void:
	_FacadeBody.add_quad(
		st, a, b, c, d, Vector2(u_a, v_a), Vector2(u_b, v_a), Vector2(u_b, v_b),
		Vector2(u_a, v_b), normal
	)
