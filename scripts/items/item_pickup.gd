class_name ItemPickup
extends Pickup

## World pickup for a single ItemDefinition.
##
## Shows the item's icon as a camera-facing Texture2D (Sprite3D billboard)
## and, on auto-grab, runs every effect the item defines. The pickup itself
## has zero knowledge of what those effects do.

@export var item: ItemDefinition

@onready var sprite: Sprite3D = $Sprite3D


func _ready() -> void:
	if item:
		sprite.texture = item.icon
		if item.pickup_radius > 0.0:
			pickup_radius = item.pickup_radius
	super._ready()


func _on_collected(player: Node3D) -> void:
	if item:
		item.apply_effects(player)
