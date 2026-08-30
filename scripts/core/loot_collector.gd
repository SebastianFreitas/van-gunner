extends Node

## Central choreographer for "collected" pickups.
##
## Pickups don't know where the crafting bench is, and they don't animate
## themselves there. When a Pickup is collected (shot, walked over, or swept
## up during a rest stop) it just calls `LootCollector.collect(self)` and
## forgets about it. This autoload:
##   - queues simultaneous collections with a small stagger between each
##   - teleports each one onto the registered collection anchor (instant —
##     no tween/lerp on position, so it can never be "left behind" by the
##     van moving mid-animation)
##   - reparents landed pickups onto the anchor, so any later nudging to
##     avoid overlap is done in the anchor's local space and stays glued to
##     it no matter how the van moves
##   - keeps landed pickups from stacking exactly on top of each other by
##     nudging them apart slowly once something new lands nearby
##
## Any future collection point (a second van room, a shop counter, ...) just
## calls `set_collection_anchor()` to take over — nothing here is specific
## to the crafting bench.

const STAGGER_DELAY := 0.15
const MIN_LANDED_SPACING := 0.22
const SETTLE_PUSH_DURATION := 0.6
const POP_IN_DURATION := 0.18

var _anchor: Node3D
var _queue: Array[Node3D] = []
var _landed: Array[Node3D] = []
var _draining := false


func _ready() -> void:
	GameSession.phase_changed.connect(_on_phase_changed)


## Registers where collected pickups should land. Call from whatever scene
## node represents the collection point (e.g. the crafting bench).
func set_collection_anchor(anchor: Node3D) -> void:
	_anchor = anchor


## Queues a pickup to teleport to the collection anchor and settle there.
## Safe to call multiple times for the same pickup; extra calls are ignored.
func collect(pickup: Node3D) -> void:
	if not is_instance_valid(pickup) or pickup in _queue or pickup in _landed:
		return
	if pickup.is_in_group(&"pickup"):
		pickup.remove_from_group(&"pickup")
	_queue.append(pickup)
	if not _draining:
		_drain_queue()


func _on_phase_changed(next_phase: GameSession.RunPhase) -> void:
	# Sweep whatever's left on the ground during the quiet moments between
	# route legs — not after every single kill, so drops still have to
	# actually be walked over/shot to be grabbed during normal play.
	if next_phase == GameSession.RunPhase.REST or next_phase == GameSession.RunPhase.ROUTE_CHOICE:
		for pickup in get_tree().get_nodes_in_group(&"pickup"):
			if pickup.has_method("force_collect"):
				pickup.force_collect()


func _drain_queue() -> void:
	_draining = true
	while not _queue.is_empty():
		var pickup: Node3D = _queue.pop_front()
		if is_instance_valid(pickup):
			_land(pickup)
		if not _queue.is_empty():
			await get_tree().create_timer(STAGGER_DELAY).timeout
	_draining = false


## Instantly relocates the pickup onto the anchor (a real teleport, not an
## interpolated move) and parents it there so it rides along with the van.
func _land(pickup: Node3D) -> void:
	if not is_instance_valid(_anchor):
		_on_landed(pickup)
		return
	_landed.append(pickup)
	pickup.reparent(_anchor, false)
	pickup.position = _landing_offset(_landed.size() - 1)
	pickup.rotation = Vector3.ZERO
	_pop_in(pickup)
	_on_landed(pickup)


## Deterministic outward spiral so most items never need to overlap at all.
func _landing_offset(index: int) -> Vector3:
	var angle := index * 2.4
	var radius := 0.1 * sqrt(float(index))
	return Vector3(cos(angle) * radius, 0.05, sin(angle) * radius)


func _pop_in(pickup: Node3D) -> void:
	pickup.scale = Vector3.ZERO
	var tween := pickup.create_tween()
	tween.tween_property(pickup, "scale", Vector3.ONE, POP_IN_DURATION).set_trans(
		Tween.TRANS_BACK
	).set_ease(Tween.EASE_OUT)


func _on_landed(pickup: Node3D) -> void:
	if is_instance_valid(pickup) and pickup.has_method("_on_settled"):
		pickup._on_settled()
	_settle_overlaps()


## Gently nudges any pair of landed pickups that ended up too close apart.
## Deliberately slow (SETTLE_PUSH_DURATION) — this is a soft "make room",
## never a fast shove. Safe from van-movement drift because both pickups
## are parented to the anchor, so this tweens local position, not global.
func _settle_overlaps() -> void:
	_landed = _landed.filter(func(p): return is_instance_valid(p))
	for i in _landed.size():
		for j in range(i + 1, _landed.size()):
			var a: Node3D = _landed[i]
			var b: Node3D = _landed[j]
			var offset := b.position - a.position
			offset.y = 0.0
			var distance := offset.length()
			if distance > 0.001 and distance < MIN_LANDED_SPACING:
				var push := offset.normalized() * (MIN_LANDED_SPACING - distance) * 0.5
				_nudge(a, -push)
				_nudge(b, push)


func _nudge(pickup: Node3D, offset: Vector3) -> void:
	var target := pickup.position + offset
	var tween := pickup.create_tween()
	tween.tween_property(pickup, "position", target, SETTLE_PUSH_DURATION).set_trans(
		Tween.TRANS_SINE
	)
