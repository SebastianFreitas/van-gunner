extends Node
## Drives one broken wall lamp's flicker: long on stretches, bursts of fast stutters and the odd
## blackout, on the light and its head's emission together.

enum Phase { ON, STUTTER, OFF }

const LEVEL_OFF := 0.06

var light: Light3D
var head: StandardMaterial3D
var base_energy := 0.0
var base_emission := 0.0
var seed_value := 0

var _rng := RandomNumberGenerator.new()
var _phase := Phase.ON
var _timer := 0.0
var _toggles_left := 0
var _lit := true


func _ready() -> void:
	_rng.seed = seed_value
	if is_instance_valid(light):
		base_energy = light.light_energy
	if head != null:
		base_emission = head.emission_energy_multiplier
	_timer = _rng.randf_range(0.5, 3.5)


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_advance()
	var k := 1.0 if _lit else LEVEL_OFF
	if is_instance_valid(light):
		light.light_energy = base_energy * k
	if head != null:
		head.emission_energy_multiplier = base_emission * k


## Moves to the next stretch: ON ends in a stutter burst or a blackout, both end back in ON.
func _advance() -> void:
	match _phase:
		Phase.ON:
			if _rng.randf() < 0.75:
				_phase = Phase.STUTTER
				_toggles_left = _rng.randi_range(3, 8)
				_lit = false
				_timer = _rng.randf_range(0.03, 0.12)
				_toggles_left -= 1
			else:
				_phase = Phase.OFF
				_lit = false
				_timer = _rng.randf_range(0.4, 1.8)
		Phase.STUTTER:
			if _toggles_left > 0:
				_lit = not _lit
				_timer = _rng.randf_range(0.03, 0.12)
				_toggles_left -= 1
			else:
				_back_on()
		Phase.OFF:
			_back_on()


func _back_on() -> void:
	_phase = Phase.ON
	_lit = true
	_timer = _rng.randf_range(0.5, 3.5)
