class_name Interactable
extends StaticBody3D
## Base class for world objects the player can interact with.

@export var prompt := "Interact"

## Left-hand gesture the first-person arms play on interact; empty plays none.
@export var gesture: StringName = &"press"

## Shows the in-world stencil at the centre of the first collision shape.
@export var show_marker := true
## Extra shift of the marker in this body's local space.
@export var marker_offset := Vector3.ZERO

var _marker: InteractionMarker


func _ready() -> void:
	if show_marker:
		_build_marker()


func get_interaction_prompt() -> String:
	return prompt


func get_gesture() -> StringName:
	return gesture


func interact(_actor: Node3D) -> void:
	pass


## Called by the player when the interaction ray starts or stops focusing this body.
func set_focused(on: bool) -> void:
	if _marker:
		_marker.set_focused(on)


## Re-centres the marker on the shapes enabled right now; call after a state change that
## disables or moves shapes inside this body. Hides it when no shape is enabled.
func refresh_marker() -> void:
	if _marker == null:
		return
	_marker.visible = _place_marker()


func _build_marker() -> void:
	_marker = InteractionMarker.new()
	add_child(_marker)
	_marker.visible = _place_marker()


func _place_marker() -> bool:
	# Union of every enabled shape, so a split collider centres on the area the ray can hit.
	var box := AABB()
	var found := false
	# Shapes of bullet-transparent proxy bodies (layer 32) count too: the ray hits them.
	var shapes: Array[Node] = get_children()
	for child in get_children():
		if child is StaticBody3D:
			shapes.append_array(child.get_children())
	for child in shapes:
		var cs := child as CollisionShape3D
		if cs and cs.shape and not cs.disabled:
			var xf := cs.transform
			if cs.get_parent() != self:
				xf = (cs.get_parent() as Node3D).transform * xf
			var part: AABB = xf * cs.shape.get_debug_mesh().get_aabb()
			box = part if not found else box.merge(part)
			found = true
	if not found or collision_layer == 0:
		return false
	var centre := box.get_center()
	# Nudge a few mm along the thinnest axis, toward the parent's origin, against z-fighting.
	var size := box.size.abs()
	var axis := 0
	for i in 3:
		if size[i] < size[axis]:
			axis = i
	var nudge := Vector3.ZERO
	nudge[axis] = -signf(centre[axis]) * 0.005 if centre[axis] != 0.0 else 0.005
	_marker.position = centre + nudge + marker_offset
	return true
