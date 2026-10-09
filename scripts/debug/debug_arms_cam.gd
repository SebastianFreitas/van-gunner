extends RefCounted
## `arms cam`: debug cameras around the hands (preset views and a free orbit).

const CAM_NAME := &"ArmsDebugCam"
## Camera offsets from the focus point in Weapon space (metres); `left` aims at the left hand,
## `elbow` at the left elbow, from below and to its left; `gun` and `gunfront` aim at the gun
## Body's centre and are placed in code (see `run`): `gun` from the player's eye, 2.5 times
## closer; `gunfront` 0.5 m out along the rails. The hands are half again as big, so
## the close-ups step back. All others aim at the right (gun) hand.
const VIEWS := {
	&"front": Vector3(0.0, 0.042, -0.448),
	&"side": Vector3(-0.42, 0.07, -0.07),
	&"rside": Vector3(0.42, 0.07, -0.07),
	&"left": Vector3(0.07, 0.112, -0.42),
	&"top": Vector3(0.0, 0.42, 0.028),
	&"under": Vector3(0.0, -0.40, -0.10),
	&"trig": Vector3(-0.16, -0.06, -0.18),
	&"rtrig": Vector3(0.16, -0.06, -0.18),
	&"back": Vector3(0.0, 0.10, 0.35),
	&"elbow": Vector3(-0.14, -0.168, -0.392),
	&"gun": Vector3.ZERO,
	&"gunfront": Vector3.ZERO,
}
## Where `DEF-forearm.L` starts (the left elbow) relative to the left-hand focus, Weapon space,
## measured with the arms at rest (-0.099, -0.051, 0.002).
const ELBOW_FROM_WRIST := Vector3(-0.1, -0.05, 0.0)
const ORBIT_USAGE := "bad args. arms cam orbit <yaw> <pitch> [dist] [hand=right|left]"

var _cmds: RefCounted  # the DebugArmsCommands owner (hides the body, builds hints)


func _init(owner: RefCounted) -> void:
	_cmds = owner


## `args` is `[view]` or `[orbit, yaw, pitch, dist?, hand?]`; returns the console reply.
func run(vm: Node, args: Array) -> String:
	var view := StringName(str(args[0]))
	var parent := vm.get_parent()
	var old := parent.get_node_or_null(NodePath(CAM_NAME))
	if old != null:
		parent.remove_child(old)
		old.free()
	_cmds._show_body()
	var player_cam := parent.get_parent() as Camera3D
	if view == &"off":
		if player_cam != null:
			player_cam.make_current()
		vm.set_viewmodel_fov(vm.viewmodel_fov)
		return "arms cam off"
	var orbit := view == &"orbit"
	if not orbit and not VIEWS.has(view):
		return "bad args. " + str(_cmds.hint("cam"))
	var offset := Vector3.ZERO
	var hand := &"right"
	var reply := "arms cam " + str(view)
	if orbit:
		if args.size() < 3 or args.size() > 5 or not str(args[1]).is_valid_float() \
				or not str(args[2]).is_valid_float():
			return ORBIT_USAGE
		var yaw := float(str(args[1]))
		var pitch := clampf(float(str(args[2])), -89.0, 89.0)
		var dist := 0.35
		if args.size() >= 4:
			if not str(args[3]).is_valid_float() or float(str(args[3])) <= 0.0:
				return ORBIT_USAGE
			dist = float(str(args[3]))
		if args.size() == 5:
			hand = StringName(str(args[4]))
			if hand != &"right" and hand != &"left":
				return ORBIT_USAGE
		# Yaw 0 / pitch 0 is the `front` side (-Z); yaw 90 swings to +X; pitch 90 is overhead.
		offset = Basis(Vector3.UP, deg_to_rad(-yaw)) \
				* Basis(Vector3.RIGHT, deg_to_rad(pitch)) * Vector3(0.0, 0.0, -dist)
		reply = "arms cam orbit %s %s %s %s" % [yaw, pitch, dist, hand]
	else:
		offset = VIEWS[view] as Vector3
		if view == &"left" or view == &"elbow":
			hand = &"left"
	# The debug cameras look at the arms from outside; the player-camera FOV override would zoom them.
	ViewmodelFov.apply(vm.get_node("Rig"), 0.0)
	var cam := Camera3D.new()
	cam.name = CAM_NAME
	cam.fov = 50.0
	cam.near = 0.01
	if player_cam != null:
		cam.cull_mask = player_cam.cull_mask
	parent.add_child(cam)
	_cmds._hide_body(vm)
	var focus: Vector3 = vm.arms_focus(hand)
	if view == &"elbow":
		focus += ELBOW_FROM_WRIST
	if view == &"gun" or view == &"gunfront":
		focus += _gun_centre_shift(vm)
	var from: Vector3 = focus + offset
	if view == &"gun":
		# On the eye-to-centre line, so the shot shows the gun from the player's own angle.
		var eye := (parent as Node3D).transform.affine_inverse().origin
		from = focus + (eye - focus) / 1.7
	elif view == &"gunfront":
		from = focus + _gun_basis(vm) * Vector3(0.0, 0.0, -0.5)
	var up := Vector3.FORWARD if view == &"top" or view == &"under" else Vector3.UP
	cam.transform = Transform3D(Basis.looking_at(focus - from, up), from)
	cam.make_current()
	return reply


## Offset from the gun hand's origin to the middle of the gun Body (receiver to muzzle).
func _gun_centre_shift(vm: Node) -> Vector3:
	var local := Vector3(0.0, 0.0, HeldGun.muzzle_in_gun.z * 0.5)
	return _gun_basis(vm) * local


## The gun Body's orientation in the camera's space; its -Z points out of the muzzle.
func _gun_basis(vm: Node) -> Basis:
	return (vm as Node3D).transform.basis * (vm.get_node("Rig") as Node3D).transform.basis \
			* HeldGun.gun_xform().basis
