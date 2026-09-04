class_name ActCardDefinition
extends Resource

## Combat behavior lives in composable `effects`. Boss fights activate an Array of
## these cards at once — keep effects stackable (add / multiply, not overwrite).

enum Polarity {
	BLESSING = 0,
	DANGER = 1,
}

@export var id: StringName = &""
@export var display_name := "Unknown Street"
@export_multiline var description := ""
@export var polarity: Polarity = Polarity.BLESSING
@export var icon: Texture2D
## Modular combat / spawn / loot hooks. Add new ActCardEffect subclasses freely.
@export var effects: Array[ActCardEffect] = []


func is_danger() -> bool:
	return polarity == Polarity.DANGER


func polarity_label() -> String:
	return "DANGER" if is_danger() else "BLESSING"


func short_summary() -> String:
	var body := description.strip_edges()
	if body.is_empty():
		return display_name
	return "%s\n%s" % [display_name, body]
