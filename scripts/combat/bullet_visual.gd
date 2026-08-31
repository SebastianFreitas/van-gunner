class_name BulletVisual
extends Node3D

## Cosmetic bullet mesh + trail. Starts at the gun muzzle and blends onto the
## logical projectile path so hits can come from the camera without the tracer
## teleporting sideways off the barrel.

const BULLET_VISUAL_SCALE := 0.28
const TRAIL_FADE_SECONDS := 0.45
## Softly blend from the muzzle-offset path onto the true path over this distance.
const CONVERGENCE_METERS := 4.0

var _velocity := Vector3.ZERO
var _muzzle_origin := Vector3.ZERO
var _logical_origin := Vector3.ZERO
var _travelled := 0.0
var _locked_to_logical := false
var _bullet_mesh: MeshInstance3D
var _trail_line: MeshInstance3D


func setup(
	origin: Vector3,
	velocity: Vector3,
	_gravity_scale: float,
	info: DamageInfo,
	stats: GunStats,
	logical_origin := origin
) -> void:
	_muzzle_origin = origin
	_logical_origin = logical_origin
	_travelled = 0.0
	_locked_to_logical = _muzzle_origin.is_equal_approx(_logical_origin)
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


func sync_to(logical_position: Vector3, velocity: Vector3) -> void:
	_velocity = velocity
	_travelled = _logical_origin.distance_to(logical_position)
	global_position = _blended_position(logical_position)
	_update_trail(global_position)
	_orient_to_velocity()


## Hard-lock onto the logical bullet (impact / end of life).
func snap_to(logical_position: Vector3, velocity: Vector3) -> void:
	_locked_to_logical = true
	_velocity = velocity
	global_position = logical_position
	_update_trail(logical_position)
	_orient_to_velocity()


func on_bounce(contact: Vector3, exit: Vector3, velocity: Vector3) -> void:
	_locked_to_logical = true
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


func _blended_position(logical_position: Vector3) -> Vector3:
	if _locked_to_logical:
		return logical_position
	var offset := _muzzle_origin - _logical_origin
	if offset.length_squared() < 0.0001:
		return logical_position
	var parallel := logical_position + offset
	var t := clampf(_travelled / CONVERGENCE_METERS, 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	return parallel.lerp(logical_position, t)


func _update_trail(world_position: Vector3) -> void:
	if not _trail_line or not _trail_line.has_method("add_point"):
		return
	# Seed the trail at the muzzle once so it reads as leaving the gun.
	if _travelled <= 0.001:
		_trail_line.call("add_point", _muzzle_origin)
	_trail_line.call("add_point", world_position)


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
