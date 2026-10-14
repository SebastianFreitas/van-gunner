class_name RearDoorDonorTopRamPower
extends RefCounted
## Static power for the donor leaf's top ram (blockout): two thick HV leads that run straight along
## the rear arch header's cabin face from the arch bracket to the hinge-side top corner, then hang
## in a slack loop down the hinge-side pillar to the floor battery's terminals, the floor battery
## (dark case, faded label, red and black caps) and its welded battery strap. Everything is fixed to
## the van body (the frame), never to the leaf. Positions are hinge-local, plus the hinge `base`.

const _Hydraulic := preload("res://scripts/van/look/rear_door_donor_hydraulic.gd")
const _Panels := preload("res://scripts/van/look/rear_door_donor_panels.gd")

const CABLE_R := 0.025
const SAG := 0.2
const STEPS := 16
## Battery case size (x along the wall, y up, z out from the wall), centre and floor lift.
const CASE := Vector3(0.30, 0.20, 0.18)
const CASE_CENTER := Vector2(-0.51, -0.58)
const LIFT := 0.015
## Terminal x offsets from the case centre; the caps top the case.
const TERM_DX := 0.09
## Header run: the leads leave the arch bracket's hinge-side edge at RUN_X and run straight along the
## header's cabin face (cable centre at RUN_Z) to the corner at CORNER_X, 4 cm clear of the pillar
## ring (x <= -0.10) and off the leaf's swept slab. Heights are relative to the bracket pin line;
## they sit above the leaf top, and 11 cm apart so the two leads never touch.
const RUN_X := 0.5
const RUN_Z := -0.32
const CORNER_X := -0.03
const START_DY: Array[float] = [0.31, 0.41]
## The loop sidesteps cabin-ward to z LOOP_Z first (t 0..0.15) so it clears the pillar ring (z >=
## -0.45), then moves across to its terminal (t 0.1..0.4) while still near the top, far from the
## bottom ram's wall bracket.
const LOOP_Z := -0.58


## Hinge-local xz points of every lead and battery part, for the swept-leaf clearance check.
static func xz_points() -> Array[Vector2]:
	var pts: Array[Vector2] = []
	for k in 2:
		for p in _lead(k, 0.0, 0.0):
			pts.append(Vector2(p.x, p.z))
	for sx: float in [-0.5, 0.5]:
		for sz: float in [-0.5, 0.5]:
			pts.append(CASE_CENTER + Vector2(sx * CASE.x, sz * CASE.z))
	# The strap's bolted foot (0.08 square) reaches 0.033 + 0.04 past the case's front.
	var foot_z := CASE_CENTER.y + CASE.z * 0.5 + 0.033
	for sx: float in [-0.04, 0.04]:
		for sz: float in [-0.04, 0.04]:
			pts.append(Vector2(CASE_CENTER.x + sx, foot_z + sz))
	return pts


## Smallest gap (m, less the lead radius) between the leads' hanging loops and the pillar ring
## (hinge-local x -0.46..-0.10, z >= -0.45).
static func keepout_clearance() -> float:
	var best := INF
	for k in 2:
		var pts := _lead(k, START_DY[k], -0.5)
		for p in pts:
			var ring := Vector2(maxf(maxf(-0.46 - p.x, p.x + 0.10), 0.0),
					maxf(-0.45 - p.z, 0.0)).length()
			best = minf(best, ring - CABLE_R)
	return best


## Builds the leads, battery and strap under `frame`; `base` is the hinge position, `ym` the pin
## line's height above it. Returns every node added (the holder first).
static func build(frame: Node3D, base: Vector3, ym: float) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var holder := Node3D.new()
	holder.name = "TopRamPower"
	frame.add_child(holder)
	out.append(holder)
	var rubber := _Panels.flat(Color(0.06, 0.06, 0.065), 0.85, 0.1)
	var case_mat := _Panels.flat(Color(0.07, 0.075, 0.08), 0.85, 0.1)
	var label := _Panels.flat(Color(0.30, 0.25, 0.10), 0.9, 0.0)
	var red := _Panels.flat(Color(0.55, 0.06, 0.05), 0.7, 0.1)
	var black := _Panels.flat(Color(0.03, 0.03, 0.03), 0.7, 0.1)
	var steel := _Panels.flat(Color(0.11, 0.11, 0.12), 0.7, 0.3)
	var cx := base.x + CASE_CENTER.x
	var cz := base.z + CASE_CENTER.y
	var cy := LIFT + CASE.y * 0.5
	var top := LIFT + CASE.y
	_Hydraulic._box(holder, "FloorBattery", CASE, case_mat, Vector3(cx, cy, cz), out)
	_Hydraulic._box(holder, "FloorBatteryLabel", Vector3(0.10, 0.09, 0.012), label,
			Vector3(cx + 0.08, cy, cz +CASE.z * 0.5 + 0.006), out)
	for k in 2:
		var tx := cx + (TERM_DX if k == 0 else -TERM_DX)
		_Hydraulic._part(holder, "FloorBatteryCap", _Hydraulic._cyl(0.03, 0.03, 0.03, 8),
				red if k == 0 else black, Vector3(tx, top + 0.015, cz), out)
	# Battery strap: flat bar over the top, a leg down the front and a bolted foot on the floor.
	var zf := cz + CASE.z * 0.5 + 0.007
	_Hydraulic._box(holder, "BatteryStrap", Vector3(0.04, 0.014, CASE.z + 0.014), steel,
			Vector3(cx, top + 0.007, cz), out)
	_Hydraulic._box(holder, "BatteryStrapLeg", Vector3(0.04, CASE.y + LIFT, 0.014), steel,
			Vector3(cx, (CASE.y + LIFT) * 0.5 + 0.0, zf + 0.0), out)
	_Hydraulic._box(holder, "BatteryStrapFoot", Vector3(0.08, 0.012, 0.08), steel,
			Vector3(cx, 0.006, zf + 0.026), out)
	_Hydraulic._part(holder, "BatteryStrapBolt", _Hydraulic._cyl(0.016, 0.016, 0.012, 6), steel,
			Vector3(cx, 0.018, zf + 0.026), out)
	# HV leads: a straight run along the header, then the segments of a slack loop to each terminal.
	for k in 2:
		var tx := cx + (TERM_DX if k == 0 else -TERM_DX)
		var pts := _lead(k, ym + START_DY[k], top + 0.03 - base.y, tx - base.x, base)
		_segment(holder, "HVLeads%d_run" % k, Vector3(RUN_X + base.x, pts[0].y, pts[0].z), pts[0],
				rubber, out)
		for i in pts.size() - 1:
			_segment(holder, "HVLeads%d_%d" % [k, i], pts[i], pts[i + 1], rubber, out)
	return out


## Points of lead `k` from the header corner to its terminal; hinge-local when `base` is zero.
static func _lead(k: int, y0: float, y1: float, tx_local: float = -999.0,
		base: Vector3 = Vector3.ZERO) -> PackedVector3Array:
	var tx := tx_local
	if tx == -999.0:
		tx = CASE_CENTER.x + (TERM_DX if k == 0 else -TERM_DX)
	var pts := PackedVector3Array()
	for i in STEPS + 1:
		var t := float(i) / float(STEPS)
		var x := lerpf(CORNER_X, tx, smoothstep(0.1, 0.4, t))
		var z := lerpf(RUN_Z, LOOP_Z, smoothstep(0.0, 0.15, t))
		pts.append(Vector3(x, lerpf(y0, y1, t) - SAG * 4.0 * t * (1.0 - t), z) + base)
	return pts


static func _segment(parent: Node3D, label: String, a: Vector3, b: Vector3, mat: Material,
		out: Array[Node3D]) -> void:
	var dir := b - a
	var rot := Basis(Quaternion(Vector3.UP, dir.normalized())).get_euler()
	# Overlap by a cable radius so the bends have no gap.
	_Hydraulic._part(parent, label, _Hydraulic._cyl(CABLE_R, CABLE_R, dir.length() + CABLE_R, 8),
			mat, (a + b) * 0.5, out, rot)
