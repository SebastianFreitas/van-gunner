extends Node3D
## A side-street branch tile; mirrors its children when attached on the right side.

const _FacadeSpans := preload("res://scripts/travel/facades/facade_spans.gd")
const _FacadeRegistry := preload("res://scripts/travel/facades/facade_registry.gd")

@export var mirror_x := false

var _configured := false


func _ready() -> void:
	if not mirror_x:
		return
	# Mirror every child (including RoadFloor), not only MeshInstance3D —
	# otherwise the branch road stays on the wrong side of the wall.
	for child in get_children():
		var t := (child as Node3D).transform
		child.transform = Transform3D(
			Vector3(-t.basis.x.x, t.basis.x.y, t.basis.x.z),
			t.basis.y,
			Vector3(-t.basis.z.x, t.basis.z.y, t.basis.z.z),
			Vector3(-t.origin.x, t.origin.y, t.origin.z)
		)


func is_configured() -> bool:
	return _configured


## Builds the flank and far-end facades. The Facades host is added here rather than in _ready,
## after the mirror loop above has already run once — so its already-mirrored spans never get
## mirrored a second time.
func configure(seed_value: int, district: int, neighborhood_seed: int) -> void:
	if _configured:
		return
	var facades := Node3D.new()
	facades.name = "Facades"
	add_child(facades)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, &"branch"])
	var district_res: FacadeDistrict = _FacadeRegistry.district(district)
	var m := -1.0 if mirror_x else 1.0
	_FacadeSpans.build_span(
		facades, "FlankNorth", Vector3(m * -24.0, 0.0, -10.0), Vector3.BACK, 48.0,
		rng, district_res, neighborhood_seed
	)
	_FacadeSpans.build_span(
		facades, "FlankSouth", Vector3(m * -24.0, 0.0, 10.0), Vector3.FORWARD, 48.0,
		rng, district_res, neighborhood_seed
	)
	_FacadeSpans.build_span(
		facades, "FarEnd", Vector3(m * -48.0, 0.0, 0.0), Vector3(m, 0.0, 0.0), 20.0,
		rng, district_res, neighborhood_seed
	)
	_configured = true
