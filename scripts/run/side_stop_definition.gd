class_name SideStopDefinition
extends Resource

## A roadside building on a fork road. Every offered street gets one, regardless
## of card polarity. Taking that road commits the street card *and* parks here.
##
## Scene contract: interiors use the shop-bay frame (origin at the corridor
## wall, +X into the building). TravelController wraps them in a shared
## vestibule that owns `DockPoint` / `ExitPoint` and the roll-up door.

@export var id: StringName = &""
@export var display_name := "Stop"
## Short word for door prompts / toasts ("SHOP", "GARAGE").
@export var short_label := "STOP"
@export var scene: PackedScene
@export var parking_toast := ""
@export var docked_toast := ""
@export var leaving_toast := ""


func fork_label() -> String:
	var name := display_name.strip_edges()
	return name.to_upper() if not name.is_empty() else "STOP"


func label_parking() -> String:
	if not parking_toast.strip_edges().is_empty():
		return parking_toast
	return "PULLING INTO THE %s..." % short_label


func label_docked() -> String:
	if not docked_toast.strip_edges().is_empty():
		return docked_toast
	return "%s — STEP OUT BACK, THEN TELL THE DRIVER TO CONTINUE" % short_label


func label_leaving() -> String:
	if not leaving_toast.strip_edges().is_empty():
		return leaving_toast
	return "PULLING OUT OF THE %s..." % short_label
