class_name ItemDescriber
extends RefCounted

## Turns item resources into readable lines for UI. Effects only carry raw
## numbers, so the bench needs this to spell out what an item actually does.

const STAT_LABELS := {
	&"fire_rate": "Fire rate",
	&"damage_per_shot": "Damage",
	&"bullet_speed": "Bullet speed",
	&"bullet_weight": "Bullet weight",
	&"bullet_size": "Bullet size",
	&"reload_speed": "Reload time",
	&"mag_size": "Magazine",
	&"aim_range": "Range",
	&"explosion_radius": "Blast radius",
	&"max_bounces": "Ricochets",
	&"bounce_speed_retention": "Bounce speed kept",
	&"bounce_damage_retention": "Bounce damage kept",
}


const TRAIT_LABELS := {
	BoonTraitKeys.PHYS_DAMAGE_BONUS: "Physical damage",
}


static func kind_name(kind: ItemDefinition.ItemKind) -> String:
	match kind:
		ItemDefinition.ItemKind.MONEY:
			return "MONEY"
		ItemDefinition.ItemKind.CONSUMABLE:
			return "CONSUMABLE"
		ItemDefinition.ItemKind.BOON:
			return "BOON"
		ItemDefinition.ItemKind.TOOL:
			return "TOOL"
	return "ITEM"


static func stat_label(stat_name: StringName) -> String:
	return STAT_LABELS.get(stat_name, String(stat_name).capitalize())


static func damage_type_name(type: DamageType.Type) -> String:
	return String(DamageType.Type.keys()[type]).capitalize()


## One line per effect, e.g. "Damage +1" or "Repairs 20 van hull".
static func effect_lines(item: ItemDefinition) -> PackedStringArray:
	var lines := PackedStringArray()
	if not item:
		return lines
	for effect in item.effects:
		if not effect:
			continue
		lines.append_array(_lines_for_effect(effect))
	return lines


## How the item behaves in the hotbar: charges, cooldown, recharge rules.
static func usage_lines(item: ItemDefinition) -> PackedStringArray:
	var lines := PackedStringArray()
	if not item or not item.is_usable():
		return lines
	var config := item.usable
	if not config:
		return lines
	lines.append("%d charge%s max" % [
		config.max_charges,
		"" if config.max_charges == 1 else "s",
	])
	if config.is_consumed_on_use:
		lines.append("Spends a charge on use")
	match config.recharge_mode:
		ItemUsableConfig.RechargeMode.COOLDOWN:
			lines.append("Recharges after %ss" % format_number(config.recharge_cooldown_sec))
		ItemUsableConfig.RechargeMode.ON_KILL:
			lines.append("+%d charge per kill" % config.recharge_per_kill)
	return lines


static func format_number(value: float) -> String:
	var text := "%.2f" % value
	if text.contains("."):
		text = text.rstrip("0").rstrip(".")
	return text


static func format_modifier(modifier: StatModifier) -> String:
	var label := stat_label(modifier.stat_name)
	if modifier.mode == StatModifier.Mode.MULTIPLY:
		var percent := (modifier.value - 1.0) * 100.0
		var sign_text := "+" if percent >= 0.0 else ""
		return "%s x%s (%s%s%%)" % [
			label,
			format_number(modifier.value),
			sign_text,
			format_number(percent),
		]
	var prefix := "+" if modifier.value >= 0.0 else ""
	return "%s %s%s" % [label, prefix, format_number(modifier.value)]


static func _lines_for_effect(effect: ItemEffect) -> PackedStringArray:
	var lines := PackedStringArray()
	if effect is GunStatModifierEffect:
		var permanent := effect as GunStatModifierEffect
		if permanent.modifier:
			lines.append("%s — permanent" % format_modifier(permanent.modifier))
	elif effect is TimedStatModifierEffect:
		var timed := effect as TimedStatModifierEffect
		for modifier in timed.modifiers:
			if modifier:
				lines.append("%s for %ss" % [
					format_modifier(modifier),
					format_number(timed.duration_sec),
				])
	elif effect is HealEffect:
		var heal := effect as HealEffect
		lines.append("Repairs %s van hull (%s%%)" % [
			format_number(GameSession.get_max_van_health() * heal.heal_percent),
			format_number(heal.heal_percent * 100.0),
		])
	elif effect is GrantCoinEffect:
		lines.append("+%d coins" % (effect as GrantCoinEffect).amount)
	elif effect is ThrowGrenadeEffect:
		var grenade := effect as ThrowGrenadeEffect
		lines.append("Throws a grenade — %s damage in %sm" % [
			format_number(grenade.explosion_damage),
			format_number(grenade.explosion_radius),
		])
		lines.append("%ss fuse" % format_number(grenade.fuse_time))
	elif effect is MaxHealthEffect:
		var max_hp := effect as MaxHealthEffect
		lines.append("+%s max van hull" % format_number(max_hp.bonus_health))
	elif effect is FullHealEffect:
		lines.append("Heal to full hull")
	elif effect is BoonTraitEffect:
		var trait := effect as BoonTraitEffect
		if trait.trait_key == &"":
			pass
		elif trait.set_flag:
			pass
		elif not is_zero_approx(trait.add_value):
			var label := TRAIT_LABELS.get(trait.trait_key, String(trait.trait_key))
			var prefix := "+" if trait.add_value >= 0.0 else ""
			lines.append("%s %s%s — permanent" % [label, prefix, format_number(trait.add_value)])
		elif not is_equal_approx(trait.multiply_value, 1.0):
			var label := TRAIT_LABELS.get(trait.trait_key, String(trait.trait_key))
			lines.append("%s x%s — permanent" % [label, format_number(trait.multiply_value)])
	elif effect is CompositeEffect:
		for child in (effect as CompositeEffect).child_effects:
			if child:
				lines.append_array(_lines_for_effect(child))
	else:
		lines.append(effect.get_script().get_global_name().capitalize())
	return lines
