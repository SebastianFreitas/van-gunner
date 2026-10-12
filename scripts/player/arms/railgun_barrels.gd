class_name RailgunBarrels
extends RefCounted
## The railgun's two barrels: flush twin rails of worn steel, the upper one 1.6 times the lower one's height, an open gap between them, both running from the receiver front to one tip.


## Half-heights and half-widths of the two box sections (in palm units p), and the gap between.
const LOW_R := 0.20
const LOW_HW := 0.19
const UP_R := 0.32
const UP_HW := 0.19
const GAP_H := 0.17
## Barrel centres: the lower one's bottom stays where it was (-0.14p); the upper sits above the gap.
const LOW_Y := 0.06
const UP_Y := LOW_Y + LOW_R + GAP_H + UP_R
## The rails' rear end, the receiver's front face, in palm units p.
const RAIL_REAR := -1.28
## The lower rail's toothed top edge: slot count and spacing (p), from zf - 0.10p toward the tip.
const SLOT_COUNT := 32
const SLOT_STEP := 0.08


## Builds both rails, their bands and the gap glow under `body` (gun space, -Z forward). Same
## `p`, `zf`, `ya` as RailgunBody.build. Returns the muzzle point: just ahead of the tips,
## centred in the gap.
static func build(body: Node3D, p: float, rng: RandomNumberGenerator, zf: float,
		ya: float) -> Vector3:
	var steel := ArmMaterials.steel(rng.randf_range(0.0, 100.0))
	var rust := ArmMaterials.rust(rng.randf_range(0.0, 100.0))
	var paint := ArmMaterials.gun_paint(rng.randf_range(0.0, 100.0))
	var dark := ArmMaterials.surface(Color(0.03, 0.03, 0.03), Color(0.02, 0.02, 0.02),
			Color(0.02, 0.02, 0.02), 60.0, 6.0, 0.0, 0.6, 0.9, 0.2, rng.randf_range(0.0, 100.0))
	var worn_low := ArmMaterials.worn_steel(rng.randf_range(0.0, 100.0))
	var worn_up := ArmMaterials.worn_steel(rng.randf_range(0.0, 100.0))
	var ztip := zf - 2.8 * p
	var rear := RAIL_REAR * p
	var ly := ya + LOW_Y * p
	var uy := ya + UP_Y * p
	var lhw := LOW_HW * p
	var lhr := LOW_R * p
	var uhw := UP_HW * p
	var uhr := UP_R * p
	var D := RailgunBarrelDetail

	# Lower rail: a long box, two bands, and a toothed edge of 32 dark slots on its top.
	D.section(body, "LowerBarrel", lhw, lhr, rear, ztip, ly, worn_low, p)
	D.band(body, "LowerBand1", lhw, lhr, zf - 1.55 * p, 0.09 * p, rust, steel, ly, p)
	D.band(body, "LowerBand2", lhw, lhr, zf - 2.15 * p, 0.09 * p, rust, steel, ly, p)
	var floor_y := ly + lhr
	for k: int in range(SLOT_COUNT):
		ArmParts.mesh(body, "LowerSlot%d" % k, ArmParts.box(Vector3(0.14 * p, 0.02 * p,
				0.03 * p)), dark, Vector3(0.0, floor_y + 0.001 * p - 0.01 * p,
				zf - (0.10 + SLOT_STEP * k) * p))

	# Upper rail: taller, the same length, its tip flush with the lower one's, a groove per flank.
	D.section(body, "UpperBarrel", uhw, uhr, rear, ztip, uy, worn_up, p)
	D.band(body, "UpperBand0", uhw, uhr, zf - 1.50 * p, 0.09 * p, paint, steel, uy, p)
	D.band(body, "UpperBand1", uhw, uhr, zf - 0.45 * p, 0.09 * p, paint, steel, uy, p)
	var g0 := zf + 0.10 * p
	var g1 := ztip + 0.25 * p
	for side: float in [-1.0, 1.0]:
		ArmParts.mesh(body, "UpperGroove%s" % ("L" if side < 0.0 else "R"),
				ArmParts.box(Vector3(0.004 * p, 0.06 * p, g0 - g1)), dark,
				Vector3(side * uhw, ya + 0.70 * p, (g0 + g1) * 0.5))

	# A dull glow line in the gap, shorter than the rails so it reads as light between them.
	var gap_y := floor_y + GAP_H * p * 0.5
	ArmParts.mesh(body, "GapGlow", ArmParts.box(Vector3(0.03 * p, 0.03 * p, 1.2 * p)),
			ArmMaterials.ember(0.0), Vector3(0.0, gap_y, zf - 1.20 * p))
	return Vector3(0.0, gap_y, ztip - 0.05 * p)
