extends RefCounted
## Van audit exemption list: findings accepted on purpose, each with its reason and plan decision.

## Opening label -> node path prefixes never reported: the PC rig stands in the left door bay
## on purpose (D39), window frames (wall, reveals, skin, stop ring) surround their cut (D41, D53),
## the side door stop strips reach 5 cm over each leaf on purpose (vangapfix D13).
const _WIN_FRAME: Array = ["Interior/Shell/SideWalls/", "VanLook/Hull/SideSkin", "/WindowStop"]
const OPENING: Dictionary = {
	&"door_left": ["Interior/Props/RequestBoard/PcRig", "Interior/Shell/SideWalls/DoorStop_"],
	&"door_right": ["Interior/Shell/SideWalls/DoorStop_"],
	&"win_left_front": _WIN_FRAME,
	&"win_left_rear": _WIN_FRAME,
	&"win_right_front": _WIN_FRAME,
	&"win_right_rear": _WIN_FRAME,
}

## FLICKER rows match when (a, b) or the swap match both globs; EDGE and LEAK_OUT rows use only "a";
## LEAK_OUT rules need the hit inside a side opening, or inside the rule's own rig-local "box"
## (an AABB) when it has one. A rule with "entry" (Array of AABB) instead exempts a ray whose
## path from the camera to its hit passes through one of them. It matches any node, so it goes LAST
## (rule_for returns the first match).
## Globs are String.match() patterns against the node path as printed in the report.
## The rear sill: deck end and step ramp under the rear doors, rig-local (D57).
const REAR_SILL := AABB(Vector3(-2.5, -0.4, 4.5), Vector3(5.0, 0.5, 0.9))
## The side door's leaf-to-jamb slide clearance slits on both sides, padded 1 cm around the 2 cm
## gap (D12, D61): the leaf (DOOR_HALF_Z 1.105 in side_door_leaf.gd, JAMB_CLEAR 0.02) sits inside
## the jamb lip (van_side_wall.gd door_center_z -3.42, door_half_length 1.235, door_jamb_inset
## 0.11: lip z -2.295 / -4.545, y 0.13 / 2.94). x spans the lip's outer face at +-2.60.
## Order per side: rear, front, bottom, top.
const DOOR_SLITS: Array[AABB] = [
	AABB(Vector3(2.30, 0.02, -2.325), Vector3(0.5, 3.03, 0.04)),
	AABB(Vector3(2.30, 0.02, -4.555), Vector3(0.5, 3.03, 0.04)),
	AABB(Vector3(2.30, 0.12, -4.555), Vector3(0.5, 0.04, 2.27)),
	AABB(Vector3(2.30, 2.91, -4.555), Vector3(0.5, 0.04, 2.27)),
	AABB(Vector3(-2.80, 0.02, -2.325), Vector3(0.5, 3.03, 0.04)),
	AABB(Vector3(-2.80, 0.02, -4.555), Vector3(0.5, 3.03, 0.04)),
	AABB(Vector3(-2.80, 0.12, -4.555), Vector3(0.5, 0.04, 2.27)),
	AABB(Vector3(-2.80, 2.91, -4.555), Vector3(0.5, 0.04, 2.27)),
]
const RULES: Array[Dictionary] = [
	{
		"section": "FLICKER", "a": "Interior/Bulkhead/KickPlate_*",
		"b": "Interior/Bulkhead/KickPlate_*", "d": "D45",
		"reason": "bulkhead kick plate segment joints: tiny, hidden in the corners; "
			+ "alternating depths read as a striped plate",
	},
	{
		"section": "FLICKER", "a": "Interior/Bulkhead/LeftWallPost_*",
		"b": "Interior/Bulkhead/LeftWallPost_*", "d": "D45",
		"reason": "bulkhead wall post segment joints: tiny, hidden in the corners; "
			+ "alternating depths read as a saw-toothed post",
	},
	{
		"section": "FLICKER", "a": "Interior/Bulkhead/RightWallPost_*",
		"b": "Interior/Bulkhead/RightWallPost_*", "d": "D45",
		"reason": "bulkhead wall post segment joints: tiny, hidden in the corners; "
			+ "alternating depths read as a saw-toothed post",
	},
	{
		"section": "EDGE", "a": "VanLook/Wheels/Well*", "b": "", "d": "D29",
		"reason": "wheel wells are single plates; their rims sit inside the flares",
	},
	{
		"section": "EDGE", "a": "Interior/Shell/SideWindows/*/ExteriorPane", "b": "", "d": "D41",
		"reason": "the window's outer glass pane is a single sheet inside the sash",
	},
	{
		"section": "EDGE", "a": "VanLook/Hull/SideSkin*", "b": "", "d": "D17",
		"reason": "the side skin owns only the outer layer, no inner face; "
			+ "its returns meet the wall's",
	},
	{
		"section": "EDGE", "a": "VanLook/Cab/CabLiner", "b": "", "d": "D59",
		"reason": "the cab liner's back rim ends inside the cab back wall at the body seam",
	},
	{
		"section": "EDGE", "a": "VanLook/Cab/CabBackLip", "b": "", "d": "D59",
		"reason": "the back lip is a single-sided trim band; its rims sit on the body and "
			+ "cab skins",
	},
	{
		"section": "EDGE", "a": "VanLook/Hull/RearSkin", "b": "", "d": "D59",
		"reason": "the rear skin's bottom seam sits below the sill, closed by the rear corners",
	},
	{
		"section": "EDGE", "a": "VanLook/Hull/CornerPostF*", "b": "", "d": "D59",
		"reason": "the front corner posts' top end caps meet the roof edge; no ray sees through",
	},
	{
		"section": "EDGE", "a": "VanLook/Hull/BellySkin", "b": "", "d": "D59",
		"reason": "the belly skin is a single plate under the deck; its rear edge is under "
			+ "the sill",
	},
	{
		"section": "EDGE", "a": "Interior/Shell/RearWall/*Hinge/CurvedBody", "b": "", "d": "D59",
		"reason": "the rear leaf body's short open edges sit under its frame, hardware and "
			+ "window frame; the leak rays find no see-through",
	},
	{
		"section": "EDGE", "a": "VanLook/Hull/RearCorner*", "b": "", "d": "D59",
		"reason": "the rear corner strip's end sits on the sill top under the rear skin",
	},
	{
		"section": "LEAK_OUT", "a": "Interior/Shell/SideWalls/DoorJamb_*", "b": "", "d": "D54",
		"reason": "the jamb lip lines the door opening; seen through the leaf's clearance gap",
	},
	{
		"section": "LEAK_OUT", "a": "Interior/Shell/SideWalls/*WallReveals", "b": "", "d": "D54",
		"reason": "wall reveals line each side cut (D18); seen through the leaf or sash gap",
	},
	{
		"section": "LEAK_OUT", "a": "Interior/Shell/SideWalls/*Wall", "b": "", "d": "D54",
		"reason": "the wall's own cut faces, seen through an opening's clearance gap",
	},
	{
		"section": "LEAK_OUT", "a": "Interior/Shell/SideDoors/*/CurvedBody", "b": "", "d": "D54",
		"reason": "the door leaf's edge band, seen past its outer skin at a grazing angle",
	},
	{
		"section": "LEAK_OUT", "a": "VanLook/InnerShell/CeilRib*", "b": "", "d": "D54",
		"reason": "ceiling rib ends at the wall top, seen through the top of an opening",
	},
	{
		"section": "LEAK_OUT", "a": "Interior/FrontWall/Slab", "b": "", "d": "D54",
		"reason": "the front wall slab's side edge, seen through the side door's front "
			+ "clearance gap",
	},
	{
		"section": "LEAK_OUT", "a": "Interior/Shell/Floor/RearEntryRamp", "b": "", "d": "D57",
		"box": REAR_SILL,
		"reason": "the rear step ramp sits outside under the rear doors by design",
	},
	{
		"section": "LEAK_OUT", "a": "Interior/Shell/Floor/Deck", "b": "", "d": "D57",
		"box": REAR_SILL,
		"reason": "the deck's end face is the rear sill under the rear doors",
	},
	{
		"section": "LEAK_OUT", "a": "*", "b": "", "d": "D61", "entry": DOOR_SLITS,
		"reason": "ray enters through the side door's 2 cm leaf-to-jamb slide clearance (D12)",
	},
]


static func rule_for(section: String, a: String, b: String) -> Dictionary:
	for rule: Dictionary in RULES:
		if rule.section != section:
			continue
		if section == "EDGE" or section == "LEAK_OUT":
			if a.match(rule.a):
				return rule
		elif (a.match(rule.a) and b.match(rule.b)) or (b.match(rule.a) and a.match(rule.b)):
			return rule
	return {}
