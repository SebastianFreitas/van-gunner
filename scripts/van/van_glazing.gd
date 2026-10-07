class_name VanGlazing
extends RefCounted
## The rolled glass and plexi materials shared by the side windows and the rear panes.

## Base material -> { glazing -> its rolled copy }, so each kept pane material is duplicated once.
static var _cache: Dictionary = {}


## The kept pane material turned into the rolled glazing; the kept one itself is never changed.
static func material(base: Material, glazing: StringName) -> Material:
	if not base is BaseMaterial3D or (glazing != &"glass" and glazing != &"plexi"):
		return base
	if not _cache.has(base):
		_cache[base] = {}
	var by_glazing: Dictionary = _cache[base]
	if not by_glazing.has(glazing):
		var mat := (base as BaseMaterial3D).duplicate() as BaseMaterial3D
		if glazing == &"glass":
			mat.roughness = 0.25
			mat.metallic = 0.30
			mat.albedo_color.a = 0.46
		else:
			mat.albedo_color = Color(0.30, 0.31, 0.28, 0.46)
			mat.roughness = 0.45
			mat.metallic = 0.1
		by_glazing[glazing] = mat
	return by_glazing[glazing] as Material
