class_name RearDoorDonorPatches
extends RefCounted
## Scrap patches that close the hole the flame cut left on the donor rear leaf's hinge side: the
## tread plate over the top (spec 3) and the corrugated roofing sheet over the bottom (spec 4).
## Hinge-local metres, x 0 at the hinge.

const _Plate := preload("res://scripts/van/look/rear_door_donor_plate.gd")
const _Sheet := preload("res://scripts/van/look/rear_door_donor_sheet.gd")
const _Seam := preload("res://scripts/van/look/rear_door_donor_seam.gd")


## Builds the patches under `hinge`; `rect` is the leaf rect the skin was pressed from. Returns
## every node added.
static func build(hinge: Node3D, rect: Rect2, profile: RearDoorProfile,
		rng: RandomNumberGenerator) -> Array[Node3D]:
	var out: Array[Node3D] = []
	out.append_array(_Plate.build(hinge, rect, profile, rng))
	out.append_array(_Sheet.build(hinge, rect, profile))
	out.append_array(_Seam.build(hinge, rect, profile))
	return out
