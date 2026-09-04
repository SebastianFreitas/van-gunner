class_name ActCardDefinition
extends Resource

## Data-only street card for the act deck.
## Polarity drives good vs danger roads; modifier fields are stored for later combat wiring.

enum Polarity {
	BLESSING = 0,
	DANGER = 1,
}

@export var id: StringName = &""
@export var display_name := "Unknown Street"
@export_multiline var description := ""
@export var polarity: Polarity = Polarity.BLESSING
@export var icon: Texture2D

## Placeholder combat knobs — not applied to enemies yet.
@export var cold_damage_bonus := 0.0
@export var enemy_speed_mult := 1.0
## Scales up with danger; intended for stronger negatives → better loot later.
@export var enemy_loot_chance_bonus := 0.0


func is_danger() -> bool:
	return polarity == Polarity.DANGER


func polarity_label() -> String:
	return "DANGER" if is_danger() else "BLESSING"


func short_summary() -> String:
	var body := description.strip_edges()
	if body.is_empty():
		return display_name
	return "%s\n%s" % [display_name, body]