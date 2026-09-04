class_name WeaponReplacePrompt
extends CanvasLayer

## Full inventory: pick a slot to replace, or Esc to cancel (gun stays in world).
## Uses runtime load() for WeaponPickup to avoid preload cycles.

signal resolved(replaced: bool)

var _incoming: WeaponInstance
var _pickup: Node ## WeaponPickup instance (untyped to break cycles)
var _inventory: WeaponInventory
var _root: Control


static func request(
	player: Node3D,
	incoming: WeaponInstance,
	pickup: Node = null
) -> WeaponReplacePrompt:
	var inventory := player.get_node_or_null("WeaponInventory") as WeaponInventory
	if inventory == null or incoming == null:
		return null
	## One prompt at a time.
	for node in player.get_tree().get_nodes_in_group(&"weapon_replace_prompt"):
		if is_instance_valid(node):
			return null
	var prompt := WeaponReplacePrompt.new()
	prompt._incoming = incoming
	prompt._pickup = pickup
	prompt._inventory = inventory
	player.get_tree().current_scene.add_child(prompt)
	prompt._build()
	return prompt


func _build() -> void:
	add_to_group(&"weapon_replace_prompt")
	layer = 80
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	_root.add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(520, 280)
	panel.position = Vector2(-260, -140)
	_root.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override(&"separation", 12)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Replace a weapon?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 22)
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "Incoming: %s  (%d mods)" % [
		_incoming.display_name(), _incoming.mods.size()
	]
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 16)
	vbox.add_child(row)

	for i in 2:
		var inst := _inventory.get_slot(i) as WeaponInstance
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(200, 64)
		if inst:
			btn.text = "Slot %s\n%s (%d mods)" % [
				"A" if i == 0 else "B",
				inst.display_name(),
				inst.mods.size(),
			]
			btn.pressed.connect(_on_replace.bind(i))
		else:
			btn.text = "Slot %s\nEmpty" % ("A" if i == 0 else "B")
			btn.disabled = true
		row.add_child(btn)

	var cancel := Button.new()
	cancel.text = "Cancel (Esc)"
	cancel.pressed.connect(_on_cancel)
	vbox.add_child(cancel)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		_on_cancel()
		get_viewport().set_input_as_handled()


func _on_replace(slot_index: int) -> void:
	var old := _inventory.replace_slot(slot_index, _incoming)
	if old:
		var container: Node = null
		var pos := Vector3.ZERO
		if is_instance_valid(_pickup) and _pickup is Node3D:
			container = _pickup.get_parent()
			pos = (_pickup as Node3D).global_position + Vector3(0.4, 0.0, 0.0)
		else:
			var player := get_tree().get_first_node_in_group(&"player") as Node3D
			container = player.get_parent() if player else get_tree().current_scene
			pos = player.global_position + Vector3(0.0, 0.4, -0.8) if player else Vector3.ZERO
		if container:
			var pickup_script = load("res://scripts/weapons/weapon_pickup.gd")
			if pickup_script:
				pickup_script.spawn_at(old, pos, container)
	if is_instance_valid(_pickup):
		_pickup.set("weapon_instance", null)
		_pickup.set("_used", true)
		if _pickup.has_method("_consume"):
			_pickup.call("_consume")
	_close(true)


func _on_cancel() -> void:
	_close(false)


func _close(replaced: bool) -> void:
	## Drop from the group before restoring so van doesn't still see this prompt.
	remove_from_group(&"weapon_replace_prompt")
	var van := get_tree().get_first_node_in_group(&"van_run")
	if van and van.has_method(&"refresh_mouse_mode"):
		van.refresh_mouse_mode()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	resolved.emit(replaced)
	queue_free()
