class_name RailgunBarrels
extends RefCounted
## The railgun's two barrels: box-section bars of the same height, a long lower one and a shorter upper one set back from the muzzle, an open gap between them and two struts tying them at the rear.


## Half-heights and half-widths of the two box sections (in palm units p), and the gap between.
const LOW_R := 0.20
const LOW_HW := 0.19
const UP_R := 0.20
const UP_HW := 0.19
const GAP_H := 0.17
## Barrel centres: the lower one's bottom stays where it was (-0.14p); the upper sits above the gap.
const LOW_Y := 0.06
const UP_Y := LOW_Y + LOW_R + GAP_H + UP_R


## Builds both barrels, their caps, bands, fins, vents, rail, brake, struts and the gap glow under
## `body` (gun space, -Z forward). Same `p`, `zf`, `ya` as RailgunBody.build. Returns the muzzle
## point: just ahead of the upper barrel's front end, centred in the gap.
static func build(body: Node3D, p: float, rng: RandomNumberGenerator, zf: float,
		ya: float) -> Vector3:
	var steel := ArmMaterials.steel(rng.randf_range(0.0, 100.0))
	var rust := ArmMaterials.rust(rng.randf_range(0.0, 100.0))
	var paint := ArmMaterials.gun_paint(rng.randf_range(0.0, 100.0))
	var dark := ArmMaterials.surface(Color(0.03, 0.03, 0.03), Color(0.02, 0.02, 0.02),
			Color(0.02, 0.02, 0.02), 60.0, 6.0, 0.0, 0.6, 0.9, 0.2, rng.randf_range(0.0, 100.0))
	var ztip := zf - 2.8 * p
	var uf := ztip + 0.9 * p
	var ur := zf - 0.15 * p
	var rear := 0.32 * p
	var ly := ya + LOW_Y * p
	var uy := ya + UP_Y * p
	var lhw := LOW_HW * p
	var lhr := LOW_R * p
	var uhw := UP_HW * p
	var uhr := UP_R * p
	var D := RailgunBarrelDetail

	# Lower barrel: a long steel box, rear collar, three bands, grooves, fins and a slotted brake.
	D.section(body, "LowerBarrel", lhw, lhr, rear, ztip, ly, steel, p)
	D.band(body, "LowerRearCollar", lhw, lhr, rear - 0.05 * p, 0.10 * p, rust, steel, ly, p)
	for i: int in range(3):
		var z := [zf + 0.15 * p, zf - 1.55 * p, zf - 2.15 * p][i] as float
		D.band(body, "LowerBand%d" % i, lhw, lhr, z, 0.09 * p, rust, steel, ly, p)
	D.grooves(body, "LowerGroove", lhw, lhr, ztip + 0.80 * p, 3, ly, dark, p)
	D.fins(body, "LowerFin", lhw, lhr, zf - 0.35 * p, 6, ly, steel, p)
	D.brake(body, lhw, lhr, ztip, ly, steel, dark, p)

	# Upper barrel: short, same height, ending well behind the muzzle, so the front half of the
	# gap is open; caps, two bands, side vents, a top rail and grooves.
	D.section(body, "UpperBarrel", uhw, uhr, ur, uf, uy, rust, p)
	D.band(body, "UpperFrontCap", uhw, uhr, uf + 0.04 * p, 0.10 * p, steel, steel, uy, p)
	D.band(body, "UpperRearCap", uhw, uhr, ur - 0.04 * p, 0.08 * p, steel, steel, uy, p)
	ArmParts.mesh(body, "UpperBore", ArmParts.box(Vector3(0.16 * p, 0.16 * p, 0.02 * p)), dark,
			Vector3(0.0, uy, uf - 0.004 * p))
	D.band(body, "UpperBand0", uhw, uhr, uf + 0.40 * p, 0.09 * p, paint, steel, uy, p)
	D.band(body, "UpperBand1", uhw, uhr, ur - 0.30 * p, 0.09 * p, paint, steel, uy, p)
	D.vents(body, "Vent", uhw, uhr, uf + 0.70 * p, 4, uy, dark, p)
	D.fins(body, "UpperFin", uhw, uhr, ur - 0.55 * p, 2, uy, steel, p)
	D.top_rail(body, "TopRail", uhr, ur - 0.10 * p, uf + 0.15 * p, uy, steel, p)
	D.grooves(body, "UpperGroove", uhw, uhr, uf + 0.22 * p, 2, uy, dark, p)

	# Two struts tie the upper barrel to the lower one, behind the open half of the gap.
	var low_top := ly + lhr
	var up_bot := uy - uhr
	for side: float in [-1.0, 1.0]:
		var tag := "L" if side < 0.0 else "R"
		ArmParts.mesh(body, "Strut" + tag,
				ArmParts.box(Vector3(0.05 * p, up_bot - low_top + 0.08 * p, 0.26 * p)), rust,
				Vector3(side * 0.12 * p, (low_top + up_bot) * 0.5, ur - 0.17 * p))
		for k: int in range(2):
			ArmParts.mesh(body, "StrutBolt%s%d" % [tag, k],
					ArmParts.cyl(0.03 * p, 0.03 * p, 0.03 * p, 6), steel,
					Vector3(side * 0.15 * p, (low_top + up_bot) * 0.5 + (k - 0.5) * 0.09 * p,
					ur - 0.17 * p), ArmParts.along(Vector3(side, 0.0, 0.0)))
	# A dull glow line in the gap, shorter than the barrels so it reads as light between them.
	var gap_y := (low_top + up_bot) * 0.5
	ArmParts.mesh(body, "GapGlow", ArmParts.box(Vector3(0.03 * p, 0.03 * p, ur - uf - 0.1 * p)),
			ArmMaterials.ember(0.0), Vector3(0.0, gap_y, (ur + uf) * 0.5))
	return Vector3(0.0, gap_y, uf - 0.05 * p)
