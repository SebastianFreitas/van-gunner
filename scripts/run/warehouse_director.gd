class_name WarehouseDirector
extends Node3D

## Picks one hide layout per visit. Early triggers (shoot / walk / laser) or
## the chest calling `trigger_all()` both spring whatever is still waiting.

const LAYOUTS: Array[StringName] = [
	&"ceiling_hatches",
	&"far_crates",
	&"big_crate",
	&"laser",
	&"wall_ninjas",
	&"wrapped_piles",
]

var _hides: Array[WarehouseHide] = []
var _laser: WarehouseLaser
var _layout: StringName = &""


func setup() -> void:
	_layout = LAYOUTS[randi() % LAYOUTS.size()]
	match _layout:
		&"ceiling_hatches":
			_build_ceiling_hatches()
		&"far_crates":
			_build_far_crates()
		&"big_crate":
			_build_big_crate()
		&"laser":
			_build_laser()
		&"wall_ninjas":
			_build_wall_ninjas()
		_:
			_build_wrapped_piles()


func trigger_all() -> void:
	if _laser and not _laser.is_fired():
		_laser.trigger()
	for hide in _hides:
		if is_instance_valid(hide) and not hide.is_fired():
			hide.trigger()


func _build_ceiling_hatches() -> void:
	var spots: Array[Vector3] = [
		Vector3(5.5, 7.55, -1.4),
		Vector3(12.2, 7.55, 1.5),
		Vector3(15.4, 7.55, -0.6),
		Vector3(7.8, 7.55, 1.8),
	]
	var tarp := WarehouseLook.tarp_dark_material()
	for i in spots.size():
		var hide := _make_hide("Hatch_%d" % i)
		hide.position = spots[i]
		hide.drop_from_ceiling = true
		hide.reveal = WarehouseHide.Reveal.FALL
		hide.dummy_count = 1
		hide.dummy_offsets = _offsets([Vector3(0.0, -7.55, 0.0)])
		hide.configure_cover(Vector3(1.6, 0.08, 1.4), tarp, false, true)


func _build_far_crates() -> void:
	var crate := WarehouseLook.crate_material()
	var zs: Array[float] = [-3.2, 0.0, 3.2]
	for i in zs.size():
		var hide := _make_hide("FarCrate_%d" % i)
		hide.position = Vector3(18.55, 0.0, zs[i])
		hide.reveal = WarehouseHide.Reveal.BURST
		hide.dummy_count = 1
		hide.dummy_offsets = _offsets([Vector3(-0.9, 0.0, 0.0)])
		hide.configure_cover(Vector3(1.15, 1.45, 1.35), crate, true, true)
		hide.add_walk_trigger(Vector3(0.7, 1.6, 1.2), Vector3(0.7, 0.8, 0.0))


func _build_big_crate() -> void:
	var hide := _make_hide("BigCrate")
	hide.position = Vector3(6.2, 0.0, 0.0)
	hide.reveal = WarehouseHide.Reveal.BURST
	hide.dummy_count = 4
	hide.dummy_offsets = _offsets([
		Vector3(-0.7, 0.0, -0.6),
		Vector3(-0.7, 0.0, 0.6),
		Vector3(0.7, 0.0, -0.5),
		Vector3(0.7, 0.0, 0.5),
	])
	hide.configure_cover(Vector3(2.15, 2.05, 2.15), WarehouseLook.canvas_material(), true, true)
	hide.add_rope(Vector3(2.2, 0.05, 0.06), Vector3(0.0, 1.4, 0.0), WarehouseLook.rope_material())
	hide.add_rope(Vector3(0.06, 0.05, 2.2), Vector3(0.0, 1.05, 0.0), WarehouseLook.rope_material())


func _build_laser() -> void:
	_laser = WarehouseLaser.new()
	_laser.name = "LaserTrap"
	_laser.position = Vector3(7.2, 0.0, 0.0)
	add_child(_laser)
	_laser.setup(4.4)
	_laser.sprung.connect(_on_laser_sprung)
	_add_laser_pockets()


func _add_laser_pockets() -> void:
	var tarp := WarehouseLook.tarp_material()
	var spots: Array[Vector3] = [Vector3(8.4, 0.0, -3.35), Vector3(8.4, 0.0, 3.35)]
	for i in spots.size():
		var hide := _make_hide("LaserPocket_%d" % i)
		hide.position = spots[i]
		hide.reveal = WarehouseHide.Reveal.PEEL
		hide.dummy_count = 1
		hide.dummy_offsets = _offsets([Vector3(0.0, 0.0, 0.0)])
		hide.configure_cover(Vector3(0.9, 1.7, 1.1), tarp, true, true)


func _on_laser_sprung() -> void:
	for hide in _hides:
		if is_instance_valid(hide) and not hide.is_fired():
			hide.trigger()


func _build_wall_ninjas() -> void:
	var tarp := WarehouseLook.tarp_dark_material()
	var spots: Array[Dictionary] = [
		{"pos": Vector3(5.2, 0.0, -5.72), "yaw": 0.0},
		{"pos": Vector3(12.6, 0.0, -5.72), "yaw": 0.0},
		{"pos": Vector3(5.2, 0.0, 5.72), "yaw": PI},
		{"pos": Vector3(12.6, 0.0, 5.72), "yaw": PI},
	]
	for i in spots.size():
		var spec: Dictionary = spots[i]
		var hide := _make_hide("Ninja_%d" % i)
		hide.position = spec["pos"]
		hide.rotation.y = spec["yaw"]
		hide.reveal = WarehouseHide.Reveal.PEEL
		hide.dummy_count = 1
		hide.dummy_offsets = _offsets([Vector3(0.0, 0.0, 0.55)])
		hide.configure_cover(Vector3(1.35, 2.15, 0.12), tarp, false, true)


func _build_wrapped_piles() -> void:
	var tarp := WarehouseLook.tarp_material()
	var canvas := WarehouseLook.canvas_material()
	var specs: Array[Dictionary] = [
		{"pos": Vector3(4.2, 0.0, -3.7), "size": Vector3(1.6, 1.35, 1.7), "mat": tarp},
		{"pos": Vector3(9.1, 0.0, 3.85), "size": Vector3(1.85, 1.55, 1.5), "mat": canvas},
		{"pos": Vector3(14.4, 0.0, -3.55), "size": Vector3(1.5, 1.2, 1.6), "mat": tarp},
	]
	for i in specs.size():
		var spec: Dictionary = specs[i]
		var hide := _make_hide("Pile_%d" % i)
		hide.position = spec["pos"]
		hide.reveal = WarehouseHide.Reveal.BURST
		hide.dummy_count = 1
		hide.dummy_offsets = _offsets([Vector3(0.8, 0.0, 0.0)])
		hide.configure_cover(spec["size"] as Vector3, spec["mat"] as Material, true, true)
		hide.add_rope(
			Vector3(spec["size"].x + 0.04, 0.05, 0.05),
			Vector3(0.0, spec["size"].y * 0.55, 0.0),
			WarehouseLook.rope_material()
		)


func _make_hide(node_name: String) -> WarehouseHide:
	var hide := WarehouseHide.new()
	hide.name = node_name
	add_child(hide)
	_hides.append(hide)
	return hide


func _offsets(values: Array) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for value in values:
		out.append(value as Vector3)
	return out
