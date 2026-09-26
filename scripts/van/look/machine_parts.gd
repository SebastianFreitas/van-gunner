class_name MachineParts
extends RefCounted
## Static low-poly part builders (motor, flywheel, belt, fan, battery, can, gauge, switch, CRT, tower, keyboard, pipe, vent, cables) for the van's interior machines.


## Dark, roughness-clamped albedo material shared by most parts.
static func dark(color: Color, roughness: float = 0.9) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(minf(color.r, 0.5), minf(color.g, 0.5), minf(color.b, 0.5))
	mat.roughness = clampf(roughness, 0.78, 0.95)
	mat.metallic = 0.2
	return mat


## Emissive-only material for LEDs, screens and gauge glow.
static func emissive(color: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.BLACK
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	return mat


static func _cyl(top: float, h: float, seg: int = 10, bottom: float = -1.0) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = top if bottom < 0.0 else bottom
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c


static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func _root(part_name: String, pos: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = part_name
	root.position = pos
	return root


static func _mesh(root: Node3D, part_name: String, mesh: Mesh, mat: Material, pos: Vector3,
		rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = part_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.layers = 2
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mi.position = pos
	mi.rotation = rot
	root.add_child(mi)
	return mi


## Builds a cylinder segment between two root-local points; used by pipe() and cable_bundle().
static func _segment(root: Node3D, a: Vector3, b: Vector3, mat: Material, radius: float,
		part_name: String) -> void:
	if a.distance_to(b) < 0.001:
		return
	var dir := b - a
	var up := Vector3.UP
	if absf(dir.normalized().dot(Vector3.UP)) > 0.99:
		up = Vector3.RIGHT
	var mi := _mesh(root, part_name, _cyl(radius, dir.length(), 8), mat, (a + b) * 0.5)
	mi.basis = Basis.looking_at(dir.normalized(), up) * Basis(Vector3.RIGHT, -PI / 2.0)


## Horizontal motor body with end caps, a mounting foot and a spinning shaft pivot.
static func motor(parent: Node3D, pos: Vector3, mat: Material, length: float = 0.5,
		radius: float = 0.16) -> Node3D:
	var root := _root("Motor", pos)
	var by := radius + 0.04
	var side := Vector3(0.0, 0.0, PI / 2.0)
	_mesh(root, "Body", _cyl(radius, length, 10), mat, Vector3(0.0, by, 0.0), side)
	var cap := _cyl(radius * 1.15, 0.03, 10)
	_mesh(root, "CapA", cap, mat, Vector3(-length / 2.0, by, 0.0), side)
	_mesh(root, "CapB", cap, mat, Vector3(length / 2.0, by, 0.0), side)
	_mesh(root, "Foot", _box(Vector3(0.8 * length, 0.04, 1.4 * radius)), mat, Vector3(0.0, 0.02, 0.0))
	var shaft := _root("Shaft", Vector3(length / 2.0, by, 0.0))
	_mesh(shaft, "ShaftRod", _cyl(0.025, 0.12, 8), mat, Vector3(0.06, 0.0, 0.0), side)
	root.add_child(shaft)
	parent.add_child(root)
	return root


## Rimmed flywheel on a spin pivot named "Wheel", with four fanned spokes and a hub.
static func flywheel(parent: Node3D, pos: Vector3, mat: Material, radius: float = 0.3) -> Node3D:
	var root := _root("Flywheel", pos)
	var wheel := _root("Wheel", Vector3(0.0, radius, 0.0))
	var torus := TorusMesh.new()
	torus.inner_radius = radius * 0.8
	torus.outer_radius = radius
	torus.rings = 12
	torus.ring_segments = 6
	_mesh(wheel, "Rim", torus, mat, Vector3.ZERO, Vector3(0.0, 0.0, PI / 2.0))
	var spoke := _box(Vector3(0.03, radius * 2.0, 0.03))
	for i: int in range(4):
		_mesh(wheel, "Spoke%d" % i, spoke, mat, Vector3.ZERO, Vector3(float(i) * PI / 4.0, 0.0, 0.0))
	_mesh(wheel, "Hub", _cyl(radius * 0.15, 0.08, 8), mat, Vector3.ZERO, Vector3(0.0, 0.0, PI / 2.0))
	root.add_child(wheel)
	parent.add_child(root)
	return root


## Two pulleys joined by top and bottom belt strips; static, motion flickers it later.
static func belt(parent: Node3D, from: Vector3, to: Vector3, mat: Material,
		radius_a: float = 0.06, radius_b: float = 0.2) -> Node3D:
	var root := _root("Belt", from)
	var dir := to - from
	var side := Vector3(0.0, 0.0, PI / 2.0)
	_mesh(root, "PulleyA", _cyl(radius_a, 0.05, 10), mat, Vector3.ZERO, side)
	_mesh(root, "PulleyB", _cyl(radius_b, 0.05, 10), mat, dir, side)
	if dir.length() >= 0.001:
		var dir_n := dir.normalized()
		var rise := Vector3(0.0, (radius_a + radius_b) * 0.5, 0.0)
		var strip := _box(Vector3(0.02, 0.02, dir.length()))
		var top := _mesh(root, "BeltTop", strip, mat, dir * 0.5 + rise)
		top.basis = Basis.looking_at(dir_n, Vector3.RIGHT)
		var bottom := _mesh(root, "BeltBottom", strip, mat, dir * 0.5 - rise)
		bottom.basis = Basis.looking_at(dir_n, Vector3.RIGHT)
	parent.add_child(root)
	return root


## Square-framed cooling fan with a spinning "Blades" pivot and a hub.
static func fan(parent: Node3D, pos: Vector3, mat: Material, radius: float = 0.18) -> Node3D:
	var root := _root("Fan", pos)
	var edge := _box(Vector3(radius * 2.0, 0.02, 0.02))
	_mesh(root, "FrameTop", edge, mat, Vector3(0.0, radius, 0.0))
	_mesh(root, "FrameBottom", edge, mat, Vector3(0.0, -radius, 0.0))
	var s := _box(Vector3(0.02, radius * 2.0, 0.02))
	_mesh(root, "FrameLeft", s, mat, Vector3(-radius, 0.0, 0.0))
	_mesh(root, "FrameRight", s, mat, Vector3(radius, 0.0, 0.0))
	var blades := _root("Blades", Vector3.ZERO)
	var blade := _box(Vector3(radius, 0.07, 0.01))
	for i: int in range(4):
		_mesh(blades, "Blade%d" % i, blade, mat, Vector3.ZERO,
				Vector3(deg_to_rad(20.0), 0.0, float(i) * PI / 2.0))
	_mesh(blades, "Hub", _cyl(radius * 0.2, 0.05, 8), mat, Vector3.ZERO, Vector3(PI / 2.0, 0.0, 0.0))
	root.add_child(blades)
	parent.add_child(root)
	return root


## Battery box with two terminal posts.
static func battery(parent: Node3D, pos: Vector3, mat: Material, terminal_mat: Material) -> Node3D:
	var root := _root("Battery", pos)
	_mesh(root, "Body", _box(Vector3(0.26, 0.2, 0.17)), mat, Vector3(0.0, 0.1, 0.0))
	var post := _cyl(0.018, 0.03, 8)
	_mesh(root, "TerminalA", post, terminal_mat, Vector3(-0.07, 0.215, -0.04))
	_mesh(root, "TerminalB", post, terminal_mat, Vector3(0.07, 0.215, -0.04))
	parent.add_child(root)
	return root


## Jerry can with a three-bar handle and an angled spout.
static func jerry_can(parent: Node3D, pos: Vector3, mat: Material) -> Node3D:
	var root := _root("JerryCan", pos)
	_mesh(root, "Body", _box(Vector3(0.34, 0.46, 0.16)), mat, Vector3(0.0, 0.23, 0.0))
	var bar := _box(Vector3(0.02, 0.02, 0.14))
	_mesh(root, "HandleL", bar, mat, Vector3(-0.1, 0.48, 0.0))
	_mesh(root, "HandleR", bar, mat, Vector3(0.1, 0.48, 0.0))
	_mesh(root, "HandleTop", _box(Vector3(0.22, 0.02, 0.02)), mat, Vector3(0.0, 0.49, 0.07))
	_mesh(root, "Spout", _cyl(0.02, 0.1, 8), mat, Vector3(0.12, 0.46, -0.04),
			Vector3(0.0, 0.0, deg_to_rad(30.0)))
	parent.add_child(root)
	return root


## Dial gauge with a face plate and a spinning "Needle" pivot.
static func gauge(parent: Node3D, pos: Vector3, mat: Material, face_mat: Material) -> Node3D:
	var root := _root("Gauge", pos)
	var flat := Vector3(PI / 2.0, 0.0, 0.0)
	_mesh(root, "Dial", _cyl(0.07, 0.03, 12), mat, Vector3.ZERO, flat)
	_mesh(root, "Face", _cyl(0.062, 0.006, 12), face_mat, Vector3(0.0, 0.0, 0.018), flat)
	var needle := _root("Needle", Vector3(0.0, 0.0, 0.021))
	_mesh(needle, "NeedlePin", _box(Vector3(0.004, 0.055, 0.004)), mat, Vector3(0.0, 0.027, 0.0))
	root.add_child(needle)
	parent.add_child(root)
	return root


## Knife switch with two contact clips and a hinged "Blade" pivot.
static func knife_switch(parent: Node3D, pos: Vector3, mat: Material,
		contact_mat: Material) -> Node3D:
	var root := _root("KnifeSwitch", pos)
	_mesh(root, "Plate", _box(Vector3(0.2, 0.28, 0.02)), mat, Vector3.ZERO)
	var clip := _box(Vector3(0.03, 0.03, 0.02))
	_mesh(root, "ClipL", clip, contact_mat, Vector3(-0.06, 0.11, 0.02))
	_mesh(root, "ClipR", clip, contact_mat, Vector3(0.06, 0.11, 0.02))
	var blade := _root("Blade", Vector3(0.0, -0.11, 0.02))
	_mesh(blade, "BladeArm", _box(Vector3(0.03, 0.22, 0.015)), mat, Vector3(0.0, 0.11, 0.0))
	_mesh(blade, "Handle", _cyl(0.014, 0.03, 8), mat, Vector3(0.0, 0.22, 0.0),
			Vector3(PI / 2.0, 0.0, 0.0))
	root.add_child(blade)
	parent.add_child(root)
	return root


## Boxy CRT with a tapered back and a front "Screen" quad.
static func crt(parent: Node3D, pos: Vector3, mat: Material, screen_mat: Material,
		size: float = 0.4) -> Node3D:
	var root := _root("CRT", pos)
	_mesh(root, "Bezel", _box(Vector3(size, 0.8 * size, 0.12)), mat, Vector3.ZERO)
	_mesh(root, "Back", _cyl(0.3 * size, 0.45 * size, 4, 0.55 * size), mat,
			Vector3(0.0, 0.0, -0.06 - 0.225 * size), Vector3(PI / 2.0, PI / 4.0, 0.0))
	var quad := QuadMesh.new()
	quad.size = Vector2(0.8 * size, 0.6 * size)
	_mesh(root, "Screen", quad, screen_mat, Vector3(0.0, 0.0, 0.061))
	parent.add_child(root)
	return root


## Tower PC box with a drive bay slot and two front LEDs.
static func tower_pc(parent: Node3D, pos: Vector3, mat: Material, led_mat: Material) -> Node3D:
	var root := _root("TowerPC", pos)
	_mesh(root, "Body", _box(Vector3(0.2, 0.42, 0.45)), mat, Vector3(0.0, 0.21, 0.0))
	_mesh(root, "DriveBay", _box(Vector3(0.18, 0.05, 0.02)), mat, Vector3(0.0, 0.32, 0.226))
	var led := _box(Vector3(0.02, 0.02, 0.01))
	_mesh(root, "LedA", led, led_mat, Vector3(-0.06, 0.24, 0.226))
	_mesh(root, "LedB", led, led_mat, Vector3(-0.02, 0.24, 0.226))
	parent.add_child(root)
	return root


## Tilted keyboard slab with three rows of key boxes.
static func keyboard(parent: Node3D, pos: Vector3, mat: Material) -> Node3D:
	var root := _root("Keyboard", pos)
	_mesh(root, "Slab", _box(Vector3(0.44, 0.025, 0.15)), mat, Vector3.ZERO,
			Vector3(deg_to_rad(6.0), 0.0, 0.0))
	var key := _box(Vector3(0.4, 0.012, 0.03))
	for i: int in range(3):
		_mesh(root, "Row%d" % i, key, mat, Vector3(0.0, 0.02, -0.04 + float(i) * 0.04))
	parent.add_child(root)
	return root


## Straight pipe run between two points with a flange ring at each end.
static func pipe(parent: Node3D, from: Vector3, to: Vector3, mat: Material,
		radius: float = 0.035) -> Node3D:
	var root := _root("Pipe", from)
	var local_to := to - from
	_segment(root, Vector3.ZERO, local_to, mat, radius, "PipeBody")
	var flange := _cyl(radius * 1.6, 0.02, 10)
	_mesh(root, "FlangeA", flange, mat, Vector3.ZERO)
	_mesh(root, "FlangeB", flange, mat, local_to)
	parent.add_child(root)
	return root


## Square duct vent with slats and a short stack.
static func vent(parent: Node3D, pos: Vector3, mat: Material, size: float = 0.3) -> Node3D:
	var root := _root("Vent", pos)
	_mesh(root, "Duct", _box(Vector3(size, 0.1, size)), mat, Vector3.ZERO)
	var slat := _box(Vector3(size * 0.9, 0.01, 0.03))
	for i: int in range(4):
		_mesh(root, "Slat%d" % i, slat, mat, Vector3(0.0, 0.055, -size * 0.3 + float(i) * size * 0.2))
	_mesh(root, "Stack", _cyl(size * 0.25, 0.12, 10), mat, Vector3(0.0, 0.11, 0.0))
	parent.add_child(root)
	return root


## Loose cable bundle strung through a run of points, each strand offset sideways along X.
static func cable_bundle(parent: Node3D, points: PackedVector3Array, mat: Material,
		radius: float = 0.02, strands: int = 3) -> Node3D:
	var root := _root("CableBundle", Vector3.ZERO)
	var count := maxi(strands, 1)
	if points.size() >= 2:
		for i: int in range(points.size() - 1):
			for s: int in range(count):
				var offset := (float(s) - float(count - 1) / 2.0) * radius * 2.2
				var side := Vector3(offset, 0.0, 0.0)
				_segment(root, points[i] + side, points[i + 1] + side, mat, radius,
						"Strand%d_%d" % [i, s])
	parent.add_child(root)
	return root
