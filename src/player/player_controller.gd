class_name PlayerController
extends Node3D
## Controla a peça do jogador: seleção, destaque de casas (azul = mover,
## vermelho = alvo, amarelo = interação), movimento por clique e ações.

enum Mode { NONE, MOVE_READY, TARGET_ATTACK, TARGET_SKILL }

var knight: BoardUnit
var board: EnvironmentManager
var hud

var mode: int = Mode.NONE
var acted := false
var busy := false
var reach: Dictionary = {}
var _hl_pool: Array[MeshInstance3D] = []
var _tg_pool: Array[MeshInstance3D] = []
var _it_pool: Array[MeshInstance3D] = []
var _cv_pool: Array[MeshInstance3D] = []
var _hover_quad: MeshInstance3D
var _sel_ring: MeshInstance3D
var _demo := false
var _rmb_down := false
var _rmb_moved := false
var _rmb_start := Vector2.ZERO
var _lmb_down := false
var _lmb_moved := false
var _lmb_start := Vector2.ZERO

func init(knight_unit: BoardUnit, board_ref: EnvironmentManager, hud_ref) -> void:
	knight = knight_unit
	board = board_ref
	hud = hud_ref
	_demo = OS.get_cmdline_user_args().has("--demo")
	_build_overlays()

func _build_overlays() -> void:
	_hover_quad = _make_quad("3fd0ff", 0.16)
	_hover_quad.visible = false
	add_child(_hover_quad)
	_sel_ring = MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.36
	t.outer_radius = 0.5
	_sel_ring.mesh = t
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.html("37e0ff")
	m.emission_enabled = true
	m.emission = Color.html("37e0ff")
	m.emission_energy_multiplier = 1.6
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_sel_ring.material_override = m
	_sel_ring.visible = false
	add_child(_sel_ring)
	_sel_ring.position.y = 0.14

func _make_quad(hex: String, alpha: float, quad_size := 1.7) -> MeshInstance3D:
	var pm := PlaneMesh.new()
	pm.size = Vector2(quad_size, quad_size)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.html(hex)
	m.albedo_color.a = alpha
	m.emission_enabled = true
	m.emission = Color.html(hex)
	m.emission_energy_multiplier = 0.5
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = m
	return mi

func _pool_show(pool: Array[MeshInstance3D], cells: Array, hex: String, alpha := 0.34, qsize := 1.7, yoff := 0.09) -> void:
	while pool.size() < cells.size():
		var q := _make_quad(hex, alpha, qsize)
		pool.append(q)
		add_child(q)
	for i in pool.size():
		if i < cells.size():
			pool[i].position = BoardGrid.world_pos(cells[i]) + Vector3(0, yoff, 0)
			pool[i].visible = true
		else:
			pool[i].visible = false

func _hide_all() -> void:
	for p in [_hl_pool, _tg_pool, _it_pool, _cv_pool]:
		for q in p:
			q.visible = false
	_hover_quad.visible = false

func on_turn_start(u: BoardUnit) -> void:
	knight = u
	# Druida transformada retoma a forma humana no inicio do proprio turno.
	if u.shifted:
		u.revert_visual()
		EventBus.log_msg.emit("%s retoma a forma humanoide." % u.display_name, "#9dff6b")
	mode = Mode.MOVE_READY
	acted = false
	busy = false
	_sel_ring.visible = true
	_sel_ring.position = knight.position + Vector3(0, 0.14, 0)
	_compute_reachable()
	hud.update_vitals(knight)
	hud.set_skill_label(knight.id)
	hud.refresh_buttons(self)
	if _demo:
		_demo_play.call_deferred()

## Bot de demonstração/validação (rodar com ++ --demo).
func _demo_play() -> void:
	await get_tree().create_timer(0.4).timeout
	if TurnManager.game_ended or mode == Mode.NONE or TurnManager.active != knight:
		return
	if not board.chest_looted and board.chest_cell.z == knight.grid_pos.z \
			and BoardGrid.chebyshev(knight.grid_pos, board.chest_cell) <= 1:
		await _loot_chest()
		return
	var targets := _enemies_in_range()
	if not targets.is_empty():
		targets.sort_custom(func(a, b): return a.hp < b.hp)
		await _execute_attack(targets[0])
		return
	var enemies: Array = []
	for c in BoardGrid.occupied.keys():
		var e = BoardGrid.occupied[c]
		if is_instance_valid(e) and e.alive and e.team == "enemy":
			enemies.append(e)
	if enemies.is_empty():
		do_pass()
		return
	# Rota real considerando escadas como passo único: alvo mais próximo
	# por distância de rota (não "linha reta" entre andares).
	enemies.sort_custom(func(a, b):
		var da: int = BoardGrid.chebyshev(knight.grid_pos, a.grid_pos) \
				+ abs(knight.grid_pos.z - a.grid_pos.z) * 4
		var db: int = BoardGrid.chebyshev(knight.grid_pos, b.grid_pos) \
				+ abs(knight.grid_pos.z - b.grid_pos.z) * 4
		return da < db)
	var goal: Vector3i = enemies[0].grid_pos
	var gdist: Dictionary = BoardGrid.dist_to_goal(goal)
	var inter = null
	if gdist.get(knight.grid_pos, 999) >= 999:
		# Sem rota até o inimigo: procurar porta/alavanca que abra o caminho.
		var glob := BoardGrid.compute_reachable(knight.grid_pos, 99, true)
		var bi = null
		var bd := 9999
		for it in board.doors:
			if it.state == DungeonDoor.State.OPEN:
				continue
			var nd := 9999
			for off in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
					Vector3i(0, 1, 0), Vector3i(0, -1, 0)]:
				nd = mini(nd, glob["dist"].get(it.cell + off, 999))
			if nd < bd:
				bd = nd
				bi = it
		if bi != null and bd < 999:
			inter = bi
			goal = bi.cell
			gdist = BoardGrid.compute_reachable(goal, 99, true)["dist"]
	if _demo:
		print("[BOT] ", knight.id, " pos=", knight.grid_pos, " ml=", knight.moves_left,
			" reach=", reach["dist"].size(), " goal=", goal,
			" rota=", gdist.get(knight.grid_pos, 999))
	if reach["dist"].size() > 1:
		var best := knight.grid_pos
		var best_d := 9999
		for c in reach["dist"].keys():
			if c == knight.grid_pos:
				continue
			var d: int = gdist.get(c, 999)
			if d < best_d:
				best_d = d
				best = c
		if _demo:
			print("[BOT] best=", best, " d=", best_d)
		if best != knight.grid_pos:
			await _do_move(best)
			if inter != null:
				await _demo_interact(inter)
				return
			await get_tree().create_timer(0.25).timeout
			var t2 := _enemies_in_range()
			if not t2.is_empty():
				t2.sort_custom(func(a, b): return a.hp < b.hp)
				await _execute_attack(t2[0])
				return
		elif inter != null and knight.grid_pos.z == inter.cell.z \
				and BoardGrid.chebyshev(knight.grid_pos, inter.cell) <= 1:
			await _demo_interact(inter)
			return
	do_pass()

func _demo_interact(it) -> void:
	if it is DungeonDoor:
		it.try_toggle()
	else:
		board.pull_lever(it.cell)
	EventBus.log_msg.emit("%s aciona o mecanismo." % knight.display_name, "#c9a227")
	await get_tree().create_timer(0.4).timeout
	do_pass()

func on_turn_end() -> void:
	mode = Mode.NONE
	busy = false
	_sel_ring.visible = false
	_hide_all()

## Células "protegidas": nenhum inimigo em alerta tem linha de visão.
func _compute_cover() -> void:
	var foes: Array = []
	for c in BoardGrid.occupied.keys():
		var e = BoardGrid.occupied[c]
		if is_instance_valid(e) and e.alive and e.team == "enemy" and e.alerted:
			foes.append(c)
	var safe: Array = []
	for c in reach["dist"].keys():
		if not BoardGrid.is_free(c):
			continue
		var seen := false
		for fc in foes:
			if BoardGrid.has_line_of_sight(c, fc):
				seen = true
				break
		if not seen:
			safe.append(c)
	_pool_show(_cv_pool, safe, "8a8f9c", 0.22, 1.0, 0.075)

func _compute_reachable() -> void:
	reach = BoardGrid.compute_reachable(knight.grid_pos, knight.moves_left)
	var cells: Array = reach["dist"].keys()
	cells.erase(knight.grid_pos)
	_pool_show(_hl_pool, cells, "37e0ff", 0.20)
	_compute_cover()
	var it_cells: Array = []
	if not board.chest_looted and board.chest_cell.z == knight.grid_pos.z \
			and BoardGrid.chebyshev(knight.grid_pos, board.chest_cell) <= 1:
		it_cells.append(board.chest_cell)
	_pool_show(_it_pool, it_cells, "ffd166")

# ------------------------------------------------------------------ input --

func _unhandled_input(event: InputEvent) -> void:
	# Editor de mapa aberto: o mouse pertence ao editor, nao ao jogo.
	if MapEditor.active:
		return
	# Botões do mouse vs. câmera: arrastar gira/move (tratado pelo CameraRig);
	# clicar sem arrastar age no jogo. Limiar de 6 px separa os dois gestos.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		var rmb_was := _rmb_down
		_rmb_down = event.pressed
		if event.pressed:
			_rmb_moved = false
			_rmb_start = event.position
		elif rmb_was and not _rmb_moved:
			_try_cancel()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var lmb_was := _lmb_down
		_lmb_down = event.pressed
		if event.pressed:
			_lmb_moved = false
			_lmb_start = event.position
		elif lmb_was and not _lmb_moved and _can_act():
			_handle_click(event.position)
		return
	if event is InputEventMouseMotion and (_rmb_down or _lmb_down):
		if _rmb_down and event.position.distance_to(_rmb_start) > 6.0:
			_rmb_moved = true
		if _lmb_down and event.position.distance_to(_lmb_start) > 6.0:
			_lmb_moved = true
		if _lmb_down and _lmb_moved:
			return
	if TurnManager.active != knight or TurnManager.game_ended:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: try_attack()
			KEY_2: try_skill()
			KEY_3: do_defend()
			KEY_4: hud.toggle_inventory(self)
			KEY_5: do_pass()
			KEY_6: do_disengage()
			KEY_ESCAPE: _try_cancel()
		return
	if mode == Mode.NONE or busy:
		return
	if event is InputEventMouseMotion:
		_update_hover(event.position)

func _can_act() -> bool:
	return TurnManager.active == knight and not TurnManager.game_ended \
		and not busy and mode != Mode.NONE

func _try_cancel() -> void:
	if TurnManager.active == knight and not TurnManager.game_ended and not busy and mode != Mode.MOVE_READY:
		_cancel_targeting()

func _mouse_cell(screen_pos: Vector2):
	# Raio contra o plano de CADA andar. Prioridade: casas no andar do herói
	# ativo (andares empilhados se sobrepõem na tela); senão, a interseção
	# mais próxima cuja casa exista (permite clicar em escadas/outros pisos).
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return null
	var origin := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.0005:
		return null
	var hero_floor: int = knight.grid_pos.z if knight != null \
			and is_instance_valid(knight) else 0
	for pass_floor in [hero_floor, -1]:
		var best = null
		var best_t := INF
		for f in maxi(1, board.floors_n):
			if pass_floor >= 0 and f != pass_floor:
				continue
			var plane_y: float = f * BoardGrid.FLOOR_H + 0.12
			var t := (plane_y - origin.y) / dir.y
			if t <= 0.01 or t >= best_t:
				continue
			var p := origin + dir * t
			var c := BoardGrid.world_to_cell(p, f)
			if BoardGrid.tiles.has(c):
				best = c
				best_t = t
		if best != null:
			return best
	return null

func _update_hover(screen_pos: Vector2) -> void:
	var c = _mouse_cell(screen_pos)
	if c == null or not BoardGrid.is_walkable(c):
		_hover_quad.visible = false
		return
	# Em mira, o cavaleiro já encara o inimigo sob o cursor (pré-ataque).
	if mode == Mode.TARGET_ATTACK or mode == Mode.TARGET_SKILL:
		var u = BoardGrid.unit_at(c)
		if u != null and u.team == "enemy":
			knight.face_towards(u.global_position)
	_hover_quad.position = BoardGrid.world_pos(c) + Vector3(0, 0.08, 0)
	_hover_quad.visible = true

func _cancel_targeting() -> void:
	mode = Mode.MOVE_READY
	_hide_all()
	_compute_reachable()
	EventBus.log_msg.emit("Ação cancelada.", "#8a8f9c")

func _handle_click(screen_pos: Vector2) -> void:
	var c = _mouse_cell(screen_pos)
	if c == null:
		return
	var unit_here = BoardGrid.unit_at(c)
	if mode == Mode.TARGET_ATTACK or mode == Mode.TARGET_SKILL:
		if unit_here != null and unit_here.team == "enemy":
			var in_range: bool = BoardGrid.chebyshev(knight.grid_pos, c) <= knight.attack_range \
					and BoardGrid.has_line_of_sight(knight.grid_pos, c)
			if in_range:
				if mode == Mode.TARGET_ATTACK:
					_execute_attack(unit_here)
				else:
					_execute_skill(unit_here)
			else:
				EventBus.log_msg.emit("Sem linha de visão ou fora do alcance.", "#ffb84d")
		else:
			EventBus.log_msg.emit("Selecione um inimigo (casa vermelha).", "#8a8f9c")
		return
	# Modo MOVE_READY
	# Portas e alavancas: interação adjacente.
	var inter = board.interactive_at(c)
	if inter != null:
		if c.z != knight.grid_pos.z or BoardGrid.chebyshev(knight.grid_pos, c) > 1:
			EventBus.log_msg.emit("Precisa estar ao lado para interagir.", "#ffb84d")
			return
		if inter is DungeonDoor:
			var msg: String = inter.try_toggle()
			if msg != "":
				EventBus.log_msg.emit("Trancada. Procure um mecanismo ou chave.", "#ffb84d")
			else:
				EventBus.shake_requested.emit(0.06)
				_compute_reachable()
		else:
			board.pull_lever(c)
			_compute_reachable()
		return
	if unit_here != null and unit_here.team == "enemy":
		if c.z == knight.grid_pos.z \
				and BoardGrid.chebyshev(knight.grid_pos, c) <= knight.attack_range \
				and BoardGrid.has_line_of_sight(knight.grid_pos, c):
			_execute_attack(unit_here)
		else:
			EventBus.log_msg.emit("Inimigo sem linha de visão ou longe demais.", "#ffb84d")
		return
	if c == board.chest_cell and not board.chest_looted:
		if c.z == knight.grid_pos.z and BoardGrid.chebyshev(knight.grid_pos, c) <= 1:
			_loot_chest()
		else:
			EventBus.log_msg.emit("O baú está longe. Aproxime-se dele.", "#ffb84d")
		return
	# Escada: clicar de novo na célula ONDE ESTÁ = atravessar (custa 1 MP).
	if c == knight.grid_pos and BoardGrid.stair_links.has(c):
		var res2 := knight.try_cross_stairs()
		if res2 == 0:
			hud.update_vitals(knight)
			_compute_reachable()
		elif res2 == 1:
			EventBus.log_msg.emit("Sem movimento para usar a escada.", "#ffb84d")
		else:
			EventBus.log_msg.emit(_stair_block_msg(c), "#ffb84d")
		return
	if reach["dist"].has(c):
		_do_move(c)
	elif BoardGrid.is_walkable(c):
		EventBus.log_msg.emit("Casa fora do seu movimento (%d restantes)." % knight.moves_left, "#ffb84d")

# ------------------------------------------------------------------ ações --

func _do_move(cell: Vector3i) -> void:
	busy = true
	_hide_all()
	var from_cell: Vector3i = knight.grid_pos
	var path: Array = BoardGrid.path_from_reachable(reach, cell)
	var dist: int = path.size()
	BoardGrid.move_unit(knight, cell)
	knight.moves_left -= dist
	await knight.animate_move(path, from_cell)
	# Clicou NA casa da escada: atravessa automaticamente e desembarca no
	# primeiro grid livre à frente do outro andar. Quem chegou PELO salto
	# pareado (destino já era o outro andar) não re-cruza.
	var prev_step: Vector3i = from_cell if path.size() == 1 \
			else path[path.size() - 2]
	var by_hop := BoardGrid.stair_pair(prev_step) == cell
	if not by_hop and BoardGrid.stair_links.has(cell):
		var res := knight.try_cross_stairs()
		if res == 1:
			EventBus.log_msg.emit("Sem movimento para usar a escada.", "#ffb84d")
		elif res == 2:
			EventBus.log_msg.emit(_stair_block_msg(cell), "#ffb84d")
	_sel_ring.position = knight.position + Vector3(0, 0.14, 0)
	hud.update_vitals(knight)
	busy = false
	if knight.moves_left > 0 and not acted:
		_compute_reachable()
	else:
		_hide_all()

## Mensagem de escada bloqueada, indicando o andar de destino.
func _stair_block_msg(cell: Vector3i) -> String:
	var pair: Vector3i = BoardGrid.stair_pair(cell)
	var onde := "acima" if pair.z > cell.z else "abaixo"
	return "Saída da escada bloqueada %s." % onde

func try_attack() -> void:
	if mode == Mode.NONE or busy or acted:
		return
	var targets := _enemies_in_range()
	if targets.is_empty():
		EventBus.log_msg.emit("Nenhum inimigo visível ao alcance.", "#ffb84d")
		return
	mode = Mode.TARGET_ATTACK
	var cells: Array = []
	for t in targets:
		cells.append(t.grid_pos)
	_pool_show(_tg_pool, cells, "ff4d4d")
	for q in _hl_pool:
		q.visible = false
	for q in _it_pool:
		q.visible = false
	EventBus.log_msg.emit("Escolha o alvo do ataque...", "#ffd166")

func try_skill() -> void:
	if mode == Mode.NONE or busy or acted:
		return
	var sk := UnitDefs.skill(knight.id)
	if sk.is_empty():
		return
	if knight.mana < sk["cost"]:
		EventBus.log_msg.emit("Mana insuficiente para %s." % sk["label"], "#ffb84d")
		return
	var targets := _enemies_in_range()
	if targets.is_empty():
		EventBus.log_msg.emit("Nenhum inimigo visível para a habilidade.", "#ffb84d")
		return
	mode = Mode.TARGET_SKILL
	var cells: Array = []
	for t in targets:
		cells.append(t.grid_pos)
	_pool_show(_tg_pool, cells, "ff4d4d")
	EventBus.log_msg.emit("%s preparado — escolha o alvo." % sk["label"], "#ffd166")

func _enemies_in_range() -> Array:
	var out: Array = []
	for c in BoardGrid.occupied.keys():
		var u = BoardGrid.occupied[c]
		if is_instance_valid(u) and u.alive and u.team == "enemy":
			if BoardGrid.chebyshev(knight.grid_pos, c) <= knight.attack_range \
					and BoardGrid.has_line_of_sight(knight.grid_pos, c):
				out.append(u)
	return out

func _execute_attack(target: BoardUnit) -> void:
	acted = true
	busy = true
	mode = Mode.NONE
	_hide_all()
	hud.refresh_buttons(self)
	await CombatSystem.attack(knight, target)
	busy = false
	TurnManager.end_hero_turn()

func _execute_skill(target: BoardUnit) -> void:
	acted = true
	busy = true
	mode = Mode.NONE
	_hide_all()
	var sk := UnitDefs.skill(knight.id)
	knight.mana -= sk["cost"]
	hud.update_vitals(knight)
	hud.refresh_buttons(self)
	await CombatSystem.attack(knight, target, sk["label"], sk["dmg"],
		sk.get("fx", ""), sk.get("transform", ""))
	busy = false
	TurnManager.end_hero_turn()

func do_defend() -> void:
	if mode == Mode.NONE or busy or acted:
		return
	acted = true
	CombatSystem.defend(knight)
	hud.update_vitals(knight)
	TurnManager.end_hero_turn()

## Dispersar: consome a ação; até o início do próximo turno o herói não
## provoca ataques de oportunidade ao se afastar de inimigos.
func do_disengage() -> void:
	if mode == Mode.NONE or busy or acted:
		return
	acted = true
	knight.disengaging = true
	EventBus.log_msg.emit("%s se dispersa com cautela (sem ataques de oportunidade)." % knight.display_name, "#9dff6b")
	hud.update_vitals(knight)
	TurnManager.end_hero_turn()

func use_item_potion() -> bool:
	if not can_use_item():
		return false
	if InventorySystem.use_potion(knight):
		acted = true
		hud.update_vitals(knight)
		TurnManager.end_hero_turn()
		return true
	return false

func can_use_item() -> bool:
	return TurnManager.active == knight and not busy and not acted and mode != Mode.NONE

func do_pass() -> void:
	if mode == Mode.NONE or busy:
		return
	acted = true
	EventBus.log_msg.emit("%s passa a vez." % knight.display_name, "#8a8f9c")
	TurnManager.end_hero_turn()

func _loot_chest() -> void:
	busy = true
	board.loot_chest()
	InventorySystem.add_potions(2)
	knight.spawn_float_text("+2 Poções!", "#ffd166")
	EventBus.log_msg.emit("Baú aberto! Você encontra 2 Poções de Vida.", "#ffd166")
	EventBus.shake_requested.emit(0.15)
	acted = true
	_hide_all()
	await get_tree().create_timer(0.4).timeout
	busy = false
	TurnManager.end_hero_turn()
