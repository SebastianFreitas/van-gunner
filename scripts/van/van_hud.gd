extends RefCounted

## Combat HUD readouts: ammo, health, waves, prompts, item toasts, stop toasts.

var van: Node3D  # untyped owner; van.gd has no class_name (cycle rule), so fields are read dynamically


func _init(owner: Node3D) -> void:
	van = owner


func on_prompt_changed(text: String) -> void:
	van.prompt_label.text = text


func on_ammo_changed(current: int, max_ammo: int) -> void:
	var name_prefix := "AMMO"
	if van.player and van.player.current_class:
		name_prefix = van.player.current_class.family_code()
	van.ammo_label.text = "%s  %d / %d" % [name_prefix, current, max_ammo]
	## While reloading, the chamber bar tween owns ammo_bar — don't snap/kill it.
	if van.weapon.is_reloading():
		van.ammo_bar.max_value = max_ammo
		van.ammo_label.modulate = Color("#c8c8c8")
		return
	kill_ammo_reload_tween()
	van.ammo_bar.max_value = max_ammo
	van.ammo_bar.value = current
	var low_ammo := current <= maxi(1, floori(max_ammo * 0.25))
	van.ammo_label.modulate = Color("#f0a84a") if low_ammo else Color("#e8d68c")


func on_reloading_changed(reloading: bool) -> void:
	van.reload_label.visible = reloading
	kill_ammo_reload_tween()
	if reloading:
		van.ammo_label.modulate = Color("#c8c8c8")
		var mag := float(van.weapon.get_mag_size())
		var current := float(van.weapon.get_current_ammo())
		var remaining: float = van.weapon.get_reload_remaining()
		van.ammo_bar.max_value = mag
		van.ammo_bar.value = current
		if remaining <= 0.0:
			van.ammo_bar.value = mag
			return
		## Fill the chamber bar in sync with reload time (from current rounds).
		van._ammo_reload_tween = van.create_tween()
		van._ammo_reload_tween.tween_property(van.ammo_bar, "value", mag, remaining).set_trans(
			Tween.TRANS_LINEAR
		)
	else:
		on_ammo_changed(van.weapon.get_current_ammo(), van.weapon.get_mag_size())


func kill_ammo_reload_tween() -> void:
	if van._ammo_reload_tween and van._ammo_reload_tween.is_valid():
		van._ammo_reload_tween.kill()
	van._ammo_reload_tween = null


func on_room_changed(_room: StringName) -> void:
	van.phase_label.text = "%s  ·  %s ROOM" % [
		GameSession.RunPhase.keys()[GameSession.phase].replace("_", " "),
		String(GameSession.current_room).to_upper(),
	]


func on_health_changed(current: float, maximum: float) -> void:
	van.health_label.text = "VAN  %d / %d" % [roundi(current), roundi(maximum)]
	if van.health_bar:
		van.health_bar.queue_redraw()


func on_player_health_changed(current: float, maximum: float) -> void:
	van.player_health_bar.max_value = maximum
	van.player_health_bar.value = current
	van.player_health_label.text = "YOU  %d / %d" % [roundi(current), roundi(maximum)]
	if van._last_player_hp >= 0.0 and current < van._last_player_hp - 0.001:
		van._flash_player_hit()
	van._last_player_hp = current


func on_wave_changed(wave: int) -> void:
	if GameSession.is_boss_combat_queued() or GameSession.phase == GameSession.RunPhase.BOSS_PICK:
		var names: PackedStringArray = PackedStringArray()
		for card in GameSession.get_boss_modifier_cards():
			names.append(card.display_name)
		var bound := "  ·  %s" % " + ".join(names) if not names.is_empty() else ""
		van.wave_label.text = "BOSS  ·  ACT %d%s" % [GameSession.run_act, bound]
		return
	var card_total := GameSession.act_cards_total
	if card_total > 0:
		var resolved := GameSession.act_cards_resolved_count()
		van.wave_label.text = "WAVES  %d  ·  ACT %d  ·  CARD %d/%d" % [
			wave,
			GameSession.run_act,
			mini(resolved + 1, card_total),
			card_total,
		]
	else:
		van.wave_label.text = "WAVES CLEARED  %d" % wave


func on_item_acquired(item: ItemDefinition, charges: int, slot_index: int) -> void:
	if not item:
		return
	match item.kind:
		ItemDefinition.ItemKind.BOON:
			van._show_message("BOON  %s" % item.display_name.to_upper())
		ItemDefinition.ItemKind.MONEY:
			van._show_message("COINS  %s" % item.display_name.to_upper())
		ItemDefinition.ItemKind.CONSUMABLE:
			van._show_message("USED  %s" % item.display_name.to_upper())
		ItemDefinition.ItemKind.TOOL:
			if slot_index >= 0:
				van._show_message("TOOL  %s  x%d  —  PRESS %d" % [
					item.display_name.to_upper(),
					charges,
					slot_index + 1,
				])


func on_usable_activated(item: ItemDefinition, success: bool) -> void:
	if not item:
		return
	if success:
		van._show_message("USED  %s" % item.display_name.to_upper())
	else:
		van._show_message("%s  NOT READY" % item.display_name.to_upper())


func active_side_stop() -> SideStopDefinition:
	var travel := van.get_tree().get_first_node_in_group(&"travel_controller")
	if travel and travel.has_method(&"get_active_stop"):
		return travel.get_active_stop()
	return null


func stop_toast_parking() -> String:
	var stop := active_side_stop()
	return stop.label_parking() if stop else "PULLING IN..."


func stop_toast_docked() -> String:
	var stop := active_side_stop()
	return stop.label_docked() if stop else "STEP OUT BACK, THEN TELL THE DRIVER TO CONTINUE"


func stop_toast_leaving() -> String:
	var stop := active_side_stop()
	return stop.label_leaving() if stop else "PULLING OUT..."


func show_phase_toast(next_phase: GameSession.RunPhase) -> void:
	match next_phase:
		GameSession.RunPhase.REST:
			van.rest_toast.text = "BREAK — ROAD KEEPS MOVING"
			van.rest_toast.show()
		GameSession.RunPhase.ACT_REVEAL:
			van.rest_toast.text = "THE ROAD AHEAD — STATUE READING"
			van.rest_toast.show()
		GameSession.RunPhase.BOSS_PICK:
			van.rest_toast.text = "THE JUDGE — TWO STREETS"
			van.rest_toast.show()
		GameSession.RunPhase.TURNING:
			if GameSession.last_direction == &"straight":
				van.rest_toast.text = "HOLDING STRAIGHT..."
			else:
				van.rest_toast.text = "TURNING %s..." % String(GameSession.last_direction).to_upper()
			van.rest_toast.show()
			van.route_panel.hide()
		GameSession.RunPhase.PARKING:
			van.rest_toast.text = stop_toast_parking()
			van.rest_toast.show()
		GameSession.RunPhase.STOP:
			van._set_stop_rear_exit(true)
			van.rest_toast.text = stop_toast_docked()
			van.rest_toast.show()
		_:
			if van.player_containment and van.player_containment.is_rear_exit_allowed():
				van._set_stop_rear_exit(false)
			van.rest_toast.hide()
