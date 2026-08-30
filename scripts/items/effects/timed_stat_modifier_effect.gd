class_name TimedStatModifierEffect
extends ItemEffect

## Applies temporary gun stat modifiers, then removes them after a duration.

@export var modifiers: Array[StatModifier] = []
@export var duration_sec := 60.0


func apply(player: Node3D) -> void:
	var controller := player.get_node_or_null("GunStats") as GunStatsController
	if not controller or modifiers.is_empty():
		return
	var applied: Array[StatModifier] = []
	for modifier in modifiers:
		if not modifier:
			continue
		var copy := modifier.duplicate() as StatModifier
		controller.add_modifier(copy)
		applied.append(copy)
	if applied.is_empty():
		return
	await player.get_tree().create_timer(duration_sec).timeout
	if not is_instance_valid(controller):
		return
	for modifier in applied:
		controller.remove_modifier_by_id(modifier.id)
