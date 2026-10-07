class_name VanWindowAssetDef
extends VanKitDef
## Kit piece type: a salvaged window asset set into a side wall.

enum Shape {
	ROUNDED_RECT = 0,
	ROUGH_RECT = 1,
}

enum Join {
	GASKET = 0,
	RIVETED_FLANGE = 1,
	WELDED_COLLAR = 2,
}

@export var shape: Shape = Shape.ROUNDED_RECT
@export var corner_radius_m := 0.0
@export var wall_part_margin_min_m := 0.08
@export var wall_part_margin_max_m := 0.15
@export var join: Join = Join.GASKET
## Bolt spacing in metres; keep at 0.20 or more so the bolts read chunky.
@export var bolt_pitch_m := 0.20
@export var bead_width_m := 0.0
@export var bar_section: StringName = &""
@export var rear_fit_rule: StringName = &""
@export var use_region_paint := false
@export var paint := Color(0, 0, 0)
@export var plate_thickness_m := 0.0
@export var edge_rough_m := 0.0
