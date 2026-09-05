class_name SoundCue
extends Resource

## One addressable sound. Adding audio should mean adding a .tres, never a
## branch inside a gameplay system — same contract as ItemDefinition and
## ActCardDefinition.
##
## Put an AudioStreamRandomizer in `stream` for anything that fires more than
## once. It holds several takes and randomises pitch/volume per play, so this
## code never has to do `pitch_scale = randf_range(...)`.

## Lookup key. Must be unique inside the bank.
@export var id: StringName = &""

## AudioStreamRandomizer for repeated sounds, plain AudioStream for one-offs.
@export var stream: AudioStream

## Bus name. Must exist in resources/audio/bus_layout.tres, or Godot silently
## falls back to Master.
@export var bus: StringName = &"SFX"

@export_range(-40.0, 12.0, 0.1) var volume_db: float = 0.0

## Seconds before this cue may retrigger. The single most important knob here:
## an 8-pellet shotgun produces 8 impacts in one frame, and without a gate they
## phase into white noise instead of sounding like one hit.
@export_range(0.0, 1.0, 0.005) var min_interval: float = 0.0

## Hard cap on simultaneous copies of this cue. Enforced for positional cues
## (the 3D pool tracks them); non-positional cues are gated by min_interval and
## the bus polyphony ceiling instead.
@export_range(1, 16) var max_voices: int = 4

## Positional cues attenuate with distance. Leave off for UI, music stingers,
## and anything that happens at the player (own gunshot, own reload).
@export var positional: bool = false

@export_range(1.0, 80.0, 0.5) var max_distance: float = 25.0

@export_range(0.0, 20.0, 0.5) var unit_size: float = 6.0
