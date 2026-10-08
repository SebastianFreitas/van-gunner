extends RefCounted
## Reseeds Godot's global random stream right before each gameplay roll the smoke triggers, so two runs of one tree roll the same raiders, boons and shop stock.

const _ShopStock := preload("res://scripts/stops/shop_stock.gd")
const _BASE := 12345

## The player's start spot inside the van, as scenes/van/van.tscn places it.
const PLAYER_START := Vector3(0.0, 0.05, VanInteriorSize.FRONT_Z + 2.0)

static var _summons := 0
static var _rests := 0


## The run consumes the global stream in frame order (gun spread, loot, wave timers), so a
## seed only holds for the synchronous roll right after it: call this immediately before.
static func pin(tag: String) -> void:
	seed(_BASE + hash(tag))


## Runs `summon <what>` `count` times, each behind its own pin (the spawn pool, the spawn
## offset and the first breach point are rolled inside the command).
static func summon(what: String, count: int) -> String:
	var replies := PackedStringArray()
	for _i in range(count):
		pin("summon %d" % _summons)
		_summons += 1
		replies.append(str(DebugCommands.run("summon " + what)))
	return "\n".join(replies)


## The REST boon roll (the 3-choice offer, or the `speed`-mode grant) happens inside the
## phase_changed handler, so the pin sits right before the phase change.
static func enter_rest() -> void:
	pin("rest %d" % _rests)
	_rests += 1
	GameSession.set_phase(GameSession.RunPhase.REST)


## For SceneTree.node_added: the shop is built inside finish_turn, many frames after the
## smoke picks the route, and node_added fires before the stock's _ready rolls its offers.
static func pin_shop_stock(node: Node) -> void:
	if node.get_script() == _ShopStock:
		pin("shop stock")


## Puts the player back on the start spot, facing the cab and standing still, so a stop
## screenshot does not depend on where the halt walk-in happened to end.
static func settle_player(tree: SceneTree) -> void:
	var van := tree.get_first_node_in_group(&"van_run")
	if van == null:
		return
	var player: FpsPlayer = van.get("player")
	if player == null:
		return
	player.position = PLAYER_START
	player.rotation.y = 0.0
	player.velocity = Vector3.ZERO
