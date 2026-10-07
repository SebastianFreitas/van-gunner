class_name SmokeShotsCabin
extends RefCounted
## Builds and shoots the cabin views for tools/smoke.py --shots: from the rear doors toward the
## cab and from the cab toward the rear doors, then close views of the left wall, the right wall
## and the left rear arch box, so the salvage kit can be judged. Lives here, not in smoke_shots.gd, which is at the line cap.

## Camera spots, rig-local (van-local -Z is the cab, the body spans z -4.7..4.7).
const _FROM_REAR := Vector3(0.0, 2.0, 4.2)
const _FROM_REAR_TARGET := Vector3(0.0, 1.5, -4.7)
const _FROM_CAB := Vector3(0.0, 2.0, -4.2)
const _FROM_CAB_TARGET := Vector3(0.0, 1.5, 4.55)


## One row per view: {label, from, target}. Doors and windows stay closed and intact.
static func views() -> Array[Dictionary]:
	return [
		{"label": "idle-cabin-from-rear", "from": _FROM_REAR, "target": _FROM_REAR_TARGET},
		{"label": "idle-cabin-from-cab", "from": _FROM_CAB, "target": _FROM_CAB_TARGET},
		{"label": "idle-left-wall-close", "from": Vector3(0.2, 1.7, 0.2),
			"target": Vector3(-2.0, 2.0, 0.2)},
		{"label": "idle-right-wall-close", "from": Vector3(-0.2, 1.7, 0.2),
			"target": Vector3(2.0, 2.0, 0.2)},
		{"label": "idle-rear-arch-close", "from": Vector3(0.2, 1.7, 4.2),
			"target": Vector3(-1.8, 0.6, 3.2)},
	]


## Shoots the two views at IDLE, then the same two for each `--van-seeds` look seed (restored
## with `rebuild(original)` afterwards). Prefix "k" so the "v" and "c" numbering never shifts.
static func run(shots: Node) -> void:
	var rig: Node3D = shots._rig()
	if rig == null:
		return
	var hidden: Array[CanvasLayer] = shots._hide_ui()
	var previous := shots.get_viewport().get_camera_3d()
	for view in views():
		await shots._save_van_view(rig, view["from"], view["label"], view["target"], "k")
	var seeds: int = shots.van_seeds
	var look := shots.get_tree().get_first_node_in_group(VanLook.GROUP) as VanLook
	if seeds > 0 and look != null:
		var original := look.van_seed
		for i in seeds:
			look.rebuild(i + 1)
			for view in views():
				await shots._save_van_view(
					rig, view["from"], "%s-van-seed-%d" % [view["label"], i + 1],
					view["target"], "k"
				)
		look.rebuild(original)
	if previous != null:
		previous.make_current()
	for layer in hidden:
		layer.visible = true
