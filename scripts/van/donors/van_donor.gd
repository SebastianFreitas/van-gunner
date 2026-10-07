class_name VanDonor
extends Resource
## One donor van whose body panels the interior walls are made from.

enum WallStyle {
	RIBBED_SMOOTH = 0,
	CORRUGATED = 1,
	RIBBED_PANEL = 2,
	FLAT = 3,
}

enum RibProfile {
	TOP_HAT = 0,
	Z = 1,
	C = 2,
}

enum FastenerEra {
	FACTORY = 0,
	HAND = 1,
}

@export var id: StringName = &""
@export var label := ""
## Linear RGB paint.
@export var paint := Color(0, 0, 0)
@export var primer := Color(0, 0, 0)
## How much paint has worn off to primer, 0..1.
@export_range(0.0, 1.0) var fade := 0.0
@export var wall_style: WallStyle = WallStyle.RIBBED_SMOOTH
## 0 unless CORRUGATED.
@export var corrugation_pitch_m := 0.0
@export var rib_profile: RibProfile = RibProfile.TOP_HAT
@export var rib_pitch_m := 0.0
@export var fastener_era: FastenerEra = FastenerEra.FACTORY
