extends RefCounted
## Samples one ArmGesture channel: a key list of {t, v, ease} at an age, independent of the others.


## The channel's value at age `a`: the first key's v before it, the last key's v after it.
## `zero` is the value of an empty channel. v is a float, Vector2 or Vector3.
static func sample(keys: Array, a: float, zero: Variant) -> Variant:
	if keys.is_empty():
		return zero
	var first: Dictionary = keys[0]
	if a <= first[&"t"]:
		return first[&"v"]
	for n in keys.size() - 1:
		var k0: Dictionary = keys[n]
		var k1: Dictionary = keys[n + 1]
		if a < k1[&"t"]:
			return _segment(k0, k1, a)
	var last: Dictionary = keys[keys.size() - 1]
	return last[&"v"]


## Between k0 and k1 by the ease stored on k1. `snap` starts at k0's v and rings about k1's v
## (the damped cosine of ArmKick), so it only lands on k1's v once the ring has died away.
static func _segment(k0: Dictionary, k1: Dictionary, a: float) -> Variant:
	var v0: Variant = k0[&"v"]
	var v1: Variant = k1[&"v"]
	var s: float = a - float(k0[&"t"])
	var u: float = s / (float(k1[&"t"]) - float(k0[&"t"]))
	match k1.get(&"ease", &"smooth"):
		&"in":
			return v0 + (v1 - v0) * (u * u)
		&"out":
			return v0 + (v1 - v0) * (1.0 - (1.0 - u) * (1.0 - u))
		&"snap":
			var ring := exp(-s / float(k1.get(&"tau", 0.06)))
			ring *= cos(float(k1.get(&"omega", 20.0)) * s)
			return v1 + (v0 - v1) * ring
	return v0 + (v1 - v0) * smoothstep(0.0, 1.0, u)
