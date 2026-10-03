class_name GunViewmodel
extends Node3D
## First-person goblin arms and pipe rifle on a 0.18-scaled rig under the camera, rebuilt from the van seed; shot kick and reload cant.

const ArmWeave := preload("res://scripts/player/arms/arm_weave.gd")
const ArmKick := preload("res://scripts/player/arms/arm_kick.gd")
const ArmGesture := preload("res://scripts/player/arms/arm_gesture.gd")
const ArmWalk := preload("res://scripts/player/arms/arm_walk.gd")

const RIG_SCALE := 0.18
## Vertical FOV the arms and gun draw with (the world camera is 78); 0 = the camera's own.
const VIEWMODEL_FOV := 50.0
const RELOAD_ROLL := -35.0 * PI / 180.0
const RELOAD_DIP := 0.1  ## virtual metres
const SWAY_MAX := 2.0 * PI / 180.0  ## radians, cap per axis
const SWAY_GAIN := 0.02  ## seconds: a 100 deg/s turn reaches the cap
const SWAY_RATE := 10.0  ## lerp rate per second
const DRIFT_WALK_KEEP := 0.3  ## share of the idle arm drift left at full walk
const SLAP_DROP := 0.12  ## virtual metres the left hand drops below the magazine
## Rig-space tuning shift for the left hand at rest; the pose constants in `ArmsBuilder` own
## the framing now, so this stays zero.
const LEFT_REST := Vector3.ZERO
const RIGHT_REST := Vector3.ZERO  ## rig-space tuning shift for the right hand, kept at zero
## Degrees XYZ tuning tilt of the right arm root, kept at zero (`ArmsBuilder` poses the hand).
const RIGHT_REST_TILT := Vector3.ZERO
const LEFT_REST_TILT := Vector3.ZERO  ## mirror for the left; fades out with `shown`
## Smoke holds the finger weave still at this time, like the facade lamp flicker.
const WEAVE_SANDBOX_T := 1.1
## Fraction of the way from the shown left wrist to the magazine point the reload slap travels;
## the gun is hidden, so the arm only swings in toward the right hand.
const LEFT_REACH_K := 0.35

## Debug overrides from the arms console command; negative means off.
var debug_reload_t := -1.0
## >= 0 pins the finger weave time, from arms weave.
var debug_weave_t := -1.0
## >= 0 pins one shot's kick at this time, from arms shot.
var debug_shot_t := -1.0
## Pins the left-hand gesture `debug_gesture_kind` at this many seconds; negative = off.
var debug_gesture_kind: StringName = &""
var debug_gesture_t := -1.0
## >= 0 pins the walk cycle (0..1) at `debug_walk_amount` strength, from arms walk.
var debug_walk_t := -1.0
var debug_walk_amount := 1.0
## `&"start"` or `&"stop"` pins that walk transition at `debug_walk_t` seconds.
var debug_walk_kind: StringName = &""
## Current viewmodel FOV in degrees, reapplied after every `rebuild_arms`.
var viewmodel_fov := VIEWMODEL_FOV
@onready var _rig: Node3D = $Rig
var _look: VanLook
var _roots := {}
## Seed of the last `rebuild_arms`, so the `arms dress` console command can rebuild the same look.
var _arms_seed := 0
var _reload_t := 0.0
var _reloading := false
var _reload_tween: Tween
var _camera: Node3D
var _body: Node3D
var _prev_basis := Basis.IDENTITY
var _prev_body_pos := Vector3.ZERO
var _has_prev := false
var _sway := Vector2.ZERO  ## x pitch, y yaw (radians)
var _weave: RefCounted = null
var _weave_t := 0.0
var _kick: RefCounted = null
var _gesture: RefCounted = null
var _kick_clock := 0.0
var _shots := 0
var _walk: RefCounted = ArmWalk.new()


func _ready() -> void:
	add_to_group(&"gun_viewmodel")
	_rig.scale = Vector3.ONE * RIG_SCALE
	# The Player node sits before VanLook in van.tscn, so wait a frame for the group.
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_camera = get_parent().get_parent() as Node3D
	_body = get_tree().get_first_node_in_group(&"player") as Node3D
	_look = get_tree().get_first_node_in_group(VanLook.GROUP) as VanLook
	if _look != null:
		_look.look_rebuilt.connect(rebuild_arms)
		rebuild_arms(_look.van_seed)
	else:
		rebuild_arms(VanLook.DEFAULT_VAN_SEED)


## Frees the old arms and rifle and builds a fresh set from the van seed.
func rebuild_arms(seed_value: int) -> void:
	_arms_seed = seed_value
	_weave = null
	_kick = null
	_gesture = null
	for child in _rig.get_children():
		_rig.remove_child(child)
		child.queue_free()
	var van_name := ""
	if _look != null:
		var markings := _look.get_node_or_null(^"Markings") as VanMarkings
		if markings != null:
			van_name = markings.van_name
	_roots = ArmsBuilder.build(_rig, seed_value, van_name)
	_weave = ArmWeave.new(_arm_model("right_root"), _arm_model("left_root"), seed_value,
			ArmsBuilder.SHOW_GUN)
	_kick = ArmKick.new(_arm_model("right_root"), _roots.get("gun_root") as Node3D)
	_gesture = ArmGesture.new(_arm_model("left_root"))
	ViewmodelFov.apply(_rig, viewmodel_fov)
	_apply()


## Sets the viewmodel FOV on the arms and gun now and for later rebuilds; 0 = the camera's own.
func set_viewmodel_fov(fov_deg: float) -> void:
	viewmodel_fov = maxf(fov_deg, 0.0)
	ViewmodelFov.apply(_rig, viewmodel_fov)


## The glb model under an arm root (the child that has a skeleton), or null.
func _arm_model(root_key: String) -> Node3D:
	var root := _roots.get(root_key) as Node3D
	if root == null:
		return null
	for c in root.get_children():
		if c is Node3D and ArmRig.skeleton(c as Node3D) != null:
			return c as Node3D
	return null


## Muzzle in Weapon space, real metres. One rifle serves every family.
func apply_family(_family: ClassDefinition.Family) -> Vector3:
	var xf := _rig.transform if _rig != null else Transform3D(
		Basis.IDENTITY.scaled(Vector3.ONE * RIG_SCALE), Vector3.ZERO
	)
	return xf * HeldGun.muzzle_local()


func play_shot() -> void:
	if _reloading:
		return
	if _kick:
		_kick.fire(_kick_clock, _shots)
	_shots += 1


## Starts a left-hand interaction gesture; returns the contact delay in seconds. While
## reloading (the left hand is busy) or without arms nothing plays and the delay is 0.
func play_gesture(kind: StringName) -> float:
	if _reloading or _gesture == null:
		return 0.0
	return _gesture.play(kind, _kick_clock)


func play_reload(duration: float) -> void:
	var d := maxf(duration, 0.05)
	if _reload_tween != null and _reload_tween.is_valid():
		_reload_tween.kill()
	if _kick:
		_kick.clear()
	if _gesture:
		_gesture.clear()
	_reloading = true
	_reload_tween = create_tween()
	_reload_tween.tween_method(_set_reload_t, 0.0, 1.0, d)
	_reload_tween.tween_callback(snap_rest)


func snap_rest() -> void:
	if _reload_tween != null and _reload_tween.is_valid():
		_reload_tween.kill()
	if _kick:
		_kick.clear()
	if _gesture:
		_gesture.clear()
	_reload_t = 0.0
	_sway = Vector2.ZERO
	_walk.reset()
	_has_prev = false
	_reloading = false
	_apply()


func _set_reload_t(v: float) -> void:
	_reload_t = v
	_apply()


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	if _camera != null:
		var cur := _camera.global_basis.orthonormalized()
		if _has_prev:
			var e := (_prev_basis.inverse() * cur).get_euler()
			var target := Vector2(
				clampf(-e.x / delta * SWAY_GAIN, -SWAY_MAX, SWAY_MAX),
				clampf(-e.y / delta * SWAY_GAIN, -SWAY_MAX, SWAY_MAX)
			)
			_sway = _sway.lerp(target, 1.0 - exp(-SWAY_RATE * delta))
		_prev_basis = cur
	var lateral := 0.0
	var forward := 0.0
	if _body != null:
		if _has_prev:
			# Parent-local, so the van's own travel never counts as walking.
			var d := _body.position - _prev_body_pos
			var speed_v := d / delta
			if Vector2(speed_v.x, speed_v.z).length() > 20.0:
				speed_v = Vector3.ZERO  # a teleport or reparent, not walking
			var parent := _body.get_parent() as Node3D
			var pb := parent.global_basis.orthonormalized() if parent else Basis.IDENTITY
			var fwd := Vector3.FORWARD
			if _camera != null:
				fwd = pb.inverse() * -_camera.global_basis.z
			fwd.y = 0.0
			if fwd.length() < 0.01:
				fwd = Vector3.FORWARD
			fwd = fwd.normalized()
			var right := fwd.cross(Vector3.UP)
			lateral = speed_v.dot(right)
			forward = speed_v.dot(fwd)
		_prev_body_pos = _body.position
	if debug_walk_t >= 0.0:
		if debug_walk_kind == &"":
			_walk.pin_cycle(debug_walk_t, debug_walk_amount)
		else:
			_walk.pin_transition(debug_walk_kind, debug_walk_t)
	elif SaveSandbox.enabled:
		_walk.reset()  # keeps smoke stills comparable
	else:
		_walk.step(delta, lateral, forward)
	_has_prev = true
	_weave_t = fmod(_weave_t + delta, 3600.0)
	var weave_at := debug_weave_t if debug_weave_t >= 0.0 else (
			WEAVE_SANDBOX_T if SaveSandbox.enabled else _weave_t)
	if _weave:
		_weave.update(weave_at)
	var clock := fmod(_kick_clock + delta, 3600.0)
	if clock < _kick_clock and _kick:
		_kick.clear()
		if _gesture:
			_gesture.clear()
	_kick_clock = clock
	if _kick:
		if debug_shot_t >= 0.0:
			_kick.pin(debug_shot_t)
		elif SaveSandbox.enabled:
			_kick.pin(10.0)  # fully settled, keeps smoke stills comparable
		else:
			_kick.sample(_kick_clock)
	if _gesture:
		if debug_gesture_t >= 0.0:
			_gesture.pin(debug_gesture_kind, debug_gesture_t)
		elif SaveSandbox.enabled:
			_gesture.settle()  # no gesture, keeps smoke stills comparable
		else:
			_gesture.sample(_kick_clock)
		_gesture.apply_bones()
	_apply()


## Debug camera target in the Weapon node's space (metres): the left wrist or the rifle.
func arms_focus(which: StringName) -> Vector3:
	if _roots.is_empty():
		return Vector3.ZERO
	if which == &"left":
		var left := _roots.get("left_root") as Node3D
		var wrist := _roots.get("left_wrist", Vector3.ZERO) as Vector3
		if left == null:
			return Vector3.ZERO
		return transform * (_rig.transform * (left.transform * wrist))
	return transform * (_rig.transform * HeldGun.gun_xform().origin)


## Look sway and the walk layer (ArmWalk) applied to the rifle and both arms.
func _motion() -> Transform3D:
	return Transform3D(
		Basis(Vector3.UP, _sway.y) * Basis(Vector3.RIGHT, _sway.x), Vector3.ZERO
	) * _walk.rig_offset(HeldGun.GRIP)


## Reload timeline t 0..1 as x cant, y left-hand reach to the magazine, z slap (two humps).
func _reload_curves(t: float) -> Vector3:
	var c := 0.0
	if t < 0.75:
		c = smoothstep(0.0, 0.25, t)
	else:
		c = 1.0 - smoothstep(0.75, 1.0, t)
	var z := 0.0
	if t >= 0.25 and t < 0.75:
		var u := (t - 0.25) / 0.5
		z = sin(PI * fmod(u * 2.0, 1.0))
	return Vector3(c, c, z)


## Poses the rifle and both arms: sway and bob on all three, the shot kick on each arm and the
## rifle, the reload cant (about the grip) on the rifle and the right arm only; the left hand
## reaches under the magazine and slaps.
func _apply() -> void:
	var kick_r: Transform3D = _kick.right_offset() if _kick else Transform3D.IDENTITY
	var kick_l: Transform3D = _kick.left_offset() if _kick else Transform3D.IDENTITY
	var gest_l: Transform3D = _gesture.left_offset() if _gesture else Transform3D.IDENTITY
	var kick_w: Transform3D = _kick.wrist_offset() if _kick else Transform3D.IDENTITY
	var grip := Transform3D(Basis.IDENTITY, HeldGun.GRIP)
	var k := _reload_curves(_reload_t if debug_reload_t < 0.0 else debug_reload_t)
	var roll := Transform3D(
		Basis(Vector3.BACK, RELOAD_ROLL * k.x), Vector3(0.0, -RELOAD_DIP * k.x, 0.0)
	)
	var cant := grip * roll * grip.affine_inverse()
	var m := _motion()
	var gun_x := m * cant
	var rest_pt := _roots.get("left_wrist", Vector3.ZERO) as Vector3
	var shown := k.y
	var hide_off := LEFT_REST * (1.0 - shown)
	var gx := cant * HeldGun.gun_xform()
	var mag_pt := gx * HeldGun.mag_slap_in_gun
	var down := (gx.basis * Vector3.DOWN).normalized()
	var off := hide_off + (mag_pt - rest_pt) * (k.y * LEFT_REACH_K) + down * SLAP_DROP * k.z
	var rest_r := Transform3D(Basis.from_euler(RIGHT_REST_TILT * (PI / 180.0)), RIGHT_REST)
	var drift_r: Transform3D = _weave.arm_offset(0) if _weave else Transform3D.IDENTITY
	var drift_l: Transform3D = _weave.arm_offset(1) if _weave else Transform3D.IDENTITY
	# Walking takes over the arm motion, so the idle drift fades out with it.
	var keep := lerpf(1.0, DRIFT_WALK_KEEP, _walk.amount())
	drift_r = Transform3D.IDENTITY.interpolate_with(drift_r, keep)
	drift_l = Transform3D.IDENTITY.interpolate_with(drift_l, keep)
	var right_x := gun_x * rest_r * drift_r * kick_r
	var tilt_l := Basis.from_euler(LEFT_REST_TILT * (1.0 - shown) * (PI / 180.0))
	var gun := _roots.get("gun_root") as Node3D
	var right := _roots.get("right_root") as Node3D
	var left := _roots.get("left_root") as Node3D
	if gun != null:
		gun.transform = right_x * kick_w
	if right != null:
		right.transform = right_x
	if left != null:
		left.transform = (m * _walk.left_offset() * kick_l * gest_l
				* Transform3D(tilt_l, off) * drift_l)
