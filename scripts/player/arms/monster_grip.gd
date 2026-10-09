class_name MonsterGrip
extends RefCounted
## The monster-hand grip study plus the railgun body: grip, trigger, guard (here) and receiver and barrel (RailgunBody).

## Measured from the right hand (arms dump): palm_len 0.198, knuckle span 0.292 m (index to pinky 0.214
## plus one knuckle spacing 0.078). That span is in the same space as the gun's p = palm_len *
## HAND_K (about 0.29), so the span is about 1.0 p. Length 1.15 * span is about 1.15 p, raised to
## 1.40 so the grip is never shorter than HeldGun's 1.35 p. Depth about 0.55 * span, width
## 0.6 * depth. All are in palm lengths (p).
const GRIP_LEN_K := 1.40
const GRIP_DEPTH_K := 0.80
const GRIP_WIDTH_K := 0.48
## Trigger guard opening (HeldGun's is 0.42 p tall, 0.75 p long: this is 1.7x), in p.
const GUARD_H_K := 0.72
const GUARD_L_K := 1.30
## Grooves on the front strap, one per finger; the trigger sits one spacing above the top one.
const GROOVES := 4
## Body scale over the hand's `p`; the grip, guard and trigger stay at `p` so the hand's wrap
## is unchanged.
const GUN_K := 1.15
const _TOP := Vector3(0.0, 0.03, -0.01)
const _RAKE := 18.0 * PI / 180.0


static func build(rng: RandomNumberGenerator, palm_len: float = 0.22) -> Node3D:
	var p := palm_len if palm_len > 0.0 else 0.22
	var root := Node3D.new()
	root.name = "Gun"
	root.set_meta(&"palm_len", p)
	var body := Node3D.new()
	body.name = "Body"
	body.transform = HeldGun.gun_xform()
	root.add_child(body)
	var steel := ArmMaterials.steel(rng.randf_range(0.0, 100.0))
	var rubber := ArmMaterials.grip_rubber()
	var glen := GRIP_LEN_K * p
	var dep := GRIP_DEPTH_K * p
	var wid := GRIP_WIDTH_K * p
	var gb := Basis(Vector3.RIGHT, -_RAKE)
	var centre := grip_centre(p)
	ArmParts.mesh(body, "GripCore", ArmParts.box(Vector3(0.7 * wid, glen, 0.9 * dep)), steel,
			centre, gb)
	for side: float in [-1.0, 1.0]:
		var tag := "L" if side < 0.0 else "R"
		ArmParts.mesh(body, "GripPanel" + tag,
				ArmParts.box(Vector3(0.2 * wid, 0.92 * glen, 0.86 * dep)), rubber,
				centre + gb * Vector3(side * 0.4 * wid, 0.0, 0.0), gb)
	ArmParts.mesh(body, "FrontStrap", ArmParts.box(Vector3(0.84 * wid, 0.94 * glen, 0.1 * dep)),
			rubber, centre + gb * Vector3(0.0, 0.0, -0.46 * dep), gb)
	ArmParts.mesh(body, "BackStrap", ArmParts.box(Vector3(0.84 * wid, 0.94 * glen, 0.1 * dep)),
			rubber, centre + gb * Vector3(0.0, 0.0, 0.46 * dep), gb)
	for i: int in range(GROOVES):
		var f := 0.15 + 0.2 * i
		ArmParts.mesh(body, "Groove%d" % i,
				ArmParts.box(Vector3(0.9 * wid, 0.05 * glen, 0.06 * dep)), steel,
				centre + gb * Vector3(0.0, glen * (0.5 - f), -0.52 * dep), gb)
	ArmParts.mesh(body, "Pommel", ArmParts.box(Vector3(1.25 * wid, 0.07 * glen, 1.2 * dep)), steel,
			grip_bottom(p), gb)
	ArmParts.mesh(body, "Beavertail", ArmParts.box(Vector3(0.9 * wid, 0.05 * p, 0.45 * dep)),
			steel, web_point(p) + Vector3(0.0, 0.02 * p, 0.12 * dep),
			Basis(Vector3.RIGHT, deg_to_rad(25.0)))
	ArmParts.mesh(body, "TopStub", ArmParts.box(Vector3(0.8 * wid, 0.1 * p, 0.95 * dep)), steel,
			_TOP + Vector3(0.0, 0.05 * p, 0.0))
	var t := trigger_point(p)
	var guard_front_z := t.z + 0.30 * p - GUARD_L_K * p
	_build_guard(body, p, steel)
	var gp := p * GUN_K
	var muzzle := RailgunBody.build(body, gp, rng, guard_front_z, t.y + 0.25 * p)
	for entry: Array in [["GripCentre", centre], ["TriggerPoint", trigger_point(p)],
			["WebPoint", web_point(p)], ["GripBottom", grip_bottom(p)]]:
		var m := Marker3D.new()
		m.name = entry[0] as String
		m.position = entry[1] as Vector3
		body.add_child(m)
	# The viewmodel reads HeldGun's statics for the muzzle and the left hand, so point them at
	# this piece: shots leave from the barrel tip, not from inside the hand.
	muzzle_in_gun_set(muzzle,
			centre + gb * Vector3(0.0, -0.2 * glen, -0.55 * dep), grip_bottom(p))
	root.set_meta(&"lamp_local", HeldGun.gun_xform() * Vector3(0.0, 0.03, -0.6 * gp))
	return root


## Writes HeldGun's gun-space points (muzzle, fore-end, mag slap) for this piece.
static func muzzle_in_gun_set(muzzle: Vector3, fore_end: Vector3, mag_slap: Vector3) -> void:
	HeldGun.muzzle_in_gun = muzzle
	HeldGun.fore_end_in_gun = fore_end
	HeldGun.mag_slap_in_gun = mag_slap


## Trigger guard of four limbs, big enough for a thick finger, and the two-box trigger blade.
static func _build_guard(body: Node3D, p: float, steel: Material) -> void:
	var t := trigger_point(p)
	var top := t.y + 0.25 * p
	var z0 := t.z + 0.30 * p
	var a := Vector3(0.0, top, z0)
	var b := Vector3(0.0, top - GUARD_H_K * p, z0)
	var c := Vector3(0.0, top - GUARD_H_K * p, z0 - GUARD_L_K * p)
	var d := Vector3(0.0, top, z0 - GUARD_L_K * p)
	var r := 0.05 * p
	ArmParts.limb(body, "GuardRear", a, b, r, r, steel)
	ArmParts.limb(body, "GuardBottom", b, c, r, r, steel)
	ArmParts.limb(body, "GuardFront", c, d, r, r, steel)
	ArmParts.limb(body, "GuardJoin", d, d + Vector3(0.0, 0.08 * p, 0.0), r, r, steel)
	ArmParts.mesh(body, "TriggerUpper", ArmParts.box(Vector3(0.12 * p, 0.30 * p, 0.10 * p)),
			steel, t + Vector3(0.0, 0.10 * p, 0.04 * p), Basis(Vector3.RIGHT, deg_to_rad(-10.0)))
	ArmParts.mesh(body, "TriggerLower", ArmParts.box(Vector3(0.12 * p, 0.28 * p, 0.10 * p)),
			steel, t + Vector3(0.0, -0.12 * p, 0.0), Basis(Vector3.RIGHT, deg_to_rad(-35.0)))


static func _down() -> Vector3:
	return Vector3(0.0, -cos(_RAKE), sin(_RAKE))


## Middle of the grip, body space.
static func grip_centre(p: float) -> Vector3:
	return _TOP + 0.5 * GRIP_LEN_K * p * _down()


## Face of the trigger: one groove spacing above the top groove, in front of the front strap.
static func trigger_point(p: float) -> Vector3:
	var spacing := 0.2 * GRIP_LEN_K * p
	var along := (0.15 * GRIP_LEN_K * p) - spacing
	return _TOP + Basis(Vector3.RIGHT, -_RAKE) * Vector3(0.0, -along,
			-(0.5 * GRIP_DEPTH_K + 0.25) * p)


## Top of the back strap, where the thumb web sits.
static func web_point(p: float) -> Vector3:
	return _TOP + Basis(Vector3.RIGHT, -_RAKE) * Vector3(0.0, 0.0, 0.5 * GRIP_DEPTH_K * p)


static func grip_bottom(p: float) -> Vector3:
	return _TOP + GRIP_LEN_K * p * _down()


## One line: grip size, guard opening and trigger reach, in metres and palm lengths.
static func size_report(p: float) -> String:
	var reach := trigger_point(p).distance_to(web_point(p))
	return ("grip len %.3f m (%.2f p) depth %.3f m (%.2f p) width %.3f m (%.2f p) | "
			+ "guard %.3f x %.3f m (%.2f x %.2f p) | trigger reach %.3f m (%.2f p)") % [
			GRIP_LEN_K * p, GRIP_LEN_K, GRIP_DEPTH_K * p, GRIP_DEPTH_K, GRIP_WIDTH_K * p,
			GRIP_WIDTH_K, GUARD_H_K * p, GUARD_L_K * p, GUARD_H_K, GUARD_L_K, reach,
			reach / p]
