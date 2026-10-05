extends RefCounted
## Box emitter for RoadFloor: one box mesh plus its optional collision shape.


static func add_box(
	road: RoadFloor,
	host: Node3D,
	node_name: String,
	size: Vector3,
	pos: Vector3,
	material: Material,
	collide: bool,
	collision_body: StaticBody3D = null,
	visual := true
) -> void:
	if visual:
		var box := BoxMesh.new()
		box.size = size
		var mi := MeshInstance3D.new()
		mi.name = node_name
		mi.mesh = box
		mi.material_override = material
		mi.position = pos
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		host.add_child(mi)

	var body := collision_body
	if body == null and collide and road.include_collision:
		body = host.get_node_or_null("CornerSurfaces") as StaticBody3D
		if body == null:
			body = StaticBody3D.new()
			body.name = "CornerSurfaces"
			host.add_child(body)

	if collide and road.include_collision and body:
		var col := CollisionShape3D.new()
		col.name = "%sCollision" % node_name
		var shape := BoxShape3D.new()
		shape.size = size
		col.shape = shape
		col.position = pos
		body.add_child(col)
