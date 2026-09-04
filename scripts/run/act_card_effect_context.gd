class_name ActCardEffectContext
extends RefCounted

## Shared bag for street-card effect hooks. Effects mutate fields; ActCardCombat
## applies collected street-trait overlays after activation.

var card: ActCardDefinition
var player: Node3D
var tree: SceneTree

## Damage / spawn / loot query targets (set per-hook).
var damage_info: DamageInfo
var target: Node
var enemy: Node
var item_drop_chance := 0.0
var wave_plan: Array[int] = []

## Collected by TempBoonTraitEffect during on_activate; applied as a replaceable
## overlay on BoonTraits so cards can reuse the whole boon combat pipeline.
var street_adds: Dictionary = {}
var street_mults: Dictionary = {}
var street_flags: Dictionary = {}


func add_street_trait(
	key: StringName,
	add_value: float = 0.0,
	multiply_value: float = 1.0,
	set_flag: bool = false
) -> void:
	if key == &"":
		return
	if not is_zero_approx(add_value):
		street_adds[key] = float(street_adds.get(key, 0.0)) + add_value
	if not is_equal_approx(multiply_value, 1.0):
		street_mults[key] = float(street_mults.get(key, 1.0)) * multiply_value
	if set_flag:
		street_flags[key] = true
