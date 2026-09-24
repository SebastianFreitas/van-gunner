class_name SideStopDefinition
extends Resource

## A roadside stop on a fork road. Every offered street gets one, regardless
## of card polarity. Taking that road commits the street card *and* visits here.
##
## A stop is arrival(content): arrival is how the van reaches the shared
## vestibule + roll-up, content is the interior mounted behind the door.
## TravelController wraps `scene` in a vestibule (reverse-park) or an elevator
## shaft (halt on the road, pad drops, same door at the bottom).

enum Arrival {
	REAR_PARK = 0,
	ELEVATOR = 1,
}

@export var id: StringName = &""
@export var display_name := "Stop"
## Short word for door prompts / toasts ("SHOP", "GARAGE").
@export var short_label := "STOP"
## Interior scene. Origin is just inside the roll-up, +X inward. No dock markers.
@export var scene: PackedScene
@export var arrival: Arrival = Arrival.REAR_PARK
## Relative chance to be offered at a fork. Keep rare shops well below 1.
@export var spawn_weight := 1.0
@export var parking_toast := ""
@export var docked_toast := ""
@export var leaving_toast := ""


func uses_elevator() -> bool:
	return arrival == Arrival.ELEVATOR


func fork_label() -> String:
	var name := display_name.strip_edges()
	var label := name.to_upper() if not name.is_empty() else "STOP"
	if uses_elevator():
		return "%s LIFT" % label
	return label


func label_parking() -> String:
	if not parking_toast.strip_edges().is_empty():
		return parking_toast
	if uses_elevator():
		return "THE ROAD DROPS — %s..." % short_label
	return "PULLING INTO THE %s..." % short_label


func label_docked() -> String:
	if not docked_toast.strip_edges().is_empty():
		return docked_toast
	return "%s — STEP OUT BACK, THEN TELL THE DRIVER TO CONTINUE" % short_label


func label_leaving() -> String:
	if not leaving_toast.strip_edges().is_empty():
		return leaving_toast
	if uses_elevator():
		return "RISING BACK TO THE STREET..."
	return "PULLING OUT OF THE %s..." % short_label


func arrival_label() -> String:
	return "elevator" if uses_elevator() else "rear_park"
