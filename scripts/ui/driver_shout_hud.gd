class_name DriverShoutHud
extends Control

## Always-on GO / EASY shouts. Voice barks come later — buttons are the placeholder.

signal boost_pressed
signal slow_pressed


@onready var hint_label: Label = $Layout/Hint
@onready var boost_button: Button = %BoostShout
@onready var slow_button: Button = %SlowShout
@onready var slow_wrap: Control = $Layout/SlowWrap
@onready var boost_cooldown: ProgressBar = %BoostCooldown
@onready var slow_cooldown: ProgressBar = %SlowCooldown


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	boost_button.focus_mode = Control.FOCUS_NONE
	slow_button.focus_mode = Control.FOCUS_NONE
	boost_cooldown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slow_cooldown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boost_button.pressed.connect(func() -> void: boost_pressed.emit())
	slow_button.pressed.connect(func() -> void: slow_pressed.emit())


func _process(_delta: float) -> void:
	_refresh()


func _travel() -> TravelController:
	return get_tree().get_first_node_in_group(&"travel_controller") as TravelController


func _refresh() -> void:
	if GameSession.phase == GameSession.RunPhase.GAME_OVER:
		visible = false
		return
	visible = true

	if GameSession.phase == GameSession.RunPhase.IDLE:
		hint_label.text = "YELL LET'S GO"
		slow_wrap.visible = false
		boost_button.disabled = false
		boost_button.text = "SHIFT  LET'S GO"
		_set_bar(boost_cooldown, 0.0, false)
		_set_bar(slow_cooldown, 0.0, false)
		return

	hint_label.text = "YELL AT THE DRIVER"
	slow_wrap.visible = true

	var travel := _travel()
	if travel == null:
		boost_button.disabled = true
		slow_button.disabled = true
		boost_button.text = "SHIFT  GO"
		slow_button.text = "C  EASY"
		_set_bar(boost_cooldown, 0.0, false)
		_set_bar(slow_cooldown, 0.0, false)
		return

	if travel.is_boosting():
		boost_button.disabled = true
		boost_button.text = "SHIFT  FLOORING IT"
		var boost_fill := 0.0
		if travel.boost_duration > 0.0:
			boost_fill = travel.get_boost_remaining() / travel.boost_duration
		_set_bar(boost_cooldown, boost_fill, true)
	elif not travel.can_boost():
		var wait := ceili(travel.get_boost_cooldown_remaining())
		boost_button.disabled = true
		boost_button.text = "SHIFT  WAIT %ds" % wait
		var cd_fill := 0.0
		if travel.boost_cooldown > 0.0:
			cd_fill = 1.0 - travel.get_boost_cooldown_remaining() / travel.boost_cooldown
		_set_bar(boost_cooldown, cd_fill, travel.get_boost_cooldown_remaining() > 0.0)
	else:
		boost_button.disabled = false
		boost_button.text = "SHIFT  GO"
		_set_bar(boost_cooldown, 0.0, false)

	if travel.is_slowing():
		slow_button.disabled = false
		slow_button.text = "C  LET'S GO"
		_set_bar(slow_cooldown, 1.0, false)
	elif not travel.can_slow():
		var wait := ceili(travel.get_slow_cooldown_remaining())
		slow_button.disabled = true
		if wait > 0:
			slow_button.text = "C  WAIT %ds" % wait
		else:
			slow_button.text = "C  EASY"
		var cd_fill := 0.0
		if travel.slow_cooldown > 0.0:
			cd_fill = 1.0 - travel.get_slow_cooldown_remaining() / travel.slow_cooldown
		_set_bar(slow_cooldown, cd_fill, travel.get_slow_cooldown_remaining() > 0.0)
	else:
		slow_button.disabled = false
		slow_button.text = "C  EASY"
		_set_bar(slow_cooldown, 0.0, false)


func _set_bar(bar: ProgressBar, value: float, shown: bool) -> void:
	bar.max_value = 1.0
	bar.value = clampf(value, 0.0, 1.0)
	bar.visible = shown
