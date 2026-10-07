class_name VanKitPlaced
extends RefCounted
## One placed kit piece: which def, where, and why it was put there.

var def_id: StringName = &""
var surface: StringName = &""
## &"" = under InteriorKit, else &"left_leaf" / &"right_leaf": the transform is in that rear
## door hinge's space and the node rides the leaf.
var attach: StringName = &""
## &"DONOR" or &"SCRAP".
var origin_kind: StringName = &""
var origin_id: StringName = &""
var reason: StringName = &""
var transform := Transform3D.IDENTITY
var size := Vector3.ZERO
var outline := PackedVector2Array()
var gen := 1
