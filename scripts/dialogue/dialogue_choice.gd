class_name DialogueChoice
extends RefCounted

## One numbered line in an NPC talk. Built in code; the HUD just renders it.

var id: StringName = &""
var label := ""
var price := 0
var available := true
var detail := ""


func line_text(index: int) -> String:
	var price_text := ""
	if price > 0:
		price_text = "  —  %d GOLD" % price
	var extra := ""
	if not detail.is_empty():
		extra = "  %s" % detail
	return "%d  %s%s%s" % [index + 1, label, price_text, extra]
