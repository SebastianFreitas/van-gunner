class_name ArmSkinFolds
extends RefCounted
## Places the knuckle creases and back-of-hand tendons of one arm's skin (rest space, fixed).

## Array size of the shader's crease uniforms.
const FOLD_MAX := 14
## Array size of the shader's tendon uniforms.
const TENDON_MAX := 4
## Sections per ring when measuring a bone's radius.
const SECTORS := 12
## The fingers that get creases and a tendon; the thumb is placed on its own.
const FINGERS: Array[String] = ["index", "middle", "ring", "pinky"]
## Finger radius at joint 1, 2, 3 as a share of the knuckle's.
const TAPER: Array[float] = [1.0, 0.9, 0.78]
## Crease reach at the knuckle, in finger radii.
const REACH_KNUCKLE := 2.4
## Crease reach at the other joints, in finger radii.
const REACH_JOINT := 2.2
## Tendon half-width, in finger radii.
const TENDON_HALF := 0.32
## How far from the wrist toward the knuckle a tendon starts.
const TENDON_START := 0.15
## How far a crease sinks into the skin.
const FOLD_HEIGHT := 0.55


## Sets the crease and tendon uniforms of `mat` from the bones of `mi`; all points are rest
## (mesh) space. `side` is ".L" or ".R". The uniforms are always set so no count goes stale, and
## no rng is used: an extra draw would move the dirt amount.
static func apply(mat: ShaderMaterial, mi: MeshInstance3D, sk: Skeleton3D, side: String) -> void:
	var fold_p := PackedVector4Array()
	var fold_d := PackedVector4Array()
	var fold_n := PackedVector4Array()
	var ten_a := PackedVector4Array()
	var ten_b := PackedVector4Array()
	var ten_n := Vector3.UP
	var wrist := Vector3.ZERO
	var hand := "DEF-hand" + side
	var has_hand := _has(mi, sk, hand)
	if has_hand:
		var hf := ArmSkinMesh.ring_frame(mi, sk, hand, 0.0)
		wrist = hf.origin
		ten_n = _back(hf.basis.y.normalized(), Vector3.UP)
	for f: String in FINGERS:
		var fr := 0.0
		for j: int in [1, 2, 3]:
			var bone := "DEF-f_%s.0%d%s" % [f, j, side]
			if not _has(mi, sk, bone):
				continue
			var frame := ArmSkinMesh.ring_frame(mi, sk, bone, 0.0)
			var y := frame.basis.y.normalized()
			if j == 1:
				fr = _radius(mi, sk, bone, 0.5)
				if has_hand:
					ten_a.append(_v4(wrist.lerp(frame.origin, TENDON_START), TENDON_HALF * fr))
					ten_b.append(_v4(frame.origin, 0.0))
			if fr <= 0.0:
				continue
			var r := fr * TAPER[j - 1]
			fold_p.append(_v4(frame.origin, (REACH_KNUCKLE if j == 1 else REACH_JOINT) * r))
			fold_d.append(_v4(y, r))
			fold_n.append(_v4(_back(y, Vector3.UP), 2.0 if j == 3 else 3.0))
	var thumb02 := "DEF-thumb.02" + side
	var thumb03 := "DEF-thumb.03" + side
	var index01 := "DEF-f_index.01" + side
	if _has(mi, sk, thumb02) and _has(mi, sk, thumb03) and _has(mi, sk, index01):
		var thumb_r := _radius(mi, sk, thumb02, 0.5)
		var hint := (ArmSkinMesh.ring_frame(mi, sk, index01, 0.0).origin
				- ArmSkinMesh.ring_frame(mi, sk, thumb02, 0.0).origin)
		var thumb_bones: Array[String] = [thumb02, thumb03]
		for k: int in 2:
			var frame := ArmSkinMesh.ring_frame(mi, sk, thumb_bones[k], 0.0)
			var y := frame.basis.y.normalized()
			var r := thumb_r if k == 0 else thumb_r * 0.9
			fold_p.append(_v4(frame.origin, REACH_JOINT * r))
			fold_d.append(_v4(y, r))
			fold_n.append(_v4(_back(y, -hint), 2.0 if k == 0 else 3.0))
	var folds := fold_p.size()
	var cords := ten_a.size()
	fold_p.resize(FOLD_MAX)
	fold_d.resize(FOLD_MAX)
	fold_n.resize(FOLD_MAX)
	ten_a.resize(TENDON_MAX)
	ten_b.resize(TENDON_MAX)
	mat.set_shader_parameter(&"fold_count", folds)
	mat.set_shader_parameter(&"fold_p", fold_p)
	mat.set_shader_parameter(&"fold_d", fold_d)
	mat.set_shader_parameter(&"fold_n", fold_n)
	mat.set_shader_parameter(&"tendon_count", cords)
	mat.set_shader_parameter(&"tendon_a", ten_a)
	mat.set_shader_parameter(&"tendon_b", ten_b)
	mat.set_shader_parameter(&"tendon_n", ten_n)
	mat.set_shader_parameter(&"fold_height", FOLD_HEIGHT)


## The part of `ref` perpendicular to `axis`, normalised: the direction of the back of the hand.
static func _back(axis: Vector3, ref: Vector3) -> Vector3:
	return (ref - axis * ref.dot(axis)).normalized()


static func _v4(v: Vector3, w: float) -> Vector4:
	return Vector4(v.x, v.y, v.z, w)


## Mean section radius of `bone` at fraction t: the scale every size here is a fraction of.
static func _radius(mi: MeshInstance3D, sk: Skeleton3D, bone: String, t: float) -> float:
	return ArmWrap.mean_radius(ArmWrap.section(mi, sk, bone, t, SECTORS, PackedStringArray()))


static func _has(mi: MeshInstance3D, sk: Skeleton3D, bone: String) -> bool:
	if ArmWrap.bind_index(mi, sk, bone) != -1:
		return true
	push_warning("ArmSkinFolds: bone %s missing, skipping its item" % bone)
	return false
