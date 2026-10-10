class_name RailgunCoils
extends Node3D
## Rusty square electromagnet frames that hover in the railgun's barrel gap: they bob and wobble slowly, jolt forward and flare on a shot.

const COUNT := 4
const IDLE_GLOW := 1.0
const FLARE_GLOW := 3.5
const BOB := 0.005  ## palms
const BOB_SPEED := 1.3
## Wobble about the barrel axis in radians: small, so a square corner never reaches a barrel.
const WOBBLE := 0.12
const WOBBLE_SPEED := 0.5
## Outer edge as a share of the barrels' gap; bar thickness and frame depth in palms.
const FRAME := 0.75
const BAR := 0.02
const DEPTH := 0.03
## How far a frame jolts toward the muzzle on a shot, in palms.
const JOLT := 0.06
## The SaveSandbox hold, so smoke stills compare.
const SANDBOX_T := 1.1

var _p := 1.0
var _rings: Array[Node3D] = []
var _rest: Array[Vector3] = []
var _mat: StandardMaterial3D
var _flare := 0.0
var _tween: Tween


## Builds the frames under `body`: centred in the gap at height `gap_y`, from `z_front` (the upper
## barrel's front) back `span` palms. Each is a square `FRAME` of the gap tall, so with the bob and
## the wobble's worst corner it still clears both barrels.
static func build(body: Node3D, p: float, rng: RandomNumberGenerator, gap_y: float,
		z_front: float, span: float) -> void:
	var coils := RailgunCoils.new()
	coils._p = p
	coils.name = "Coils"
	body.add_child(coils)
	var rust := ArmMaterials.rust(rng.randf_range(0.0, 100.0))
	var steel := ArmMaterials.steel(rng.randf_range(0.0, 100.0))
	var copper := ArmMaterials.surface(Color(0.30, 0.17, 0.08), Color(0.16, 0.09, 0.05),
			Color(0.08, 0.06, 0.04), 60.0, 6.0, 0.0, 0.55, 0.8, 0.5, rng.randf_range(0.0, 100.0))
	coils._mat = MachineParts.emissive(Color(1.0, 0.45, 0.12), IDLE_GLOW)
	var h := RailgunBarrels.GAP_H * FRAME * 0.5
	# Four bars as [centre x, centre y, width, height]: top and bottom full width, sides between.
	var bars: Array[Array] = [[0.0, h - BAR * 0.5, 2.0 * h, BAR],
			[0.0, -h + BAR * 0.5, 2.0 * h, BAR],
			[h - BAR * 0.5, 0.0, BAR, 2.0 * h - 2.0 * BAR],
			[-h + BAR * 0.5, 0.0, BAR, 2.0 * h - 2.0 * BAR]]
	for i: int in range(COUNT):
		var ring := Node3D.new()
		ring.name = "Coil%d" % i
		var at := Vector3(0.0, gap_y, z_front + (0.24 + span * float(i) / float(COUNT)) * p)
		ring.position = at
		coils.add_child(ring)
		coils._rings.append(ring)
		coils._rest.append(at)
		for k: int in range(4):
			var bar: Array = bars[k]
			var cx: float = bar[0]
			var cy: float = bar[1]
			var bw: float = bar[2]
			var bh: float = bar[3]
			var sides := k < 2
			ArmParts.mesh(ring, "Hoop%d" % k, ArmParts.box(Vector3(bw, bh, DEPTH) * p), rust,
					Vector3(cx, cy, 0.0) * p)
			# Copper winding wrapped round the middle of each bar.
			var wind := Vector3(bw * 0.5 if sides else bw + 0.004,
					bh + 0.004 if sides else bh * 0.5, DEPTH * 0.5)
			ArmParts.mesh(ring, "Winding%d" % k, ArmParts.box(wind * p), copper,
					Vector3(cx, cy, 0.0) * p)
		ArmParts.mesh(ring, "Field", ArmParts.cyl(0.020 * p, 0.012 * p, 0.020 * p, 10), coils._mat,
				Vector3.ZERO, ArmParts.along(Vector3.BACK))
		for side: float in [-1.0, 1.0]:
			ArmParts.mesh(ring, "Lug%s" % ("L" if side < 0.0 else "R"),
					ArmParts.box(Vector3(0.012, 0.014, 0.03) * p), steel,
					Vector3(side * (h + 0.006) * p, 0.0, 0.0))


func _ready() -> void:
	_bind.call_deferred()


func _bind() -> void:
	var gun := get_tree().get_first_node_in_group(&"gun_controller")
	if gun != null and gun.has_signal(&"shot"):
		gun.connect(&"shot", _on_shot)


func _process(_delta: float) -> void:
	var t := SANDBOX_T if SaveSandbox.enabled else Time.get_ticks_msec() * 0.001
	for i: int in range(_rings.size()):
		var ring := _rings[i]
		var ph := float(i) * 1.7
		var at := _rest[i]
		at.y += sin(t * BOB_SPEED + ph) * BOB * _p
		at.z -= _flare * JOLT * _p
		ring.position = at
		ring.rotation.z = sin(t * WOBBLE_SPEED + ph) * WOBBLE
	_mat.emission_energy_multiplier = lerpf(IDLE_GLOW, FLARE_GLOW, _flare)


func _on_shot() -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "_flare", 1.0, 0.03)
	_tween.tween_property(self, "_flare", 0.0, 0.45) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
