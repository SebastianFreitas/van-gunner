class_name GunBoonVisuals
extends RefCounted
## Boon id -> chunky low-poly piece that bolts onto a railgun socket (built in GunBoonPieces).
## Builders take the socket, the gun's palm length p and an rng, and return a Node3D in Body space.

static var REGISTRY: Dictionary = {
	&"cold_rounds": {"zones": [&"top", &"muzzle"], "build": GunBoonPieces.cold},
	&"explosive_rounds": {"zones": [&"top", &"left"], "build": GunBoonPieces.explosive},
	&"poison_rounds": {"zones": [&"rear", &"top"], "build": GunBoonPieces.poison},
}


static func has(id: StringName) -> bool:
	return REGISTRY.has(id)


static func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for k: StringName in REGISTRY.keys():
		out.append(k)
	return out


## The preferred zones of `id` as a typed array.
static func zones_of(id: StringName) -> Array[StringName]:
	var zones: Array[StringName] = []
	zones.assign((REGISTRY[id] as Dictionary)["zones"])
	return zones
