extends Node

## Teleports shot/swept pickups onto the van's center table. Effects are
## applied only when the player walks into the pickup — not on landing.

const STAGGER_DELAY := 0.12
const POP_IN_DURATION := 0.18
const LAND_RADIUS := 0.28
const LAND_RADIUS_STEP := 0.18

var _anchor: Node3D
var _queue: Array[Node3D] = []
var _landed: Array[Node3D] = []
var _draining := false


func _ready() -> void:
	GameSession.phase_changed.connect(_on_phase_changed)


func set_collection_anchor(anchor: Node3D) -> void:
	_anchor = anchor


func collect(pickup: Node3D) -> void:
	if not is_instance_valid(pickup) or pickup in _queue or pickup in _landed:
		return
	_queue.append(pickup)
	if not _draining:
		_drain_queue()


func unregister(pickup: Node3D) -> void:
	_landed.erase(pickup)


func _on_phase_changed(next_phase: GameSession.RunPhase) -> void:
	if next_phase == GameSession.RunPhase.REST or next_phase == GameSession.RunPhase.ROUTE_CHOICE:
		for node in get_tree().get_nodes_in_group(&"pickup"):
			var pickup := node as Pickup
			if pickup and not pickup._stashed and not pickup._used:
				pickup.force_collect()


func _drain_queue() -> void:
	_draining = true
	while not _queue.is_empty():
		var pickup: Node3D = _queue.pop_front()
		if is_instance_valid(pickup):
			_land(pickup)
		if not _queue.is_empty():
			await get_tree().create_timer(STAGGER_DELAY).timeout
	_draining = false


func _land(pickup: Node3D) -> void:
	if not is_instance_valid(_anchor):
		_on_landed(pickup, _landed.size())
		return
	var land_index := _landed.size()
	_landed.append(pickup)
	pickup.reparent(_anchor, false)
	pickup.position = _landing_offset(land_index)
	pickup.rotation = Vector3.ZERO
	_pop_in(pickup)
	_on_landed(pickup, land_index)


## Golden-angle spiral so new drops spread out instead of stacking.
func _landing_offset(index: int) -> Vector3:
	var angle := float(index) * 2.3999632
	var radius := LAND_RADIUS + LAND_RADIUS_STEP * sqrt(float(index))
	return Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)


func _pop_in(pickup: Node3D) -> void:
	pickup.scale = Vector3.ZERO
	var tween := pickup.create_tween()
	tween.tween_property(pickup, "scale", Vector3.ONE, POP_IN_DURATION).set_trans(
		Tween.TRANS_BACK
	).set_ease(Tween.EASE_OUT)


func _on_landed(pickup: Node3D, land_index: int) -> void:
	if is_instance_valid(pickup) and pickup.has_method("_on_stashed"):
		pickup._on_stashed(land_index)
