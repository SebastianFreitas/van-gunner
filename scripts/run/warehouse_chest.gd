class_name WarehouseChest
extends Interactable

## Table-top crate. E opens a bonus 3-choice boon, then springs leftover hides.

var _opened := false
var _lid: MeshInstance3D
var _director: WarehouseDirector


func bind(director: WarehouseDirector) -> void:
	_director = director


func _ready() -> void:
	collision_layer = 3
	collision_mask = 0
	prompt = "E  OPEN CHEST"
	_build()


func get_interaction_prompt() -> String:
	if _opened:
		return ""
	return prompt


func interact(_actor: Node3D) -> void:
	if _opened:
		return
	_opened = true
	prompt = ""
	_open_lid()
	AudioDirector.play(&"usable")
	var rewards := get_tree().get_first_node_in_group(&"boon_reward_controller")
	if rewards and rewards.has_method(&"present_bonus_choices"):
		rewards.present_bonus_choices()
	if _director:
		_director.trigger_all()


func _build() -> void:
	var wood := WarehouseLook.wood_material()
	var steel := WarehouseLook.steel_material()
	WarehouseLook.add_box(self, "Body", Vector3(0.72, 0.38, 0.48), Vector3(0.0, 0.19, 0.0), wood)
	_lid = WarehouseLook.add_box(
		self, "Lid", Vector3(0.74, 0.06, 0.5), Vector3(0.0, 0.41, 0.0), wood
	)
	WarehouseLook.add_box(self, "Latch", Vector3(0.12, 0.08, 0.08), Vector3(0.0, 0.36, 0.26), steel)
	WarehouseLook.add_collision(self, Vector3(0.78, 0.48, 0.54), Vector3(0.0, 0.24, 0.0))


func _open_lid() -> void:
	if _lid == null:
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(_lid, "rotation:x", -1.35, 0.28)
	tween.parallel().tween_property(_lid, "position", Vector3(0.0, 0.52, -0.12), 0.28)
