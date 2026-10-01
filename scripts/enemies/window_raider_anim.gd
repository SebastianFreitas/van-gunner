extends RefCounted
## Steps the door raider's four-frame run sheet: Sprite3D.frame advances at RUN_FPS while
## the raider moves and rests on frame 0 (the still) when it stands. Does nothing for a
## single-frame sprite (the window crawler, the biker boss), whose hframes is 1.

const RUN_FPS := 8.0
const RUN_FRAMES := 4

var raider: WindowRaider
var _clock := 0.0


func _init(owner: WindowRaider) -> void:
	raider = owner


## Called by the raider once per physics frame with whether it moved this frame.
func step(delta: float, moving: bool) -> void:
	var sprite := raider.sprite
	if sprite == null or sprite.hframes < RUN_FRAMES:
		return
	if not moving:
		_clock = 0.0
		if sprite.frame != 0:
			sprite.frame = 0
		return
	_clock = fmod(_clock + delta * RUN_FPS, float(RUN_FRAMES))
	var next := int(_clock)
	# A Sprite3D property write is a redraw, so only write when the frame changes.
	if sprite.frame != next:
		sprite.frame = next
