extends RefCounted
## Van audit exemption list: findings accepted on purpose, each with its reason and plan decision.

## Opening label -> node path prefixes never reported: the PC rig stands in the left door bay
## on purpose (D39), window frames (wall, reveals, skin, stop ring) surround their cut (D41, D53).
const _WIN_FRAME: Array = ["Interior/Shell/SideWalls/", "VanLook/Hull/SideSkin", "/WindowStop"]
const OPENING: Dictionary = {
	&"door_left": ["Interior/Props/RequestBoard/PcRig"],
	&"win_left_front": _WIN_FRAME,
	&"win_left_rear": _WIN_FRAME,
	&"win_right_front": _WIN_FRAME,
	&"win_right_rear": _WIN_FRAME,
}

## FLICKER rows match when (a, b) or the swap match both globs; EDGE and LEAK_OUT rows use only "a";
## LEAK_OUT rules need the hit inside a side opening, or inside the rule's own rig-local "box"
## (an AABB) when it has one.
## Globs are String.match() patterns against the node path as printed in the report.
## The rear sill: deck end and step ramp under the rear doors, rig-local (D57).
const REAR_SILL := AABB(Vector3(-2.5, -0.4, 4.5), Vector3(5.0, 0.5, 0.9))
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
