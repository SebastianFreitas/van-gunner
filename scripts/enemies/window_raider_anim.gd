extends RefCounted
## Steps the door raider's thirteen-frame run sheet: Sprite3D.frame advances at RUN_FPS while
## the raider moves and rests on frame 0 (the still) when it stands. Does nothing for a
## single-frame sprite (the window crawler, the biker boss), whose hframes is 1.

const RUN_FPS := 18.0
const RUN_FRAMES := 13
## Run frames whose claws touch the floor (every frame but the airborne kick, fall and drop
## at 6-8). Inside the cabin the loper prowls on these so it does not hop around the van.
const GROUNDED_FRAMES: Array[int] = [0, 1, 2, 3, 4, 5, 9, 10, 11, 12]

var raider: WindowRaider
var _clock := 0.0


func _init(owner: WindowRaider) -> void:
	raider = owner


## Called by the raider once per physics frame with whether it moved this frame. Inside the
## cabin (attacking the bench or the player) it loops only the grounded frames.
func step(delta: float, moving: bool) -> void:
	var sprite := raider.sprite
	if sprite == null or sprite.hframes < RUN_FRAMES:
		return
	if not moving:
		_clock = 0.0
		if sprite.frame != 0:
			sprite.frame = 0
		return
	var phase := raider.assault_phase
	var next := 0
	if (
		phase == WindowRaider.AssaultPhase.ATTACKING_BENCH
		or phase == WindowRaider.AssaultPhase.ATTACKING_PLAYER
	):
		_clock = fmod(_clock + delta * RUN_FPS, float(GROUNDED_FRAMES.size()))
		next = GROUNDED_FRAMES[mini(int(_clock), GROUNDED_FRAMES.size() - 1)]
	else:
		_clock = fmod(_clock + delta * RUN_FPS, float(RUN_FRAMES))
		next = int(_clock)
	# A Sprite3D property write is a redraw, so only write when the frame changes.
	if sprite.frame != next:
		sprite.frame = next
