class_name EnemyAI
extends Node
## IA simples dos inimigos: perseguem o herói e atacam quando possível.
## O arqueiro mantém distância; o boss alterna habilidades.

func run_turn(u) -> void:
	if not u.alerted:
		var h0 = _hero()
		if h0 != null and _can_see(u, h0):
			u.alerted = true
			u.spawn_float_text("!", "#ffd166")
			EventBus.log_msg.emit("%s te avistou!" % u.display_name, "#ffb84d")
			await get_tree().create_timer(0.35).timeout
		else:
			EventBus.log_msg.emit("%s mantém a guarda." % u.display_name, "#5f6472")
			return
	match u.id:
		"goblin_warrior":
			await _melee(u)
		"goblin_archer":
			await _archer(u)
		"boss_knight":
			await _boss(u)

func _can_see(u, target) -> bool:
	var d: int = BoardGrid.chebyshev(u.grid_pos, target.grid_pos)
	if d > u.vision_range:
		return false
	return BoardGrid.has_line_of_sight(u.grid_pos, target.grid_pos)

func _hero():
	for x in TurnManager.order:
		if is_instance_valid(x) and x.alive and x.team == "hero":
			return x
	return null

func _approach(u, goal: Vector2i) -> void:
	if BoardGrid.chebyshev(u.grid_pos, goal) <= 1 or u.moves_left <= 0:
		return
	var path: Array = BoardGrid.find_path(u.grid_pos, goal)
	if path.is_empty():
		return
	path = path.slice(0, mini(u.moves_left, path.size()))
	BoardGrid.move_unit(u, path[path.size() - 1])
	u.moves_left -= path.size()
	EventBus.log_msg.emit("%s avança." % u.display_name, "#8a8f9c")
	EventBus.unit_moved.emit(u)
	await u.animate_move(path)

func _melee(u) -> void:
	var h = _hero()
	if h == null:
		return
	await get_tree().create_timer(0.35).timeout
	await _approach(u, h.grid_pos)
	if h.alive and BoardGrid.chebyshev(u.grid_pos, h.grid_pos) <= u.attack_range:
		await get_tree().create_timer(0.3).timeout
		await CombatSystem.attack(u, h)

func _archer(u) -> void:
	var h = _hero()
	if h == null:
		return
	await get_tree().create_timer(0.35).timeout
	var d: int = BoardGrid.chebyshev(u.grid_pos, h.grid_pos)
	if d > u.attack_range:
		var path: Array = BoardGrid.find_path(u.grid_pos, h.grid_pos)
		if not path.is_empty():
			# Avança só até entrar em alcance confortável.
			var stop := path.size()
			for i in path.size():
				if BoardGrid.chebyshev(path[i], h.grid_pos) <= 4:
					stop = i + 1
					break
			stop = mini(stop, u.moves_left)
			if stop > 0:
				var step: Array = path.slice(0, stop)
				BoardGrid.move_unit(u, step[step.size() - 1])
				u.moves_left -= stop
				EventBus.log_msg.emit("%s reposiciona-se." % u.display_name, "#8a8f9c")
				EventBus.unit_moved.emit(u)
				await u.animate_move(step)
	d = BoardGrid.chebyshev(u.grid_pos, h.grid_pos)
	if h.alive and d <= u.attack_range and BoardGrid.has_line_of_sight(u.grid_pos, h.grid_pos):
		await get_tree().create_timer(0.3).timeout
		await CombatSystem.attack(u, h)

func _boss(u) -> void:
	var h = _hero()
	if h == null:
		return
	await get_tree().create_timer(0.45).timeout
	await _approach(u, h.grid_pos)
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
		await CombatSystem.attack(u, h, "Lâmina Sombria", "2d8+4")
	else:
		await CombatSystem.attack(u, h)
