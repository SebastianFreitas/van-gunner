extends Node3D
## Spins a searchlight beam around its own tilted Y axis, sweeping a cone over the street.


@export var tilt := 0.6
@export var degrees_per_second := 20.0


func _ready() -> void:
	rotation.z = tilt


func _process(delta: float) -> void:
	rotate_y(deg_to_rad(degrees_per_second) * delta)
