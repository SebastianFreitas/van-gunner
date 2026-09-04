class_name ActCardCombat
extends RefCounted

## Dispatcher for the active street card — mirrors BoonCombat for act cards.
## Call clear() while the old card id is still set, then set the new id and
## activate(). Query hooks always read GameSession.get_active_street_card().


static func activate_active_card() -> void:
	activate(GameSession.get_active_street_card())


static func activate(card: ActCardDefinition) -> void:
	_clear_overlay()
	if card == null:
		return
	var ctx := _make_base_ctx(card)
	for effect in card.effects:
		if effect:
			effect.on_activate(ctx)
	_apply_street_overlay(ctx)


static func clear() -> void:
	var card := GameSession.get_active_street_card()
	if card:
		var ctx := _make_base_ctx(card)
		for effect in card.effects:
			if effect:
				effect.on_deactivate(ctx)
	_clear_overlay()


static func modify_outgoing_damage(info: DamageInfo, target: Node) -> void:
	var card := GameSession.get_active_street_card()
	if card == null or info == null:
		return
	var ctx := _make_base_ctx(card)
	ctx.damage_info = info
	ctx.target = target
	for effect in card.effects:
		if effect:
			effect.modify_outgoing_damage(ctx)


static func configure_enemy(enemy: Node) -> void:
	var card := GameSession.get_active_street_card()
	if card == null or enemy == null:
		return
	var ctx := _make_base_ctx(card)
	ctx.enemy = enemy
	for effect in card.effects:
		if effect:
			effect.configure_enemy(ctx)


static func modify_item_drop_chance(chance: float) -> float:
	var card := GameSession.get_active_street_card()
	if card == null:
		return chance
	var ctx := _make_base_ctx(card)
	ctx.item_drop_chance = chance
	var result := chance
	for effect in card.effects:
		if effect:
			result = effect.modify_item_drop_chance(result, ctx)
	return clampf(result, 0.0, 1.0)


static func modify_wave_plan(plan: Array[int]) -> Array[int]:
	var card := GameSession.get_active_street_card()
	if card == null:
		return plan
	var ctx := _make_base_ctx(card)
	ctx.wave_plan = plan
	var result := plan
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
