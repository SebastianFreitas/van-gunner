extends RefCounted
## Skin patches that close the gaps left in VanHull's outer shell: the rear corner strip behind
## the side skin, the rocker sill along both sides and the belly between the sills. Every outline
## is sampled from the wall profile, never a standalone constant.

var _hull: VanHull


## The corner strip runs from the side skin's end (span_z / 2) to the rear face at this z.
const CORNER_Z1 := 4.78

## Sill extent, matching the old box's span along z. SILL_Z1 also matches the floor deck's rear
## end (4.80), so the belly strips end edge to edge with it.
const SILL_Z0 := -4.72
const SILL_Z1 := 4.80
## The sill chamfer's inner top, where the rear corner strip starts.
const SILL_TOP_Y := 0.04


func _init(hull: VanHull) -> void:
	_hull = hull


## Builds every patch for both sides of the van.
func build(walls: VanSideWall) -> void:
	for s: float in [-1.0, 1.0]:
		_build_rear_corner(walls, s)
		_build_sill(walls, s)
	var floor_node := walls.get_parent().get_node_or_null(^"Floor") as VanFloor
	if floor_node == null:
		push_warning("VanHullPatches: Floor node not found, belly skipped")
		return
	_build_belly(walls, floor_node.span_x * 0.5)


## Strip that continues the side skin's outer face from its end (span_z / 2) to the rear face, so
## there is no gap between SideSkin and RearSkin. RearSkin's posts own the rear face itself. It
## starts at the sill's inner top (SILL_TOP_Y), so it is not buried inside the sill below the skin.
func _build_rear_corner(walls: VanSideWall, s: float) -> void:
	var y_steps := 12
	var z0 := walls.span_z * 0.5

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Side strip: x tracks the skin and only varies with y, so cross(edge_y, edge_z) always has
	# a positive x-component; flip the winding for s < 0 so that side faces -X (outward) too.
	for iy in range(y_steps):
		var y0 := lerpf(SILL_TOP_Y, walls.wall_height, float(iy) / float(y_steps))
		var y1 := lerpf(SILL_TOP_Y, walls.wall_height, float(iy + 1) / float(y_steps))
		var x0 := s * (walls.wall_x_at(clampf(y0, 0.0, walls.wall_height)) + VanHull.SIDE_SKIN_OUTER_M)
		var x1 := s * (walls.wall_x_at(clampf(y1, 0.0, walls.wall_height)) + VanHull.SIDE_SKIN_OUTER_M)
		var p00 := Vector3(x0, y0, z0)
		var p01 := Vector3(x0, y0, CORNER_Z1)
		var p10 := Vector3(x1, y1, z0)
		var p11 := Vector3(x1, y1, CORNER_Z1)
		if s > 0.0:
			st.add_vertex(p00)
			st.add_vertex(p10)
			st.add_vertex(p01)
			st.add_vertex(p10)
			st.add_vertex(p11)
			st.add_vertex(p01)
		else:
			st.add_vertex(p00)
			st.add_vertex(p01)
			st.add_vertex(p10)
			st.add_vertex(p01)
			st.add_vertex(p11)
			st.add_vertex(p10)

	st.generate_normals()
	_hull._add_mesh("RearCornerL" if s < 0.0 else "RearCornerR", st.commit())


## Rocker sill, an extruded closed chamfer-top/outer-face/bottom/inner-face ring running the length
## of the body at the skin's floor position, replacing the old plain box.
func _build_sill(walls: VanSideWall, s: float) -> void:
	var xs: float = walls.wall_x_at(0.0) + VanHull.SIDE_SKIN_OUTER_M
	# Outer-to-inner ring: chamfer top, outer face, bottom.
	var section: Array[Vector2] = [
		Vector2(xs - 0.02, SILL_TOP_Y),
		Vector2(xs + 0.06, -0.02),
		Vector2(xs + 0.06, -0.25),
		Vector2(xs - 0.04, -0.25),
	]

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# The four running faces (a closed ring, the last being the inner face), wound outward the same
	# way as the rear corner's side strip.
	for i in range(section.size()):
		var a: Vector2 = section[i]
		var b: Vector2 = section[(i + 1) % section.size()]
		var a0 := Vector3(s * a.x, a.y, SILL_Z0)
		var a1 := Vector3(s * a.x, a.y, SILL_Z1)
		var b0 := Vector3(s * b.x, b.y, SILL_Z0)
		var b1 := Vector3(s * b.x, b.y, SILL_Z1)
		if s > 0.0:
			st.add_vertex(a0)
			st.add_vertex(b0)
			st.add_vertex(a1)
			st.add_vertex(b0)
			st.add_vertex(b1)
			st.add_vertex(a1)
		else:
			st.add_vertex(a0)
			st.add_vertex(a1)
			st.add_vertex(b0)
			st.add_vertex(b0)
			st.add_vertex(a1)
			st.add_vertex(b1)

	# End caps, fanned from the ring's first point back around to it. Mirroring x flips the
	# ring's winding, so which cap is "forward" (kept as given) flips with s too.
	_add_sill_cap(st, section, s, SILL_Z0, s > 0.0)
	_add_sill_cap(st, section, s, SILL_Z1, s < 0.0)

	st.generate_normals()
	_hull._add_mesh("SillL" if s < 0.0 else "SillR", st.commit())


## Fans one end cap of the sill's ring at `z`. `forward` keeps the ring's given order (0,1,2,3);
## otherwise the fan is reversed so the cap's normal still faces outward along z.
func _add_sill_cap(
	st: SurfaceTool, section: Array[Vector2], s: float, z: float, forward: bool
) -> void:
	for i in range(1, section.size() - 1):
		var p0 := Vector3(s * section[0].x, section[0].y, z)
		var p1 := Vector3(s * section[i].x, section[i].y, z)
		var p2 := Vector3(s * section[i + 1].x, section[i + 1].y, z)
		if forward:
			st.add_vertex(p0)
			st.add_vertex(p1)
			st.add_vertex(p2)
		else:
			st.add_vertex(p0)
			st.add_vertex(p2)
			st.add_vertex(p1)


## Flat underside as two strips, one per side, at the sills' bottom y: each runs edge to edge from
## the floor deck's side (`deck_half_x`) to its sill's bottom face (which ends at xs - 0.04). The
## deck already closes the bottom between them, so a full plate would lie coplanar on it.
func _build_belly(walls: VanSideWall, deck_half_x: float) -> void:
	var x_edge: float = walls.wall_x_at(0.0) + VanHull.SIDE_SKIN_OUTER_M - 0.04

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s: float in [-1.0, 1.0]:
		# x_a < x_b for both strips, so one winding serves both.
		var x_a := minf(s * deck_half_x, s * x_edge)
		var x_b := maxf(s * deck_half_x, s * x_edge)
		var p00 := Vector3(x_a, -0.25, SILL_Z0)
		var p10 := Vector3(x_b, -0.25, SILL_Z0)
		var p01 := Vector3(x_a, -0.25, SILL_Z1)
		var p11 := Vector3(x_b, -0.25, SILL_Z1)
		# Wound the reverse of the roof's grid so the face points -Y (down).
		st.add_vertex(p00)
		st.add_vertex(p01)
		st.add_vertex(p10)
		st.add_vertex(p10)
		st.add_vertex(p01)
		st.add_vertex(p11)
	st.generate_normals()
	_hull._add_mesh("BellySkin", st.commit())
