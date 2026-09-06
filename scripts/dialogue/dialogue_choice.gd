class_name DialogueChoice
extends RefCounted

## One option in an NPC talk. Built in code; the HUD just renders it.

var id: StringName = &""
var label := ""
var price := 0
var available := true
var detail := ""


func display_text() -> String:
	var price_text := ""
	if price > 0:
		price_text = "  —  %d GOLD" % price
	var extra := ""
	if not detail.is_empty():
		extra = "  %s" % detail
	return "%s%s%s" % [label, price_text, extra]


func line_text(index: int) -> String:
	return "%d  %s" % [index + 1, display_text()]
