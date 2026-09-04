extends Node3D

const _ActRevealPanel := preload("res://scripts/ui/act_reveal_panel.gd")
const _ActDeckController := preload("res://scripts/run/act_deck_controller.gd")
const _BoonChoicePanel := preload("res://scripts/ui/boon_choice_panel.gd")
const _BoonRewardController := preload("res://scripts/run/boon_reward_controller.gd")

@onready var player: FpsPlayer = $TravelPath/VanFollow/VanRig/Player
@onready var weapon: GunController = $TravelPath/VanFollow/VanRig/Player/Head/Camera3D/Weapon
@onready var usables: UsablesController = $TravelPath/VanFollow/VanRig/Player/Usables
@onready var player_containment: VanPlayerContainment = (
	$TravelPath/VanFollow/VanRig/Interior/PlayerContainment
)
@onready var item_hud: Control = $HUD/ItemHUD
@onready var prompt_label: Label = %InteractionPrompt
@onready var phase_label: Label = %PhaseLabel
@onready var wave_label: Label = %WaveLabel
@onready var health_bar: ProgressBar = %VanHealth
@onready var health_label: Label = %HealthLabel
@onready var message_label: Label = %MessageLabel
@onready var crosshair: Label = %Crosshair
@onready var ammo_label: Label = %AmmoLabel
@onready var ammo_bar: ProgressBar = %AmmoBar
@onready var reload_label: Label = %ReloadLabel
@onready var route_panel: Control = %RouteChoice
@onready var driver_talk_panel: Control = %DriverTalk
@onready var driver_talk_hint: Label = %DriverTalkHint
@onready var start_run_button: Button = %StartRun
@onready var accelerate_button: Button = %Accelerate
@onready var rest_toast: Label = %RestToast
@onready var game_over_panel: Control = %GameOver
@onready var bench_screen: BenchScreen = %BenchScreen
@onready var crafting_table: CraftingTable = (
	$TravelPath/VanFollow/VanRig/Interior/Props/CraftingTable
)

var _debug_console: Control
var _act_reveal: Control
var _act_deck: Node
var _boon_choice: Control
var _boon_rewards: Node
var _driver_talk_open := false
var _weapon_slots_hud: WeaponSlotsHud
var _ammo_reload_tween: Tween


func _ready() -> void:
	if DebugConfig.ENABLED:
		## load() not preload() — compile-time preload of the console scene
		## hard-fails van.gd (and boot's van preload) if the console graph breaks.
		var console_scene := load("res://scenes/ui/debug_console.tscn") as PackedScene
		if console_scene:
			_debug_console = console_scene.instantiate()
			$HUD.add_child(_debug_console)
			_debug_console.opened.connect(_on_debug_console_opened)
			_debug_console.closed.connect(_on_debug_console_closed)
		else:
			push_warning("Van: could not load debug_console.tscn")
	add_to_group(&"van_run")
	player.interaction_prompt_changed.connect(_on_prompt_changed)
	player.shot_fired.connect(_on_shot_fired)
	weapon.ammo_changed.connect(_on_ammo_changed)
	weapon.reloading_changed.connect(_on_reloading_changed)
	crafting_table.opened.connect(_open_bench)
	bench_screen.closed.connect(_on_bench_closed)
	bench_screen.bind(player, usables, player.gun_stats, weapon, player.weapon_inventory)
	GameSession.phase_changed.connect(_on_phase_changed)
	GameSession.van_health_changed.connect(_on_health_changed)
	GameSession.wave_changed.connect(_on_wave_changed)
	GameSession.room_changed.connect(_on_room_changed)
	_on_health_changed(GameSession.van_health, GameSession.get_max_van_health())
	_on_wave_changed(GameSession.wave_count)
	_on_phase_changed(GameSession.phase)
	_on_ammo_changed(weapon.get_current_ammo(), weapon.get_mag_size())
	item_hud.bind(usables)
	usables.item_acquired.connect(_on_item_acquired)
	usables.usable_activated.connect(_on_usable_activated)
	_act_reveal = _ActRevealPanel.new()
	$HUD.add_child(_act_reveal)
	_act_deck = _ActDeckController.new()
	add_child(_act_deck)
	_act_deck.bind(_act_reveal)
	_boon_choice = _BoonChoicePanel.new()
	$HUD.add_child(_boon_choice)
	_boon_choice.bind(player)
	_boon_rewards = _BoonRewardController.new()
	add_child(_boon_rewards)
	_boon_rewards.bind(player, _boon_choice)
	driver_talk_panel.hide()
	_refresh_driver_talk_options()
	_setup_weapon_slots_hud()
	if player.weapon_inventory:
		player.weapon_inventory.loadout_changed.connect(_on_weapon_loadout_changed)
		player.weapon_inventory.active_weapon_changed.connect(
			func(_i: int, _w) -> void: _on_weapon_loadout_changed()
		)
	set_process(false)


func _setup_weapon_slots_hud() -> void:
	_weapon_slots_hud = WeaponSlotsHud.new()
	var top_left := $HUD/TopLeft as VBoxContainer
	if top_left and reload_label:
		top_left.add_child(_weapon_slots_hud)
		top_left.move_child(_weapon_slots_hud, reload_label.get_index())
	else:
		$HUD.add_child(_weapon_slots_hud)
	if player.weapon_inventory:
		_weapon_slots_hud.bind(player.weapon_inventory)


func _on_weapon_loadout_changed() -> void:
	## Ammo label always; reload bar is owned by reloading_changed (don't kill its tween).
	_on_ammo_changed(weapon.get_current_ammo(), weapon.get_mag_size())
	reload_label.visible = weapon.is_reloading()


func _process(_delta: float) -> void:
	if not _driver_talk_open:
		set_process(false)
		return
	_refresh_driver_talk_options()


func _on_prompt_changed(text: String) -> void:
	prompt_label.text = text


func _on_shot_fired(hit: bool) -> void:
	crosshair.modulate = Color("#e7c45b") if hit else Color("#d86a4d")
	await get_tree().create_timer(0.09).timeout
	crosshair.modulate = Color.WHITE


func _on_ammo_changed(current: int, max_ammo: int) -> void:
	var name_prefix := "AMMO"
	if player and player.weapon_inventory:
		var active := player.weapon_inventory.get_active() as WeaponInstance
		if active:
			name_prefix = active.family_code()
	ammo_label.text = "%s  %d / %d" % [name_prefix, current, max_ammo]
	## While reloading, the chamber bar tween owns ammo_bar — don't snap/kill it.
	if weapon.is_reloading():
		ammo_bar.max_value = max_ammo
		ammo_label.modulate = Color("#c8c8c8")
		return
	_kill_ammo_reload_tween()
	ammo_bar.max_value = max_ammo
	ammo_bar.value = current
	var low_ammo := current <= maxi(1, floori(max_ammo * 0.25))
	ammo_label.modulate = Color("#f0a84a") if low_ammo else Color("#e8d68c")


func _on_reloading_changed(reloading: bool) -> void:
	reload_label.visible = reloading
	_kill_ammo_reload_tween()
	if reloading:
		ammo_label.modulate = Color("#c8c8c8")
		var mag := float(weapon.get_mag_size())
		var current := float(weapon.get_current_ammo())
		var remaining := weapon.get_reload_remaining()
		ammo_bar.max_value = mag
		ammo_bar.value = current
		if remaining <= 0.0:
			ammo_bar.value = mag
			return
		## Fill the chamber bar in sync with reload time (from current rounds).
		_ammo_reload_tween = create_tween()
		_ammo_reload_tween.tween_property(ammo_bar, "value", mag, remaining).set_trans(
			Tween.TRANS_LINEAR
		)
	else:
		_on_ammo_changed(weapon.get_current_ammo(), weapon.get_mag_size())


func _kill_ammo_reload_tween() -> void:
	if _ammo_reload_tween and _ammo_reload_tween.is_valid():
		_ammo_reload_tween.kill()
	_ammo_reload_tween = null


func _on_phase_changed(next_phase: GameSession.RunPhase) -> void:
	phase_label.text = "%s  ·  %s ROOM" % [
		GameSession.RunPhase.keys()[next_phase].replace("_", " "),
		String(GameSession.current_room).to_upper(),
	]
	_on_wave_changed(GameSession.wave_count)
	route_panel.visible = next_phase == GameSession.RunPhase.ROUTE_CHOICE
	if next_phase == GameSession.RunPhase.ROUTE_CHOICE:
		_refresh_route_choice_labels()
	game_over_panel.visible = next_phase == GameSession.RunPhase.GAME_OVER
	if next_phase == GameSession.RunPhase.GAME_OVER or next_phase == GameSession.RunPhase.ROUTE_CHOICE:
		close_driver_talk()
	else:
		_refresh_driver_talk_options()

	match next_phase:
		GameSession.RunPhase.REST:
			rest_toast.text = "BREAK — ROAD KEEPS MOVING"
			rest_toast.show()
		GameSession.RunPhase.ACT_REVEAL:
			rest_toast.text = "THE ROAD AHEAD — STATUE READING"
			rest_toast.show()
		GameSession.RunPhase.TURNING:
			rest_toast.text = "TURNING %s..." % String(GameSession.last_direction).to_upper()
			rest_toast.show()
			route_panel.hide()
		GameSession.RunPhase.PARKING:
			rest_toast.text = "PULLING INTO THE SHOP..."
			rest_toast.show()
		GameSession.RunPhase.SHOP:
			_set_shop_rear_exit(true)
			rest_toast.text = "SHOP — STEP OUT BACK, THEN TELL THE DRIVER TO CONTINUE"
			rest_toast.show()
		_:
			if player_containment and player_containment.is_rear_exit_allowed():
				_set_shop_rear_exit(false)
			rest_toast.hide()

	var bench_blocked := next_phase in [
		GameSession.RunPhase.COMBAT,
		GameSession.RunPhase.ROUTE_CHOICE,
		GameSession.RunPhase.GAME_OVER,
		GameSession.RunPhase.PARKING,
		GameSession.RunPhase.ACT_REVEAL,
	]
	if _act_reveal and _act_reveal.visible:
		bench_blocked = true
	if _boon_choice and _boon_choice.visible:
		bench_blocked = true
	if _driver_talk_open:
		bench_blocked = true
	if bench_screen.visible:
		# close() re-applies the mouse mode through _on_bench_closed.
		if bench_blocked:
			bench_screen.close()
		return
	_apply_phase_mouse_mode(next_phase)


func _refresh_route_choice_labels() -> void:
	var left_btn: Button = %RouteChoice.get_node("Layout/Buttons/Left")
	var right_btn: Button = %RouteChoice.get_node("Layout/Buttons/Right")
	var travel := get_tree().get_first_node_in_group(&"travel_controller")
	var shop_side: StringName = &""
	if travel and travel.has_method(&"get_shop_fork_side"):
		shop_side = travel.get_shop_fork_side()
	var offers := GameSession.peek_route_cards()
	var left_card: ActCardDefinition = offers[0] if offers.size() > 0 else null
	var right_card: ActCardDefinition = offers[1] if offers.size() > 1 else left_card
	left_btn.custom_minimum_size = Vector2(210, 150)
	right_btn.custom_minimum_size = Vector2(210, 150)
	left_btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right_btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left_btn.text = _route_button_text(left_card, shop_side == &"left", true)
	right_btn.text = _route_button_text(right_card, shop_side == &"right", false)
	var hint: Label = %RouteChoice.get_node("Layout/Hint")
	if shop_side == &"left":
		hint.text = "Shop is on the left — each road still carries a street card."
	elif shop_side == &"right":
		hint.text = "Shop is on the right — each road still carries a street card."
	else:
		hint.text = "One street card per road. Pick a turn — or the road picks for you."


func _route_button_text(card: ActCardDefinition, is_shop: bool, is_left: bool) -> String:
	var heading := "SHOP ←" if is_shop and is_left else ("SHOP →" if is_shop else ("← LEFT" if is_left else "RIGHT →"))
	if card == null:
		return heading
	return "%s\n\n%s\n%s\n%s" % [
		heading,
		card.polarity_label(),
		card.display_name,
		card.description.strip_edges(),
	]


## Re-apply the correct mouse mode for the current phase / open overlays.
## Overlays should call this on close instead of hardcoding CAPTURED.
func refresh_mouse_mode() -> void:
	_apply_phase_mouse_mode(GameSession.phase)


func wants_free_cursor(phase: GameSession.RunPhase = GameSession.phase) -> bool:
	if has_modal_free_cursor():
		return true
	return phase in [
		GameSession.RunPhase.ROUTE_CHOICE,
		GameSession.RunPhase.GAME_OVER,
		GameSession.RunPhase.ACT_REVEAL,
		GameSession.RunPhase.REST,
	]


## True only when a clickable overlay owns the cursor (blocks Esc FPS toggle).
func has_modal_free_cursor() -> bool:
	if _driver_talk_open:
		return true
	if bench_screen and bench_screen.visible:
		return true
	if _debug_console and _debug_console.visible:
		return true
	if _act_reveal and _act_reveal.visible:
		return true
	if _boon_choice and _boon_choice.visible:
		return true
	if route_panel and route_panel.visible:
		return true
	if game_over_panel and game_over_panel.visible:
		return true
	return _has_weapon_replace_prompt()


func _has_weapon_replace_prompt() -> bool:
	for node in get_tree().get_nodes_in_group(&"weapon_replace_prompt"):
		if is_instance_valid(node):
			return true
	return false


func _apply_phase_mouse_mode(phase: GameSession.RunPhase) -> void:
	Input.mouse_mode = (
		Input.MOUSE_MODE_VISIBLE if wants_free_cursor(phase) else Input.MOUSE_MODE_CAPTURED
	)


func _open_bench() -> void:
	if GameSession.phase == GameSession.RunPhase.GAME_OVER:
		return
	if _driver_talk_open:
		close_driver_talk()
	bench_screen.open()
	refresh_mouse_mode()


func _on_bench_closed() -> void:
	refresh_mouse_mode()


func _on_debug_console_opened() -> void:
	if bench_screen.visible:
		bench_screen.close()
	if _driver_talk_open:
		close_driver_talk()
	refresh_mouse_mode()


func _on_debug_console_closed() -> void:
	refresh_mouse_mode()


func _on_room_changed(_room: StringName) -> void:
	phase_label.text = "%s  ·  %s ROOM" % [
		GameSession.RunPhase.keys()[GameSession.phase].replace("_", " "),
		String(GameSession.current_room).to_upper(),
	]


func _on_health_changed(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	health_label.text = "VAN  %d / %d" % [roundi(current), roundi(maximum)]


func _on_wave_changed(wave: int) -> void:
	var card_total := GameSession.act_cards_total
	if card_total > 0:
		var resolved := GameSession.act_cards_resolved_count()
		wave_label.text = "WAVES  %d  ·  ACT %d  ·  CARD %d/%d" % [
			wave,
			GameSession.run_act,
			mini(resolved + 1, card_total),
			card_total,
		]
	else:
		wave_label.text = "WAVES CLEARED  %d" % wave


func _show_message(text: String) -> void:
	message_label.text = text
	message_label.show()
	await get_tree().create_timer(2.5).timeout
	message_label.hide()


func _on_item_acquired(item: ItemDefinition, charges: int, slot_index: int) -> void:
	if not item:
		return
	match item.kind:
		ItemDefinition.ItemKind.BOON:
			_show_message("BOON  %s" % item.display_name.to_upper())
		ItemDefinition.ItemKind.MONEY:
			_show_message("COINS  %s" % item.display_name.to_upper())
		ItemDefinition.ItemKind.CONSUMABLE:
			_show_message("USED  %s" % item.display_name.to_upper())
		ItemDefinition.ItemKind.TOOL:
			if slot_index >= 0:
				_show_message("TOOL  %s  x%d  —  PRESS %d" % [
					item.display_name.to_upper(),
					charges,
					slot_index + 1,
				])


func _on_usable_activated(item: ItemDefinition, success: bool) -> void:
	if not item:
		return
	if success:
		_show_message("USED  %s" % item.display_name.to_upper())
	else:
		_show_message("%s  NOT READY" % item.display_name.to_upper())


func _on_left_route_pressed() -> void:
	GameSession.choose_route(&"left")


func _on_right_route_pressed() -> void:
	GameSession.choose_route(&"right")


func open_driver_talk() -> void:
	if GameSession.phase == GameSession.RunPhase.GAME_OVER:
		return
	if GameSession.phase == GameSession.RunPhase.ROUTE_CHOICE:
		return
	if GameSession.phase == GameSession.RunPhase.SHOP:
		return
	if GameSession.phase == GameSession.RunPhase.PARKING:
		return
	if GameSession.phase == GameSession.RunPhase.ACT_REVEAL:
		return
	if _act_reveal and _act_reveal.visible:
		return
	if bench_screen.visible:
		bench_screen.close()
	_driver_talk_open = true
	_refresh_driver_talk_options()
	driver_talk_panel.show()
	refresh_mouse_mode()
	set_process(true)


func close_driver_talk() -> void:
	if not _driver_talk_open and not driver_talk_panel.visible:
		return
	_driver_talk_open = false
	driver_talk_panel.hide()
	set_process(false)
	refresh_mouse_mode()


func _refresh_driver_talk_options() -> void:
	var idle := GameSession.phase == GameSession.RunPhase.IDLE
	start_run_button.visible = idle
	accelerate_button.visible = not idle
	if idle:
		driver_talk_hint.text = "Ready when you are."
		start_run_button.disabled = false
		return

	var travel := get_tree().get_first_node_in_group(&"travel_controller") as TravelController
	if travel == null:
		driver_talk_hint.text = "Ask the driver for more speed."
		accelerate_button.disabled = true
		accelerate_button.text = "ACCELERATE"
		return

	if travel.is_boosting():
		driver_talk_hint.text = "Hold on — flooring it."
		accelerate_button.disabled = true
		accelerate_button.text = "FLOORING IT"
	elif not travel.can_boost():
		var wait := ceili(travel.get_boost_cooldown_remaining())
		driver_talk_hint.text = "Engine's hot — give it a moment."
		accelerate_button.disabled = true
		accelerate_button.text = "WAIT %ds" % wait
	else:
		driver_talk_hint.text = "Ask the driver for more speed."
		accelerate_button.disabled = false
		accelerate_button.text = "ACCELERATE"


func _on_start_run_pressed() -> void:
	GameSession.begin_run()
	_refresh_driver_talk_options()
	close_driver_talk()
	_show_message("RUN STARTED — ROAD AHEAD")


func _on_accelerate_pressed() -> void:
	var travel := get_tree().get_first_node_in_group(&"travel_controller") as TravelController
	if travel == null or not travel.try_boost():
		_refresh_driver_talk_options()
		return
	close_driver_talk()
	_show_message("DRIVER FLOORS IT")


func _on_driver_talk_close_pressed() -> void:
	close_driver_talk()


func seal_van_after_shop() -> void:
	_set_shop_rear_exit(false)
	rest_toast.text = "PULLING OUT OF THE SHOP..."
	rest_toast.show()


func _set_shop_rear_exit(allowed: bool) -> void:
	if player_containment:
		player_containment.set_rear_exit_allowed(allowed)
	var rear_doors: Node = get_tree().get_first_node_in_group(&"rear_doors")
	if rear_doors == null:
		return
	if allowed and rear_doors.has_method(&"open"):
		rear_doors.open()
	elif not allowed and rear_doors.has_method(&"close"):
		rear_doors.close()


func _on_main_menu_pressed() -> void:
	SaveManager.save_active_session()
	SceneRouter.go_to_main_menu()
