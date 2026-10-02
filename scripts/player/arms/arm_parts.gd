class_name ArmParts
extends RefCounted
## Low-poly primitives for the first-person arms: meshes, cylinders, boxes and tapered limbs.


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
