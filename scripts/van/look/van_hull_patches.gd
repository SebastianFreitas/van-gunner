extends RefCounted
## Skin patches that close the four gaps left in VanHull's outer shell: the rear corner return
## behind the door posts, the rocker sill along both sides, and a casing ring around each side
## door opening. Every outline is sampled from the wall profile, never a standalone constant.

var _hull: VanHull


## How far into the rear face the corner strip runs, and the outward return that closes it.
const CORNER_Z0 := 4.64
const CORNER_Z1 := 4.80
## How far the corner return pulls in from the skin, clamped clear of the rear door edge.
const CORNER_RETURN_M := 0.12
## The rear door leaves swing at this |x|; the corner return must never sit inside it.
const REAR_DOOR_EDGE_X := 2.40

## Sill extent, matching the old box's span along z.
const SILL_Z0 := -4.72
const SILL_Z1 := 4.80

## Casing ring width around the side door opening.
const CASING_WIDTH_M := 0.07
## Casing outer face distance from the wall liner.
const CASING_PROUD_M := 0.19
## Casing inner face distance from the wall liner, so it seals behind the side skin.
const CASING_BACK_M := 0.04


func _init(hull: VanHull) -> void:
	_hull = hull


## Builds every patch for both sides of the van.
func build(walls: VanSideWall) -> void:
	for s: float in [-1.0, 1.0]:
		_build_rear_corner(walls, s)
		_build_sill(walls, s)
		_build_door_casing(walls, s)


## Strip that continues the side skin out to the rear face, plus the return face that closes it
## against the rear door post, so there is no gap between SideSkin and RearSkin.
func _build_rear_corner(walls: VanSideWall, s: float) -> void:
	var y_steps := 12

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Side strip: x tracks the skin and only varies with y, so cross(edge_y, edge_z) always has
	# a positive x-component; flip the winding for s < 0 so that side faces -X (outward) too.
	for iy in range(y_steps):
		var y0 := lerpf(-0.25, walls.wall_height, float(iy) / float(y_steps))
		var y1 := lerpf(-0.25, walls.wall_height, float(iy + 1) / float(y_steps))
		var x0 := s * (walls.wall_x_at(clampf(y0, 0.0, walls.wall_height)) + VanHull.SKIN_OFFSET_M)
		var x1 := s * (walls.wall_x_at(clampf(y1, 0.0, walls.wall_height)) + VanHull.SKIN_OFFSET_M)
		var p00 := Vector3(x0, y0, CORNER_Z0)
		var p01 := Vector3(x0, y0, CORNER_Z1)
		var p10 := Vector3(x1, y1, CORNER_Z0)
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

	# Return face at CORNER_Z1, from the rear door edge in to the skin. Winding mirrored between
	# sides so both faces come out +Z (outward), the same trick VanHull._build_rear uses for its
	# posts.
	for iy in range(y_steps):
		var y0 := lerpf(-0.25, walls.wall_height, float(iy) / float(y_steps))
		var y1 := lerpf(-0.25, walls.wall_height, float(iy + 1) / float(y_steps))
		var x_skin0 := walls.wall_x_at(clampf(y0, 0.0, walls.wall_height)) + VanHull.SKIN_OFFSET_M
		var x_skin1 := walls.wall_x_at(clampf(y1, 0.0, walls.wall_height)) + VanHull.SKIN_OFFSET_M
		var in0 := Vector3(s * maxf(REAR_DOOR_EDGE_X, x_skin0 - CORNER_RETURN_M), y0, CORNER_Z1)
		var out0 := Vector3(s * x_skin0, y0, CORNER_Z1)
		var in1 := Vector3(s * maxf(REAR_DOOR_EDGE_X, x_skin1 - CORNER_RETURN_M), y1, CORNER_Z1)
		var out1 := Vector3(s * x_skin1, y1, CORNER_Z1)
		if s > 0.0:
			st.add_vertex(in0)
			st.add_vertex(out0)
			st.add_vertex(in1)
			st.add_vertex(out0)
			st.add_vertex(out1)
			st.add_vertex(in1)
		else:
			st.add_vertex(in0)
			st.add_vertex(in1)
			st.add_vertex(out0)
			st.add_vertex(out0)
			st.add_vertex(in1)
			st.add_vertex(out1)

	st.generate_normals()
	_hull._add_mesh("RearCornerL" if s < 0.0 else "RearCornerR", st.commit())


## Rocker sill, an extruded chamfer-top/outer-face/bottom cross-section running the length of the
## body at the skin's floor position, replacing the old plain box.
func _build_sill(walls: VanSideWall, s: float) -> void:
	var xs: float = walls.wall_x_at(0.0) + VanHull.SKIN_OFFSET_M
	# Outer-to-inner ring: chamfer top, outer face, bottom.
	var section: Array[Vector2] = [
		Vector2(xs - 0.02, 0.04),
		Vector2(xs + 0.06, -0.02),
		Vector2(xs + 0.06, -0.25),
		Vector2(xs - 0.04, -0.25),
	]

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# The three running faces, wound outward the same way as the rear corner's side strip.
	for i in range(section.size() - 1):
		var a: Vector2 = section[i]
		var b: Vector2 = section[i + 1]
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


## Casing ring around the side door opening: a curved shell whose hole is exactly the opening,
## so it seals to the liner behind the skin and stands proud of it in front, without touching the
## door leaf's swept footprint.
func _build_door_casing(walls: VanSideWall, s: float) -> void:
	var mid_y := (walls.door_y_min + walls.door_y_max) * 0.5
	var x_ref := walls.wall_x_at(mid_y)
	var z_ref := walls.door_center_z
	var half_len := walls.door_half_length

	var mesh := walls.build_curved_shell_mesh(
		s,
		walls.door_y_min - CASING_WIDTH_M, walls.door_y_max + CASING_WIDTH_M,
		z_ref - half_len - CASING_WIDTH_M, z_ref + half_len + CASING_WIDTH_M,
		x_ref, mid_y, z_ref, CASING_PROUD_M - CASING_BACK_M,
		s * CASING_BACK_M, 28, 16,
		walls.door_y_min, walls.door_y_max, z_ref - half_len, z_ref + half_len
	)
	var pos := Vector3(s * x_ref, mid_y, z_ref)
	_hull._add_mesh("SideDoorCasingL" if s < 0.0 else "SideDoorCasingR", mesh, pos)
