class_name VanKitSkinEnds
extends RefCounted
## Kit skin pass, cab-end wall and the two rear-door leaves: bare donor panels, no hardware.

const CAB_PANEL := &"skin/cab_panel"
const LEAF_PANEL := &"skin/leaf_panel"
## The cab wall stops this far (cm) short of the doorway casing.
const _DOORWAY_GAP_CM := 4.0
const _DOORWAY_HALF_CM := 85.5
const _DOORWAY_TOP_CM := 238.0
## Leaf outline inset (cm) and the rear window hole's half size (cm) and centre in the leaf.
const _LEAF_INSET_CM := 2.0
const _HOLE_HALF_CM := Vector2(108.0, 88.5)
const _HOLE_CENTRE_CM := Vector2(12.5, 22.5)
## A leaf panel's outer depth: its back sits over 1 cm off the leaf body, past the audit's plane
## tolerance, so it never reads as coplanar with CurvedBody.
const _LEAF_DEPTH := 0.022


static func place(ctx: VanKitBuilder.Ctx, out: Array[VanKitPlaced]) -> void:
	if ctx.donors.donors.is_empty():
		return
	var first: VanDonor = ctx.donors.donors[0]
	var last: VanDonor = ctx.donors.donors[ctx.donors.donors.size() - 1]
	_cab(ctx, first, out)
	for surface: StringName in [VanKitSurface.LEFT_LEAF, VanKitSurface.RIGHT_LEAF]:
		_leaf(ctx, surface, last, out)


static func _cab(ctx: VanKitBuilder.Ctx, donor: VanDonor, out: Array[VanKitPlaced]) -> void:
	var rng := ctx.rng(&"skin", &"cab_wall")
	var outline := VanKitSurface.outline(VanKitSurface.CAB_WALL)
	if outline.size() < 3:
		return
	var b := VanKitSkin._bounds(outline)
	var step := donor.rib_pitch_m * 200.0 if donor.rib_pitch_m > 0.0 else 120.0
	var laps: Array[float] = []
	var cuts: Array[float] = [b[0].x]
	var x := b[0].x + step
	while x < b[1].x - 1.0:
		cuts.append(x)
		x += step
	cuts.append(b[1].x)
	for i in cuts.size():
		laps.append(rng.randf_range(VanKitSkin.LAP_CM.x, VanKitSkin.LAP_CM.y))
	var door := VanKitSkin._rect(
		Vector2(-_DOORWAY_HALF_CM - _DOORWAY_GAP_CM, b[0].y - 1.0),
		Vector2(_DOORWAY_HALF_CM + _DOORWAY_GAP_CM, _DOORWAY_TOP_CM + _DOORWAY_GAP_CM))
	for i in cuts.size() - 1:
		var depth := VanKitSkin.DEPTH_EVEN if i % 2 == 0 else VanKitSkin.DEPTH_ODD
		var z0 := cuts[i] - (laps[i] if i > 0 else 0.0)
		var pieces: Array[PackedVector2Array] = []
		pieces.assign(Geometry2D.intersect_polygons(
				VanKitSkin._rect(Vector2(z0, b[0].y - 1.0), Vector2(cuts[i + 1], b[1].y + 1.0)),
				outline))
		pieces = VanKitSkin._minus(pieces, door)
		for piece in pieces:
			for part in VanKitClip.cut(ctx.keep_out, VanKitSurface.CAB_WALL, piece, depth, &"skin"):
				_add(out, VanKitSurface.CAB_WALL, CAB_PANEL, donor.id, part, depth)


static func _leaf(ctx: VanKitBuilder.Ctx, surface: StringName, donor: VanDonor,
		out: Array[VanKitPlaced]) -> void:
	var sign_x := 1.0 if surface == VanKitSurface.LEFT_LEAF else -1.0
	var centre := Vector2(_HOLE_CENTRE_CM.x * sign_x, _HOLE_CENTRE_CM.y)
	var hole := VanKitSkin._rect(centre - _HOLE_HALF_CM, centre + _HOLE_HALF_CM)
	var depth := _LEAF_DEPTH
	for poly in VanKitStructure._offset(VanKitSurface.outline(surface), -_LEAF_INSET_CM):
		var pieces: Array[PackedVector2Array] = [poly]
		for piece in VanKitSkin._minus(pieces, hole):
			for part in VanKitClip.cut(ctx.keep_out, surface, piece, depth, &"skin"):
				_add(out, surface, LEAF_PANEL, donor.id, part, depth)


static func _add(out: Array[VanKitPlaced], surface: StringName, def_id: StringName,
		donor_id: StringName, poly: PackedVector2Array, depth: float) -> void:
	var b := VanKitSkin._bounds(poly)
	var centre := (b[0] + b[1]) * 0.5
	var leaf := VanKitSurface.is_leaf(surface)
	var normal := VanKitSurface.normal(surface, centre.x, centre.y)
	var p := VanKitPlaced.new()
	p.def_id = def_id
	p.surface = surface
	p.attach = surface if leaf else &""
	p.origin_kind = &"DONOR"
	p.origin_id = donor_id
	p.reason = &"region_skin"
	var basis := Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP) if leaf \
			else Basis(Vector3.RIGHT, Vector3.BACK, Vector3.DOWN)
	p.transform = Transform3D(basis, VanKitSurface.point(surface, centre.x, centre.y, 0.0)
			+ normal * (depth * 0.5))
	p.size = Vector3((b[1].x - b[0].x) * 0.01, depth, (b[1].y - b[0].y) * 0.01)
	p.outline = poly
	p.gen = VanKit.GEN
	out.append(p)
