extends RefCounted
## Puts the rear leaves' outward-visible parts on layers 1+2 so street lights reach them (D15).


static func apply(left: Node3D, right: Node3D) -> void:
	for hinge in [left, right]:
		if hinge == null:
			continue
		for part in ["CurvedBody", "WindowGlass", "WindowFrame"]:
			var root := (hinge as Node3D).get_node_or_null(part)
			if root == null:
				continue
			_street_lit(root)
		var cross := (hinge as Node3D).get_node_or_null("IronCross") as IronCross
		if cross:
			cross.set_street_lit(true)


static func _street_lit(node: Node) -> void:
	var vi := node as VisualInstance3D
	if vi != null and not (vi is Light3D):
		if not vi.is_in_group(VanLighting.GROUP_EXTERIOR_LAYER):
			vi.add_to_group(VanLighting.GROUP_EXTERIOR_LAYER)
		VanLighting.retarget_layers(vi, VanLighting.LAYER_STREET_AND_INTERIOR)
	for child in node.get_children():
		_street_lit(child)
