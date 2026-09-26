class_name MachineMotion
extends Node
## Drives every moving part of one van machine (spin, pump, wobble, flicker) from a single _process, scaled by its damage state.

## The damage state's multiplier on all motion.
var speed_scale := 1.0
## 0 is steady; 1 is a flicker that drops to black.
var flicker_amount := 0.0

var _time := 0.0
var _entries: Array[Dictionary] = []


func add_spin(target: Node3D, axis: Vector3, rad_per_sec: float) -> void:
	_entries.append({
		&"kind": &"spin",
		&"target": target,
		&"axis": axis.normalized(),
		&"rate": rad_per_sec,
	})


func add_pump(target: Node3D, axis: Vector3, amplitude: float, hz: float) -> void:
	_entries.append({
		&"kind": &"pump",
		&"target": target,
		&"axis": axis,
		&"amplitude": amplitude,
		&"hz": hz,
		&"rest": target.position,
	})


func add_wobble(target: Node3D, amplitude_rad: float, hz: float) -> void:
	_entries.append({
		&"kind": &"wobble",
		&"target": target,
		&"amplitude": amplitude_rad,
		&"hz": hz,
		&"rest": target.rotation,
	})


func add_flicker(target: Object, property: StringName, base: float) -> void:
	_entries.append({
		&"kind": &"flicker",
		&"target": target,
		&"property": property,
		&"base": base,
	})


func clear() -> void:
	_entries.clear()


func _process(delta: float) -> void:
	_time += delta * speed_scale
	for e: Dictionary in _entries:
		var kind: StringName = e[&"kind"]
		if kind == &"flicker":
			var flicker_target: Object = e[&"target"]
			if not is_instance_valid(flicker_target):
				continue
			var base: float = e[&"base"]
			var property: StringName = e[&"property"]
			if flicker_amount <= 0.0:
				flicker_target.set(property, base)
			else:
				var dip := randf() * flicker_amount
				if randf() < flicker_amount * 0.15:
					dip = 1.0
				flicker_target.set(property, base * (1.0 - dip))
			continue

		var target := e[&"target"] as Node3D
		if not is_instance_valid(target):
			continue
		match kind:
			&"spin":
				var axis: Vector3 = e[&"axis"]
				var rate: float = e[&"rate"]
				target.rotate_object_local(axis, rate * delta * speed_scale)
			&"pump":
				var pump_axis: Vector3 = e[&"axis"]
				var amplitude: float = e[&"amplitude"]
				var hz: float = e[&"hz"]
				var rest: Vector3 = e[&"rest"]
				target.position = rest + pump_axis * sin(_time * TAU * hz) * amplitude
			&"wobble":
				var wobble_amplitude: float = e[&"amplitude"]
				var wobble_hz: float = e[&"hz"]
				var wobble_rest: Vector3 = e[&"rest"]
				target.rotation = wobble_rest + Vector3(
					0.0,
					0.0,
					sin(_time * TAU * wobble_hz) * wobble_amplitude * (1.0 + flicker_amount * 2.0)
				)
