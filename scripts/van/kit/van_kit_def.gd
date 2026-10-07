class_name VanKitDef
extends Resource
## Base data of one salvage kit piece type.

enum Fastener {
	NONE = 0,
	RIVET = 1,
	BOLT = 2,
	WELD = 3,
	SCREW = 4,
}

@export var id: StringName = &""
@export var order: int = 0
@export var since_gen: int = 1
@export var weight: float = 1.0
## Piece size range in metres.
@export var size_min := Vector2.ZERO
@export var size_max := Vector2.ZERO
## Depth range in metres, measured from the liner.
@export var depth_min := 0.0
@export var depth_max := 0.0
@export var zones: Array[StringName] = []
@export var fastener: Fastener = Fastener.NONE
