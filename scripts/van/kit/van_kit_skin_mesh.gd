class_name VanKitSkinMesh
extends RefCounted
## Builds the skin panels as thin slabs that follow the wall's lean and the ceiling's vault.

## Unpainted tread plate: scrap steel, wall_style 4 in the grime shader.
const TREAD_PAINT := Color(0.13, 0.13, 0.125)
const TREAD_STYLE := 4
const _MATERIAL:ShaderMaterial = preload("res://resources/van_kit/van_kit_grime_material.tres")


## One MeshInstance3D per placed panel under `parent`, the region donor's look on each.
static func build(donors: VanDonorSet, placed: Array[VanKitPlaced], parent: Node3D,
		van_seed: int) -> void:
	for p in placed:
		var donor: VanDonor = null
		for d in donors.donors:
			if d.id == p.origin_id:
				donor = d
		if donor == null and p.def_id != VanKitSkinFloor.TREAD:
			continue
		var mi := MeshInstance3D.new()
		var kind := "Seam_lap_" if p.def_id == VanKitSeams.LAP else "Skin_"
		mi.name = kind + String(p.surface) + "_" + str(parent.get_child_count())
		mi.mesh = VanKitSurface.slab(p.surface, p.outline, p.size.y, VanKitSkin.THICK)
		if p.def_id == VanKitSkinFloor.PLATE:
			mi.transform = Transform3D(p.transform.basis,
				p.transform.origin - p.transform.basis * p.transform.origin)
		mi.material_override = _MATERIAL
		var lap := p.def_id == VanKitSeams.LAP
		# A lap's exposed edge casts a line, so the splice shows which side is on top.
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if lap 				else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.layers = VanLighting.LAYER_VAN_INTERIOR
		parent.add_child(mi)
		VanKitWindowsMesh.style_height(mi)
		mi.set_instance_shader_parameter(&"fastener_era",
			int(donor.fastener_era) if donor != null else -1)
		var is_floor := p.surface == VanKitSurface.FLOOR
		if p.def_id == VanKitSkinFloor.TREAD:
			mi.set_instance_shader_parameter(&"paint", TREAD_PAINT)
			mi.set_instance_shader_parameter(&"primer", Color(0.1, 0.095, 0.085))
			mi.set_instance_shader_parameter(&"rust_amount", 0.3)
		else:
			# Floor donor sheets and plates are the donor's paint darkened.
			var paint := donor.paint * 0.7 if is_floor else donor.paint
			if lap:
				var nb := _neighbour(donors, p)
				paint = nb.paint if nb != null else donor.paint * 0.6
			mi.set_instance_shader_parameter(&"paint", paint)
			mi.set_instance_shader_parameter(&"primer", donor.primer)
			mi.set_instance_shader_parameter(&"rust_amount", clampf(donor.fade, 0.0, 1.0))
		mi.set_instance_shader_parameter(&"grime_amount", 0.6)
		var style := int(donor.wall_style) if donor != null else 0
		if is_floor:
			style = TREAD_STYLE if p.def_id == VanKitSkinFloor.TREAD else int(VanDonor.WallStyle.FLAT)
		mi.set_instance_shader_parameter(&"wall_style", style)
		var pitch := 0.0 if is_floor or donor == null else donor.rib_pitch_m
		mi.set_instance_shader_parameter(&"rib_pitch_m", clampf(pitch, 0.0, 1.0))
		mi.set_instance_shader_parameter(&"seed",
			float(van_seed % 997) + float(hash(p.origin_id) % 97))


## The donor whose region lies next to a lap, not the one it is cut from: the region under
## the lap's centre if that is another donor, else the nearest other region on its surface.
static func _neighbour(donors: VanDonorSet, p: VanKitPlaced) -> VanDonor:
	var b := VanKitSkin._bounds(p.outline)
	var c := (b[0] + b[1]) * 0.5
	var best := ""
	var best_d := INF
	for region: Dictionary in donors.regions:
		if region[&"surface"] != p.surface or region[&"donor_id"] == p.origin_id:
			continue
		var rb := VanKitSkin._bounds(region[&"outline"])
		var d := Vector2(maxf(maxf(rb[0].x - c.x, c.x - rb[1].x), 0.0),
			maxf(maxf(rb[0].y - c.y, c.y - rb[1].y), 0.0)).length()
		if d < best_d:
			best_d = d
			best = region[&"donor_id"]
	for d in donors.donors:
		if String(d.id) == best:
			return d
	return null
