extends FacadeSetPiece
## A cinema marquee bolted onto a storefront: a lit canopy slab with chasing bulb strips on its
## three outer faces, a backlit title panel, a vertical CINEMA blade, and one light underneath.


const _FacadeKeepOut := preload("res://scripts/travel/facades/facade_keep_out.gd")
const _FacadePlan := preload("res://scripts/travel/facades/facade_plan.gd")
const _FacadeMaterials := preload("res://scripts/travel/facades/facade_materials.gd")
const _FacadeMeshKit := preload("res://scripts/travel/facades/facade_mesh_kit.gd")
const _FacadeSigns := preload("res://scripts/travel/facades/facade_signs.gd")

const _BASE_Y := _FacadePlan.BASE_Y
const LIGHT_GROUP := &"facade_lights"
const MAX_LIGHTS := 12
const TITLES: Array[String] = [
	"NOW SHOWING", "LAST NIGHT", "DOUBLE BILL", "MIDNIGHT", "SOLD OUT", "NO REFUNDS",
]


func can_apply(plans: Array[Dictionary]) -> bool:
	return _target_index(plans) != -1


func pick_plan(plans: Array[Dictionary], _rng: RandomNumberGenerator) -> int:
	return _target_index(plans)


func apply_plans(plans: Array[Dictionary], _rng: RandomNumberGenerator) -> void:
	var target := _target_index(plans)
	if target == -1:
		return
	plans[target][&"params"][&"lit_ratio"] = 0.35
	plans[target][&"rare"] = id
	plans[target][&"suppress"] = [&"awnings", &"signs", &"fire_escape"]


func build(ctx: Dictionary) -> void:
	var host: Node3D = ctx[&"host"]
	var plan: Dictionary = ctx[&"plan"]
	var ss: float = ctx[&"side_sign"]
	var keep_out: RefCounted = ctx[&"keep_out"]
	var rng: RandomNumberGenerator = ctx[&"rng"]
	var width := float(plan[&"width"])
	var x_face := _FacadePlan.face_x(plan, ss)
	var z_mid := _z_at(plan, ss, width * 0.5)
	var canopy_c := Vector3(x_face - ss * 1.0, _BASE_Y + 7.1, z_mid)

	_FacadeMeshKit.add_box_node(
		host, "Marquee", Vector3(2.0, 1.0, 8.0), canopy_c, Vector3.ZERO,
		_FacadeMaterials.trim_material(plan[&"preset"]), true, keep_out
	)
	var road_x := canopy_c.x - ss * 1.0
	_build_bulb_strip(
		host, "MarqueeBulbsRoad", Vector3(road_x, canopy_c.y, z_mid), Vector3(0.02, 0.25, 8.0),
		keep_out, 8.0,
		func(st: SurfaceTool) -> void:
			_FacadeSigns.emit_face_x(
				st, road_x, canopy_c.y + 0.125, canopy_c.y - 0.125, z_mid, 8.0, ss
			)
	)
	for i in 2:
		var dz := -4.0 if i == 0 else 4.0
		var end_z := z_mid + dz
		var nz := -1.0 if i == 0 else 1.0
		_build_bulb_strip(
			host, "MarqueeBulbsEnd%d" % i, Vector3(canopy_c.x, canopy_c.y, end_z),
			Vector3(2.0, 0.25, 0.02), keep_out, 2.0,
			func(st: SurfaceTool) -> void:
				_FacadeSigns.emit_face_z(
					st, end_z, canopy_c.y + 0.125, canopy_c.y - 0.125, canopy_c.x, 2.0, nz
				)
		)

	var title_size := Vector3(0.1, 0.5, 7.0)
	var title_c := Vector3(
		road_x - ss * (_FacadeMeshKit.FACE_GAP + title_size.x * 0.5), canopy_c.y, z_mid
	)
	var title_word: String = TITLES[rng.randi() % TITLES.size()]
	_FacadeSigns.build_boxed(
		host, "TitlePanel", title_c, title_size, [Vector3(-ss, 0.0, 0.0)], keep_out,
		func(st: SurfaceTool) -> void:
			_FacadeSigns.emit_face_x(
				st, title_c.x - ss * title_size.x * 0.5, title_c.y + title_size.y * 0.5,
				title_c.y - title_size.y * 0.5, title_c.z, title_size.z, ss
			),
		_FacadeMaterials.sign_material(
			title_word, 4, false, Color(1.0, 0.95, 0.85), 2.0, 0, rng.randf() * 1000.0, 0.0, 0.0,
			8.0
		)
	)

	_FacadeSigns.build_blade(
		host, "CinemaBlade", plan, ss, keep_out, width * 0.5, "CINEMA", Vector3(1.2, 5.0, 0.3),
		8.0, Color(0.4, 0.9, 1.0), 2.4, rng.randf() * 1000.0, 0.0, 0.1
	)

	var light_c := Vector3(x_face - ss * 1.2, _BASE_Y + 6.7, z_mid)
	if not keep_out.allows(_FacadeKeepOut.box_aabb(light_c, Vector3(0.2, 0.2, 0.2))):
		return
	if (
		not host.is_inside_tree()
		or host.get_tree().get_nodes_in_group(LIGHT_GROUP).size() >= MAX_LIGHTS
	):
		return
	var light := OmniLight3D.new()
	light.name = "MarqueeLight"
	light.light_color = Color(1.0, 1.0, 1.0)
	light.light_energy = 1.8
	light.omni_range = 9.0
	light.shadow_enabled = false
	light.light_cull_mask = 1
	light.position = light_c
	light.add_to_group(LIGHT_GROUP)
	host.add_child(light)


## Builds one marquee bulb quad (never a BoxMesh: its UV atlas would scramble the bulb grid).
func _build_bulb_strip(
	host: Node3D, node_name: String, aabb_center: Vector3, aabb_size: Vector3, keep_out: RefCounted,
	length_m: float, emit_cb: Callable
) -> void:
	if not keep_out.allows(_FacadeKeepOut.box_aabb(aabb_center, aabb_size)):
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	emit_cb.call(st)
	_FacadeMeshKit.commit(
		host, st, node_name, _FacadeMaterials.marquee_material(Color(1.0, 0.85, 0.5), length_m),
		false
	)


## Widest plan at least 10 m wide with a storefront ground floor: the canopy needs a doorway.
func _target_index(plans: Array[Dictionary]) -> int:
	var best := -1
	var best_width := -1.0
	for i in plans.size():
		var width := float(plans[i].get(&"width", 0.0))
		var storefront := int(plans[i].get(&"ground_kind", -1)) == _FacadePlan.GROUND_STOREFRONT
		if width >= 10.0 and storefront and width > best_width:
			best_width = width
			best = i
	return best


## u (metres along the building) to world z; mirrors facade_body._u's inverse.
static func _z_at(plan: Dictionary, side_sign: float, u: float) -> float:
	var z0: float = plan[&"z0"]
	var z1: float = plan[&"z1"]
	return z0 + u if side_sign > 0.0 else z1 - u
