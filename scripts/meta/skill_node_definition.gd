class_name SkillNodeDefinition
extends Resource

## One cell on the van schematic. Gameplay lives in `effects`; layout is grid
## units from the origin (HUD multiplies by a pixel spacing).

enum Branch {
	ORIGIN = 0,
	UP = 1,
	DOWN = 2,
	LEFT = 3,
	RIGHT = 4,
}

@export var id: StringName = &""
@export var display_name := "Unknown"
@export_multiline var description := ""
@export var icon: Texture2D
@export var branch: Branch = Branch.ORIGIN
@export var parent_id: StringName = &""
@export var cost := 1
## Grid offset from origin; +Y is down the tree (hull), -Y is up (speed).
@export var layout_offset := Vector2.ZERO
@export var effects: Array[SkillNodeEffect] = []


func is_origin() -> bool:
	return branch == Branch.ORIGIN or parent_id == &""


func is_stub() -> bool:
	return effects.is_empty() and not is_origin()


func effect_summary() -> String:
	var lines: PackedStringArray = PackedStringArray()
	var body := description.strip_edges()
	if not body.is_empty():
		lines.append(body)
	for effect in effects:
		if effect == null:
			continue
		var line := effect.describe().strip_edges()
		if not line.is_empty():
			lines.append(line)
	return "\n".join(lines)
