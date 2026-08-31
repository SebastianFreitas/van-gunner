extends Node3D

const VARIANT_COUNT := 4

@onready var _variants: Array[Node3D] = [
	$Structure/Variant0,
	$Structure/Variant1,
	$Structure/Variant2,
	$Structure/Variant3,
]


func apply_variant(index: int) -> void:
	index = clampi(index, 0, VARIANT_COUNT - 1)
	for variant_index in _variants.size():
		_variants[variant_index].visible = variant_index == index
