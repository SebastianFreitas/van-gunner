class_name VanKit
extends RefCounted
## Static switches of the salvage interior kit.

const GEN := 1



## The pieces the kit places for a van seed: what the builder's passes place, read off the live
## van rig for the keep-out (null when no van is in the tree).
static func place(seed_value: int) -> Array[VanKitPlaced]:
	var van: Node = Engine.get_main_loop().root.get_tree().get_first_node_in_group(&"van_run")
	var rig: Node3D = van.get_node_or_null(^"TravelPath/VanFollow/VanRig") if van != null else null
	return VanKitBuilder.place_all(seed_value, rig)
