class_name WeaponPricing
extends RefCounted

## Gold prices for shop weapon offers (mega-expensive vs typical boons).


static func shop_price(instance: WeaponInstance, rng: RandomNumberGenerator = null) -> int:
	if instance == null:
		return 80
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var level := maxi(instance.weapon_level, 1)
	var mods_n := maxi(instance.mods.size(), 0)
	var base := maxi(80, mods_n * level * 25)
	var def := instance.get_definition()
	var premium := 0
	if def:
		if def.tier == WeaponDefinition.Tier.A1:
			premium += 150
		if def.element != WeaponDefinition.Element.NONE:
			premium += 200
	base += premium
	var hi := int(ceil(float(base) * 2.0))
	var price := rng.randi_range(base, maxi(base, hi))
	return maxi(1, roundi(float(price) * GameBalance.WEAPON_SHOP_PRICE_MULT))


static func craft_add_cost(instance: WeaponInstance) -> int:
	if instance == null:
		return 0
	var level := maxi(instance.weapon_level, 1)
	var n := instance.mods.size()
	var times := maxi(instance.times_add_used, 0)
	var raw := 80 * level * (n + 1) * (1 + times)
	return maxi(1, roundi(float(raw) * GameBalance.WEAPON_CRAFT_COST_MULT))


static func craft_remove_cost(instance: WeaponInstance) -> int:
	return craft_add_cost(instance)
