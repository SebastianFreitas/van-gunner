extends RefCounted
## The seven floor views (f01-...) of the smoke shots, split from `smoke_shots_closeups.gd`.


const _CloseupViews := preload("res://tools/smoke/smoke_shots_closeups.gd")


## Saves every floor view through `shots` (the `smoke_shots.gd` node), the rear doors set per view.
static func save_all(shots: Node, rig: Node3D) -> void:
	var rear_doors := shots.get_tree().get_first_node_in_group(&"rear_doors")
	for view in floor_views(rig):
		var want_open: bool = view.get("rear_open", false)
		if rear_doors != null and want_open != rear_doors.is_open():
			await _CloseupViews.set_rear_doors(rear_doors, want_open)
		var from: Vector3 = view["from"]
		var target: Vector3 = view["target"]
		if view.get("whole_ram", false):
			# Pin positions move with the door pose, so aim after it: the ram is about 2.5 m long.
			var body_at := _part_at(rig, "BodyPin", target)
			var door_at := _part_at(rig, "DoorPin", target)
			target = (body_at + door_at) * 0.5
			# 2.5 m out on the cabin side, perpendicular to the pin line, 0.5 m low.
			var along := door_at - body_at
			var side := Vector3(-along.z, 0.0, along.x).normalized()
			if side.z > 0.0:
				side = -side
			from = target + side * 2.5 + Vector3(0.0, -0.5, 0.0)
			# The open leaf turns the line toward the side wall: shoot from the other side then.
			if absf(from.x) > VanInteriorSize.BOTTOM_HALF - 0.2:
				from = target - side * 2.5 + Vector3(0.0, -0.5, 0.0)
		var lamp: OmniLight3D = null
		if view.get("lamp", false):
			lamp = _inspection_lamp(rig, from)
		await shots.call(&"_save_van_view", rig, from, view["label"], target, "f", 60.0 if view.get("whole_ram", false) else 0.0)
		if lamp != null:
			# A light freed while paired can crash (van-render-layers.md): hide, wait, free.
			lamp.visible = false
			await shots.get_tree().process_frame
			lamp.queue_free()


## Van-local, shot in game light: rear low, the stairs, the mid room low, the rear from high up,
## the welded plates close under the rear work lamp, and the donor leaf's top ram with the rear
## doors open (f06) and closed (f07), set by `rear_open`.
static func floor_views(rig: Node3D) -> Array[Dictionary]:
	var ram := rig.find_child("TopRam", true, false) as Node3D
	var ram_at := rig.to_local(ram.global_position) if ram != null else Vector3(-3.0, 3.4, 6.2)
	# Inside the cabin at eye height, 2 m cabin-ward (-Z) of the ram, looking at it.
	var cam_from := Vector3(ram_at.x, 2.0, ram_at.z - 1.5)
	var plate_at := _part_at(rig, "BodyPin", ram_at)
	var battery_at := _part_at(rig, "FloorBattery", plate_at - Vector3(0.0, 3.0, 0.0))
	var power_mid := (plate_at + battery_at) * 0.5
	var power_from := Vector3(power_mid.x, 2.0, power_mid.z - 3.6)
	return [
		{"label": "floor-rear-low", "from": Vector3(0.0, 0.6, 5.5),
				"target": Vector3(-1.5, 0.3, 1.3)},
		{"label": "floor-stairs", "from": Vector3(-2.5, 1.6, 2.6),
				"target": Vector3(-2.5, 0.2, 1.1)},
		{"label": "floor-mid-low", "from": Vector3(-3.0, 1.8, -0.7),
				"target": Vector3(-2.5, 0.0, -3.5)},
		{"label": "floor-rear-high", "from": Vector3(-0.2, 2.5, 6.6),
				"target": Vector3(-1.9, 0.2, 2.6)},
		{"label": "floor-plates-close", "from": Vector3(0.0, 3.0, 6.3),
				"target": Vector3(0.0, 0.0, 4.3)},
		{"label": "topram", "from": cam_from, "target": ram_at - Vector3(0.0, 0.3, 0.0),
				"rear_open": true, "lamp": true, "whole_ram": true},
		{"label": "topram-closed", "from": cam_from,
				"target": ram_at - Vector3(0.0, 0.3, 0.0), "rear_open": false, "lamp": true,
				"whole_ram": true},
		{"label": "topram-power", "from": power_from, "target": power_mid,
				"rear_open": false, "lamp": true},
	]


## Rig-local global position of the named part, or `fallback` when the part is missing.
static func _part_at(rig: Node3D, part: String, fallback: Vector3) -> Vector3:
	# Pin names can gain a suffix when built, so match the prefix and skip the "...Lug" boxes.
	for node: Node in rig.find_children(part + "*", "Node3D", true, false):
		if not str(node.name).begins_with(part + "Lug"):
			return rig.to_local((node as Node3D).global_position)
	return fallback


## Shot-only light beside the camera so the blockout geometry reads; the caller frees it.
static func _inspection_lamp(rig: Node3D, at: Vector3) -> OmniLight3D:
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.95, 0.85)
	lamp.light_energy = 2.0
	lamp.omni_range = 7.0
	lamp.shadow_enabled = false
	lamp.light_cull_mask = VanLighting.LAYER_VAN_INTERIOR
	lamp.position = at
	rig.add_child(lamp)
	return lamp
