class_name RailgunBarrelDetail
extends RefCounted
## Box-section pieces for the railgun's barrels: chamfered boxes, boxy bands, fins, slotted vents, a top rail, grooves and a slotted muzzle brake.


## A chamfered rectangular bar along z: two crossed boxes plus four 45-degree corner prisms,
## so the section is an octagon with long flats. `hw`/`hr` are half-width/half-height.
static func section(body: Node3D, node_name: String, hw: float, hr: float, z0: float, z1: float,
		y: float, mat: Material, p: float) -> void:
	var c := 0.05 * p
	var blen := z0 - z1
	var zc := (z0 + z1) * 0.5
	ArmParts.mesh(body, node_name, ArmParts.box(Vector3(2.0 * hw, 2.0 * hr - 2.0 * c, blen)), mat,
			Vector3(0.0, y, zc))
	ArmParts.mesh(body, node_name + "Wide", ArmParts.box(Vector3(2.0 * hw - 2.0 * c, 2.0 * hr, blen)),
			mat, Vector3(0.0, y, zc))
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			ArmParts.mesh(body, "%sCorner%s%s" % [node_name, "L" if sx < 0.0 else "R",
					"B" if sy < 0.0 else "T"], ArmParts.box(Vector3(c * 1.4142, c * 1.4142, blen)),
					mat, Vector3(sx * (hw - c), y + sy * (hr - c), zc),
					Basis(Vector3.BACK, PI / 4.0))


## A square-shouldered band or collar around a barrel, with a hex bolt head on each side.
static func band(body: Node3D, node_name: String, hw: float, hr: float, z: float, blen: float,
		mat: Material, bolt_mat: Material, y: float, p: float) -> void:
	ArmParts.mesh(body, node_name, ArmParts.box(Vector3(2.0 * hw + 0.05 * p, 2.0 * hr + 0.05 * p,
			blen)), mat, Vector3(0.0, y, z))
	for side: float in [-1.0, 1.0]:
		ArmParts.mesh(body, "%sBolt%s" % [node_name, "L" if side < 0.0 else "R"],
				ArmParts.cyl(0.03 * p, 0.03 * p, 0.03 * p, 6), bolt_mat,
				Vector3(side * (hw + 0.025 * p), y, z), ArmParts.along(Vector3(side, 0.0, 0.0)))


## Cooling fins: thin vertical plates standing off both flanks, `n` of them from `z` backward.
static func fins(body: Node3D, node_name: String, hw: float, hr: float, z: float, n: int,
		y: float, mat: Material, p: float) -> void:
	for side: float in [-1.0, 1.0]:
		for k: int in range(n):
			ArmParts.mesh(body, "%s%s%d" % [node_name, "L" if side < 0.0 else "R", k],
					ArmParts.box(Vector3(0.05 * p, 2.0 * hr * 0.78, 0.04 * p)), mat,
					Vector3(side * (hw + 0.02 * p), y, z - 0.17 * p * k))


## Slotted vents: dark upright slots set into both flanks.
static func vents(body: Node3D, node_name: String, hw: float, hr: float, z: float, n: int,
		y: float, mat: Material, p: float) -> void:
	for side: float in [-1.0, 1.0]:
		for k: int in range(n):
			ArmParts.mesh(body, "%s%s%d" % [node_name, "L" if side < 0.0 else "R", k],
					ArmParts.box(Vector3(0.016 * p, 2.0 * hr * 0.6, 0.05 * p)), mat,
					Vector3(side * (hw - 0.002 * p), y, z + 0.14 * p * k))


## A top rail along the barrel with three upright posts under it.
static func top_rail(body: Node3D, node_name: String, hr: float, z0: float, z1: float, y: float,
		mat: Material, p: float) -> void:
	var top := y + hr
	ArmParts.mesh(body, node_name, ArmParts.box(Vector3(0.09 * p, 0.04 * p, z0 - z1)), mat,
			Vector3(0.0, top + 0.05 * p, (z0 + z1) * 0.5))
	for k: int in range(3):
		ArmParts.mesh(body, "%sPost%d" % [node_name, k], ArmParts.box(Vector3(0.05 * p, 0.05 * p,
				0.05 * p)), mat, Vector3(0.0, top + 0.015 * p,
				z1 + (z0 - z1) * (0.15 + 0.35 * k)))


## Machined grooves: dark rings a hair proud of the barrel, `n` of them, 0.12p apart from `z`.
static func grooves(body: Node3D, node_name: String, hw: float, hr: float, z: float, n: int,
		y: float, mat: Material, p: float) -> void:
	for k: int in range(n):
		ArmParts.mesh(body, "%s%d" % [node_name, k], ArmParts.box(Vector3(2.0 * hw + 0.008 * p,
				2.0 * hr + 0.008 * p, 0.022 * p)), mat, Vector3(0.0, y, z - 0.12 * p * k))


## Slotted muzzle brake: a squat steel block at the tip with dark slots in the flanks and top.
static func brake(body: Node3D, hw: float, hr: float, ztip: float, y: float, steel: Material,
		dark: Material, p: float) -> void:
	var blen := 0.34 * p
	ArmParts.mesh(body, "MuzzleBrake", ArmParts.box(Vector3(2.0 * hw + 0.07 * p,
			2.0 * hr + 0.07 * p, blen)), steel, Vector3(0.0, y, ztip + blen * 0.5))
	for k: int in range(3):
		var z := ztip + (0.07 + 0.10 * k) * p
		ArmParts.mesh(body, "BrakeSlotTop%d" % k, ArmParts.box(Vector3(0.18 * p, 0.02 * p,
				0.04 * p)), dark, Vector3(0.0, y + hr + 0.036 * p, z))
		for side: float in [-1.0, 1.0]:
			ArmParts.mesh(body, "BrakeSlot%s%d" % ["L" if side < 0.0 else "R", k],
					ArmParts.box(Vector3(0.02 * p, 2.0 * hr * 0.6, 0.04 * p)), dark,
					Vector3(side * (hw + 0.035 * p), y, z))
	ArmParts.mesh(body, "LowerBore", ArmParts.box(Vector3(0.16 * p, 0.16 * p, 0.02 * p)), dark,
			Vector3(0.0, y, ztip - 0.004 * p))
