class_name EnemyAI
extends Node
## IA dos inimigos. Regra de movimento: valor fixo por turno (goblin 4,
## arqueiro 3, boss 3) â€” nunca rola dados nem recebe modificadores.
## Comportamento: manter a guarda atÃ© detectar o herÃ³i (visÃ£o + linha de
## visÃ£o); apÃ³s o alerta, avanÃ§ar todo turno e atacar ao alcanÃ§Ã¡-lo.

func run_turn(u) -> void:
	if not u.alerted:
		var h0 = _hero(u.grid_pos)
		if h0 != null and _can_see(u, h0):
			u.alerted = true
			u.spawn_float_text("!", "#ffd166")
			EventBus.log_msg.emit("%s avistou %s!" % [u.display_name, h0.display_name], "#ffb84d")
			await get_tree().create_timer(0.35).timeout
		else:
			EventBus.log_msg.emit("%s mantÃ©m a guarda." % u.display_name, "#5f6472")
			return
	match u.id:
		"goblin_warrior":
			await _melee(u)
		"goblin_archer":
			await _archer(u)
		"boss_knight":
			await _boss(u)

## HerÃ³i vivo mais proximo de `from` (o grupo pode ter varios membros).
func _hero(from: Vector2i = Vector2i(-999, -999)):
	var best = null
	var best_d := 9999
	for x in TurnManager.order:
		if is_instance_valid(x) and x.alive and x.team == "hero":
			if best == null:
				best = x
				best_d = 9999 if from == Vector2i(-999, -999) \
					else BoardGrid.chebyshev(from, x.grid_pos)
			else:
				var d := BoardGrid.chebyshev(from, x.grid_pos)
				if d < best_d:
					best = x
					best_d = d
	return best

func _can_see(u, target) -> bool:
	var d: int = BoardGrid.chebyshev(u.grid_pos, target.grid_pos)
	if d > u.vision_range:
		return false
	return BoardGrid.has_line_of_sight(u.grid_pos, target.grid_pos)

## Movimento fixo em direÃ§Ã£o ao alvo: dentro das cÃ©lulas alcanÃ§Ã¡veis neste
## turno, escolhe a que deixa o inimigo mais perto do herÃ³i (empate: menos
## passos). Garante progresso mesmo com caminhos bloqueados por aliados.
func _step_toward(u, goal: Vector2i, stop_at_range := 1) -> void:
	if u.moves_left <= 0:
		return
	var cur_d: int = BoardGrid.chebyshev(u.grid_pos, goal)
	if cur_d <= stop_at_range:
		return
	var reach: Dictionary = BoardGrid.compute_reachable(u.grid_pos, u.moves_left)
	var best: Vector2i = u.grid_pos
	var best_d := cur_d
	var best_cost := 9999
	for c in reach["dist"].keys():
		var cd: int = BoardGrid.chebyshev(c, goal)
		var cost: int = reach["dist"][c]
		if cd < best_d or (cd == best_d and cost < best_cost):
			best_d = cd
			best_cost = cost
			best = c
	if best == u.grid_pos:
		return
	var path: Array = BoardGrid.path_from_reachable(reach, best)
	BoardGrid.move_unit(u, best)
	u.moves_left -= path.size()
	EventBus.log_msg.emit("%s avanÃ§a %d casa(s)." % [u.display_name, path.size()], "#8a8f9c")
	EventBus.unit_moved.emit(u)
	await u.animate_move(path)

## Melhor casa de tiro: dentro do alcance com linha de visÃ£o; senÃ£o,
## aproxima-se o mÃ¡ximo possÃ­vel.
func _best_shooting_cell(u, goal: Vector2i) -> Vector2i:
	var reach: Dictionary = BoardGrid.compute_reachable(u.grid_pos, u.moves_left)
	var best_fire: Vector2i = u.grid_pos
	var best_fire_d := 9999
	var best_any: Vector2i = u.grid_pos
	var best_any_d: int = BoardGrid.chebyshev(u.grid_pos, goal)
	var best_any_cost := 9999
	for c in reach["dist"].keys():
		var cd: int = BoardGrid.chebyshev(c, goal)
		var cost: int = reach["dist"][c]
		if cd <= u.attack_range and cd < best_fire_d and BoardGrid.has_line_of_sight(c, goal):
			best_fire_d = cd
			best_fire = c
		if cd < best_any_d or (cd == best_any_d and cost < best_any_cost):
			best_any_d = cd
			best_any_cost = cost
			best_any = c
	return best_fire if best_fire != u.grid_pos else best_any

func _melee(u) -> void:
	var h = _hero(u.grid_pos)
	if h == null:
		return
	await get_tree().create_timer(0.35).timeout
	await _step_toward(u, h.grid_pos, 1)
	if h.alive and BoardGrid.chebyshev(u.grid_pos, h.grid_pos) <= u.attack_range:
		await get_tree().create_timer(0.3).timeout
		await CombatSystem.attack(u, h)

func _archer(u) -> void:
	var h = _hero(u.grid_pos)
	if h == null:
		return
	await get_tree().create_timer(0.35).timeout
	var d: int = BoardGrid.chebyshev(u.grid_pos, h.grid_pos)
	var has_shot: bool = d <= u.attack_range and BoardGrid.has_line_of_sight(u.grid_pos, h.grid_pos)
	if not has_shot:
		var target: Vector2i = _best_shooting_cell(u, h.grid_pos)
		if target != u.grid_pos:
			var reach: Dictionary = BoardGrid.compute_reachable(u.grid_pos, u.moves_left)
			var path: Array = BoardGrid.path_from_reachable(reach, target)
			BoardGrid.move_unit(u, target)
			u.moves_left -= path.size()
			EventBus.log_msg.emit("%s reposiciona-se (%d casa(s))." % [u.display_name, path.size()], "#8a8f9c")
			EventBus.unit_moved.emit(u)
			await u.animate_move(path)
	d = BoardGrid.chebyshev(u.grid_pos, h.grid_pos)
	if h.alive and d <= u.attack_range and BoardGrid.has_line_of_sight(u.grid_pos, h.grid_pos):
		await get_tree().create_timer(0.3).timeout
		await CombatSystem.attack(u, h)

func _boss(u) -> void:
	var h = _hero(u.grid_pos)
	if h == null:
		return
	await get_tree().create_timer(0.45).timeout
	await _step_toward(u, h.grid_pos, 1)
	if not h.alive or BoardGrid.chebyshev(u.grid_pos, h.grid_pos) > u.attack_range:
		return
	await get_tree().create_timer(0.3).timeout
	var r := randf()
	if u.hp < u.max_hp / 2 and r < 0.15:
		EventBus.combat_message.emit("Escudo Sombrio!")
		CombatSystem.defend(u)
	elif r < 0.3:
		await CombatSystem.attack(u, h, "Golpe Pesado", "1d12+6")
	elif r < 0.45:
		await CombatSystem.attack(u, h, "LÃ¢mina Sombria", "2d8+4")
	else:
		await CombatSystem.attack(u, h)
