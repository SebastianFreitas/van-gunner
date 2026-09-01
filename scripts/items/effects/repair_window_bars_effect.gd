class_name RepairWindowBarsEffect
extends ItemEffect

## Instantly restores all window / side-door-window bars to full HP.
## If a point was breached, swaps BrokenIronCross back to the intact IronCross.


func apply(player: Node3D) -> void:
	if not player:
		return
	for node in player.get_tree().get_nodes_in_group(&"breach_points"):
		if node is BreachPoint:
			(node as BreachPoint).repair_bars()
