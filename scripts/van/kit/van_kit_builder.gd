class_name VanKitBuilder
extends Node3D
## Runs the salvage kit's passes in order under the look rebuild; builds nothing when the kit is off.
##
## Pass contract: a pass script (RefCounted or static) exposes
## `static func place(ctx: VanKitBuilder.Ctx) -> Array[VanKitPlaced]` (pure data, a function of
## the seed) and `static func build(ctx: VanKitBuilder.Ctx, placed: Array[VanKitPlaced],
## parent: Node3D) -> void`, which adds that pass's nodes under `parent` (this node). Every mesh
## node a pass adds sets `layers = VanLighting.LAYER_VAN_INTERIOR` before `add_child`.

## Pass scripts in build order.
const PASSES: Array[GDScript] = [preload("res://scripts/van/kit/van_kit_structure.gd"),
	preload("res://scripts/van/kit/van_kit_skin.gd"),
	preload("res://scripts/van/kit/van_kit_seams.gd"),
	preload("res://scripts/van/kit/van_kit_windows.gd"),
	preload("res://scripts/van/kit/van_kit_windows_rear.gd"),
	preload("res://scripts/van/kit/van_kit_arch.gd"),
	preload("res://scripts/van/kit/van_kit_patches.gd"),
	preload("res://scripts/van/kit/van_kit_braces.gd"),
	preload("res://scripts/van/kit/van_kit_wear.gd")]

## What the last kit rebuild placed.
var placed: Array[VanKitPlaced] = []
## Nodes passes added under a rear-door hinge (outside this node, so cleared by hand).
var _leaf_nodes: Array[Node] = []


## Everything a pass reads: the seed, the donor set, the keep-out and a per-pass RNG.
class Ctx extends RefCounted:
	var van_seed := 0
	var donors: VanDonorSet
	var keep_out: VanKitKeepOut
	## The van rig, for passes that avoid shell fixtures; null in a headless check without one.
	var rig: Node3D
	## The van_look node (the rig's VanLook child), for `VanWheels.rear_axles_for(look)`.
	var look: Node
	## What the passes before this one placed.
	var placed: Array[VanKitPlaced] = []

	func rng(pass_id: StringName, surface: StringName = &"") -> RandomNumberGenerator:
		var key := "kit/" + String(pass_id)
		if surface != &"":
			key += "/" + String(surface)
		return VanLook.rng_for_seed(van_seed, StringName(key))


## The pieces every pass places for a seed; the golden, the rules check and the builder read it.
static func place_all(van_seed: int, rig: Node3D) -> Array[VanKitPlaced]:
	var ctx := Ctx.new()
	ctx.van_seed = van_seed
	ctx.donors = VanDonors.roll_seed(van_seed)
	ctx.rig = rig
	if rig != null:
		ctx.look = rig.get_node_or_null(^"VanLook")
	if rig != null:
		ctx.keep_out = VanKitKeepOut.build(rig, ctx.donors)
	var out: Array[VanKitPlaced] = []
	for pass_script in PASSES:
		var pass_placed: Array[VanKitPlaced] = pass_script.place(ctx)
		ctx.placed.append_array(pass_placed)
		out.append_array(pass_placed)
	return out


func rebuild_look(look: VanLook) -> void:
	for node in _leaf_nodes:
		if is_instance_valid(node):
			node.get_parent().remove_child(node)
			node.queue_free()
	_leaf_nodes.clear()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	placed = []
	var ctx := Ctx.new()
	ctx.van_seed = look.van_seed
	ctx.donors = VanDonors.roll(look)
	ctx.rig = look.get_parent() as Node3D
	ctx.look = look
	ctx.keep_out = VanKitKeepOut.build(look.get_parent() as Node3D, ctx.donors)
	for pass_script in PASSES:
		var pass_placed: Array[VanKitPlaced] = pass_script.place(ctx)
		placed.append_array(pass_placed)
		ctx.placed.append_array(pass_placed)
		_build_pass(pass_script, ctx, pass_placed, look.get_parent() as Node3D)


## Builds a pass's pieces: under this node for `attach` &"", else under the rear-door hinge.
func _build_pass(pass_script: GDScript, ctx: Ctx, pass_placed: Array[VanKitPlaced],
		rig: Node3D) -> void:
	var groups := {&"": [] as Array[VanKitPlaced], &"left_leaf": [] as Array[VanKitPlaced],
		&"right_leaf": [] as Array[VanKitPlaced]}
	for p in pass_placed:
		groups[p.attach].append(p)
	pass_script.build(ctx, groups[&""], self)
	for attach: StringName in [&"left_leaf", &"right_leaf"]:
		var group: Array[VanKitPlaced] = groups[attach]
		var hinge_name := "LeftHinge" if attach == &"left_leaf" else "RightHinge"
		var hinge := rig.get_node_or_null("Interior/Shell/RearWall/" + hinge_name) as Node3D
		if group.is_empty() or hinge == null:
			continue
		var before := hinge.get_children()
		pass_script.build(ctx, group, hinge)
		for child in hinge.get_children():
			if not before.has(child):
				_leaf_nodes.append(child)
