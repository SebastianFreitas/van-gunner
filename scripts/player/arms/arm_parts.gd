class_name ArmParts
extends RefCounted
## Low-poly primitives for the first-person arms: tapered limbs, cloth sleeves, straps, wounds, shards and scars.


static func mesh(root: Node3D, node_name: String, shape: Mesh, mat: Material, at: Vector3,
		rot: Basis = Basis.IDENTITY) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = shape
	mi.material_override = mat
	mi.layers = VanLighting.LAYER_VAN_INTERIOR
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.transform = Transform3D(rot, at)
	root.add_child(mi)
	return mi


## Basis that puts a CylinderMesh's +Y (its axis) along dir, so top_radius is the far end.
static func along(dir: Vector3) -> Basis:
	var d := dir.normalized()
	var up := Vector3.UP if absf(d.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	return Basis.looking_at(d, up) * Basis(Vector3.RIGHT, -PI / 2.0)


static func cyl(top: float, h: float, bottom: float, seg: int = 8) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c


static func box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func limb(root: Node3D, node_name: String, a: Vector3, b: Vector3, r_a: float, r_b: float,
		mat: Material, seg: int = 8) -> MeshInstance3D:
	var d := b - a
	return mesh(root, node_name, cyl(r_b, d.length(), r_a, seg), mat, (a + b) * 0.5, along(d))


## A unit vector perpendicular to the limb axis, at `angle` around it.
static func radial(axis: Vector3, angle: float) -> Vector3:
	var d := axis.normalized()
	var ref := Vector3.UP if absf(d.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var u := d.cross(ref).normalized()
	var v := d.cross(u)
	return u * cos(angle) + v * sin(angle)


## A radial within `spread` radians of the side facing `facing`, so dressing lands in view.
static func radial_toward(axis: Vector3, facing: Vector3, spread: float,
		rng: RandomNumberGenerator) -> Vector3:
	var d := axis.normalized()
	var ref := Vector3.UP if absf(d.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var u := d.cross(ref).normalized()
	var v := d.cross(u)
	var f := facing - d * facing.dot(d)
	var base := atan2(f.dot(v), f.dot(u))
	return radial(axis, base + rng.randf_range(-spread, spread))


## A right-handed basis with Y along `y_dir` and X as close to `x_hint` as possible.
static func basis_y(y_dir: Vector3, x_hint: Vector3) -> Basis:
	var y := y_dir.normalized()
	var x := (x_hint - y * x_hint.dot(y)).normalized()
	return Basis(x, y, x.cross(y))


## Projects a point near a limb back onto the limb's tube of the given radius.
static func on_surface(p: Vector3, centre: Vector3, axis: Vector3, radius: float) -> Vector3:
	var d := axis.normalized()
	var foot := centre + d * (p - centre).dot(d)
	return foot + (p - foot).normalized() * radius


## A cloth tube with ragged hem flaps fanned out around its end at `b`.
static func sleeve(root: Node3D, node_name: String, a: Vector3, b: Vector3, r_a: float,
		r_b: float, mat: Material, rng: RandomNumberGenerator,
		hem_count: int) -> MeshInstance3D:
	var tube := limb(root, node_name, a, b, r_a, r_b, mat, 8)
	var dn := (b - a).normalized()
	for i in hem_count:
		var ang := TAU * (float(i) + rng.randf_range(-0.3, 0.3)) / float(hem_count)
		var r := radial(dn, ang)
		var length := rng.randf_range(0.04, 0.10)
		var tilt := rng.randf_range(0.08, 0.26)
		var dir := (dn * cos(tilt) + r * sin(tilt)).normalized()
		var bs := basis_y(dir, r)
		mesh(root, "%s_hem%d" % [node_name, i], box(Vector3(0.018, length, 0.035)), mat,
				b + r * (r_b - 0.004) + dir * (length * 0.5 - 0.015), bs)
	return tube


## A knotted rag strap: an octagonal band round the limb, a knot and two hanging tails.
static func strap(root: Node3D, node_name: String, centre: Vector3, axis: Vector3,
		radius: float, facing: Vector3, mat: Material, rng: RandomNumberGenerator) -> void:
	var dn := axis.normalized()
	var w := rng.randf_range(0.03, 0.045)
	var rr := radius + 0.006
	var chord := 2.0 * rr * tan(PI / 8.0) * 1.08
	var a0 := rng.randf_range(0.0, TAU)
	for i in 8:
		var r := radial(dn, a0 + TAU * float(i) / 8.0)
		mesh(root, "%s_%d" % [node_name, i], box(Vector3(0.012, w, chord)), mat,
				centre + r * rr, basis_y(dn, r))
	var k := radial_toward(dn, facing, 0.9, rng)
	var knot_pos := centre + k * (radius + 0.02)
	mesh(root, node_name + "_knot", box(Vector3(0.04, w + 0.012, 0.045)), mat, knot_pos,
			basis_y(dn, k))
	for t in 2:
		var side := -1.0 if t == 0 else 1.0
		var tangent := k.cross(dn)
		var down := (Vector3.DOWN - k * Vector3.DOWN.dot(k)).normalized()
		var dir := (down + tangent * side * rng.randf_range(0.25, 0.6) + k * 0.25).normalized()
		var length := rng.randf_range(0.08, 0.14)
		mesh(root, "%s_tail%d" % [node_name, t], box(Vector3(0.012, length, 0.028)), mat,
				knot_pos + dir * (length * 0.5), basis_y(dir, k))


## A raw wound patch on the limb with one or two drips running down the skin.
static func wound(root: Node3D, node_name: String, centre: Vector3, axis: Vector3,
		radius: float, facing: Vector3, mat: Material, rng: RandomNumberGenerator) -> void:
	var dn := axis.normalized()
	var r := radial_toward(dn, facing, 0.8, rng)
	var pos := centre + r * (radius + 0.004)
	var length := rng.randf_range(0.07, 0.11)
	var wid := rng.randf_range(0.04, 0.065)
	var bs := basis_y(dn, r)
	mesh(root, node_name, box(Vector3(0.006, length, wid)), mat, pos, bs)
	for i in rng.randi_range(1, 2):
		var s0 := pos + bs.z * rng.randf_range(-wid * 0.4, wid * 0.4) \
				+ bs.y * rng.randf_range(-length * 0.4, length * 0.4)
		var down := (Vector3.DOWN - r * Vector3.DOWN.dot(r)).normalized()
		var s1 := on_surface(s0 + down * rng.randf_range(0.03, 0.07), centre, dn, radius + 0.004)
		mesh(root, "%s_drip%d" % [node_name, i], box(Vector3(0.005, s0.distance_to(s1), 0.012)),
				mat, (s0 + s1) * 0.5, basis_y(s1 - s0, r))


## A glass shard stuck in the limb at a lean, with a small cut where it enters.
static func shard(root: Node3D, node_name: String, centre: Vector3, axis: Vector3,
		radius: float, facing: Vector3, mat: Material, wound_mat: Material,
		rng: RandomNumberGenerator) -> void:
	var dn := axis.normalized()
	var r := radial_toward(dn, facing, 1.0, rng)
	var entry := centre + r * radius
	var lean := rng.randf_range(0.35, 0.9)
	var swing := rng.randf_range(0.0, TAU)
	var side := dn * cos(swing) + r.cross(dn) * sin(swing)
	var dir := (r * cos(lean) + side * sin(lean)).normalized()
	var length := rng.randf_range(0.06, 0.11)
	var wid := rng.randf_range(0.012, 0.022)
	mesh(root, node_name, box(Vector3(0.004, length, wid)), mat,
			entry + dir * (length * 0.5 - 0.02), basis_y(dir, r))
	mesh(root, node_name + "_cut", box(Vector3(0.005, 0.035, 0.03)), wound_mat,
			entry + r * 0.004, basis_y(dn, r))


## A stitched scar: a thin ridge along the limb with cross stitches.
static func scar(root: Node3D, node_name: String, centre: Vector3, axis: Vector3,
		radius: float, facing: Vector3, mat: Material, rng: RandomNumberGenerator) -> void:
	var dn := axis.normalized()
	var r := radial_toward(dn, facing, 0.5, rng)
	var pos := centre + r * (radius + 0.003)
	var length := rng.randf_range(0.05, 0.10)
	var ang := rng.randf_range(-0.35, 0.35)
	var along_dir := (dn * cos(ang) + r.cross(dn) * sin(ang)).normalized()
	var bs := basis_y(along_dir, r)
	mesh(root, node_name, box(Vector3(0.008, length, 0.012)), mat, pos, bs)
	var n := rng.randi_range(3, 5)
	for i in n:
		var t := (float(i) + 0.5) / float(n) - 0.5
		mesh(root, "%s_st%d" % [node_name, i], box(Vector3(0.006, 0.006, 0.026)), mat,
				pos + bs.y * (t * length), bs)
