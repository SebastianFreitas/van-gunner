extends RefCounted
## Debug console `arms thumbs`: per hand, the thumb against the index (angle, C gap, hook, how far it points up and forward), with bars.


## Shaft ratio (thumb over index) both thumbs must reach.
const SHAFT_MIN := 1.2

## Left hand, an open C ("holding an invisible can"): thumb-to-index angle window in degrees.
const L_ANGLE := Vector2(40.0, 95.0)
## Left hand: thumb tip to index tip distance window, in palm lengths. In the loose fist the
## curled index tip sits near the thumb, so the floor only catches a thumb touching it.
const L_GAP := Vector2(0.08, 0.85)
## Left hand: largest angle in degrees between the thumb tip bone and the line to the index tip.
const L_HOOK_MAX := 70.0
## Left hand: largest dot of the thumb chord with the camera's up.
const L_UP_MAX := 0.45

## Right hand, the thumb wraps the grip's far side under the slide: angle window in degrees.
const R_ANGLE := Vector2(20.0, 80.0)
## Right hand: thumb tip to index tip distance window, in palm lengths.
const R_GAP := Vector2(0.20, 0.90)
## Right hand: largest angle in degrees between the thumb tip bone and the line to the index tip.
const R_HOOK_MAX := 80.0
## Right hand: largest dot of the thumb chord with the camera's up.
const R_UP_MAX := 0.30
## Right hand: smallest dot of the thumb chord with the camera's forward.
const R_FWD_MIN := 0.35


## Read-only readout of each thumb against its index finger: angle, shaft and length ratios, the
## C gap and hook, and how far the thumb points up and forward, ending THUMBS OK or THUMBS CHECK.
func run(vm: Node) -> String:
	var lines: Array[String] = []
	var cam := vm.get_viewport().get_camera_3d()
	if cam == null:
		return "thumbs: no camera\nTHUMBS CHECK"
	var roots := vm.get("_roots") as Dictionary
	var gun := roots.get("gun_root") as Node3D
	var p := 1.0
	if ArmsBuilder.SHOW_GUN and gun != null and gun.visible:
		p = HeldGun.palm_len_of(gun)
	else:
		lines.append("thumbs: no gun, gap in metres")
	var ok := true
	for hand: Array in [["R", "right_root"], ["L", "left_root"]]:
		var h: String = hand[0]
		var root := roots.get(hand[1]) as Node3D
		var model: Node3D = null
		if root != null:
			for c in root.get_children():
				if c is Node3D and ArmRig.skeleton(c as Node3D) != null:
					model = c as Node3D
		if model == null:
			lines.append("thumbs %s: no model" % h)
			ok = false
			continue
		var res := _hand(model, h, p, cam)
		lines.append(res[&"line"])
		ok = ok and res[&"ok"]
	lines.append("THUMBS OK" if ok else "THUMBS CHECK")
	return "\n".join(lines)


## {line, ok} for one hand's readout line and whether it clears the bars.
func _hand(model: Node3D, h: String, p: float, cam: Camera3D) -> Dictionary:
	var fail := {&"line": "thumbs %s: bone missing" % h, &"ok": false}
	var sk := ArmRig.skeleton(model)
	sk.force_update_all_bone_transforms()
	var mi: MeshInstance3D = null
	for c in sk.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).skin != null:
			mi = c as MeshInstance3D
			break
	var t1 := sk.find_bone("DEF-thumb.01." + h)
	var t2 := sk.find_bone("DEF-thumb.02." + h)
	var t3 := sk.find_bone("DEF-thumb.03." + h)
	var i1 := sk.find_bone("DEF-f_index.01." + h)
	var i2 := sk.find_bone("DEF-f_index.02." + h)
	var i3 := sk.find_bone("DEF-f_index.03." + h)
	if mi == null or t1 == -1 or t2 == -1 or t3 == -1 or i1 == -1 or i2 == -1 or i3 == -1:
		return fail
	var fingers: Dictionary = model.get_meta(&"fingers", {})
	var a := sk.get_bone_global_pose(t2).basis.y
	var b := sk.get_bone_global_pose(i1).basis.y
	var angle := rad_to_deg(a.angle_to(b))
	var thumb: Dictionary = fingers.get(&"thumb", {})
	var index: Dictionary = fingers.get(&"f_index", {})
	var shaft := 0.0
	var len_x := 0.0
	if thumb.has(&"shaft") and index.has(&"shaft") and float(index[&"shaft"]) != 0.0:
		shaft = float(thumb[&"shaft"]) / float(index[&"shaft"])
	if thumb.has(&"length") and index.has(&"length") and float(index[&"length"]) != 0.0:
		len_x = float(thumb[&"length"]) / float(index[&"length"])
	var w2 := sk.global_transform * sk.get_bone_global_pose(t2)
	var w3 := sk.global_transform * sk.get_bone_global_pose(t3)
	var thumb_tip := _tip(mi, sk, w3, "DEF-thumb.03." + h)
	var index_tip := _tip(mi, sk, sk.global_transform * sk.get_bone_global_pose(i3),
			"DEF-f_index.03." + h)
	var gap := thumb_tip.distance_to(index_tip) / p
	var hook := rad_to_deg(w3.basis.y.angle_to(index_tip - w3.origin))
	var chord := (thumb_tip - w2.origin).normalized()
	var up := chord.dot(cam.global_basis.y)
	var fwd := chord.dot(-cam.global_basis.z)
	var bars: Array[String] = []
	if shaft < SHAFT_MIN:
		bars.append("shaft")
	if h == "L":
		if angle < L_ANGLE.x or angle > L_ANGLE.y:
			bars.append("angle")
		if gap < L_GAP.x or gap > L_GAP.y:
			bars.append("gap")
		if hook > L_HOOK_MAX:
			bars.append("hook")
		if up > L_UP_MAX:
			bars.append("up")
	else:
		if angle < R_ANGLE.x or angle > R_ANGLE.y:
			bars.append("angle")
		if gap < R_GAP.x or gap > R_GAP.y:
			bars.append("gap")
		if hook > R_HOOK_MAX:
			bars.append("hook")
		if up > R_UP_MAX:
			bars.append("up")
		if fwd < R_FWD_MIN:
			bars.append("fwd")
	var line := "thumbs %s: angle %.0f shaft x%.2f len x%.2f gap/p %.2f hook %.0f up %+.2f fwd %+.2f" % [
			h, angle, shaft, len_x, gap, hook, up, fwd]
	if not bars.is_empty():
		line += " BAR " + ",".join(bars)
	return {&"line": line, &"ok": bars.is_empty()}


## World tip of a leaf bone: its origin plus its world y axis times its rest length, scaled by the
## pose's world y scale (bone_len is a rest length).
func _tip(mi: MeshInstance3D, sk: Skeleton3D, world: Transform3D, bone_name: String) -> Vector3:
	var len_w := ArmWrap.bone_len(mi, sk, bone_name) * world.basis.y.length()
	return world.origin + world.basis.y.normalized() * len_w
