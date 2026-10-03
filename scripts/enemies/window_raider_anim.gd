extends RefCounted
## Plays named clips from the loper's sheet (door_raider.png, 64 x 80 cells, SHEET_COLUMNS x
## SHEET_ROWS): each clip is a sheet row with its frames, fps and loop flag, and new animations
## add a row and a clip here. Does nothing for a sprite whose hframes/vframes are not the
## sheet's (the biker boss: 1 x 1).

## Columns of the sheet: the thirteen run frames.
const SHEET_COLUMNS := 13
## Rows of the sheet; grows as animation PRs add them.
const SHEET_ROWS := 7
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
	# lands on contact, then holds the cling frame through GRIPPING; CLIMBING hands over to
	# the crawl once the latch reaches its last frame.
	&"latch": {"row": 2, "frames": [0, 1, 2, 3], "fps": 10.0, "loop": false},
	# Front-on wall crawl on CLIMBING. 12 fps: one 8-frame cycle (two strides of ~0.34 m) is
	# ~0.67 m at the wall helper's CLIMB_SPEED 1.0 m/s, so the paws don't skate.
	&"climb": {"row": 3, "frames": [0, 1, 2, 3, 4, 5, 6, 7], "fps": 12.0, "loop": true},
	# One swing at the window bars while BREACHING; frame 0 is the ready pose it rests on.
	&"rake": {"row": 4, "frames": [0, 1, 2, 3, 4, 5], "fps": 12.0, "loop": false},
	# One claw swipe at the bench or the player inside the van; frame 0 is the ready pose.
	&"swipe": {"row": 5, "frames": [0, 1, 2, 3, 4, 5], "fps": 12.0, "loop": false},
		# The window loper's climb in over the sill while ENTERING (1.3 m at 1.6 m/s = 0.81 s);
		# holds the last frame until the phase ends.
		&"enter": {"row": 6, "frames": [0, 1, 2, 3, 4], "fps": 6.0, "loop": false},
}
## Swipe frame that shows the claws landing; start_swipe is timed so it coincides with the hit.
const SWIPE_IMPACT_FRAME := 3
## Rake frame that shows the claws landing on the bars; start_rake is timed so it coincides
## with the breach point taking damage.
const RAKE_IMPACT_FRAME := 3

## False while the current jump goes down to the road (drop off the wall), so that jump keeps
## the take-off clip and never latches.
var latch_jump := true
var raider: WindowRaider
var _clock := 0.0 # seconds into the current clip
var _clip := &"still"
var _raking := false # a rake swing is playing; false rests on its frame 0
var _swiping := false # a swipe is playing; false falls back to prowl/still


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


## Seconds from the start of a rake swing to its impact frame.
func rake_lead_seconds() -> float:
	return RAKE_IMPACT_FRAME / float(CLIPS[&"rake"]["fps"])


## Starts one rake swing from frame 0, restarting it if one is already playing.
func start_rake() -> void:
	if drives_sprite() and has_clip(&"rake"):
		_clip = &"rake"
		_clock = 0.0
		_raking = true


## Seconds from the start of a swipe to its impact frame.
func swipe_lead_seconds() -> float:
	return SWIPE_IMPACT_FRAME / float(CLIPS[&"swipe"]["fps"])


## Starts one swipe from frame 0, restarting it if one is already playing.
func start_swipe() -> void:
	if drives_sprite() and has_clip(&"swipe"):
		_clip = &"swipe"
		_clock = 0.0
		_swiping = true


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
		if phase == WindowRaider.AssaultPhase.CLIMBING and has_clip(&"climb"):
			# Let the latch's impact and pull-in finish; a CLIMBING that starts from GRIPPING
			# already has the latch done and goes straight to the crawl.
			var latch_frames: Array = CLIPS[&"latch"]["frames"]
			var unfinished := (
				_clip == &"latch"
				and int(_clock * float(CLIPS[&"latch"]["fps"])) < latch_frames.size() - 1
			)
			if not unfinished:
				picked = &"climb"
	var in_cabin := (
		phase == WindowRaider.AssaultPhase.ATTACKING_BENCH
		or phase == WindowRaider.AssaultPhase.ATTACKING_PLAYER
	)
	if moving and not jumping and not on_wall:
		picked = &"prowl" if in_cabin else &"run"
	var entering := (
		phase == WindowRaider.AssaultPhase.ENTERING
		and raider.is_agile and not raider.is_boss and has_clip(&"enter")
	)
	if entering:
		picked = &"enter"
	var swiping := _swiping and in_cabin and has_clip(&"swipe")
	if swiping:
		picked = &"swipe"
	else:
		_swiping = false
	var raking := (
		phase == WindowRaider.AssaultPhase.BREACHING
		and raider.is_agile and not raider.is_boss and has_clip(&"rake")
	)
	if raking:
		picked = &"rake"
	else:
		_raking = false
	play(picked)
	if raking:
		_step_rake(delta)
	elif swiping:
		_step_swipe(delta)
	elif moving or jumping or on_wall or entering:
		_clock += delta
		var data: Dictionary = CLIPS[_clip]
		if data["loop"]:
			var frames: Array = data["frames"]
			_clock = fmod(_clock, frames.size() / float(data["fps"]))
	show_clip_at(_clock, _clip)


## Advances a playing swipe; when it ends the swipe flag clears so step falls back to
## prowl/still on the next frame.
func _step_swipe(delta: float) -> void:
	_clock += delta
	if _clock >= clip_seconds(&"swipe"):
		_clock = 0.0
		_swiping = false
	show_clip_at(_clock, _clip)


## Advances a playing rake swing; when it ends the clock resets so frame 0 (ready) shows
## until start_rake plays the next one.
func _step_rake(delta: float) -> void:
	if _raking:
		_clock += delta
		if _clock >= clip_seconds(&"rake"):
			_clock = 0.0
			_raking = false
	show_clip_at(_clock, _clip)
