class_name WarehouseHide
extends Node3D

## One ambush pocket. `trigger()` is idempotent — shooting, walking a volume,
## or the chest can all fire it.

signal triggered

enum Reveal { BURST, FALL, PEEL }

var dummy_count := 1
var dummy_offsets: Array[Vector3] = []
var drop_from_ceiling := false
var reveal := Reveal.BURST

var _fired := false
var _cover: Node3D
var _solid: StaticBody3D
var _hit: Area3D


func configure_cover(
	size: Vector3,
	material: Material,
	solid: bool = true,
	hit_layer: bool = true
) -> void:
	_cover = Node3D.new()
	_cover.name = "Cover"
	add_child(_cover)
	WarehouseLook.add_box(_cover, "Mesh", size, Vector3(0.0, size.y * 0.5, 0.0), material)
	if solid:
		_solid = StaticBody3D.new()
		_solid.name = "Solid"
		_solid.collision_layer = 1
		_solid.collision_mask = 0
		add_child(_solid)
		WarehouseLook.add_collision(_solid, size, Vector3(0.0, size.y * 0.5, 0.0))
	if hit_layer:
		_hit = Area3D.new()
		_hit.name = "Hit"
		_hit.collision_layer = 4
		_hit.collision_mask = 0
		_hit.monitoring = false
		_hit.monitorable = true
		add_child(_hit)
		WarehouseLook.add_collision(_hit, size, Vector3(0.0, size.y * 0.5, 0.0))


func add_rope(size: Vector3, pos: Vector3, material: Material) -> void:
	if _cover == null:
		return
	WarehouseLook.add_box(_cover, "Rope", size, pos, material)


func add_walk_trigger(size: Vector3, pos: Vector3) -> void:
	var zone := Area3D.new()
	zone.name = "WalkTrigger"
	zone.collision_layer = 0
	zone.collision_mask = 1
	zone.monitoring = true
	zone.monitorable = false
	zone.position = pos
	add_child(zone)
	WarehouseLook.add_collision(zone, size, Vector3.ZERO)
	zone.body_entered.connect(_on_walk_body)


func take_damage(_amount = null) -> void:
	trigger()


func is_fired() -> bool:
	return _fired


func trigger() -> void:
	if _fired:
		return
	_fired = true
	_disable_collision()
	_play_reveal()
	_spawn_dummies()
	AudioDirector.play_at(&"breach", self)
	triggered.emit()


func _on_walk_body(body: Node) -> void:
	if body != null and body.is_in_group(&"player"):
		trigger()


func _disable_collision() -> void:
	if _solid:
		_solid.collision_layer = 0
		for child in _solid.get_children():
			if child is CollisionShape3D:
				(child as CollisionShape3D).set_deferred(&"disabled", true)
	if _hit:
		_hit.collision_layer = 0
		_hit.monitorable = false


func _play_reveal() -> void:
	if _cover == null:
		return
	var tween := create_tween()
	tween.set_parallel(true)
	match reveal:
		Reveal.FALL:
			tween.tween_property(_cover, "position:y", _cover.position.y - 7.4, 0.4).set_trans(
				Tween.TRANS_QUAD
			).set_ease(Tween.EASE_IN)
			tween.tween_property(_cover, "rotation:z", 0.55, 0.4)
			tween.chain().tween_callback(_hide_cover)
		Reveal.PEEL:
			tween.tween_property(_cover, "rotation:x", 1.2, 0.28).set_trans(Tween.TRANS_BACK)
			tween.tween_property(_cover, "position:y", _cover.position.y + 0.4, 0.28)
			tween.chain().tween_callback(_hide_cover)
		_:
			tween.tween_property(_cover, "scale", Vector3(1.15, 0.15, 1.15), 0.22)
			tween.tween_property(_cover, "position:y", _cover.position.y + 0.2, 0.22)
			tween.chain().tween_callback(_hide_cover)


func _hide_cover() -> void:
	if is_instance_valid(_cover):
		_cover.hide()


func _spawn_dummies() -> void:
	var offsets := dummy_offsets
	if offsets.is_empty():
		for i in dummy_count:
			var side := -0.45 if i % 2 == 0 else 0.45
			offsets.append(Vector3(side * float(i / 2), 0.0, side * float((i + 1) / 2)))
	var host := get_parent()
	if host == null:
		host = self
	for offset in offsets:
		var dummy := WarehouseDummy.new()
		host.add_child(dummy)
		var dest := to_global(offset)
		if drop_from_ceiling:
			dummy.global_position = dest + Vector3(0.0, 6.2, 0.0)
			dummy.drop_to(dest)
		else:
			dummy.global_position = dest
