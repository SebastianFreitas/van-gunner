class_name VanWallAnchor
extends Node3D
## Child marker that places its parent against the van walls from VanInteriorSize and
## VanOpenings, so a resized van moves wall-hugging props, zones and lights with it.

enum ZRef { NONE, FRONT, REAR, BULKHEAD }

## -1 left wall, 1 right wall, 0 leaves the parent's x alone.
@export_range(-1, 1) var side := 0
## Metres in from the liner's floor line (VanInteriorSize.BOTTOM_HALF).
@export var inset := 0.0
## End the parent's z is measured from, plus `z_offset` (toward the cabin is positive from
## FRONT, negative from REAR).
@export var z_ref := ZRef.NONE
@export var z_offset := 0.0
## Optional far end of a zone: the parent sits at the midpoint of the two ends and its
## `Collision` child is scaled to the span.
@export var span_ref := ZRef.NONE
@export var span_offset := 0.0


func _enter_tree() -> void:
	var target := get_parent() as Node3D
	if target == null:
		return
	if side != 0:
		target.position.x = float(side) * (VanInteriorSize.BOTTOM_HALF - inset)
	if z_ref == ZRef.NONE:
		return
	var z0 := _z_of(z_ref) + z_offset
	if span_ref == ZRef.NONE:
		target.position.z = z0
		return
	var z1 := _z_of(span_ref) + span_offset
	target.position.z = (z0 + z1) * 0.5
	var shape := target.get_node_or_null(^"Collision") as Node3D
	if shape != null:
		shape.scale.z = absf(z1 - z0)


func _z_of(ref: ZRef) -> float:
	match ref:
		ZRef.FRONT:
			return VanInteriorSize.FRONT_Z
		ZRef.REAR:
			return VanInteriorSize.REAR_Z
		ZRef.BULKHEAD:
			return VanOpenings.BULKHEAD_Z
	return 0.0
