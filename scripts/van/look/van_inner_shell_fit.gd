extends RefCounted
## Keeps the inner shell's plates and patches clear of the ribs, the bulkhead frame and each other.

## Bulkhead frame plane; its posts and rails are 0.16 deep.
const BULKHEAD_Z := 1.0
const BULKHEAD_HALF := 0.08
## (z, y) span of the fuse box generator on the right wall (parts span z 0.865..1.565 at the
## fuse box origin z 1.215, y up to the plate band), grown by 0.02; plates on side +1 stay out.
const GENERATOR_ZONE := Rect2(0.845, 0.0, 0.74, 1.3)

var _shell: Node3D


func _init(shell: Node3D) -> void:
	_shell = shell


## False when the z span comes within a rib's half depth plus RIB_CLEAR of any rib, or a
## bulkhead post's half depth plus RIB_CLEAR of the bulkhead plane.
func clear_of_ribs(z0: float, z1: float) -> bool:
	var band: float = VanInnerShell.RIB_HALF_DEPTH + VanInnerShell.RIB_CLEAR
	for i: int in range(VanInnerShell.RIB_COUNT):
		var rz: float = VanInnerShell.RIB_Z0 + float(i) * VanInnerShell.RIB_STEP
		if z1 > rz - band and z0 < rz + band:
			return false
	var bulk_band: float = BULKHEAD_HALF + VanInnerShell.RIB_CLEAR
	return not (z1 > BULKHEAD_Z - bulk_band and z0 < BULKHEAD_Z + bulk_band)


## False when the rect (z, y), grown by RIB_CLEAR, meets a plate already placed on that side.
func clear_of_plates(side: float, rect: Rect2) -> bool:
	var plates: Dictionary = _shell.get("_placed_plates")
	var grown := rect.grow(VanInnerShell.RIB_CLEAR)
	for other: Rect2 in plates.get(side, []):
		if grown.intersects(other):
			return false
	return true
