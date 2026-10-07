extends RefCounted
## VanHull's front face: the roof-step strip, its corners, and the fill with its band that closes
## the box's front behind the bolted-on cab.

const _HullPatches := preload("res://scripts/van/look/van_hull_patches.gd")

var _hull: VanHull


func _init(hull: VanHull) -> void:
	_hull = hull


## The front face closes the whole front of the box at the side skin's front returns' z: the strip
## over the roof step between the skin (0.22 m off the liner) and the cab skin (0.12 m off), whose
## inner edge lies on the cab outline's top and outer edge on the roof curve, a quad per corner
## down to the returns' top edge (y = wall height), and a fill that stands 2.5 cm before the
## interior front wall's cab-side face (z -4.75) and before the floor deck's front face, 2.5 cm
## outside the wall's outline, with a band along its sides and top back to the returns at `z`,
## because the bolted-on truck cab (x +-1.95, roof 3.05) no longer covers the slab.
func build(walls: VanSideWall) -> void:
	var z := VanInteriorSize.FRONT_Z
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# The fill: stands in front of the interior front wall's slab (so it never shows) and closes
	# its sides and top back to the returns, since the bolted-on cab is smaller than the box.
	# In front of the floor deck's front face too (below), so the deck never shows.
	var g := VanHull.FRONT_FILL_GAP_M
	var zf := minf(VanFrontWall.BACK_Z, z) - g
	var h: float = walls.wall_height
	var rows := 12
	# The fill's foot is at least as wide as the floor deck, whose front corners would otherwise
	# poke 3 mm past the band below the sills' start (the audit's LEAK_OUT at the front corners).
	var x0: float = _hull._profile.outer_x_at(0.0)
	var floor_node := walls.get_parent().get_node_or_null(^"Floor") as VanFloor
	if floor_node != null:
		x0 = maxf(x0, floor_node.span_x * 0.5)
		# The deck runs past the side walls' front returns, so the fill stands before it too.
		zf = minf(zf, floor_node.center_z - floor_node.span_z * 0.5 - g)
	var pts := PackedVector2Array()
	pts.append(Vector2(x0 + g, VanCab.BASE_Y))
	pts.append(Vector2(x0 + g, 0.0))
	for i in range(1, rows + 1):
		var y := h * float(i) / float(rows)
		pts.append(Vector2(_hull._profile.outer_x_at(y) + g, y))
	# Up the roof corner arc, across the crown and down the other arc: the roof's front edge.
	var outline := _hull._upper_outline()
	for k in range(1, outline.size() - 1):
		pts.append(Vector2(outline[k].x + signf(outline[k].x) * g, outline[k].y + g))
	for i in range(rows, 0, -1):
		var y := h * float(i) / float(rows)
		pts.append(Vector2(-(_hull._profile.outer_x_at(y) + g), y))
	pts.append(Vector2(-(x0 + g), 0.0))
	pts.append(Vector2(-(x0 + g), VanCab.BASE_Y))
	var c := Vector2.ZERO
	for p: Vector2 in pts:
		c += p
	c /= float(pts.size())
	for k in range(pts.size()):
		var p := pts[k]
		var q := pts[(k + 1) % pts.size()]
		_hull._rear_tri(st, Vector3(c.x, c.y, zf), Vector3(p.x, p.y, zf), Vector3(q.x, q.y, zf),
				Vector3.FORWARD)
	# The band: from the fill back to the returns along the sides and top (not the open bottom).
	for k in range(pts.size() - 1):
		var p := pts[k]
		var q := pts[k + 1]
		var e := q - p
		var nrm := Vector2(e.y, -e.x)
		if nrm.dot((p + q) * 0.5 - c) < 0.0:
			nrm = -nrm
		var out := Vector3(nrm.x, nrm.y, 0.0).normalized()
		var pf := Vector3(p.x, p.y, zf)
		var qf := Vector3(q.x, q.y, zf)
		# The foot (below the deck top) runs back past the sills' start, closing the deck's side
		# faces at the front corners, which nothing else covers between the returns and the sills.
		# It overlaps 10 cm past the sill's front cap: the foot stands 3.5 cm inside the sill's
		# inner face, and a ray slanting in just before the cap otherwise slips through that slot.
		var zb := _HullPatches.SILL_Z0 + 0.1 if p.y <= 0.0 and q.y <= 0.0 else z
		var qb := Vector3(q.x, q.y, zb)
		var pb := Vector3(p.x, p.y, zb)
		_hull._rear_tri(st, pf, qf, qb, out)
		_hull._rear_tri(st, pf, qb, pb, out)

	# Cap over the roof's front edge: RoofSkin ends at z, g behind the fill's band, so a thin strip
	# at z joins the roof edge along the whole upper outline to the band's outer edge.
	var cap_in := PackedVector2Array()
	var cap_out := PackedVector2Array()
	for k in range(outline.size()):
		var o := outline[k]
		var ends := k == 0 or k == outline.size() - 1
		cap_in.append(o)
		cap_out.append(Vector2(o.x + signf(o.x) * g, o.y + (0.0 if ends else g)))
	for k in range(outline.size() - 1):
		var ia := Vector3(cap_in[k].x, cap_in[k].y, z)
		var ib := Vector3(cap_in[k + 1].x, cap_in[k + 1].y, z)
		var oa := Vector3(cap_out[k].x, cap_out[k].y, z)
		var ob := Vector3(cap_out[k + 1].x, cap_out[k + 1].y, z)
		_hull._rear_tri(st, ia, ib, oa, Vector3.FORWARD)
		_hull._rear_tri(st, ib, ob, oa, Vector3.FORWARD)

	# Cap over each side skin's front end, from the band out to the skin's outer face, in the skin's
	# own end plane: a ray slanting past the front corner otherwise slips between band and skin
	# (a cap 1 cm before the end let shallow rays through on the right).
	for side: float in [-1.0, 1.0]:
		for i in range(rows):
			var ya := h * float(i) / float(rows)
			var yb := h * float(i + 1) / float(rows)
			var ia: float = _hull._profile.outer_x_at(ya)
			var ib: float = _hull._profile.outer_x_at(yb)
			var oa: float = ia + 0.012
			var ob: float = ib + 0.012
			var zc := z
			_hull._rear_tri(st, Vector3(side * ia, ya, zc), Vector3(side * oa, ya, zc),
					Vector3(side * ib, yb, zc), Vector3.FORWARD)
			_hull._rear_tri(st, Vector3(side * oa, ya, zc), Vector3(side * ob, yb, zc),
					Vector3(side * ib, yb, zc), Vector3.FORWARD)

	st.generate_normals()
	# No tangents: the exterior shader projects in model space and these meshes carry no UVs.
	_hull._add_mesh("FrontSkin", st.commit())
