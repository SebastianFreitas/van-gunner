extends RefCounted
## Debug `arms frame`: how much of the player camera's picture the arms and gun cover, found by
## drawing them white and diffing against the normal frame.

const _STEP := 2
const _THRESHOLD := 0.25
## Bars on the share of the screen the viewmodel may cover, in percent.
const COVER_MIN := 12.0
const COVER_MAX := 28.0
## Viewmodel pixels above the lower third (y < 2/3 of the height), percent of the screen.
const UPPER_MAX := 2.0
## The crosshair zone in screen fractions, and how much of its own pixels the viewmodel may fill.
const AIM_ZONE := Rect2(0.35, 0.30, 0.30, 0.30)
const AIM_MAX := 0.5


## One line: share of the screen, bounding box, rule-of-thirds cells, upper and aim shares, fov,
## image size and OK or BAD with the bars that failed.
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
	var upper := 0
	var aim := 0
	var zone := Rect2(AIM_ZONE.position.x * w, AIM_ZONE.position.y * h,
			AIM_ZONE.size.x * w, AIM_ZONE.size.y * h)
	var min_x := w
	var max_x := -1
	var min_y := h
	var max_y := -1
	for y in range(0, h, _STEP):
		for x in range(0, w, _STEP):
			var d := absf(lit.get_pixel(x, y).get_luminance() - base.get_pixel(x, y).get_luminance())
			if d > _THRESHOLD:
				count += 1
				if y * 3 < h * 2:
					upper += 1
				if zone.has_point(Vector2(x, y)):
					aim += 1
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
		var upper_pct := float(upper * _STEP * _STEP) * 100.0 / (float(w) * float(h))
		var aim_pct := float(aim * _STEP * _STEP) * 100.0 / (zone.size.x * zone.size.y)
		var bad: Array[String] = []
		if pct < COVER_MIN or pct > COVER_MAX:
			bad.append("cover")
		if upper_pct > UPPER_MAX:
			bad.append("upper")
		if aim_pct > AIM_MAX:
			bad.append("aim")
		var verdict := "OK" if bad.is_empty() else "BAD " + " ".join(bad)
		line = ("FRAME %.1f%% box x %.2f..%.2f y %.2f..%.2f thirds x %d-%d y %d-%d "
				+ "upper %.1f%% aim %.1f%% fov %.1f %dx%d %s") % [
			pct, fx0, fx1, fy0, fy1, _third(fx0), _third(fx1), _third(fy0), _third(fy1),
			upper_pct, aim_pct, vm.viewmodel_fov, w, h, verdict]
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
