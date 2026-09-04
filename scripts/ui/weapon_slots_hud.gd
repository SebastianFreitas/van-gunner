class_name WeaponSlotsHud
extends HBoxContainer

## Two weapon slots near ammo — highlight active, dashed empty.

var _inventory: WeaponInventory
var _slot_labels: Array[Label] = []


func _ready() -> void:
	add_theme_constant_override(&"separation", 8)
	for i in 2:
		var label := Label.new()
		label.custom_minimum_size = Vector2(56, 28)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override(&"font_size", 14)
		add_child(label)
		_slot_labels.append(label)
	_refresh()


func bind(inventory: WeaponInventory) -> void:
	if _inventory:
		if _inventory.loadout_changed.is_connected(_refresh):
			_inventory.loadout_changed.disconnect(_refresh)
		if _inventory.active_weapon_changed.is_connected(_on_active_changed):
			_inventory.active_weapon_changed.disconnect(_on_active_changed)
	_inventory = inventory
	if _inventory:
		_inventory.loadout_changed.connect(_refresh)
		_inventory.active_weapon_changed.connect(_on_active_changed)
	_refresh()


func _on_active_changed(_index: int, _instance: WeaponInstance) -> void:
	_refresh()


func _refresh() -> void:
	if _slot_labels.size() < 2:
		return
	for i in 2:
		var label := _slot_labels[i]
		var inst: WeaponInstance = null
		if _inventory:
			inst = _inventory.get_slot(i)
		if inst == null:
			label.text = "[ -- ]"
			label.modulate = Color(0.45, 0.45, 0.45, 1)
		else:
			label.text = "[ %s ]" % inst.family_code()
			if _inventory and i == _inventory.active_index:
				label.modulate = Color(0.91, 0.84, 0.55, 1)
			else:
				label.modulate = Color(0.7, 0.72, 0.68, 1)
