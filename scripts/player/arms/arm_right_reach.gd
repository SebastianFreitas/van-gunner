class_name ArmRightReach
extends RefCounted
## The right arm's gun-grip `ArmRig.reach` inputs, shared by the build and the inspect re-solve.


## Inputs for `ArmRig.reach` with the gun shown: shoulder, wrist, pole, hand_dir, palm.
static func inputs(gx: Transform3D, gun_style: StringName, shoulder_r: Vector3) -> Dictionary:
	var grip := gun_style == &"grip"
	return {
		"shoulder": shoulder_r,
		"wrist": gx * (ArmsBuilder.right_wrist_in_gun * ArmsBuilder.HAND_K),
		"pole": ArmsBuilder.RIGHT_POLE,
		"hand_dir": (gx.basis * (ArmsBuilder.GRIP_HAND_DIR_IN_GUN if grip
				else ArmsBuilder.RIGHT_HAND_DIR_IN_GUN)).normalized(),
		"palm": (gx.basis * (ArmsBuilder.GRIP_PALM_IN_GUN if grip
				else ArmsBuilder.RIGHT_PALM_IN_GUN)).normalized(),
	}
