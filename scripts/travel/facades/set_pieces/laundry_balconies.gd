extends FacadeSetPiece
## A tenement plastered in balconies: full window-grid coverage (not the rare few an ordinary
## building rolls), each one strung with hanging laundry.


const _FacadeKeepOut := preload("res://scripts/travel/facades/facade_keep_out.gd")
const _FacadePlan := preload("res://scripts/travel/facades/facade_plan.gd")
const _FacadeMaterials := preload("res://scripts/travel/facades/facade_materials.gd")
const _FacadeMeshKit := preload("res://scripts/travel/facades/facade_mesh_kit.gd")

const _BASE_Y := _FacadePlan.BASE_Y
const _GROUND_H := _FacadePlan.GROUND_HEIGHT
const _FLOOR_H := _FacadePlan.FLOOR_HEIGHT
const MAX_BALCONIES := 24
const _COLOR_NAMES: Array[StringName] = [&"white", &"red", &"blue", &"yellow", &"green"]
const _COLORS := {
	&"white": Color(0.88, 0.88, 0.86), &"red": Color(0.7, 0.15, 0.15),
	&"blue": Color(0.15, 0.25, 0.55), &"yellow": Color(0.85, 0.75, 0.2),
	&"green": Color(0.25, 0.5, 0.25),
}


func can_apply(plans: Array[Dictionary]) -> bool:
	return _target_index(plans) != -1


func pick_plan(plans: Array[Dictionary], _rng: RandomNumberGenerator) -> int:
	return _target_index(plans)


func apply_plans(plans: Array[Dictionary], _rng: RandomNumberGenerator) -> void:
	var target := _target_index(plans)
	if target == -1:
		return
	plans[target][&"rare"] = id
	plans[target][&"suppress"] = [&"balconies", &"fire_escape", &"ac_units"]


func build(ctx: Dictionary) -> void:
	var host: Node3D = ctx[&"host"]
	var plan: Dictionary = ctx[&"plan"]
	var ss: float = ctx[&"side_sign"]
	var keep_out: RefCounted = ctx[&"keep_out"]
	var rng: RandomNumberGenerator = ctx[&"rng"]
	var floors := int(plan[&"floors"])
	var pitch := float(plan[&"params"].get(&"window_pitch", 2.6))
	var sill := float(plan[&"params"].get(&"window_sill", 0.9))
	var cols := maxi(0, floori((float(plan[&"width"]) - 0.3) / pitch))
	var xf := _FacadePlan.face_x(plan, ss)
	var slab_st := SurfaceTool.new()
	slab_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rail_st := SurfaceTool.new()
	rail_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cloth_sts: Dictionary = {}
	var cloth_added: Dictionary = {}
	for cn: StringName in _COLOR_NAMES:
		cloth_sts[cn] = SurfaceTool.new()
		cloth_sts[cn].begin(Mesh.PRIMITIVE_TRIANGLES)
		cloth_added[cn] = false
	var slab_added := false
	var rail_added := false
	var count := 0
	for k in range(1, floors + 1):
		if count >= MAX_BALCONIES:
			break
		for col in cols:
			if count >= MAX_BALCONIES:
				break
			var z := _z_at(plan, ss, (float(col) + 0.5) * pitch)
			var y := _BASE_Y + _GROUND_H + float(k - 1) * _FLOOR_H + sill - 0.07
			var slab_c := Vector3(xf - ss * (0.02 + 0.45), y, z)
			var slab_s := Vector3(0.9, 0.14, 2.2)
			if not keep_out.allows(_FacadeKeepOut.box_aabb(slab_c, slab_s)):
				continue
			count += 1
			_FacadeMeshKit.add_box_ungated(slab_st, slab_c, slab_s)
			slab_added = true
			var top := y + 0.07
			var ox := xf - ss * (0.02 + 0.9)
			for dz: float in [-1.1, 1.1]:
				_FacadeMeshKit.add_box_ungated(
					rail_st, Vector3(ox, top + 0.5, z + dz), Vector3(0.04, 1.0, 0.04)
				)
			_FacadeMeshKit.add_box_ungated(
				rail_st, Vector3(ox, top + 1.0, z), Vector3(0.04, 0.05, 2.2)
			)
			_FacadeMeshKit.add_box_ungated(
				rail_st, Vector3(ox, top + 0.225, z), Vector3(0.03, 0.45, 2.2)
			)
			rail_added = true
			for j in rng.randi_range(2, 4):
				var cn: StringName = _COLOR_NAMES[rng.randi_range(0, _COLOR_NAMES.size() - 1)]
				var cz := z + lerpf(-0.9, 0.9, (float(j) + 0.5) / 4.0)
				_FacadeMeshKit.add_box_ungated(
					cloth_sts[cn], Vector3(ox, top + 0.75, cz), Vector3(0.02, 0.5, 0.35)
				)
				cloth_added[cn] = true
	if slab_added:
		_FacadeMeshKit.commit(
			host, slab_st, "Balconies", _FacadeMaterials.concrete_material(), true
		)
	if rail_added:
		_FacadeMeshKit.commit(
			host, rail_st, "BalconyRails", _FacadeMaterials.iron_material(), false
		)
	for cn: StringName in _COLOR_NAMES:
		if not cloth_added[cn]:
			continue
		var mat := _FacadeMaterials.prop_material(
			StringName("laundry_" + String(cn)), _COLORS[cn], 0.95, 0.0
		)
		_FacadeMeshKit.commit(
			host, cloth_sts[cn], "Laundry%s" % String(cn).capitalize(), mat, false
		)


## Widest plan with windows on and a plaster/brick skin (style 0 brick, 2 plaster).
func _target_index(plans: Array[Dictionary]) -> int:
	var best := -1
	var best_width := -1.0
	for i in plans.size():
		var params: Dictionary = plans[i][&"params"]
		var style := int(params[&"style"])
		if float(params.get(&"windows_on", 1.0)) <= 0.5 or not (style == 0 or style == 2):
			continue
		var width := float(plans[i][&"width"])
		if width > best_width:
			best_width = width
			best = i
	return best


## u (metres along the building) to world z; mirrors facade_body._u's inverse.
static func _z_at(plan: Dictionary, side_sign: float, u: float) -> float:
	var z0: float = plan[&"z0"]
	var z1: float = plan[&"z1"]
	return z0 + u if side_sign > 0.0 else z1 - u
