extends RefCounted

## Builds the bulkhead's frame posts, headers, panels and diagonal mesh netting.

var bulkhead: Node3D  # the owning VanBulkhead; reads/writes its fields when called


func _init(owner: Node3D) -> void:
	bulkhead = owner


func add_post(node_name: String, x: float, material: Material) -> void:
	var top: float = bulkhead._vault_y(x)
	bulkhead._add_box(
		node_name,
		Vector3(bulkhead.frame_thickness, top, bulkhead.frame_depth),
		Vector3(x, top * 0.5, 0.0),
		material
	)


func add_curved_wall_post(node_name: String, wall_sign: float, material: Material) -> void:
	var segs := maxi(bulkhead.wall_post_segments, 4)
	var inset: float = bulkhead.frame_thickness * 0.5
	var y_top_limit: float = bulkhead._vault_y(wall_sign * (bulkhead._vault_half() - inset))
	for i in range(segs):
		var t0 := float(i) / float(segs)
		var t1 := float(i + 1) / float(segs)
		var y0 := lerpf(0.0, y_top_limit, t0)
		var y1 := lerpf(0.0, y_top_limit, t1)
		var x0: float = wall_sign * (bulkhead._wall_half(y0) - inset)
		var x1: float = wall_sign * (bulkhead._wall_half(y1) - inset)
		# Clip the upper end if it would poke through the vault.
		if y0 >= bulkhead._vault_y(x0) - 0.01:
			continue
		if y1 > bulkhead._vault_y(x1):
			y1 = bulkhead._vault_y(x1)
			x1 = wall_sign * (bulkhead._wall_half(y1) - inset)
		var dx := x1 - x0
		var dy := y1 - y0
		var length := sqrt(dx * dx + dy * dy)
		if length < 0.02:
			continue
		# Box local +Y along the wall tangent. RotZ maps (0,1) → (-sin θ, cos θ),
		# so θ = atan2(-dx, dy) aims +Y at (dx, dy).
		var angle := atan2(-dx, dy)
		bulkhead._add_box(
			"%s_%d" % [node_name, i],
			Vector3(bulkhead.frame_thickness, length + 0.006, bulkhead.frame_depth),
			Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, 0.0),
			material,
			Vector3(0.0, 0.0, angle)
		)


func add_panel_post(node_name: String, x: float, material: Material) -> void:
	var top: float = bulkhead._vault_y(x)
	var height: float = top - bulkhead.kick_height
	if height < 0.05:
		return
	bulkhead._add_box(
		node_name,
		Vector3(bulkhead.frame_thickness * 0.75, height, bulkhead.frame_depth * 0.85),
		Vector3(x, bulkhead.kick_height + height * 0.5, 0.0),
		material
	)


func add_panel_slab(
	node_name: String,
	inner_x: float,
	outer_sign: float,
	y0: float,
	y1: float,
	depth: float,
	material: Material,
	x_inset: float
) -> void:
	## Horizontal strips so the outer edge follows the wall bow.
	var segs := 6
	for i in range(segs):
		var t0 := float(i) / float(segs)
		var t1 := float(i + 1) / float(segs)
		var ya := lerpf(y0, y1, t0)
		var yb := lerpf(y0, y1, t1)
		var y := (ya + yb) * 0.5
		var h := absf(yb - ya) + 0.002
		var outer_x: float = outer_sign * (bulkhead._wall_half(y) - x_inset)
		var width := absf(outer_x - inner_x)
		if width < 0.04:
			continue
		bulkhead._add_box(
			"%s_%d" % [node_name, i],
			Vector3(width, h, depth),
			Vector3((inner_x + outer_x) * 0.5, y, 0.0),
			material
		)


func add_curved_header(inner_x: float, outer_x: float, material: Material) -> void:
	var left_x := minf(inner_x, outer_x)
	var right_x := maxf(inner_x, outer_x)
	var segments := 10
	var y_off: float = bulkhead.frame_thickness * 0.45
	for i in range(segments):
		var t0 := float(i) / float(segments)
		var t1 := float(i + 1) / float(segments)
		var x0 := lerpf(left_x, right_x, t0)
		var x1 := lerpf(left_x, right_x, t1)
		var y0: float = bulkhead._vault_y(x0) - y_off
		var y1: float = bulkhead._vault_y(x1) - y_off
		var dx := x1 - x0
		var dy := y1 - y0
		var length := sqrt(dx * dx + dy * dy)
		if length < 0.01:
			continue
		# Box local +X is the long axis for the rail — rotate from +X onto the vault tangent.
		var angle := atan2(dy, dx)
		bulkhead._add_box(
			"TopRail_%d" % i,
			Vector3(length + 0.008, bulkhead.frame_thickness, bulkhead.frame_depth),
			Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, 0.0),
			material,
			Vector3(0.0, 0.0, angle)
		)


func add_diagonal_mesh(
	inner_x: float,
	outer_sign: float,
	bottom_y: float,
	material: Material
) -> void:
	var inset: float = bulkhead.frame_thickness * 0.65
	bottom_y += inset * 0.35

	# Bounding rect uses the widest wall half in the mesh band so cells stay uniform.
	var max_half := 0.0
	var max_top: float = bulkhead._vault_y(0.0) - bulkhead.frame_thickness - inset * 0.25
	for i in range(12):
		var y := lerpf(bottom_y, max_top, float(i) / 11.0)
		max_half = maxf(max_half, bulkhead._wall_half(y))

	var left_x: float
	var right_x: float
	if outer_sign > 0.0:
		left_x = inner_x + inset
		right_x = max_half - inset
	else:
		left_x = -max_half + inset
		right_x = inner_x - inset

	var width := right_x - left_x
	if width <= 0.08:
		return

	var cols := maxi(2, int(ceil(width / bulkhead.mesh_spacing)))
	var rows := maxi(2, int(ceil((max_top - bottom_y) / bulkhead.mesh_spacing)))
	var cell_w := width / float(cols)
	var cell_h := (max_top - bottom_y) / float(rows)
	var index := 0

	for col in range(cols):
		for row in range(rows):
			var x0 := left_x + float(col) * cell_w
			var x1 := x0 + cell_w
			var y0 := bottom_y + float(row) * cell_h
			var y1 := y0 + cell_h
			var limit0: float = bulkhead._vault_y(x0) - bulkhead.frame_thickness - inset * 0.25
			var limit1: float = bulkhead._vault_y(x1) - bulkhead.frame_thickness - inset * 0.25
			var vault_ok := minf(limit0, limit1)
			if y0 < vault_ok:
				if y1 <= vault_ok + 0.03 and mesh_segment_ok(x0, y0, x1, y1, inset):
					add_segment("MeshFwd_%d" % index, Vector3(x0, y0, 0.0), Vector3(x1, y1, 0.0), material)
					index += 1
				if y0 <= vault_ok + 0.03 and mesh_segment_ok(x0, y1, x1, y0, inset):
					add_segment("MeshBack_%d" % index, Vector3(x0, y1, 0.0), Vector3(x1, y0, 0.0), material)
					index += 1


func mesh_point_inside(x: float, y: float, inset: float) -> bool:
	return absf(x) <= bulkhead._wall_half(y) - inset + 0.02


func mesh_segment_ok(x0: float, y0: float, x1: float, y1: float, inset: float) -> bool:
	# Keep bars that mostly sit inside the wall profile.
	var mid_x := (x0 + x1) * 0.5
	var mid_y := (y0 + y1) * 0.5
	return (
		mesh_point_inside(mid_x, mid_y, inset)
		and (mesh_point_inside(x0, y0, inset) or mesh_point_inside(x1, y1, inset))
	)


func add_segment(node_name: String, a: Vector3, b: Vector3, material: Material) -> void:
	var delta := b - a
	var length := delta.length()
	if length < 0.02:
		return
	var mid := (a + b) * 0.5
	var angle := atan2(delta.y, delta.x)
	bulkhead._add_box(
		node_name,
		Vector3(length, bulkhead.mesh_bar_size, bulkhead.mesh_bar_depth),
		mid,
		material,
		Vector3(0.0, 0.0, angle)
	)


func steel_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.23, 0.24, 1.0)
	mat.metallic = 0.78
	mat.roughness = 0.42
	return mat


func mesh_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.125, 0.13, 1.0)
	mat.metallic = 0.88
	mat.roughness = 0.38
	return mat
