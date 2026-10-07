class_name VanWheels
extends Node3D
## The van's seeded road wheels (1.6 m lugged tyres on beadlocked rims, meshes from van_wheel_mesh.gd), mud flaps and axles, spun by the van's measured speed; the chassis kit around them lives in van_chassis.gd.

const HULL_PATH := ^"../Hull"
## Builds the flares, steps, tank, toolbox, exhaust, spares and rear bumper.
const _Chassis := preload("res://scripts/van/look/van_chassis.gd")
## Builds the axle beams, differentials and driveshafts under the lifted body.
const _Axles := preload("res://scripts/van/look/van_axles.gd")
## Builds each wheel's tyre, rim and steel meshes.
const _WheelMesh := preload("res://scripts/van/look/van_wheel_mesh.gd")

## How far the body rides above its stock height: VanRig rests this high on its PathFollow3D (rig_rest_transform), and the wheels hang this much lower under the arches so the tyres still touch the road.
const BODY_LIFT := 0.7
## The road line in body space before the lift; ROAD_Y is this minus BODY_LIFT.
const ARCH_ROAD_Y := -0.2
## The road in VanRig space: tyres, flap bottoms and axles reach it.
const ROAD_Y := ARCH_ROAD_Y - BODY_LIFT
## The hull's underside (VanHullPatches' sill and belly bottom): the rear arches' flares and wells
## end on it and the mud flaps hang from it.
const HULL_BOTTOM_Y := -0.25
## Front (cab) wheel x, unchanged.
const WHEEL_X := 3.06
const TYRE_WIDTH := 0.5
## Rear wheel x: the tyre's inner cap sits 0.22 outside the widened body's floor-level skin.
const REAR_WHEEL_X := VanInteriorSize.BOTTOM_HALF + 0.22 + TYRE_WIDTH * 0.5

const FRONT_AXLE_Z := -7.25
## Front wheels sit this much further out than the rear, so the tyre's inner cap clears the cab
## skin's bowed side by 2 cm (the audit's coplanar tolerance is 1 cm).
const FRONT_WHEEL_OUT := 0.04
const FRONT_RADIUS := 0.8
const REAR_RADIUS := 0.8

const REAR_AXLES_4: Array[float] = [4.78]
const REAR_AXLES_6: Array[float] = [3.28, 5.44]

## Chance a look builds the tandem rear axles.
const SIX_WHEEL_CHANCE := 0.4

## Spinning pivots, one per wheel.
var wheel_pivots: Array[Node3D] = []
## The radius per pivot, same order as wheel_pivots.
var _radii: Array[float] = []
var _last_pos := Vector3.ZERO
var _has_last := false


func rebuild_look(look: VanLook) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	wheel_pivots.clear()
	_radii.clear()
	_has_last = false

	var rubber := StandardMaterial3D.new()
	rubber.albedo_color = Color(0.05, 0.05, 0.05)
	rubber.roughness = 0.92
	rubber.metallic = 0.0
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.09, 0.085, 0.08)
	steel.roughness = 0.75
	steel.metallic = 0.3

	var hull := get_node_or_null(HULL_PATH) as VanHull
	var hull_mat: Material = rubber
	if hull != null and hull.material != null:
		hull_mat = hull.material

	var rng := look.rng_for(&"wheels")
	var six := rng.randf() < SIX_WHEEL_CHANCE
	var exhaust_side := -1.0 if rng.randf() < 0.5 else 1.0
	var spare_mask := rng.randi_range(1, 3)

	var rear_axles: Array[float] = REAR_AXLES_6 if six else REAR_AXLES_4
	var last_rear_z: float = rear_axles[rear_axles.size() - 1]

	var mesh_cache := {}
	for side: float in [-1.0, 1.0]:
		var side_label := "L" if side < 0.0 else "R"
		var idx := 0
		_build_wheel("Wheel%s%d" % [side_label, idx],
				Vector3(side * (WHEEL_X + FRONT_WHEEL_OUT), ROAD_Y + FRONT_RADIUS, FRONT_AXLE_Z),
				FRONT_RADIUS, _wheel_meshes(mesh_cache, FRONT_RADIUS, side), hull_mat, rubber, steel)
		idx += 1
		for z: float in rear_axles:
			_build_wheel("Wheel%s%d" % [side_label, idx],
					Vector3(side * REAR_WHEEL_X, ROAD_Y + REAR_RADIUS, z), REAR_RADIUS,
					_wheel_meshes(mesh_cache, REAR_RADIUS, side), hull_mat, rubber, steel)
			idx += 1
		_build_mud_flap("MudFlap%s" % side_label, side * REAR_WHEEL_X,
				last_rear_z + REAR_RADIUS + 0.12, rubber)

	_Chassis.new(self).build(hull_mat, rubber, rear_axles, exhaust_side, spare_mask)
	_Axles.new(self).build(rear_axles)


## The rear axle z list rebuild_look builds for this look: replays the first draw of the "wheels" stream.
static func rear_axles_for(look: VanLook) -> Array[float]:
	return REAR_AXLES_6 if look.rng_for(&"wheels").randf() < SIX_WHEEL_CHANCE else REAR_AXLES_4


## Merged z spans (x = start, y = end) of the rear wheel arches' openings, where the hull's sill breaks.
static func rear_arch_spans(look: VanLook) -> Array[Vector2]:
	var r := REAR_RADIUS + _Chassis.FLARE_GAP
	var spans: Array[Vector2] = []
	for z: float in rear_axles_for(look):
		var span := Vector2(z - r, z + r)
		if not spans.is_empty() and span.x <= spans[spans.size() - 1].y:
			spans[spans.size() - 1].y = maxf(spans[spans.size() - 1].y, span.y)
		else:
			spans.append(span)
	return spans


## VanRig's transform on its PathFollow3D: the body lift. Travel code resets the rig to this, never to identity.
static func rig_rest_transform() -> Transform3D:
	return Transform3D(Basis.IDENTITY, Vector3(0.0, BODY_LIFT, 0.0))


func _process(delta: float) -> void:
	if delta <= 0.0 or wheel_pivots.is_empty():
		return
	var pos := global_position
	if _has_last:
		var dist := pos.distance_to(_last_pos)
		if dist > 5.0:
			dist = 0.0
		for i: int in range(wheel_pivots.size()):
			wheel_pivots[i].rotation.x -= dist / _radii[i]
	_last_pos = pos
	_has_last = true


## The [tyre, rim, steel] meshes for a wheel radius on one side, built once per rebuild.
func _wheel_meshes(cache: Dictionary, radius: float, outer: float) -> Array[Mesh]:
	var key := Vector2(radius, outer)
	if not cache.has(key):
		var built: Array[Mesh] = [
			_WheelMesh.tyre(radius, TYRE_WIDTH),
			_WheelMesh.rim(radius, TYRE_WIDTH, outer),
			_WheelMesh.steel(radius, TYRE_WIDTH, outer),
		]
		cache[key] = built
	return cache[key]


func _build_wheel(wheel_name: String, pos: Vector3, radius: float, meshes: Array[Mesh],
		hull_mat: Material, rubber: Material, steel: Material) -> void:
	var pivot := Node3D.new()
	pivot.name = wheel_name
	pivot.position = pos
	add_child(pivot)
	wheel_pivots.append(pivot)
	_radii.append(radius)

	_add_mesh("Tyre", meshes[0], rubber, Vector3.ZERO, pivot)
	_add_mesh("Rim", meshes[1], hull_mat, Vector3.ZERO, pivot)
	_add_mesh("Steel", meshes[2], steel, Vector3.ZERO, pivot)


func _build_mud_flap(flap_name: String, x: float, z: float, rubber: Material) -> void:
	var top := HULL_BOTTOM_Y + 0.03
	var bottom := ROAD_Y + 0.12
	_add_mesh(flap_name, _box(Vector3(0.52, top - bottom, 0.03)), rubber,
			Vector3(x, (top + bottom) * 0.5, z))


func _add_mesh(mesh_name: String, mesh: Mesh, mat: Material, pos: Vector3, parent: Node3D = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = mesh_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.layers = 1
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	return mi


func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh
