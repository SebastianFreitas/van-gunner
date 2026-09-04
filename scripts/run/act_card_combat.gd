class_name ActCardCombat
extends RefCounted

## Dispatcher for active street cards — mirrors BoonCombat for act cards.
## Call clear() while the old ids are still set, then set the new ids and
## activate_active_cards(). Query hooks always read GameSession.get_active_modifier_cards()
## so a boss fight can stack more than one card.


static func activate_active_card() -> void:
	activate_active_cards()


static func activate_active_cards() -> void:
	activate_cards(GameSession.get_active_modifier_cards())


static func activate(card: ActCardDefinition) -> void:
	var cards: Array[ActCardDefinition] = []
	if card:
		cards.append(card)
	activate_cards(cards)


static func activate_cards(cards: Array[ActCardDefinition]) -> void:
	_clear_overlay()
	if cards.is_empty():
		return
	var merged := _make_base_ctx(cards[0])
	for card in cards:
		if card == null:
			continue
		var ctx := _make_base_ctx(card)
		for effect in card.effects:
			if effect:
				effect.on_activate(ctx)
		_merge_street_overlay(merged, ctx)
	_apply_street_overlay(merged)


static func clear() -> void:
	for card in GameSession.get_active_modifier_cards():
		if card == null:
			continue
		var ctx := _make_base_ctx(card)
		for effect in card.effects:
			if effect:
				effect.on_deactivate(ctx)
	_clear_overlay()


static func modify_outgoing_damage(info: DamageInfo, target: Node) -> void:
	if info == null:
		return
	for card in GameSession.get_active_modifier_cards():
		if card == null:
			continue
		var ctx := _make_base_ctx(card)
		ctx.damage_info = info
		ctx.target = target
		for effect in card.effects:
			if effect:
				effect.modify_outgoing_damage(ctx)


static func configure_enemy(enemy: Node) -> void:
	if enemy == null:
		return
	for card in GameSession.get_active_modifier_cards():
		if card == null:
			continue
		var ctx := _make_base_ctx(card)
		ctx.enemy = enemy
		for effect in card.effects:
			if effect:
				effect.configure_enemy(ctx)


static func modify_item_drop_chance(chance: float) -> float:
	var result := chance
	for card in GameSession.get_active_modifier_cards():
		if card == null:
			continue
		var ctx := _make_base_ctx(card)
		ctx.item_drop_chance = result
		for effect in card.effects:
			if effect:
				result = effect.modify_item_drop_chance(result, ctx)
	return clampf(result, 0.0, 1.0)


static func modify_wave_plan(plan: Array[int]) -> Array[int]:
	var result := plan
	for card in GameSession.get_active_modifier_cards():
		if card == null:
			continue
		var ctx := _make_base_ctx(card)
		ctx.wave_plan = result
		for effect in card.effects:
			if effect:
				result = effect.modify_wave_plan(result, ctx)
	return result


static func _make_base_ctx(card: ActCardDefinition) -> ActCardEffectContext:
	var ctx := ActCardEffectContext.new()
	ctx.card = card
	ctx.player = _find_player()
	if ctx.player:
		ctx.tree = ctx.player.get_tree()
	elif Engine.get_main_loop() is SceneTree:
		ctx.tree = Engine.get_main_loop() as SceneTree
	return ctx


static func _merge_street_overlay(into: ActCardEffectContext, from: ActCardEffectContext) -> void:
	if into == null or from == null:
		return
	for key in from.street_adds.keys():
		into.street_adds[key] = float(into.street_adds.get(key, 0.0)) + float(from.street_adds[key])
	for key in from.street_mults.keys():
		into.street_mults[key] = float(into.street_mults.get(key, 1.0)) * float(from.street_mults[key])
	for key in from.street_flags.keys():
		if bool(from.street_flags[key]):
			into.street_flags[key] = true


static func _apply_street_overlay(ctx: ActCardEffectContext) -> void:
	if ctx == null:
		return
	var traits := BoonTraits.find_on(ctx.player)
	if traits == null:
		return
	traits.set_street_overlay(ctx.street_adds, ctx.street_mults, ctx.street_flags)


static func _clear_overlay() -> void:
	var traits := BoonTraits.find_on(_find_player())
	if traits:
		traits.clear_street_overlay()


static func _find_player() -> Node3D:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.get_first_node_in_group(&"player") as Node3D
