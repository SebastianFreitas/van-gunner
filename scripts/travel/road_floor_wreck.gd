extends RefCounted
## Builds RoadFloor's wrecked sidewalk: real slab boxes on a soil bed and a curb in pieces,
## each side as one merged mesh. Wreckage follows the ruin tier of the building beside it.

const SLAB_T := 0.09 ## slab box height; its bottom sinks into the soil bed
const BED_DROP := 0.05 ## soil bed top sits this far under the walk top (pit depth)
const SLAB_LEN := 1.2 ## must equal the sidewalk shader's slab_spacing_m
const GAP := 0.02
const MISSING: Array[float] = [0.0, 0.03, 0.10, 0.22]
const PIT_CHUNKS: Array[float] = [0.0, 0.3, 0.5, 0.7]
const SPLIT: Array[float] = [0.04, 0.12, 0.22, 0.30]
const HEAVE: Array[float] = [0.03, 0.10, 0.20, 0.30]
const MAX_TILT_DEG: Array[float] = [2.0, 4.0, 7.0, 10.0]
const SINK: Array[float] = [0.03, 0.08, 0.12, 0.15]
const CURB_CHIP: Array[float] = [0.05, 0.15, 0.30, 0.40]
const CURB_MISSING: Array[float] = [0.0, 0.03, 0.10, 0.20]
const CURB_KNOCKED: Array[float] = [0.02, 0.08, 0.15, 0.22]

var road: RoadFloor
## Running vertex count of the SurfaceTool being filled (reset per tool).
var _verts := 0
## Slab UV inputs: road-side x of the walk and z of its start.
var _inner_x := 0.0
var _z_start := 0.0


func _init(owner_road: RoadFloor) -> void:
	road = owner_road


func build(side_idx: int, walk_len: float, walk_cz: float, walk_inner_x: float,
		sidewalk_top: float, curb_x: float, curb_bottom_y: float, curb_top_y: float,
		curb_depth: float, slab_mat: Material, curb_mat: Material) -> void:
	var side := -1.0 if side_idx == 0 else 1.0
	if walk_len < 0.3:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = road._seed_value(97 + side_idx * 1000)
	_inner_x = walk_inner_x
	_z_start = walk_cz - walk_len * 0.5
	var tag := "Left" if side_idx == 0 else "Right"

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_verts = 0
	_build_slabs(st, rng, side_idx, side, walk_len, walk_cz, sidewalk_top)
	if _verts > 0:
		st.generate_tangents()
		var mi := MeshInstance3D.new()
		mi.name = "WalkSlabs" + tag
		mi.mesh = st.commit()
		mi.material_override = slab_mat
		road.add_child(mi)

	# Curb boxes stay centred on their node: curb_surface.gdshader reads abs(VERTEX.x/y).
	var cst := SurfaceTool.new()
	cst.begin(Mesh.PRIMITIVE_TRIANGLES)
	_verts = 0
	_build_curb(cst, rng, side_idx, side, walk_len, curb_top_y - curb_bottom_y, curb_depth,
			(curb_bottom_y + curb_top_y) * 0.5)
	if _verts > 0:
		cst.generate_tangents()
		var cmi := MeshInstance3D.new()
		cmi.name = "WalkCurb" + tag
		cmi.mesh = cst.commit()
		cmi.material_override = curb_mat
		cmi.position = Vector3(side * curb_x, (curb_bottom_y + curb_top_y) * 0.5, 0.0)
		road.add_child(cmi)


func tier_at(side_idx: int, z: float) -> int:
	if road.wreck_spans.size() == 2:
		for v: Vector3 in road.wreck_spans[side_idx]:
			if v.x <= z and z < v.y:
				return clampi(int(v.z), 0, 3)
	return clampi(road.default_wreck_tier, 0, 3)


func _build_slabs(st: SurfaceTool, rng: RandomNumberGenerator, side_idx: int, side: float,
		walk_len: float, _walk_cz: float, sidewalk_top: float) -> void:
	var z_end := _z_start + walk_len
	var rows := ceili(walk_len / SLAB_LEN - 0.001)
	var width := road.sidewalk_width
	var cx := side * (_inner_x + width * 0.5)
	for r in rows:
		var z0 := _z_start + r * SLAB_LEN
		var z1 := minf(z0 + SLAB_LEN, z_end)
		var tier := tier_at(side_idx, (z0 + z1) * 0.5)
		var wreck := tier / 3.0
		var r_miss := rng.randf()
		var r_chunk := rng.randf()
		var r_split := rng.randf()
		var r_pos := rng.randf()
		var r_tone := rng.randf()
		var kept := false
		if road.dressing_z.size() == 2:
			for dz: float in road.dressing_z[side_idx]:
				if dz >= z0 - 0.3 and dz <= z1 + 0.3:
					kept = true
		if r_miss < MISSING[tier] and not kept:
			if r_chunk < PIT_CHUNKS[tier]:
				for i in (2 if r_tone > 0.5 else 1):
					var c := Vector3(
							side * (_inner_x + rng.randf_range(0.1, width - 0.1)),
							sidewalk_top - BED_DROP,
							rng.randf_range(z0 + 0.1, maxf(z0 + 0.1, z1 - 0.1)))
					_add_chunk(st, rng, c, wreck, true)
			continue
		# Pieces as (z centre, length).
		var pieces: Array[Vector2] = []
		if r_split < SPLIT[tier]:
			var zc := z0 + (z1 - z0) * lerpf(0.35, 0.65, r_pos)
			pieces.append(Vector2((z0 + zc - 0.015) * 0.5, zc - 0.015 - z0 - GAP * 0.5))
			pieces.append(Vector2((zc + 0.015 + z1) * 0.5, z1 - zc - 0.015 - GAP * 0.5))
		else:
			pieces.append(Vector2((z0 + z1) * 0.5, z1 - z0 - GAP))
		for p in pieces:
			var r_heave := rng.randf()
			var r_axis := rng.randf()
			var r_ang := rng.randf()
			var r_sink := rng.randf()
			var r_jit := rng.randf()
			if p.y < 0.1:
				continue
			var yaw := (r_jit - 0.5) * deg_to_rad(1.0) * (0.3 + wreck)
			var y := sidewalk_top - SLAB_T * 0.5
			var tilt := Basis.IDENTITY
			if not kept and r_heave < HEAVE[tier]:
				var ang := deg_to_rad(MAX_TILT_DEG[tier]) * lerpf(0.4, 1.0, r_ang)
				if r_axis < 0.6:
					tilt = Basis(Vector3.RIGHT, ang)
					y += 0.5 * p.y * sin(ang)
				else:
					ang *= 0.5
					tilt = Basis(Vector3.BACK, ang)
					y += 0.5 * (width - GAP) * sin(ang)
			elif not kept and r_sink < SINK[tier]:
				y -= lerpf(0.012, 0.035, r_ang)
			else:
				y += (r_jit - 0.5) * 0.006
			var centre := Vector3(cx, y, p.x)
			var xf := Transform3D(Basis(Vector3.UP, yaw) * tilt, centre)
			_append_box(st, Vector3(width - GAP, SLAB_T, p.y), xf, Color(wreck, r_tone, 0.0), true)


func _build_curb(st: SurfaceTool, rng: RandomNumberGenerator, side_idx: int, side: float,
		walk_len: float, curb_h: float, curb_depth: float, curb_mid_y: float) -> void:
	var z_end := _z_start + walk_len
	var cuts: Array[float] = [_z_start]
	var k := ceili(_z_start / 1.2 - 0.5)
	while (k + 0.5) * 1.2 < z_end:
		if (k + 0.5) * 1.2 > _z_start:
			cuts.append((k + 0.5) * 1.2)
		k += 1
	cuts.append(z_end)
	var gutter_y := road.road_surface_y - road.gutter_depth
	for i in cuts.size() - 1:
		var a0 := cuts[i]
		var a1 := cuts[i + 1]
		var zmid := (a0 + a1) * 0.5
		var length := a1 - a0 - 0.024
		var r_miss := rng.randf()
		var r_chip := rng.randf()
		var r_knock := rng.randf()
		var a := rng.randf()
		var b := rng.randf()
		if length < 0.1:
			continue
		var tier := tier_at(side_idx, zmid)
		var wreck := tier / 3.0
		var gutter_local_y := gutter_y - curb_mid_y
		var chunks := 0
		var h := curb_h
		var xshift := 0.0
		var drop := 0.0
		var yaw := 0.0
		if r_miss < CURB_MISSING[tier]:
			chunks = 2 if a > 0.5 else 1
		else:
			if r_knock < CURB_KNOCKED[tier]:
				yaw = (1.0 if a > 0.5 else -1.0) * deg_to_rad(lerpf(3.0, 9.0, a))
				xshift = -side * lerpf(0.02, 0.06, b)
				drop = lerpf(0.01, 0.03, a)
				chunks = 1
			if r_chip < CURB_CHIP[tier]:
				h -= lerpf(0.02, 0.05, b)
			var cy := -curb_h * 0.5 + h * 0.5 - drop
			var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(xshift, cy, zmid))
			_append_box(st, Vector3(curb_depth, h, length), xf,
					Color(wreck, rng.randf(), 0.0), false)
		for c in chunks:
			var cp := Vector3(-side * rng.randf_range(0.12, 0.35), gutter_local_y,
					rng.randf_range(a0 + 0.1, maxf(a0 + 0.1, a1 - 0.1)))
			_add_chunk(st, rng, cp, wreck, false)


func _add_chunk(st: SurfaceTool, rng: RandomNumberGenerator, centre: Vector3, wreck: float,
		slab_uv: bool) -> void:
	var size := Vector3(rng.randf_range(0.12, 0.3), rng.randf_range(0.05, 0.1),
			rng.randf_range(0.12, 0.3))
	var rot := Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(0.0, TAU),
			rng.randf_range(-0.5, 0.5))
	var pos := Vector3(centre.x, centre.y + size.y * 0.3, centre.z)
	var color := Color(maxf(wreck, 0.66), rng.randf(), 0.0)
	_append_box(st, size, Transform3D(Basis.from_euler(rot), pos), color, slab_uv)


func _append_box(st: SurfaceTool, size: Vector3, xform: Transform3D, color: Color,
		slab_uv: bool) -> void:
	var box := BoxMesh.new()
	box.size = size
	var arrays := box.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for i in verts.size():
		var uv := uvs[i]
		if slab_uv:
			# Unrotated road-local position keeps the shader's seams glued to the slab.
			var p := xform.origin + verts[i]
			uv = Vector2((absf(p.x) - _inner_x) / road.sidewalk_width, p.z - _z_start)
		st.set_color(color)
		st.set_normal((xform.basis * normals[i]).normalized())
		st.set_uv(uv)
		st.add_vertex(xform * verts[i])
	for idx in indices:
		st.add_index(idx + _verts)
	_verts += verts.size()
