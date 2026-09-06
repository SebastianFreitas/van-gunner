class_name SkillNodeEffect
extends Resource

## One gameplay hook on a meta skill-tree node. Nodes hold an Array of these —
## same pattern as ItemEffect. Query methods are summed by MetaProgression from
## allocated (live) nodes only; pending nodes must not answer these.


func describe() -> String:
	return ""


func van_speed_levels() -> int:
	return 0


## Extra max HP for one interior vital. Empty `vital_id` on the effect means
## every machine gets `amount`.
func vital_max_bonus(_vital_id: StringName) -> float:
	return 0.0
