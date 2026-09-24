extends RefCounted

## Vital bookkeeping for GameSession. Static helpers; every function takes the
## GameSession autoload as `session`.


static func bind_vital(session: Node, vital: Node) -> void:
	if vital == null or not ("vital_id" in vital):
		return
	var key := String(vital.vital_id)
	var share_max := _bind_max_for_vital(session, vital)
	var share_cur := share_max
	if session.pending_vital_health.has(key):
		share_cur = float(session.pending_vital_health[key])
	if vital.has_method("apply_saved"):
		vital.apply_saved(share_cur, share_max)
	session.sync_van_health_from_vitals()


static func sync_van_health_from_vitals(session: Node) -> void:
	var vitals := vital_nodes(session)
	if vitals.is_empty():
		return
	var cur := 0.0
	var mx := 0.0
	for vital in vitals:
		cur += float(vital.health)
		mx += float(vital.max_health)
	session.van_health = cur
	session.van_max_health = maxf(session.BASE_MAX_VAN_HEALTH, mx)
	session.van_health_changed.emit(session.van_health, session.van_max_health)
	if is_zero_approx(session.van_health) and session.phase != session.RunPhase.GAME_OVER:
		session.set_phase(session.RunPhase.GAME_OVER)


static func apply_meta_vital_delta(session: Node, node: Resource) -> void:
	if node == null or session.phase == session.RunPhase.GAME_OVER:
		return
	var vitals := vital_nodes(session)
	if vitals.is_empty():
		return
	for vital in vitals:
		var add := 0.0
		for effect in node.effects:
			if effect:
				add += effect.vital_max_bonus(vital.vital_id)
		if not is_zero_approx(add) and vital.has_method("add_max"):
			vital.add_max(add)
	session.sync_van_health_from_vitals()


static func add_max_van_health(session: Node, amount: float) -> void:
	if is_zero_approx(amount):
		return
	session.van_max_health = maxf(session.BASE_MAX_VAN_HEALTH, session.van_max_health + amount)
	var vitals := vital_nodes(session)
	if vitals.is_empty():
		if amount > 0.0:
			session.van_health += amount
		else:
			session.van_health = minf(session.van_health, session.van_max_health)
		session.van_health_changed.emit(session.van_health, session.van_max_health)
		return
	var share := amount / float(vitals.size())
	for vital in vitals:
		if vital.has_method("add_max"):
			vital.add_max(share)
	session.sync_van_health_from_vitals()


static func damage_van(session: Node, amount: float) -> void:
	if amount <= 0.0 or session.phase == session.RunPhase.GAME_OVER:
		return
	var target := _lowest_hp_living_vital(session)
	if target and target.has_method("take_damage"):
		target.take_damage(amount)
		return
	session.van_health = maxf(0.0, session.van_health - amount)
	session.van_health_changed.emit(session.van_health, session.van_max_health)
	if is_zero_approx(session.van_health):
		session.set_phase(session.RunPhase.GAME_OVER)


static func is_van_fully_repaired(session: Node) -> bool:
	if not session.is_van_at_full_health():
		return false
	var tree := session.get_tree()
	if tree == null:
		return true
	for node in tree.get_nodes_in_group(&"breach_points"):
		if node and node.has_method(&"is_at_full_health") and not node.is_at_full_health():
			return false
	return true


static func repair_van_full(session: Node) -> bool:
	if session.phase == session.RunPhase.GAME_OVER:
		return false
	var any := false
	for vital in vital_nodes(session):
		if not vital.has_method(&"heal"):
			continue
		var cap := float(vital.max_health) if "max_health" in vital else 0.0
		if vital.heal(cap) > 0.001:
			any = true
	var tree := session.get_tree()
	if tree:
		for node in tree.get_nodes_in_group(&"breach_points"):
			if node == null or not node.has_method(&"repair"):
				continue
			var cap := float(node.max_health) if "max_health" in node else 0.0
			if node.repair(cap) > 0.001:
				any = true
	return any


static func _bind_max_for_vital(session: Node, vital: Node) -> float:
	var key := String(vital.vital_id)
	if session.pending_vital_max.has(key):
		return maxf(0.1, float(session.pending_vital_max[key]))
	var base: float = session.BASE_MAX_VAN_HEALTH / float(session.VITAL_COUNT)
	var bonus := 0.0
	if "vital_id" in vital:
		bonus = MetaProgression.get_allocated_vital_max_bonus(vital.vital_id)
	return maxf(0.1, base + bonus)


static func apply_pending_to_tree(session: Node) -> void:
	var vitals := vital_nodes(session)
	if vitals.is_empty():
		return
	for vital in vitals:
		var key := String(vital.vital_id)
		var share_max := _bind_max_for_vital(session, vital)
		var share_cur := share_max
		if session.pending_vital_health.has(key):
			share_cur = float(session.pending_vital_health[key])
		if vital.has_method("apply_saved"):
			vital.apply_saved(share_cur, share_max)
	session.sync_van_health_from_vitals()


static func reset_vitals_in_tree(session: Node) -> void:
	session.pending_vital_health = {}
	session.pending_vital_max = {}
	var vitals := vital_nodes(session)
	if vitals.is_empty():
		return
	for vital in vitals:
		var share := _bind_max_for_vital(session, vital)
		if vital.has_method("apply_saved"):
			vital.apply_saved(share, share)
	session.sync_van_health_from_vitals()


static func vital_nodes(session: Node) -> Array:
	var tree := session.get_tree()
	if tree == null:
		return []
	var result: Array = []
	for node in tree.get_nodes_in_group(&"van_vitals"):
		if node and "health" in node and "max_health" in node:
			result.append(node)
	return result


static func _lowest_hp_living_vital(session: Node) -> Node:
	var best: Node = null
	var best_hp := INF
	for vital in vital_nodes(session):
		if float(vital.health) <= 0.001:
			continue
		if float(vital.health) < best_hp:
			best_hp = float(vital.health)
			best = vital
	return best
