## Stencils the van's seeded name and a tally count onto the right forearm as two decals, per run.
class_name ArmTattoo
extends RefCounted

const _Font := preload("res://scripts/van/look/van_stencil_font.gd")
const INK := Color(0.05, 0.06, 0.09)
const NAME_HEIGHT := 0.05
const NAME_MAX_WIDTH := 0.26
const TALLY_HEIGHT := 0.035
const DEPTH := 0.12
const NAME_T := 0.60
const TALLY_ONLY_T := 0.65
const GAP := 0.03


## Adds the name decal (when the van has one) and the tally decal to `root`, on the forearm top.
static func apply(root: Node3D, rng: RandomNumberGenerator, van_name: String, elbow: Vector3,
		wrist: Vector3, r_elbow: float, r_wrist: float, facing: Vector3) -> void:
	var d := wrist - elbow
	var dn := d.normalized()
	# Out of the forearm toward the camera.
	var n := (facing - dn * facing.dot(dn)).normalized()
	# Text reads along x (wrist toward elbow), the decal projects along -y, z is the text's down.
	var basis := Basis(-dn, n, (-dn).cross(n))
	var t := NAME_T
	var named := van_name != ""
	if named:
		var img: Image = _Font.render_text(van_name, rng, rng.randf_range(0.08, 0.18), 6)
		var aspect := float(img.get_width()) / float(img.get_height())
		var h := minf(NAME_HEIGHT, NAME_MAX_WIDTH / aspect)
		var w := h * aspect
		_decal(root, "TattooName", img, w, h,
				_surface(elbow, wrist, t, r_elbow, r_wrist, n), basis)
		t += (w * 0.5 + GAP) / d.length()
	var tallies: Image = _Font.render_tallies(rng.randi_range(3, 9), rng, 6)
	var ta := float(tallies.get_width()) / float(tallies.get_height())
	var tw := TALLY_HEIGHT * ta
	if named:
		t += tw * 0.5 / d.length()
	else:
		t = TALLY_ONLY_T
	_decal(root, "TattooTallies", tallies, tw, TALLY_HEIGHT,
			_surface(elbow, wrist, t, r_elbow, r_wrist, n), basis)


static func _surface(elbow: Vector3, wrist: Vector3, t: float, r_elbow: float, r_wrist: float,
		n: Vector3) -> Vector3:
	return elbow + (wrist - elbow) * t + n * lerpf(r_elbow, r_wrist, t)


static func _decal(root: Node3D, decal_name: String, img: Image, width: float, height: float,
		centre: Vector3, basis: Basis) -> void:
	var dec := Decal.new()
	dec.name = decal_name
	dec.texture_albedo = ImageTexture.create_from_image(img)
	dec.modulate = INK
	dec.albedo_mix = 0.85
	dec.cull_mask = VanLighting.LAYER_VAN_INTERIOR
	dec.layers = VanLighting.LAYER_VAN_INTERIOR
	dec.normal_fade = 0.35
	dec.upper_fade = 0.0
	dec.lower_fade = 0.0
	dec.size = Vector3(width, DEPTH, height)
	dec.transform = Transform3D(basis, centre)
	root.add_child(dec)
