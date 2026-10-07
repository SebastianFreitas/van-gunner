class_name SideWindowFit
extends RefCounted
## Fits one side window root to the bowed wall; safe to re-run (clears what an earlier fit made).

const _Exterior := preload("res://scripts/van/side_window_exterior.gd")
const _Fixtures := preload("res://scripts/van/side_window_fixtures.gd")

const META_FRAME_MAT := &"fit_frame_material"
const META_GLASS_MAT := &"fit_glass_material"
## Today's IronCross extents (its exported defaults) and the hole's margins, metres.
const IRON_FRAME_HALF := Vector2(1.202, 0.687)
const IRON_CLEAR_HALF := Vector2(1.125, 0.642)
const HOLE_GROW_M := 0.04
const GLASS_INSET_Z := 0.102
const GLASS_INSET_Y := 0.07
const PANE_GROW_M := 0.02
const STOP_OUT_M := 0.06
const STOP_IN_M := 0.03

var _o: Node3D

func _init(owner: Node3D) -> void:
	_o = owner


## `hole` is this window's wall hole (window-local metres, opening + 2 cm); with it the frame,
## glass, pane, bars, collision and cut are sized to it. An empty hole is a caller bug.
## `glazing` is the rolled pane type; empty keeps the kept material.
func fit(root: Node3D, wall_sign: float, z_center: float, walls: VanSideWall,
		hole: PackedVector2Array = PackedVector2Array(), glazing: StringName = &"") -> void:
	if root == null:
		return
	if hole.is_empty():
		push_error("SideWindowFit.fit: empty hole")
		return
	var cut := root.get_node_or_null("WallPanel/WindowCut") as CSGPolygon3D
	var refit := root.has_meta(META_FRAME_MAT)
	var frame_poly: PackedVector2Array = _o.FRAME_OUTER_POLY
	var glass_poly: PackedVector2Array = _o.GLASS_POLY
	var pane_poly: PackedVector2Array = _o.PANE_POLY
	var frame_half := IRON_FRAME_HALF
	var clear_half := IRON_CLEAR_HALF
	var glass_size := Vector2.ZERO
	var stop_outer: PackedVector2Array = _Fixtures.STOP_OUTER_POLY
	var stop_inner: PackedVector2Array = _Fixtures.STOP_INNER_POLY
	var ring := hole.duplicate()
	if Geometry2D.is_polygon_clockwise(ring) != Geometry2D.is_polygon_clockwise(frame_poly):
		ring.reverse()
	var grown := _grow(ring, -HOLE_GROW_M)
	if not grown.is_empty():
		frame_poly = grown
		# The stop ring keeps its margins on the hole: 4 cm past it (D53), 3 cm over the frame.
		stop_outer = _grow(frame_poly, HOLE_GROW_M + STOP_OUT_M - 0.02)
		stop_inner = _grow(frame_poly, -STOP_IN_M)
		var box := _bounds(frame_poly)
		var half := box.size * 0.5
		var mid := box.get_center()
		glass_poly = PackedVector2Array()
		for p in frame_poly:
			glass_poly.append(Vector2(
				mid.x + (p.x - mid.x) * (half.x - GLASS_INSET_Z) / half.x,
				mid.y + (p.y - mid.y) * (half.y - GLASS_INSET_Y) / half.y
			))
		pane_poly = _grow(glass_poly, PANE_GROW_M)
		var ratio := half / IRON_FRAME_HALF
		frame_half = half
		clear_half = IRON_CLEAR_HALF * ratio
		glass_size = _bounds(glass_poly).size
		if cut:
			cut.polygon = hole

	var sash_half_h: float = _o.SASH_HALF_H
	var bump: float = _o.glass_outward_bump
	var mid_y := walls.window_center_y
	var y_hinge := mid_y + sash_half_h
	var x_ref := walls.wall_x_at(y_hinge)
	root.rotation = Vector3.ZERO
	root.position = Vector3(wall_sign * x_ref, y_hinge, z_center)

	var hinge := root.get_node_or_null("Hinge") as Node3D
	if hinge == null:
		return

	# Steal once: the scene's own materials, kept on the root for every later fit.
	if not root.has_meta(META_FRAME_MAT):
		root.set_meta(META_FRAME_MAT, _steal_material(hinge, "WindowFrame/Outer"))
		var stolen := _steal_material(hinge, "WindowGlass")
		# Single-sided (facing the cabin): drop the duplicate backface triangles.
		if stolen is BaseMaterial3D:
			stolen = (stolen as BaseMaterial3D).duplicate() as BaseMaterial3D
			(stolen as BaseMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
		root.set_meta(META_GLASS_MAT, stolen)

	# Undo an earlier fit: its generated parts go, the other children return to the unshifted pivot.
	_free_node(hinge, "CurvedFrame")
	_free_node(hinge, "WindowGlass")
	_free_node(root, "WindowStop")
	_free_node(root, "HingeRail")
	for strap in hinge.find_children("StrapHinge*", "Node3D", false, false):
		strap.free()
	if refit:
		for child in hinge.get_children():
			if child is Node3D:
				(child as Node3D).position += hinge.position
		hinge.position = Vector3.ZERO
		hinge.rotation = Vector3.ZERO

	var frame_mat := root.get_meta(META_FRAME_MAT) as Material
	var glass_mat := VanGlazing.material(root.get_meta(META_GLASS_MAT) as Material, glazing)

	_hide_node(root, "WallPanel")
	_hide_node(hinge, "WindowFrame")
	_free_node(root, "CurvedBezel")

	# No separate bezel — VanSideWall punches the rounded WindowCut so the liner
	# itself is the surround (same as the rear door leaf around its pane).

	var glass_inset: float = _o.GLASS_INSET
	var glass_x := wall_sign * (bump - glass_inset)
	var breakable_inset: float = _o.BREAKABLE_INSET - bump

	var frame := MeshInstance3D.new()
	frame.name = "CurvedFrame"
	frame.mesh = walls.build_curved_frame_ring_mesh(
		wall_sign, frame_poly, glass_poly,
		x_ref, y_hinge, z_center, mid_y, _o.FRAME_THICKNESS, 0.0, VanSideWall.WINDOW_EDGE_SUBDIV
	)
	frame.material_override = frame_mat
	frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	frame.layers = VanLighting.LAYER_STREET_AND_INTERIOR
	frame.add_to_group(VanLighting.GROUP_EXTERIOR_LAYER)
	hinge.add_child(frame)
	_Fixtures.add_stop(root, walls, wall_sign, x_ref, y_hinge, z_center, mid_y, frame_mat,
		stop_outer, stop_inner)

	var glass := MeshInstance3D.new()
	glass.name = "WindowGlass"
	glass.mesh = walls.build_curved_pane_from_poly(
		wall_sign, pane_poly, x_ref, y_hinge, z_center, mid_y, glass_x, VanSideWall.WINDOW_EDGE_SUBDIV, false
	)
	glass.material_override = glass_mat
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glass.layers = VanLighting.LAYER_STREET_AND_INTERIOR
	glass.add_to_group(VanLighting.GROUP_EXTERIOR_LAYER)
	hinge.add_child(glass)

	_Exterior.add_exterior_pane(
		glass, walls, wall_sign, pane_poly, x_ref, y_hinge, z_center, mid_y,
		wall_sign * _o.EXTERIOR_PANE_PROUD_M
	)

	var col := root.get_node_or_null("Hinge/BreakableGlass/Collision") as CollisionShape3D
	var breakable := hinge.get_node_or_null("BreakableGlass")
	if col and glass_size != Vector2.ZERO:
		var box := (col.shape as BoxShape3D).duplicate() as BoxShape3D
		box.size = Vector3(box.size.x, glass_size.y, glass_size.x)
		col.shape = box
	if breakable and breakable.has_method("bind_glass_visual"):
		breakable.bind_glass_visual(glass)
		# A shattered window stays shattered across a refit: the new pane starts hidden.
		if breakable.has_method("is_intact") and not breakable.is_intact():
			glass.visible = false

	var iron_cross := hinge.get_node_or_null("IronCross") as IronCross
	if iron_cross and (iron_cross.frame_half != frame_half or iron_cross.clear_half != clear_half):
		iron_cross.frame_half = frame_half
		iron_cross.clear_half = clear_half
		# Free now, not queue_free, so the rebuilt bars keep their real names.
		for old in iron_cross.get_children():
			iron_cross.remove_child(old)
			old.free()
		iron_cross.rebuild()
	# A breached window shows the stub set, which copied the old extents: rebuild it to the hole.
	var broken_cross := hinge.get_node_or_null("BrokenIronCross") as BrokenIronCross
	if broken_cross and (broken_cross.frame_half != frame_half
			or broken_cross.clear_half != clear_half):
		broken_cross.frame_half = frame_half
		broken_cross.clear_half = clear_half
		for old in broken_cross.get_children():
			broken_cross.remove_child(old)
			old.free()
		broken_cross.follow_side_wall_curve(walls, mid_y)
	_place_on_curve(iron_cross, walls, wall_sign, x_ref, y_hinge, mid_y, 0.0, _o.IRON_INSET - bump)
	if iron_cross:
		iron_cross.set_street_lit(true)
		iron_cross.follow_side_wall_curve(walls, mid_y)
	_place_on_curve(breakable as Node3D, walls, wall_sign, x_ref, y_hinge, mid_y, 0.0, breakable_inset)
	_place_on_curve(hinge.get_node_or_null("Interact") as Node3D, walls, wall_sign, x_ref, y_hinge, mid_y, 0.0, 0.0)

	var handle := hinge.get_node_or_null("Handle") as Node3D
	if handle:
		_place_on_curve(handle, walls, wall_sign, x_ref, y_hinge, mid_y - 0.52, -0.95, 0.08)

	# Move the pivot outboard of every part so the tipping sash never rises through the wall;
	# children shift the other way, so the closed pose is unchanged.
	var hinge_out: float = _o.HINGE_OUT_M
	var pivot := Vector3(wall_sign * hinge_out, 0.0, 0.0)
	hinge.position = pivot
	for child in hinge.get_children():
		if child is Node3D:
			(child as Node3D).position -= pivot
	_Fixtures.add_hinges(root, hinge, walls, wall_sign, x_ref, y_hinge, hinge_out,
		hole, sash_half_h)


## Mitred offset of a poly by delta (positive = outward) that keeps every vertex's index, which
## the ring builders pair between an outer and an inner poly; Clipper reorders vertices.
func _grow(poly: PackedVector2Array, delta: float) -> PackedVector2Array:
	var n := poly.size()
	var area := 0.0
	for i in n:
		area += poly[i].cross(poly[(i + 1) % n])
	var out_sign := 1.0 if area > 0.0 else -1.0
	var out := PackedVector2Array()
	for i in n:
		var e0 := (poly[i] - poly[(i + n - 1) % n]).normalized()
		var e1 := (poly[(i + 1) % n] - poly[i]).normalized()
		var n0 := Vector2(e0.y, -e0.x) * out_sign
		var n1 := Vector2(e1.y, -e1.x) * out_sign
		out.append(poly[i] + (n0 + n1) / (1.0 + n0.dot(n1)) * delta)
	return out


func _bounds(poly: PackedVector2Array) -> Rect2:
	var r := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		r = r.expand(p)
	return r


func _place_on_curve(
	node: Node3D, walls: VanSideWall, wall_sign: float, x_ref: float, y_ref: float,
	world_y: float, local_z: float, into_cabin: float
) -> void:
	if node == null:
		return
	var node_basis := node.transform.basis
	var local_x := walls.local_x_on_wall(wall_sign, world_y, x_ref) - wall_sign * into_cabin
	node.transform = Transform3D(node_basis, Vector3(local_x, world_y - y_ref, local_z))


func _hide_node(parent: Node, path: String) -> void:
	var node := parent.get_node_or_null(path) as Node3D
	if node:
		node.visible = false


func _free_node(parent: Node, path: String) -> void:
	var node := parent.get_node_or_null(path)
	if node:
		node.free()


func _steal_material(parent: Node, path: String) -> Material:
	var node := parent.get_node_or_null(path)
	if node == null:
		return null
	if node is GeometryInstance3D and (node as GeometryInstance3D).material_override:
		return (node as GeometryInstance3D).material_override
	if node.get("material") != null:
		return node.get("material") as Material
	return null
