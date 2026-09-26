class_name VanMarkings
extends Node3D
## The van's seeded painted identity: a stencil name on both sides, a number on the cab doors and kill tallies, as exterior-only decals.

const _Font := preload("res://scripts/van/look/van_stencil_font.gd")

const NAMES: Array[String] = [
	"IRON MULE", "RUST BUCKET", "OL' BESSIE", "NO BRAKES", "MAD MAUD", "SCRAPHEAP",
	"DEAD END", "LAST RUN", "ROAD HOG", "BIG MAMA", "GRAVEDIGGER", "TIN CAN",
]
const PAINTS: Array[Color] = [
	Color(0.46, 0.44, 0.38), Color(0.34, 0.10, 0.08), Color(0.42, 0.36, 0.14),
]

const SIDE_X := 2.6

## The rolled name, for later UI.
var van_name := ""
var van_number := 0


func rebuild_look(look: VanLook) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	var rng := look.rng_for(&"markings")

	van_name = NAMES[rng.randi_range(0, NAMES.size() - 1)]
	van_number = rng.randi_range(1, 99)
	var paint: Color = PAINTS[rng.randi_range(0, PAINTS.size() - 1)]
	var wear := rng.randf_range(0.08, 0.18)
	var tally_count := rng.randi_range(3, 17)

	for side: float in [-1.0, 1.0]:
		var name_img := _Font.render_text(van_name, rng, wear, 6)
		var name_height := 0.4
		var name_width: float = min(3.4, name_height * name_img.get_width() / name_img.get_height())
		if name_width >= 3.4:
			name_height = name_width * name_img.get_height() / name_img.get_width()
		var name_center := Vector3(side * SIDE_X, 0.55, -0.3)
		_add_decal("Name" + ("L" if side < 0.0 else "R"), name_img, paint, side, name_center, name_width, name_height)

	for side: float in [-1.0, 1.0]:
		var number_img := _Font.render_text("%02d" % van_number, rng, wear, 8)
		var number_height := 0.6
		var number_width: float = number_height * number_img.get_width() / number_img.get_height()
		var number_center := Vector3(side * 2.47, 1.75, -5.55)
		_add_decal("Number" + ("L" if side < 0.0 else "R"), number_img, paint, side, number_center, number_width, number_height)

	var tally_img := _Font.render_tallies(tally_count, rng, 6)
	var tally_height := 0.28
	var tally_width: float = tally_height * tally_img.get_width() / tally_img.get_height()
	var tally_center := Vector3(-SIDE_X, 2.78, -2.0 + tally_width * 0.5)
	_add_decal("Tallies", tally_img, paint, -1.0, tally_center, tally_width, tally_height)


func _add_decal(decal_name: String, img: Image, color: Color, side: float, center: Vector3, width: float, height: float) -> Decal:
	var d := Decal.new()
	d.name = decal_name
	d.texture_albedo = ImageTexture.create_from_image(img)
	d.modulate = color
	d.albedo_mix = 1.0
	d.cull_mask = 1 ## Exterior layer only; the interior liner is on layer 2.
	d.normal_fade = 0.35
	d.upper_fade = 0.0
	d.lower_fade = 0.0
	d.size = Vector3(width, 0.5, height)
	d.position = center
	d.basis = Basis(Vector3(0.0, 0.0, -side), Vector3(side, 0.0, 0.0), Vector3(0.0, -1.0, 0.0))
	add_child(d)
	return d
