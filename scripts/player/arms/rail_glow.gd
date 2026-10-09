class_name RailGlow
extends Node3D
## The railgun's own light: the charge strip and capacitor lamps glow and flare on every shot.

const IDLE_STRIP := 0.5
const IDLE_LAMP := 0.9
const IDLE_LIGHT := 0.3
const IDLE_LAMP_LIGHT := 0.12
const FLARE_LAMP_LIGHT := 1.6
const FLARE_STRIP := 3.0
const FLARE_LAMP := 2.4
const FLARE_LIGHT := 2.5
## World metres: the rig is 0.18-scaled, so the light lives under the unscaled Weapon.
const LIGHT_RANGE := 0.45
## The lamp bank's own small pool, so the receiver's rear face and what sits on it is lit.
const LAMP_LIGHT_RANGE := 0.35
## Rig units above the strip's centre, so the pool washes the rail tops.
const LIGHT_LIFT := 0.1

var _light: OmniLight3D
var _lamp_light: OmniLight3D
var _lamps: Array[MeshInstance3D] = []
var _strip: MeshInstance3D
var _strip_mat: StandardMaterial3D
var _lamp_mats: Array[StandardMaterial3D] = []
var _tween: Tween
var _lamp_tween: Tween


func _ready() -> void:
	name = "RailGlow"
	_light = OmniLight3D.new()
	_light.name = "GlowLight"
	_light.light_color = Color(1.0, 0.5, 0.15)
	_light.light_energy = IDLE_LIGHT
	_light.omni_range = LIGHT_RANGE
	_light.shadow_enabled = false
	add_child(_light)
	_lamp_light = OmniLight3D.new()
	_lamp_light.name = "LampLight"
	_lamp_light.light_color = Color(1.0, 0.6, 0.2)
	_lamp_light.light_energy = IDLE_LAMP_LIGHT
	_lamp_light.omni_range = LAMP_LIGHT_RANGE
	_lamp_light.shadow_enabled = false
	add_child(_lamp_light)
	_bind.call_deferred()


func _exit_tree() -> void:
	if _light != null and is_instance_valid(_light):
		_light.queue_free()
	if _lamp_light != null and is_instance_valid(_lamp_light):
		_lamp_light.queue_free()


func _process(_delta: float) -> void:
	if _strip == null or not is_instance_valid(_light):
		return
	var host := _light.get_parent() as Node3D
	var at := _strip.global_transform * Vector3(0.0, LIGHT_LIFT, 0.0)
	_light.position = host.global_transform.affine_inverse() * at
	if _lamps.is_empty():
		return
	var mid := Vector3.ZERO
	for lamp: MeshInstance3D in _lamps:
		mid += lamp.global_position / float(_lamps.size())
	_lamp_light.position = host.global_transform.affine_inverse() * mid


## Finds the parts once the rig is built and listens for shots.
func _bind() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var weapon: Node = self
	while weapon != null and weapon.name != &"Weapon":
		weapon = weapon.get_parent()
	if weapon != null:
		_light.reparent(weapon, false)
		_lamp_light.reparent(weapon, false)
	_strip = parent.get_node_or_null("ChargeStrip") as MeshInstance3D
	if _strip != null:
		_strip_mat = _own_material(_strip)
		_strip_mat.emission_energy_multiplier = IDLE_STRIP
	for n: int in range(4):
		var lamp := parent.get_node_or_null("Lamp%d" % n) as MeshInstance3D
		if lamp != null:
			var mat := _own_material(lamp)
			mat.emission_energy_multiplier = IDLE_LAMP
			_lamp_mats.append(mat)
			_lamps.append(lamp)
	var gun := get_tree().get_first_node_in_group(&"gun_controller")
	if gun != null and gun.has_signal(&"shot"):
		gun.connect(&"shot", _on_shot)


func _own_material(mi: MeshInstance3D) -> StandardMaterial3D:
	var mat := (mi.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
	mi.material_override = mat
	return mat


func _on_shot() -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_light, "light_energy", FLARE_LIGHT, 0.03)
	_tween.tween_property(_lamp_light, "light_energy", FLARE_LAMP_LIGHT, 0.03)
	if _strip_mat != null:
		_tween.tween_property(_strip_mat, "emission_energy_multiplier", FLARE_STRIP, 0.03)
	_tween.chain().set_parallel(true)
	_tween.tween_property(_light, "light_energy", IDLE_LIGHT, 0.4) 			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_tween.tween_property(_lamp_light, "light_energy", IDLE_LAMP_LIGHT, 0.4)
	if _strip_mat != null:
		_tween.tween_property(_strip_mat, "emission_energy_multiplier", IDLE_STRIP, 0.4) 				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	# The lamps flicker once (up, back to idle, up, settle) and never sag below idle.
	if _lamp_tween != null:
		_lamp_tween.kill()
	_lamp_tween = create_tween()
	_lamp_tween.set_parallel(true)
	for mat: StandardMaterial3D in _lamp_mats:
		_lamp_tween.tween_property(mat, "emission_energy_multiplier", FLARE_LAMP, 0.03)
	_lamp_tween.chain().set_parallel(true)
	for mat: StandardMaterial3D in _lamp_mats:
		_lamp_tween.tween_property(mat, "emission_energy_multiplier", IDLE_LAMP, 0.06)
	_lamp_tween.chain().set_parallel(true)
	for mat: StandardMaterial3D in _lamp_mats:
		_lamp_tween.tween_property(mat, "emission_energy_multiplier", FLARE_LAMP - 0.4, 0.03)
	_lamp_tween.chain().set_parallel(true)
	for mat: StandardMaterial3D in _lamp_mats:
		_lamp_tween.tween_property(mat, "emission_energy_multiplier", IDLE_LAMP, 0.3) 				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
