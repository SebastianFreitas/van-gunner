extends RefCounted
## Van audit exemption list: findings accepted on purpose, each with its reason and plan decision.

## Opening label -> node path prefixes never reported: the PC rig stands in the left door bay
## on purpose (D39), window frames (wall, reveals, skin, stop ring, hinge rail) surround their cut (D41, D53),
## the side door stop strips reach 5 cm over each leaf on purpose (vangapfix D13).
const _WIN_FRAME: Array = ["Interior/Shell/SideWalls/", "VanLook/Hull/SideSkin", "/WindowStop", "/HingeRail/"]
const OPENING: Dictionary = {
	&"door_left": ["Interior/Shell/SideWalls/DoorStop_"],
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
## A rule nothing used in a full audit prints VAN AUDIT STALE EXEMPT and fails the smoke; the
## rear sill, tail lamp and wheel arch boxes went that way (spec 14) and are gone.
## The box below follows VanInteriorSize and VanOpenings, so a remodel moves it.
## The rear sill: deck end and step ramp under the rear doors, rig-local (D57).
const REAR_SILL := AABB(
	Vector3(-(VanInteriorSize.REAR_DOOR_HALF - 0.2), -0.4, VanInteriorSize.REAR_Z - 0.68),
	Vector3(2.0 * (VanInteriorSize.REAR_DOOR_HALF - 0.2), 0.5, 1.4))
## The right DoorEdgeSeal, rig-local, 1 cm round it (door front edge, wall_x + 0.106..0.195).
## Right side only; its rule's "mirror" covers the left seal.
const DOOR_EDGE_SEAL := AABB(
	Vector3(VanInteriorSize.BOTTOM_HALF - 0.08, VanOpenings.SIDE_DOOR_Y_MIN - 0.01,
		VanOpenings.SIDE_DOOR_Z - VanOpenings.SIDE_DOOR_HALF - 0.031),
	Vector3(2.0 * VanOpenings.SKIN, VanOpenings.SIDE_DOOR_HEIGHT, 0.16))
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
		"section": "FLICKER", "a": "Interior/Shell/Floor/MidSlab",
		"b": "Interior/Props/FuseBox/Generator/*", "d": "D25 (auto)",
		"reason": "the generator's plates stand within 1 cm of the MidSlab end face at z 1.00 "
			+ "in several depths: the slab end is hidden behind them; nudges up to 7 cm only moved it",
	},
	{
		"section": "FLICKER", "a": "Interior/Shell/Floor/RearSheet",
		"b": "Interior/Shell/RearWall/*/AstragalOuter", "d": "D31 (auto)",
		"reason": "the sheet's rear face meets each astragal's inner face within 1 cm, 6 cm2 hidden "
			+ "behind the sill; nudges to 6.65 and 6.70 only moved it onto RearSkin and the leaf lips",
	},
	{
		"section": "FLICKER", "a": "Interior/Shell/Floor/Plate*",
		"b": "Interior/Shell/Floor/Bead*", "d": "D32 (auto)",
		"reason": "each bead is sunk into its plate's side and shares the plate's underside at "
			+ "y -0.02, both hidden under the sheet top",
	},
	{
		"section": "FLICKER", "a": "Interior/Shell/Floor/LipRight",
		"b": "Interior/Props/FuseBox/Generator/PanFloor", "d": "D31 (auto)",
		"reason": "the generator pan floor sits at the lip's top height for 7 cm2 beside the wall; "
			+ "the lip top can't move because the floor seal top (0.05) is 2 cm above",
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
		"section": "EDGE", "a": "VanLook/Hull/RearSkin", "b": "", "d": "D59",
		"reason": "the rear skin's bottom seam sits below the sill, closed by the rear corners",
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
		"section": "EDGE", "a": "VanLook/Hull/FrontSkin", "b": "", "d": "cabrebuild",
		"reason": "the front fill's bottom edge, left open at the cab's base under the deck "
			+ "(a bolted-on donor cab, seam on purpose); no ray sees through",
	},
	{
		"section": "LEAK_OUT", "a": "Interior/Shell/SideWalls/DoorJamb_*", "b": "", "d": "D54",
		"reason": "the jamb lip lines the door opening; seen through the leaf's clearance gap"
			+ "; re-earned (vangapfix D21); not see-through (vangapfix2)",
	},
	{
		"section": "LEAK_OUT", "a": "Interior/Shell/SideWalls/*WallReveals", "b": "", "d": "D54",
		"reason": "wall reveals line each side cut (D18); seen through the leaf or sash gap"
			+ "; re-earned (vangapfix D21); not see-through (vangapfix2)",
	},
	{
		"section": "LEAK_OUT", "a": "Interior/Shell/SideWalls/*Wall", "b": "", "d": "D54",
		"reason": "the wall's own cut faces, seen through an opening's clearance gap"
			+ "; re-earned (vangapfix D21); not see-through (vangapfix2)",
	},
	{
		"section": "LEAK_OUT", "a": "Interior/Shell/SideDoors/*/CurvedBody", "b": "", "d": "D54",
		"reason": "the door leaf's edge band, seen past its outer skin at a grazing angle"
			+ "; re-earned (vangapfix D21); not see-through (vangapfix2)",
	},
	{
		"section": "LEAK_OUT", "a": "Interior/Shell/SideWalls/DoorEdgeSeal_*", "b": "", "d": "D54",
		"box": DOOR_EDGE_SEAL, "mirror": true,
		"reason": "the strip over the bay's front edge sits behind the skin; seen through the "
			+ "leaf's front clearance gap, which it exists to close",
	},
	{
		"section": "LEAK_OUT", "a": "Interior/Shell/Floor/RearEntryRamp", "b": "", "d": "D57",
		"box": REAR_SILL,
		"reason": "the rear step ramp sits outside under the rear doors by design"
			+ "; re-earned (vangapfix D21); not see-through (vangapfix2)",
	},
]


## Rules that exempted something in this process: key -> true. A shard prints them and the
## full audit (or smoke, summing the shards) reports every rule missing from the union.
static var used: Dictionary = {}


## Stable name of a rule for the stale report.
static func key_of(rule: Dictionary) -> String:
	# Stripped: smoke reads the list from a line whose trailing space the judge cuts, so an
	# empty "b" would make the last-listed rule look unused.
	return ("%s %s %s" % [rule.section, rule.a, rule.get("b", "")]).strip_edges()


static func mark(rule: Dictionary) -> void:
	used[key_of(rule)] = true


static func opening_key(label: StringName, prefix: String) -> String:
	return "OPENING %s %s" % [label, prefix]


## Every rule and opening prefix, in the order they are declared.
static func all_keys() -> PackedStringArray:
	var keys := PackedStringArray()
	for rule: Dictionary in RULES:
		keys.append(key_of(rule))
	for label: StringName in OPENING.keys():
		for prefix: String in OPENING[label]:
			keys.append(opening_key(label, prefix))
	return keys


## A full run reports the rules nothing used; a shard prints its used and all keys so
## tools/smoke.py can judge the union (a shard runs only some of the passes that use a rule).
static func report_stale(runner: Node, full_run: bool) -> void:
	var keys := all_keys()
	if not full_run:
		print("AUDIT EXEMPT USED " + "|".join(PackedStringArray(used.keys())))
		print("AUDIT EXEMPT KEYS " + "|".join(keys))
		return
	for key in keys:
		if not used.has(key):
			print("VAN AUDIT STALE EXEMPT: " + key)
			runner.add_finding("STALE_EXEMPT", key)


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
