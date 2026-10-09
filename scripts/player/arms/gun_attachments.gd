class_name GunAttachments
extends Node3D
## Builds a boon visual on a railgun socket for every owned boon that has a GunBoonVisuals entry,
## and previews any of them for the `gun attach` debug command.

const DEBUG_META := &"debug_boon"

var _usables: Node
var _warned: Dictionary = {}


func _ready() -> void:
	name = "Attachments"
	_connect.call_deferred()


func _connect() -> void:
	var player := get_tree().get_first_node_in_group(&"player")
	_usables = player.get_node_or_null("Usables") if player != null else null
	if _usables == null:
		return
	if not _usables.is_connected(&"boons_changed", _sync):
		_usables.connect(&"boons_changed", _sync)
	_sync()


## One piece per owned boon instance that has none yet.
func _sync() -> void:
	var owned: Dictionary = {}
	for item: ItemDefinition in _usables.call(&"get_boons"):
		if GunBoonVisuals.has(item.id):
			owned[item.id] = int(owned.get(item.id, 0)) + 1
	for id: StringName in GunBoonVisuals.ids():
		if not owned.has(id):
			continue
		var have := _count(id, false)
		for _i in range(int(owned[id]) - have):
			if not _place(id, false):
				break


func _count(id: StringName, debug: bool) -> int:
	var n := 0
	for c in get_children():
		if c.get_meta(DEBUG_META, false) == debug and c.get_meta(&"boon_id", &"") == id:
			n += 1
	return n


func _place(id: StringName, debug: bool) -> bool:
	var body := get_parent() as Node3D
	var sockets := GunSockets.claim(body, GunBoonVisuals.zones_of(id))
	if sockets == null:
		for s in GunSockets.all(body):
			if not bool(s.get_meta(&"used", false)):
				s.set_meta(&"used", true)
				sockets = s
				break
	if sockets == null:
		if not _warned.has(id):
			_warned[id] = true
			print("gun: no socket for ", id)
		return false
	var rng: RandomNumberGenerator
	if body.has_meta(&"seed"):
		rng = ArmsBuilder.rng_for(int(body.get_meta(&"seed")), &"arm_boon_" + id)
	else:
		rng = RandomNumberGenerator.new()
		rng.seed = hash(sockets.name)
	var gun := body.get_parent()
	var p := (HeldGun.palm_len_of(gun as Node3D) if gun != null else 0.22) * MonsterGrip.GUN_K
	var build: Callable = (GunBoonVisuals.REGISTRY[id] as Dictionary)["build"]
	var piece: Node3D = build.call(sockets, p, rng)
	piece.name = "Boon_%s_%d" % [id, get_child_count()]
	piece.set_meta(DEBUG_META, debug)
	piece.set_meta(&"boon_id", id)
	piece.set_meta(&"socket", sockets.name)
	add_child(piece)
	return true


## Shows one registry piece on a free socket without owning the boon.
func attach_debug(id: StringName) -> bool:
	return GunBoonVisuals.has(id) and _place(id, true)


func attach_all_debug() -> void:
	for id in GunBoonVisuals.ids():
		attach_debug(id)


## Removes the debug pieces and frees their sockets; owned pieces stay.
func clear_debug() -> void:
	var body := get_parent() as Node3D
	for c in get_children():
		if c.get_meta(DEBUG_META, false):
			for s in GunSockets.all(body):
				if s.name == c.get_meta(&"socket", &""):
					GunSockets.release(s)
			remove_child(c)
			c.queue_free()
