extends RefCounted
## The donor leaf's scene Handle: parked on the edge beam's cabin face and hidden (the owner
## dropped the button and the lock rod; the rod is at tag archive/rear-door-lock-rod). The Handle's
## nodes stay so the door's latch animation and mount lookups keep working. Hinge-local metres.

## The donor Handle's place on the beam's cabin face; its Mount sits 0.5 cm back into the beam.
const HANDLE_X := 2.5605
const HANDLE_Z := -0.25


## Places the scene Handle on the beam and hides its boxes.
static func build(hinge: Node3D) -> void:
	var handle := hinge.get_node_or_null("Handle") as Node3D
	if handle == null:
		return
	handle.position.x = HANDLE_X
	handle.position.z = HANDLE_Z
	for part: Node in handle.get_children():
		(part as Node3D).visible = false
