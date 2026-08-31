class_name BulletVisual
extends Node3D

## Cosmetic bullet mesh + trail locked to the logical Projectile.

const BULLET_VISUAL_SCALE := 0.28
const TRAIL_FADE_SECONDS := 0.45

var _velocity := Vector3.ZERO
var _muzzle_origin := Vector3.ZERO
var _travelled := 0.0
var _bullet_mesh: MeshInstance3D
var _trail_line: MeshInstance3D


func setup(
	origin: Vector3,
	velocity: Vector3,
	_gravity_scale: float,
	info: DamageInfo,
	stats: GunStats
) -> void:
	_muzzle_origin = origin
	_travelled = 0.0
	global_position = origin
	_velocity = velocity
	_ensure_nodes()
	_apply_size(stats.bullet_size)
	_apply_trail_color(info)
	if _trail_line and _trail_line.has_method("clear_points"):
		_trail_line.call("clear_points")
	if _bullet_mesh:
		_bullet_mesh.show()
	show()


func sync_to(position: Vector3, velocity: Vector3) -> void:
	_velocity = velocity
	var step := global_position.distance_to(position)
	_travelled += step
	global_position = position
	# Seed the trail at the muzzle once so it reads as leaving the gun.
	if _trail_line and _trail_line.has_method("add_point"):
		if _travelled <= step + 0.0001:
			_trail_line.call("add_point", _muzzle_origin)
		_trail_line.call("add_point", position)
	_orient_to_velocity()


func on_bounce(contact: Vector3, exit: Vector3, velocity: Vector3) -> void:
	_velocity = velocity
	global_position = exit
	if _trail_line and _trail_line.has_method("set_bounce_vertex"):
		_trail_line.call("set_bounce_vertex", contact, exit)
	_orient_to_velocity()


func fade_out() -> void:
	if _bullet_mesh:
		_bullet_mesh.hide()
	if _trail_line and _trail_line.has_method("detach_and_fade"):
		_trail_line.call("detach_and_fade", TRAIL_FADE_SECONDS)
		_trail_line = null
	queue_free()


func _ensure_nodes() -> void:
	if not _bullet_mesh:
		_bullet_mesh = MeshInstance3D.new()
		_bullet_mesh.name = &"BulletMesh"
		_bullet_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var sphere := SphereMesh.new()
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.92, 0.45, 1.0)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.72, 0.18, 1.0)
		mat.emission_energy_multiplier = 4.0
		sphere.material = mat
		_bullet_mesh.mesh = sphere
		add_child(_bullet_mesh)

	if not _trail_line:
		_trail_line = MeshInstance3D.new()
		_trail_line.name = &"TrailLine"
		_trail_line.set_script(preload("res://scripts/combat/bullet_trail.gd"))
		add_child(_trail_line)


func _apply_size(size: float) -> void:
	if _bullet_mesh and _bullet_mesh.mesh is SphereMesh:
		var visual_radius := size * BULLET_VISUAL_SCALE
		(_bullet_mesh.mesh as SphereMesh).radius = visual_radius
		(_bullet_mesh.mesh as SphereMesh).height = visual_radius * 2.0


func _apply_trail_color(info: DamageInfo) -> void:
	if not _trail_line:
		return
	var dmg_type := DamageType.Type.NORMAL
	if info:
		dmg_type = info.damage_type
	if _trail_line.has_method("set_trail_color"):
		_trail_line.call("set_trail_color", BulletTrail.color_for_damage_type(dmg_type))


func _orient_to_velocity() -> void:
	if _velocity.length_squared() < 0.001:
		return
	var forward := _velocity.normalized()
	var up := Vector3.UP if absf(forward.dot(Vector3.UP)) < 0.99 else Vector3.FORWARD
	look_at(global_position + forward, up)
