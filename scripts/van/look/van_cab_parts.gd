extends RefCounted

## The cab's side mirrors, on seeded arms off the body's sides.

var cab: VanCab


func _init(owner_cab: VanCab) -> void:
	cab = owner_cab


func build_mirrors(mat: Material, rng: RandomNumberGenerator) -> void:
	var mirror_z := VanCab.CAB_FRONT_Z + 0.25
	for s: float in [-1.0, 1.0]:
		var suffix := "L" if s < 0.0 else "R"
		var outer_x := VanCab.CAB_HALF_W
		cab._add_mesh("MirrorArm%s" % suffix, cab._box(Vector3(0.45, 0.04, 0.04)), mat,
				Vector3(s * (outer_x + 0.2), 2.4, mirror_z))
		var tilt := deg_to_rad(s * rng.randf_range(-8.0, 8.0))
		cab._add_mesh("Mirror%s" % suffix, cab._box(Vector3(0.08, 0.4, 0.24)), mat,
				Vector3(s * (outer_x + 0.45), 2.4, mirror_z), Vector3(0.0, tilt, 0.0))
