extends Node


func _ready() -> void:
	var van: Node = load("res://scenes/van/van.tscn").instantiate()
	add_child(van)
	await get_tree().process_frame
	await get_tree().process_frame

	var player: Node3D = van.get_node("TravelPath/VanFollow/VanRig/Player")
	for path in [
		"res://resources/items/chew_tobacco.tres",
		"res://resources/items/ricochet_rounds.tres",
		"res://resources/items/rubber_casings.tres",
		"res://resources/items/frag_grenade.tres",
		"res://resources/items/adrenaline_stim.tres",
	]:
		(load(path) as ItemDefinition).collect(player)

	GameSession.add_coins(37)
	GameSession.damage_van(28.0)

	var bench: BenchScreen = van.get_node("HUD/BenchScreen")
	bench.open()
	await get_tree().process_frame

	var cells := _find_cells(bench.get_node("%ItemsColumn"))
	if cells.size() > 4:
		cells[4].mouse_entered.emit()
		await get_tree().process_frame
		bench.set_process(false)
		var tooltip: PanelContainer = bench.get_node("%Tooltip")
		tooltip.reset_size()
		tooltip.global_position = Vector2(700, 300)

	for i in range(6):
		await RenderingServer.frame_post_draw

	var image := get_viewport().get_texture().get_image()
	image.save_png("res://bench_preview.png")
	print("SAVED")
	get_tree().quit()


func _find_cells(root: Node) -> Array[Control]:
	var found: Array[Control] = []
	for child in root.get_children():
		if child is PanelContainer:
			found.append(child)
		else:
			found.append_array(_find_cells(child))
	return found
