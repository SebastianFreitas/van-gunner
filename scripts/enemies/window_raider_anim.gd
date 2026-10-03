extends RefCounted
## Plays named clips from the loper's sheet (door_raider.png, 64 x 80 cells, SHEET_COLUMNS x
## SHEET_ROWS): each clip is a sheet row with its frames, fps and loop flag, and new animations
## add a row and a clip here. Does nothing for a sprite whose hframes/vframes are not the
## sheet's (the biker boss: 1 x 1).

## Columns of the sheet: the thirteen run frames.
const SHEET_COLUMNS := 13
## Rows of the sheet; grows as animation PRs add them.
const SHEET_ROWS := 3
## Seconds into the jump when the latch clip takes over: the jump lasts window_raider_wall.gd
## JUMP_TIME 0.8 s and, at 10 fps, the latch's impact frame (index 2) starts at 0.75 s, i.e. on
## contact. Keep the two in step.
const LATCH_START := 0.55
## Run frames whose claws touch the floor (every frame but the airborne kick, fall and drop
## at 6-8). Inside the cabin the loper prowls on these so it does not hop around the van.
const GROUNDED_FRAMES: Array[int] = [0, 1, 2, 3, 4, 5, 9, 10, 11, 12]
## Clips by name: {"row": sheet row, "frames": columns in play order, "fps", "loop"}.
## No death clip yet: W7/W8 add it, and _die then holds it before the fade.
const CLIPS: Dictionary = {
	&"still": {"row": 0, "frames": [0], "fps": 1.0, "loop": true},
	&"run": {"row": 0, "frames": [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], "fps": 18.0, "loop": true},
	# The in-cabin loop on the grounded frames.
	&"prowl": {"row": 0, "frames": [0, 1, 2, 3, 4, 5, 9, 10, 11, 12], "fps": 18.0, "loop": true},
	# Take-off plays in 0.33 s, then holds frame 4 (airborne) until the latch takes over at
	# LATCH_START into the 0.8 s jump.
	&"jump": {"row": 1, "frames": [0, 1, 2, 3, 4], "fps": 15.0, "loop": false},
	# Front-on latch onto the van wall, started LATCH_START s into the jump so the impact frame
	# lands on contact, then holds the cling frame through GRIPPING and CLIMBING until the
	# crawl (W4).
	&"latch": {"row": 2, "frames": [0, 1, 2, 3], "fps": 10.0, "loop": false},
}

## False while the current jump goes down to the road (drop off the wall), so that jump keeps
## the take-off clip and never latches.
var latch_jump := true
var raider: WindowRaider
var _clock := 0.0 # seconds into the current clip
var _clip := &"still"


func _init(owner: WindowRaider) -> void:
	raider = owner


## True when the sprite is laid out as this sheet.
func drives_sprite() -> bool:
	var sprite := raider.sprite
	return sprite != null and sprite.hframes == SHEET_COLUMNS and sprite.vframes == SHEET_ROWS


## True when CLIPS has a clip of this name.
func has_clip(clip: StringName) -> bool:
	return CLIPS.has(clip)


## Length of a one-shot clip in seconds; 0.0 for a missing or looping clip or a foreign sprite.
func clip_seconds(clip: StringName) -> float:
	if not CLIPS.has(clip) or not drives_sprite():
		return 0.0
	var data: Dictionary = CLIPS[clip]
	if data["loop"]:
		return 0.0
	var frames: Array = data["frames"]
	return frames.size() / float(data["fps"])


## Switches to a clip from its first frame; does nothing if it is already the current one.
func play(clip: StringName) -> void:
	if clip != _clip:
		_clip = clip
		_clock = 0.0


## Shows the frame a clip has reached after `seconds`. Seconds come first so a Tween's
## tween_method can bind the clip name.
func show_clip_at(seconds: float, clip: StringName) -> void:
	if not drives_sprite() or not CLIPS.has(clip):
		return
	var data: Dictionary = CLIPS[clip]
	var frames: Array = data["frames"]
	var index := int(seconds * float(data["fps"]))
	if data["loop"]:
		index = posmod(index, frames.size())
	else:
		index = mini(index, frames.size() - 1)
	var target := Vector2i(frames[index], data["row"])
	# A Sprite3D property write is a redraw, so only write when the frame changes.
	if raider.sprite.frame_coords != target:
		raider.sprite.frame_coords = target


## Called by the raider once per physics frame with whether it moved this frame. Inside the
## cabin (attacking the bench or the player) it loops only the grounded frames.
func step(delta: float, moving: bool) -> void:
	if not drives_sprite():
		return
	var phase := raider.assault_phase
	# The jump is a flight, not a walk: it animates whether or not the raider "moved".
	var jumping := phase == WindowRaider.AssaultPhase.JUMPING
	var on_wall := (
		phase == WindowRaider.AssaultPhase.GRIPPING or phase == WindowRaider.AssaultPhase.CLIMBING
	)
	var picked := &"still"
	if jumping:
		var latching := _clip == &"latch" or (_clip == &"jump" and _clock >= LATCH_START)
		picked = &"latch" if latch_jump and latching else &"jump"
	elif on_wall and has_clip(&"latch"):
		picked = &"latch"
	if moving and not jumping and not on_wall:
		var in_cabin := (
			phase == WindowRaider.AssaultPhase.ATTACKING_BENCH
			or phase == WindowRaider.AssaultPhase.ATTACKING_PLAYER
		)
		picked = &"prowl" if in_cabin else &"run"
	play(picked)
	if moving or jumping or on_wall:
		_clock += delta
		var data: Dictionary = CLIPS[_clip]
		if data["loop"]:
			var frames: Array = data["frames"]
			_clock = fmod(_clock, frames.size() / float(data["fps"]))
	show_clip_at(_clock, _clip)
