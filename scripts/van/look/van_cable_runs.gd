class_name VanCableRuns
extends Node3D
## Seeded power tree: a thick generator-to-relay feed along the right trunk, relay drops to the PC
## rig, welding bench and hopper, ceiling lamp taps, then wall junk (battery bank, cans, gas bottles).

const Router := preload("res://scripts/van/look/van_cable_router.gd")

const LIGHTING_PATH := ^"../../Lighting"
const WALLS_PATH := ^"../Interior/Shell/SideWalls"
const PROPS_PATH := ^"../Interior/Props"
const PORT_GROUP := &"machine_power_ports"
const K_GEN := "generator_source"
const K_HUB := "relay_rack_hub"
const K_OUT := "relay_rack_out"
const K_PC := "pc_rig_load"
const K_BENCH := "welding_bench_load"
const K_HOPPER := "scrap_hopper_load"

const TRUNK_HALF_X := 2.2
const TRUNK_Y := 2.95
const TRUNK_Z_MIN := -4.4
const TRUNK_Z_MAX := 4.4
const TRUNK_STEPS := 7
const FEED_DROP := 0.14
const FRONT_Z := -4.35
const GAP_Z_MIN := 0.85
const GAP_Z_MAX := 1.61
const CLAMP_STEP := 0.6
const TAPE_STEP := 0.9
const ROUTE_COUNT := 4

var _router: Router
var _steel: Material
var _tie: Material
var _tape: Material
var _insul: Array[Material] = []
var _colors: Array[Material] = []
var _plan := PackedFloat32Array()
var _style_seed := 0
var _clamp_count := 0
var _used := {}
var _trunk_l := PackedVector3Array()
var _trunk_r := PackedVector3Array()


func rebuild_look(look: VanLook) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_used.clear()
	_clamp_count = 0

	_router = Router.new(get_node_or_null(WALLS_PATH) as VanSideWall)
	_steel = MachineParts.dark(Color(0.18, 0.18, 0.17), 0.8)
	_tie = MachineParts.dark(Color(0.3, 0.3, 0.28), 0.85)
	_tape = MachineParts.dark(Color(0.33, 0.32, 0.29), 0.9)
	_insul = [
		MachineParts.dark(Color(0.05, 0.05, 0.05), 0.95),
		MachineParts.dark(Color(0.2, 0.08, 0.05), 0.9),
		MachineParts.dark(Color(0.22, 0.21, 0.16), 0.9),
	]
	var rng := look.rng_for(&"cables")
	# Every draw below happens even if a route is skipped, so a missing port never reshuffles.
	_colors.clear()
	for i: int in range(ROUTE_COUNT):
		_colors.append(_insul[rng.randi() % _insul.size()])
	_colors[0] = _insul[1]
	_plan.clear()
	for i: int in range(ROUTE_COUNT):
		_plan.append(float(rng.randi_range(1, 2)))
		_plan.append(rng.randf_range(0.2, 0.45))
		_plan.append(rng.randf_range(0.55, 0.8))
	_style_seed = rng.randi()

	_trunk_l = _build_trunk(-1.0, rng)
	_trunk_r = _build_trunk(1.0, rng)
	if is_inside_tree():
		var ports := _router.read_ports(self, PORT_GROUP)
		var keepouts := _router.build_keepouts(get_node_or_null(PROPS_PATH), self)
		_build_feed(ports, keepouts)
		_build_pc(ports, keepouts)
		_build_bench(ports, keepouts)
		_build_hopper(ports, keepouts)
	_build_lamp_drops()
	_build_junk(rng)


func _trunk_x() -> float:
	return minf(TRUNK_HALF_X, _router.wall_x(TRUNK_Y) - 0.14)


func _build_trunk(sx: float, rng: RandomNumberGenerator) -> PackedVector3Array:
	var side := "L" if sx < 0.0 else "R"
	var x := sx * _trunk_x()
	var pts := PackedVector3Array()
	for i: int in range(TRUNK_STEPS):
		var t := float(i) / float(TRUNK_STEPS - 1)
		var z := lerpf(TRUNK_Z_MIN, TRUNK_Z_MAX, t)
		var sag := 0.0
		if i > 0 and i < TRUNK_STEPS - 1:
			sag = rng.randf_range(0.03, 0.08)
		pts.append(Vector3(x, TRUNK_Y - sag, z))

	MachineParts.cable_bundle(self, pts, _insul[0], 0.018, 4)
	_add_ties(rng, pts, side)
	_add_splices(rng, pts, side)
	return pts


func _add_ties(rng: RandomNumberGenerator, pts: PackedVector3Array, side: String) -> void:
	var z := TRUNK_Z_MIN + rng.randf_range(0.7, 1.0)
	var idx := 0
	while z < TRUNK_Z_MAX:
		if _claim(&"tie", pts[0].x, z):
			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.05, 0.05, 0.03)
			_add_mesh("Tie%s%d" % [side, idx], mesh, _tie, Vector3(pts[0].x, _trunk_y(pts, z), z))
			idx += 1
		z += rng.randf_range(0.7, 1.0)


func _add_splices(rng: RandomNumberGenerator, pts: PackedVector3Array, side: String) -> void:
	for i: int in range(rng.randi_range(1, 2)):
		var z := rng.randf_range(TRUNK_Z_MIN + 0.4, TRUNK_Z_MAX - 0.4)
		if _claim(&"splice", pts[0].x, z):
			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.07, 0.07, 0.14)
			_add_mesh("Splice%s%d" % [side, i], mesh, _tape, Vector3(pts[0].x, _trunk_y(pts, z), z))


## Linear height along a trunk's sampled points, used to anchor junctions and lamp taps.
func _trunk_y(pts: PackedVector3Array, z: float) -> float:
	for i: int in range(pts.size() - 1):
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		if z >= a.z and z <= b.z:
			return lerpf(a.y, b.y, (z - a.z) / (b.z - a.z))
	return pts[pts.size() - 1].y


## True the first time hardware of this kind is placed at this z on this trunk side.
func _claim(kind: StringName, side_x: float, z: float) -> bool:
	var key := "%s_%d_%d" % [kind, int(signf(side_x)), roundi(z / 0.2)]
	if _used.has(key):
		return false
	_used[key] = true
	return true


func _junction(sx: float, z: float) -> void:
	if not _claim(&"junction", sx, z):
		return
	var pts := _trunk_r if sx > 0.0 else _trunk_l
	var pos := Vector3(sx * _trunk_x(), _trunk_y(pts, z) - 0.06, z)
	_router.add_junction_box(self, pos, _steel, _insul[0])


## Point on the wall side of the cabin at height y, inset from the wall by gap.
func _wall_pt(sx: float, y: float, z: float, gap: float) -> Vector3:
	return Vector3(sx * (_router.wall_x(y) - gap), y, z)


func _build_feed(ports: Dictionary, keepouts: Array[AABB]) -> void:
	if not (ports.has(K_GEN) and ports.has(K_HUB)):
		return
	var g: Vector3 = ports[K_GEN]
	var h: Vector3 = ports[K_HUB]
	var tx := _trunk_x() - 0.05
	var fy := TRUNK_Y - FEED_DROP
	# Slack loop first: a 0.25 m sagging U toward the gap's far edge, then up into the trunk.
	var a := Vector3(g.x, g.y + 0.35, g.z)
	var a2 := Vector3(g.x, a.y, minf(g.z + 0.25, GAP_Z_MAX - 0.1))
	var mid := (a + a2) * 0.5 + Vector3(0.0, -0.12, 0.0)
	var pts := _router.route(PackedVector3Array([
		g, a, mid, a2, Vector3(tx, fy, a2.z), Vector3(tx, fy, FRONT_Z),
		Vector3(h.x, fy, FRONT_Z), h,
	]), keepouts)
	MachineParts.cable_bundle(self, pts, _colors[0], 0.032, 2)
	_furnish(pts, 0.032, CLAMP_STEP, TAPE_STEP)
	_splice_route(pts, 0.032, 0)
	_junction(1.0, a2.z)
	for corner: Vector3 in [Vector3(tx, fy, FRONT_Z), Vector3(h.x, fy, FRONT_Z)]:
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.11, 0.11, 0.11)
		_add_mesh("Elbow", mesh, _steel, corner)


func _build_pc(ports: Dictionary, keepouts: Array[AABB]) -> void:
	if not (ports.has(K_OUT) and ports.has(K_PC)):
		return
	var o: Vector3 = ports[K_OUT]
	var p: Vector3 = ports[K_PC]
	var pts := _router.route(PackedVector3Array([o, o + Vector3(0.0, -0.2, 0.0), p]), keepouts)
	pts = _router.sag(pts, 0.12)
	_lay(pts, 1, 0.02, 3)
	_router.add_plug(self, p, (p - pts[pts.size() - 2]).normalized(), _steel)


func _build_bench(ports: Dictionary, keepouts: Array[AABB]) -> void:
	if not (ports.has(K_BENCH) and ports.has(K_GEN)):
		return
	var b: Vector3 = ports[K_BENCH]
	var g: Vector3 = ports[K_GEN]
	# Up the wall inside the window gap; the jog in z happens low (y 0.9) where windows are absent.
	var gz := clampf(g.z, GAP_Z_MIN + 0.1, GAP_Z_MAX - 0.1)
	var pts := _router.route(PackedVector3Array([
		b, _wall_pt(1.0, b.y + 0.15, b.z, 0.12), _wall_pt(1.0, 0.9, b.z, 0.12),
		_wall_pt(1.0, 0.9, gz, 0.12), _wall_pt(1.0, g.y, gz, 0.12), g,
	]), keepouts)
	_lay(pts, 2, 0.022, 3)
	_router.add_plug(self, b, (b - pts[1]).normalized(), _steel)


func _build_hopper(ports: Dictionary, keepouts: Array[AABB]) -> void:
	if not (ports.has(K_OUT) and ports.has(K_HOPPER)):
		return
	var o: Vector3 = ports[K_OUT]
	var h: Vector3 = ports[K_HOPPER]
	var lx := -_trunk_x() + 0.05
	var fy := TRUNK_Y - FEED_DROP
	var hz := clampf(h.z, GAP_Z_MIN + 0.1, GAP_Z_MAX - 0.1)
	var pts := _router.route(PackedVector3Array([
		o, Vector3(lx, fy, o.z), Vector3(lx, fy, hz), _wall_pt(-1.0, 1.9, hz, 0.12),
		_wall_pt(-1.0, h.y + 0.15, hz, 0.12), h,
	]), keepouts)
	_lay(pts, 3, 0.022, 3)
	_junction(-1.0, o.z)


## Bundle plus clamps and taped splices for one non-feed route; idx picks its seeded plan.
func _lay(pts: PackedVector3Array, idx: int, radius: float, strands: int) -> void:
	MachineParts.cable_bundle(self, pts, _colors[idx], radius, strands)
	_furnish(pts, radius, CLAMP_STEP, 0.0)
	_splice_route(pts, radius, idx)


## Clamps every clamp_step and tape bands every tape_step (0 = none) of arc length along pts.
func _furnish(pts: PackedVector3Array, radius: float, clamp_step: float, tape_step: float) -> void:
	var travelled := 0.0
	var next_clamp := clamp_step * 0.5
	var next_tape := tape_step * 0.5
	for i: int in range(pts.size() - 1):
		var seg_len := pts[i].distance_to(pts[i + 1])
		if seg_len < 0.01:
			continue
		var dir := (pts[i + 1] - pts[i]) / seg_len
		while next_clamp < travelled + seg_len:
			var pos := pts[i] + dir * (next_clamp - travelled)
			var style := int((_style_seed + _clamp_count * 7919) % 3)
			_router.add_clamp(self, pos, dir, radius, style, _steel, _tie)
			_clamp_count += 1
			next_clamp += clamp_step
		while tape_step > 0.0 and next_tape < travelled + seg_len:
			_router.add_tape_band(self, pts[i] + dir * (next_tape - travelled), dir, radius, _tape, 0.05)
			next_tape += tape_step
		travelled += seg_len


func _splice_route(pts: PackedVector3Array, radius: float, idx: int) -> void:
	var total := 0.0
	for i: int in range(pts.size() - 1):
		total += pts[i].distance_to(pts[i + 1])
	for k: int in range(int(_plan[idx * 3])):
		var want := total * _plan[idx * 3 + 1 + k]
		var travelled := 0.0
		for i: int in range(pts.size() - 1):
			var seg_len := pts[i].distance_to(pts[i + 1])
			if seg_len >= 0.01 and travelled + seg_len >= want:
				var dir := (pts[i + 1] - pts[i]) / seg_len
				_router.add_tape_band(self, pts[i] + dir * (want - travelled), dir, radius + 0.008,
						_tape, 0.12)
				break
			travelled += seg_len


## Taps each interior ceiling lamp (Lighting sibling under VanRig) within x +/-1.5 from the nearer
## trunk, with a junction box where the tap meets it.
func _build_lamp_drops() -> void:
	var lighting := get_node_or_null(LIGHTING_PATH)
	if lighting == null:
		return
	for child in lighting.get_children():
		if not (child is OmniLight3D):
			continue
		var light := child as OmniLight3D
		if light.light_cull_mask != VanLighting.LAYER_VAN_INTERIOR:
			continue
		if absf(light.position.x) > 1.5:
			continue
		var sx := 1.0 if light.position.x >= 0.0 else -1.0
		var trunk_pts := _trunk_r if sx > 0.0 else _trunk_l
		var anchor := Vector3(sx * _trunk_x(), _trunk_y(trunk_pts, light.position.z), light.position.z)
		var target := Vector3(light.position.x, minf(light.position.y + 0.05, 2.95), light.position.z)
		MachineParts.cable_bundle(self, PackedVector3Array([anchor, target]), _insul[0], 0.015, 3)
		_junction(sx, light.position.z)


func _build_junk(rng: RandomNumberGenerator) -> void:
	var bx := -(_router.wall_x(0.25) - 0.16)
	var batt_zs: Array[float] = [-1.3, -1.05, -0.8]
	var tops := PackedVector3Array()
	for z: float in batt_zs:
		var batt := MachineParts.battery(self, Vector3(bx, 0.0, z), _steel, _steel)
		batt.rotation.y = rng.randf_range(-0.3, 0.3)
		tops.append(Vector3(bx, 0.25, z))
	MachineParts.cable_bundle(self, tops, _insul[1], 0.015, 2)
	# Jumper rides 0.26-0.3 m inside the wall so it clears the window frames, then ties into the trunk.
	var riser := PackedVector3Array([
		Vector3(bx, 0.27, -1.05), Vector3(bx, 0.95, -1.05), _wall_pt(-1.0, 1.6, -1.05, 0.3),
		_wall_pt(-1.0, 2.3, -1.05, 0.26),
		Vector3(-_trunk_x(), _trunk_y(_trunk_l, -1.05) - 0.06, -1.05),
	])
	MachineParts.cable_bundle(self, riser, _insul[1], 0.015, 2)
	_furnish(riser, 0.015, CLAMP_STEP, 0.0)
	_junction(-1.0, -1.05)
	_router.add_coil(self, Vector3(-(_router.wall_x(0.72) - 0.11), 0.72, -0.45), _insul[2], _steel)

	for z: float in [2.0, 2.35]:
		var can := MachineParts.jerry_can(self, Vector3(-(_router.wall_x(0.5) - 0.2), 0.0, z), _steel)
		can.rotation.y = rng.randf_range(-0.3, 0.3)

	var bottle_mat := MachineParts.dark(Color(0.32, 0.11, 0.07), 0.8)
	var idx := 0
	for z: float in [-1.95, -1.7]:
		var gx := _router.wall_x(0.62) - 0.2
		var bottle_mesh := CylinderMesh.new()
		bottle_mesh.top_radius = 0.11
		bottle_mesh.bottom_radius = 0.11
		bottle_mesh.height = 0.62
		bottle_mesh.radial_segments = 8
		var body := _add_mesh("GasBottle%d" % idx, bottle_mesh, bottle_mat, Vector3(gx, 0.31, z))
		body.rotation.y = rng.randf_range(-0.3, 0.3)

		var cap_mesh := CylinderMesh.new()
		cap_mesh.top_radius = 0.03
		cap_mesh.bottom_radius = 0.03
		cap_mesh.height = 0.06
		_add_mesh("GasBottleCap%d" % idx, cap_mesh, _steel, Vector3(gx, 0.65, z))

		var strap_mesh := BoxMesh.new()
		strap_mesh.size = Vector3(0.3, 0.03, 0.03)
		_add_mesh("GasBottleStrap%d" % idx, strap_mesh, _steel, Vector3(gx, 0.5, z))
		_build_spare_hose(Vector3(gx, 0.68, z))
		idx += 1


## Spare torch hose: bottle cap up to a wall clip 0.5 m higher, ending in a short capped stub.
func _build_spare_hose(cap: Vector3) -> void:
	var cy := cap.y + 0.5 - 0.03
	var cx := _router.wall_x(cy) - 0.07
	var clip := Vector3(cx, cy, cap.z)
	var stub := Vector3(cx, cy - 0.05, cap.z - 0.15)
	var pts := PackedVector3Array([
		cap, Vector3(cap.x + 0.02, cap.y + 0.15, cap.z), Vector3(cx, cy - 0.15, cap.z), clip, stub,
	])
	MachineParts.cable_bundle(self, pts, _insul[0], 0.012, 1)
	_router.add_clamp(self, clip, Vector3(0.0, 0.0, -1.0), 0.012, 0, _steel, _tie)
	var end_cap := CylinderMesh.new()
	end_cap.top_radius = 0.02
	end_cap.bottom_radius = 0.02
	end_cap.height = 0.03
	end_cap.radial_segments = 8
	_add_mesh("HoseCap", end_cap, _steel, stub)


func _add_mesh(mesh_name: String, mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = mesh_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.layers = 2
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi
