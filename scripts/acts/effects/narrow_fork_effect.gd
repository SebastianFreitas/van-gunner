class_name NarrowForkEffect
extends ActCardEffect

## After this street, the next fork is a T — two face-up cards instead of three.
## Boss stacks skip this; a new act already redraws a full 4-way.


func on_activate(_ctx: ActCardEffectContext) -> void:
	if GameSession.is_boss_combat_queued():
		return
	GameSession.pending_narrow_fork = true
