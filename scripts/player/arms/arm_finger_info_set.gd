class_name ArmFingerInfoSet
extends Resource
## Every finger's `ArmFingerInfo`, both hands, saved as `assets/models/arms/arm_fingers_info.tres`.

@export var fingers: Array[ArmFingerInfo] = []
## Mesh metas ArmRig sets on each side's skin mesh, keyed "L" / "R" (only the hands
## probe reads them): `wrist_seam` is the seam curve, `knuckle_rise` the head rises. Plain numbers
## and mesh-space points, so no vertex indices.
@export var wrist_seam := {}
@export var knuckle_rise := {}
