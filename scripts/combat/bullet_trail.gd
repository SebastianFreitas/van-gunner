extends MeshInstance3D

const MAX_POINTS := 14

var _points: PackedVector3Array = PackedVector3Array()


func _ready() -> void:
	mesh = ImmediateMesh.new()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func add_point(world_position: Vector3) -> void:
	_points.append(world_position)
	if _points.size() > MAX_POINTS:
		_points = _points.slice(_points.size() - MAX_POINTS)
	_rebuild()


func _rebuild() -> void:
	var immediate := mesh as ImmediateMesh
	immediate.clear_surfaces()
	if _points.size() < 2:
		return
	immediate.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in _points.size():
		var t := float(i) / float(_points.size() - 1)
		immediate.surface_set_color(Color(1.0, 0.78, 0.22, lerpf(0.15, 1.0, t)))
		immediate.surface_add_vertex(to_local(_points[i]))
	immediate.surface_end()
