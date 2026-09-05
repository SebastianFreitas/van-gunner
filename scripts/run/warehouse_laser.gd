class_name WarehouseLaser
extends Node3D

## Waist-high trip across the aisle. Jump over to stay quiet; walking through
## or shooting an emitter springs the hide.

signal sprung

var _fired := false
var _beam: Area3D
var _beam_mesh: MeshInstance3D


func setup(length: float) -> void:
	var beam_size := Vector3(0.12, 0.18, length)
	_beam_mesh = WarehouseLook.add_box(
		self, "Beam", beam_size, Vector3(0.0, 0.85, 0.0), WarehouseLook.laser_material()
	)

	_beam = Area3D.new()
	_beam.name = "Trip"
	_beam.collision_layer = 0
	_beam.collision_mask = 1
	_beam.monitoring = true
	_beam.monitorable = false
	add_child(_beam)
	WarehouseLook.add_collision(_beam, beam_size, Vector3(0.0, 0.85, 0.0))
	_beam.body_entered.connect(_on_body_entered)

	_add_emitter(Vector3(0.0, 0.85, length * 0.5 + 0.08))
	_add_emitter(Vector3(0.0, 0.85, -length * 0.5 - 0.08))


func is_fired() -> bool:
	return _fired


func trigger() -> void:
	if _fired:
		return
	_fired = true
	if _beam:
		_beam.monitoring = false
		_beam.collision_mask = 0
	if _beam_mesh:
		_beam_mesh.hide()
	AudioDirector.play_at(&"breach", self)
	sprung.emit()


func take_damage(_amount = null) -> void:
	trigger()


func _add_emitter(pos: Vector3) -> void:
	var steel := WarehouseLook.steel_material()
	WarehouseLook.add_box(self, "Post", Vector3(0.12, 1.05, 0.12), pos + Vector3(0.0, -0.32, 0.0), steel)
	var hit := Area3D.new()
	hit.name = "EmitterHit"
	hit.collision_layer = 4
	hit.collision_mask = 0
	hit.monitoring = false
	hit.monitorable = true
	hit.position = pos
	add_child(hit)
	WarehouseLook.add_collision(hit, Vector3(0.22, 0.28, 0.22), Vector3.ZERO)


func _on_body_entered(body: Node) -> void:
	if body != null and body.is_in_group(&"player"):
		trigger()
