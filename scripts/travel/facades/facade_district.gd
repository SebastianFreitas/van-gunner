class_name FacadeDistrict
extends Resource
## One neighborhood look: skin presets, height range, ground-floor kinds, window state ratios
## and prop chances. Edit the .tres files in resources/facades/districts/ to tune a district.


@export var id := &"tenement"
## Position in the neighborhood picker; must be unique across the folder.
@export var index := 0
## Repetition = weight.
@export var presets: Array[StringName] = [
	&"brick_red", &"brick_red", &"brick_brown", &"brick_brown", &"plaster_tan", &"plaster_green"
]
@export var height_min := 16.0
@export var height_max := 26.0
@export var tall_chance := 0.2
@export var tall_min := 28.0
@export var tall_max := 34.0
@export var ground_kinds: Array[int] = [1, 1, 1, 2, 5, 0]
@export var lit_ratio := 0.35
@export var grime := 0.55
@export var boarded_ratio := 0.0
@export var broken_ratio := 0.03
@export var damage := 0.05
## Condition weights per building: intact, worn, broken, gutted (facade_ruin.gd).
@export var ruin_weights: Array[float] = [0.12, 0.38, 0.32, 0.18]
@export var band_every: Array[float] = [0.0, 2.0, 3.0]

## Prop chances (0..1).
@export var cornice_chance := 0.7
@export var ledge_chance := 0.8
## Per window cell.
@export var ac_unit_chance := 0.25
@export var fire_escape_chance := 0.4
@export var balcony_chance := 0.2
@export var downspout_chance := 0.6
@export var roof_clutter_chance := 0.6
@export var wall_pipe_chance := 0.1

## Lighting (used by step 5; declared now so districts don't need a later migration).
@export var lamp_color := Color(1.0, 0.62, 0.3)
@export var lamp_energy := 1.2
@export var lamps_per_side := 2
@export var dead_lamp_chance := 0.05

## Signage (used by step 7; declared now so districts don't need a later migration).
@export var sign_words: PackedStringArray = PackedStringArray([
	"BODEGA", "LAUNDRY", "PAWN", "LIQUOR", "CHECKS CASHED", "KEYS", "NOODLES", "PIZZA", "TATTOO",
	"BAIL BONDS",
])
@export var sign_chance := 0.6
@export var awning_chance := 0.5
@export var furniture_chance := 0.5

## Chance a plain (both-sides-NONE, no rare) tile gets cross-street overhead dressing.
@export var overhead_chance := 0.0

## Spray-paint graffiti on this district's walls: 0 none, 1 heavy.
@export_range(0.0, 1.0) var graffiti_amount := 0.6
## Pasted paper posters on this district's walls: 0 none, 1 heavy.
@export_range(0.0, 1.0) var poster_amount := 0.5

## Chance a lot steps back 1-3 m from the street line (range below).
@export var recess_mild_chance := 0.0
## Chance a lot steps back 4-6 m from the street line (range below).
@export var recess_deep_chance := 0.0
## Mild recess depth range, metres.
@export var recess_mild_range := Vector2(1.0, 3.0)
## Deep recess depth range, metres.
@export var recess_deep_range := Vector2(4.0, 6.0)
## Chance the whole tile side steps back together by one whole-metre depth.
@export var recess_side_chance := 0.0
## A lot here stepped back 3 m or more gets a flagstone plaza instead of a wider road.
@export var plaza := false
