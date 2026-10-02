extends RefCounted
## Debug `arms frame`: how much of the player camera's picture the arms and gun cover, found by
## drawing them white and diffing against the normal frame.

const _STEP := 2
const _THRESHOLD := 0.25


## One line: share of the screen, bounding box, rule-of-thirds cells, fov and image size.
func run(vm: Node) -> String:
	if DisplayServer.get_name() == "headless":
		return "FRAME n/a (headless, no renderer)"
	var vp := vm.get_viewport()
	RenderingServer.force_draw(false)
	var base := vp.get_texture().get_image()
	if base == null or base.is_empty():
		return "FRAME ERR no viewport image"
	var overlay := StandardMaterial3D.new()
	overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	overlay.albedo_color = Color.WHITE
	overlay.cull_mode = BaseMaterial3D.CULL_DISABLED
	overlay.use_fov_override = vm.viewmodel_fov > 0.0
	overlay.fov_override = vm.viewmodel_fov
	var geoms: Array[GeometryInstance3D] = []
	var olds: Array[Material] = []
	_collect(vm.get_node("Rig"), geoms)
	for g in geoms:
		olds.append(g.material_overlay)
		g.material_overlay = overlay
	RenderingServer.force_draw(false)
	var lit := vp.get_texture().get_image()
	for i in geoms.size():
		geoms[i].material_overlay = olds[i]
	if lit == null or lit.is_empty():
		return "FRAME ERR no viewport image"
	var w := mini(base.get_width(), lit.get_width())
	var h := mini(base.get_height(), lit.get_height())
	var count := 0
	var min_x := w
	var max_x := -1
	var min_y := h
	var max_y := -1
	for y in range(0, h, _STEP):
		for x in range(0, w, _STEP):
			var d := absf(lit.get_pixel(x, y).get_luminance() - base.get_pixel(x, y).get_luminance())
			if d > _THRESHOLD:
				count += 1
				min_x = mini(min_x, x)
				max_x = maxi(max_x, x)
				min_y = mini(min_y, y)
				max_y = maxi(max_y, y)
	var line: String
	if count == 0:
		line = "FRAME 0.0%% (no viewmodel pixels) fov %.1f" % vm.viewmodel_fov
	else:
		var fx0 := float(min_x) / w
		var fx1 := float(max_x) / w
		var fy0 := float(min_y) / h
		var fy1 := float(max_y) / h
		var pct := float(count * _STEP * _STEP) * 100.0 / (float(w) * float(h))
		line = "FRAME %.1f%% box x %.2f..%.2f y %.2f..%.2f thirds x %d-%d y %d-%d fov %.1f %dx%d" % [
			pct, fx0, fx1, fy0, fy1, _third(fx0), _third(fx1), _third(fy0), _third(fy1),
			vm.viewmodel_fov, w, h]
	print(line)
	return line


func _third(frac: float) -> int:
	return clampi(int(frac * 3.0), 0, 2) + 1


func _collect(node: Node, out: Array[GeometryInstance3D]) -> void:
	for child in node.get_children():
		var g := child as GeometryInstance3D
		if g != null and g.is_visible_in_tree():
			out.append(g)
		_collect(child, out)
