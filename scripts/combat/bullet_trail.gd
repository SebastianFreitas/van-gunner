class_name BulletTrail
extends MeshInstance3D

const MAX_POINTS := 28
const FADE_SECONDS := 0.45

var _points: PackedVector3Array = PackedVector3Array()
var _fade_alpha := 1.0
var _base_color := Color(1.0, 0.86, 0.28, 1.0)


static func color_for_damage_type(type: DamageType.Type) -> Color:
	match type:
		DamageType.Type.POISON:
			return Color(0.45, 0.95, 0.35, 1.0)
		DamageType.Type.FIRE:
			return Color(1.0, 0.28, 0.12, 1.0)
		DamageType.Type.COLD:
			return Color(0.55, 0.82, 1.0, 1.0)
		DamageType.Type.LIGHTNING:
			return Color(0.82, 0.72, 1.0, 1.0)
		DamageType.Type.EXPLOSIVE:
			return Color(1.0, 0.55, 0.22, 1.0)
		_:
			return Color(1.0, 0.86, 0.28, 1.0)


func set_trail_color(color: Color) -> void:
	_base_color = color
	_rebuild()


func _ready() -> void:
	mesh = ImmediateMesh.new()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.disable_receive_shadows = true
	material_override = mat


func clear_points() -> void:
	_points = PackedVector3Array()
	_fade_alpha = 1.0
	var immediate := mesh as ImmediateMesh
	if immediate:
		immediate.clear_surfaces()


func add_point(world_position: Vector3) -> void:
	_points.append(world_position)
	if _points.size() > MAX_POINTS:
		_points = _points.slice(_points.size() - MAX_POINTS)
	_rebuild()


## Reparent into the live scene and fade out instead of vanishing with the bullet.
func detach_and_fade(fade_seconds := FADE_SECONDS) -> void:
	if _points.size() < 2:
		return
	var scene := get_tree().current_scene
	if not scene or not get_parent():
		return
	var world_xform := global_transform
	get_parent().remove_child(self)
	scene.add_child(self)
	global_transform = world_xform
	_fade_alpha = 1.0
	_rebuild()
	var tween := create_tween()
	tween.tween_method(_set_fade_alpha, 1.0, 0.0, fade_seconds)
	tween.tween_callback(queue_free)


func _set_fade_alpha(alpha: float) -> void:
	_fade_alpha = alpha
	_rebuild()


func _rebuild() -> void:
	var immediate := mesh as ImmediateMesh
	immediate.clear_surfaces()
	if _points.size() < 2:
		return
	immediate.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in _points.size():
		var t := float(i) / float(_points.size() - 1)
		var color := _base_color
		color.a = lerpf(0.15, 1.0, t) * _fade_alpha
		immediate.surface_set_color(color)
		immediate.surface_add_vertex(to_local(_points[i]))
	immediate.surface_end()
