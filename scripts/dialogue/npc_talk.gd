class_name NpcTalk
extends Interactable

## Look + E opens talk. Hover + click picks; E or walking off closes.
## Subclass and override `build_choices` / `execute_choice`. Frees the cursor.

@export var speaker_name := "Someone"
@export_multiline var greeting := "Yeah?"
@export var leave_distance := 4.5

## Set by execute_choice when a pick fails (can't afford, already full, …).
var last_error := ""

var _actor: Node3D
var _talking := false


func _ready() -> void:
	collision_layer = 3
	collision_mask = 0
	if prompt.strip_edges().is_empty() or prompt == "Interact":
		prompt = "E  TALK"
	set_process(false)


func _exit_tree() -> void:
	if _talking:
		close_talk()


func _process(_delta: float) -> void:
	if not _talking or _actor == null or not is_instance_valid(_actor):
		close_talk()
		return
	var away := _actor.global_position - global_position
	away.y = 0.0
	if away.length() > leave_distance:
		close_talk()


func is_talking() -> bool:
	return _talking


func get_interaction_prompt() -> String:
	if _talking:
		return ""
	return prompt


func interact(actor: Node3D) -> void:
	if actor == null:
		return
	if GameSession.phase == GameSession.RunPhase.GAME_OVER:
		return
	if _talking:
		close_talk()
		return
	open_talk(actor)


func open_talk(actor: Node3D) -> void:
	var hud := _hud()
	if hud == null or actor == null:
		return
	if hud.has_method(&"is_open") and hud.is_open() and hud.get("npc") != self:
		hud.close()
	_actor = actor
	_talking = true
	last_error = ""
	set_process(true)
	hud.open(self, actor)
	if actor.has_signal("interaction_prompt_changed"):
		actor.interaction_prompt_changed.emit(get_interaction_prompt())


func close_talk() -> void:
	if not _talking:
		set_process(false)
		return
	_talking = false
	set_process(false)
	var hud := _hud()
	if hud and hud.get("npc") == self and hud.has_method(&"close"):
		hud.close()
	var actor := _actor
	_actor = null
	if actor == null or not is_instance_valid(actor):
		return
	if not actor.has_method(&"get_look_interactable"):
		return
	if actor.get_look_interactable() != self:
		return
	if actor.has_signal("interaction_prompt_changed"):
		actor.interaction_prompt_changed.emit(get_interaction_prompt())


func get_speaker_line(_actor: Node3D) -> String:
	return greeting


func build_choices(_actor: Node3D) -> Array:
	return []


## Return true when the buy/action applied. False keeps the page open.
func execute_choice(_actor: Node3D, _choice: Variant) -> bool:
	return false


func _hud() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group(&"dialogue_hud")
