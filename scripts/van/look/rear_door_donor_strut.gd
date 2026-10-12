extends Node3D
## Telescoping ram of the donor leaf's hydraulic hinge (spec 2d): three crude welded sleeves of
## stepped diameter pinned at the frame lug and the beam lug. It re-aims whenever the leaf's angle
## changes and spreads the extension evenly over the stages, so both eyes stay on their lugs
## through the whole swing (0.24 m closed to 0.57 m open).

## Sleeve radii, outermost first: a 4 mm radial step, so no two concentric faces are close.
const STAGE_R: Array[float] = [0.024, 0.020, 0.016]
## Outer radius of the eye rings at both ends.
const EYE := 0.03
## Offset between the sleeve ends when fully collapsed, so no two caps share a plane.
const MIN_STEP := 0.012

var _leaf: Node3D
var _beam_lug := Vector3.ZERO
var _sleeve_len := 0.216
var _stages: Array[MeshInstance3D] = []
var _beads: Array[MeshInstance3D] = []
var _rod_eye: Node3D
var _last_angle := INF


## `frame_at` is the frame lug in this node's parent space, `beam_lug` the beam lug in `leaf`
## space, `sleeve_len` the length of each of the nested sleeves.
func setup(leaf: Node3D, frame_at: Vector3, beam_lug: Vector3, sleeve_len: float) -> void:
	_leaf = leaf
	_beam_lug = beam_lug
	_sleeve_len = sleeve_len
	position = frame_at
	var colors: Array[Color] = [Color(0.05, 0.05, 0.055), Color(0.13, 0.13, 0.125),
			Color(0.3, 0.3, 0.29)]
	for i: int in STAGE_R.size():
		var sleeve := MeshInstance3D.new()
		sleeve.name = "StrutStage%d" % i
		var cyl := CylinderMesh.new()
		cyl.top_radius = STAGE_R[i]
		cyl.bottom_radius = STAGE_R[i]
		cyl.height = sleeve_len
		cyl.radial_segments = 10
		cyl.rings = 1
		sleeve.mesh = cyl
		sleeve.material_override = _mat(colors[i], 0.6, 0.3)
		_add(sleeve)
		_stages.append(sleeve)
		if i < STAGE_R.size() - 1:
			# Crude weld bead round the mouth the next sleeve slides out of.
			var bead := MeshInstance3D.new()
			bead.name = "StrutWeld%d" % i
			var ring := TorusMesh.new()
			ring.inner_radius = STAGE_R[i] - 0.002
			ring.outer_radius = STAGE_R[i] + 0.005
			ring.rings = 10
			ring.ring_segments = 5
			bead.mesh = ring
			bead.material_override = _mat(Color(0.2, 0.17, 0.14), 0.7, 0.3)
			_add(bead)
			_beads.append(bead)
	_eye(Vector3.ZERO)
	_rod_eye = _eye(Vector3.ZERO)
	_aim()


func _process(_delta: float) -> void:
	if _leaf != null and not is_equal_approx(_leaf.rotation.y, _last_angle):
		_aim()


func _aim() -> void:
	_last_angle = _leaf.rotation.y
	var target := _leaf.transform * _beam_lug
	var dir := target - position
	var dist := dir.length()
	if dist < 0.001:
		return
	var y := dir / dist
	var x := Vector3.UP.cross(y).normalized()
	basis = Basis(x, y, x.cross(y))
	_rod_eye.position = Vector3(0.0, dist, 0.0)
	# Every stage starts one equal step above the one below; the last one ends on the beam eye.
	var gaps := STAGE_R.size() - 1
	var step := clampf((dist - _sleeve_len) / gaps, MIN_STEP, _sleeve_len - 0.02)
	for i: int in _stages.size():
		var start := minf(i * step, dist - _sleeve_len)
		_stages[i].position = Vector3(0.0, start + _sleeve_len * 0.5, 0.0)
		if i < _beads.size():
			_beads[i].position = Vector3(0.0, start + _sleeve_len, 0.0)


## Ring with a bolt and nut through it, its axis on local z (world up while the strut is level).
func _eye(at: Vector3) -> Node3D:
	var root := Node3D.new()
	root.position = at
	add_child(root)
	var ring := MeshInstance3D.new()
	ring.name = "StrutEye"
	var torus := TorusMesh.new()
	torus.inner_radius = EYE * 0.45
	torus.outer_radius = EYE
	torus.rings = 12
	torus.ring_segments = 6
	ring.mesh = torus
	ring.material_override = _mat(Color(0.05, 0.05, 0.055), 0.6, 0.3)
	ring.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	root.add_child(ring)
	_dress(ring)
	var bolt := MeshInstance3D.new()
	bolt.name = "StrutEyeBolt"
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.008
	shaft.bottom_radius = 0.008
	shaft.height = 0.085
	shaft.radial_segments = 6
	shaft.rings = 1
	bolt.mesh = shaft
	bolt.material_override = _mat(Color(0.3, 0.3, 0.29), 0.5, 0.3)
	bolt.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	root.add_child(bolt)
	_dress(bolt)
	return root


func _dress(node: MeshInstance3D) -> void:
	node.layers = 2
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_to_group(VanLighting.GROUP_EXTERIOR_LAYER)
	VanLighting.retarget_layers(node, VanLighting.LAYER_STREET_AND_INTERIOR)


func _add(node: MeshInstance3D) -> void:
	node.layers = 2
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	node.add_to_group(VanLighting.GROUP_EXTERIOR_LAYER)
	VanLighting.retarget_layers(node, VanLighting.LAYER_STREET_AND_INTERIOR)


static func _mat(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	return mat
