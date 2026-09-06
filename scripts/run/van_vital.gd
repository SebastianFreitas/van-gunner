class_name VanVital
extends Node3D

## One interior machine whose HP is a slice of van death hull.
## Raiders path to AttackMarker; the weld kit heals the looked-at parent prop.

signal health_changed(current: float, maximum: float)

@export var vital_id: StringName = &""
@export var display_name := "Machine"

var max_health := 25.0
var health := 25.0


func _ready() -> void:
	if vital_id == &"":
		vital_id = StringName(name.to_snake_case())
	add_to_group(&"van_vitals")
	GameSession.bind_vital(self)


func is_alive() -> bool:
	return health > 0.001


func is_at_full_health() -> bool:
	return health >= max_health - 0.001


func get_attack_marker() -> Node3D:
	var marker := get_node_or_null("AttackMarker") as Node3D
	return marker if marker else self


func apply_saved(current: float, maximum: float) -> void:
	max_health = maxf(0.1, maximum)
	health = clampf(current, 0.0, max_health)
	health_changed.emit(health, max_health)


func add_max(amount: float) -> void:
	if is_zero_approx(amount):
		return
	max_health = maxf(0.1, max_health + amount)
	if amount > 0.0:
		health += amount
	else:
		health = minf(health, max_health)
	health_changed.emit(health, max_health)


func take_damage(amount: float) -> void:
	if amount <= 0.0 or not is_alive() or GameSession.phase == GameSession.RunPhase.GAME_OVER:
		return
	health = maxf(0.0, health - amount)
	health_changed.emit(health, max_health)
	var pos := get_attack_marker().global_position
	CombatFeedback.show_damage(
		pos + Vector3(0, 0.6, 0),
		amount,
		false,
		DamageType.Type.NORMAL
	)
	GameSession.sync_van_health_from_vitals()


func heal(amount: float) -> float:
	if amount <= 0.0 or GameSession.phase == GameSession.RunPhase.GAME_OVER:
		return 0.0
	var before := health
	health = minf(max_health, health + amount)
	var gained := health - before
	if gained > 0.001:
		health_changed.emit(health, max_health)
		GameSession.sync_van_health_from_vitals()
	return gained


static func find_on(node: Node) -> VanVital:
	if node == null:
		return null
	if node is VanVital:
		return node as VanVital
	for child in node.get_children():
		if child is VanVital:
			return child as VanVital
	return null
