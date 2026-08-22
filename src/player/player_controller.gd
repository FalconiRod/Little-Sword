class_name PlayerController
extends Node3D
## Controla a peça do jogador: seleção, destaque de casas (azul = mover,
## vermelho = alvo, amarelo = interação), movimento por clique e ações.

enum Mode { NONE, MOVE_READY, TARGET_ATTACK, TARGET_SKILL }

var knight: BoardUnit
var board: BoardBuilder
var hud

var mode: int = Mode.NONE
var acted := false
var busy := false
var reach: Dictionary = {}
var _hl_pool: Array[MeshInstance3D] = []
var _tg_pool: Array[MeshInstance3D] = []
var _it_pool: Array[MeshInstance3D] = []
var _hover_quad: MeshInstance3D
var _sel_ring: MeshInstance3D
var _boss_shown := false
var _demo := false
var _rmb_down := false
var _rmb_moved := false
var _rmb_start := Vector2.ZERO
var _lmb_down := false
var _lmb_moved := false
var _lmb_start := Vector2.ZERO

func init(knight_unit: BoardUnit, board_ref: BoardBuilder, hud_ref) -> void:
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
	knight.add_child(_sel_ring)
	_sel_ring.position.y = 0.14

func _make_quad(hex: String, alpha: float) -> MeshInstance3D:
	var pm := PlaneMesh.new()
	pm.size = Vector2(1.7, 1.7)
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

func _pool_show(pool: Array[MeshInstance3D], cells: Array, hex: String) -> void:
	while pool.size() < cells.size():
		var q := _make_quad(hex, 0.34)
		pool.append(q)
		add_child(q)
	for i in pool.size():
		if i < cells.size():
			pool[i].position = BoardGrid.world_pos(cells[i]) + Vector3(0, 0.09, 0)
			pool[i].visible = true
		else:
			pool[i].visible = false

func _hide_all() -> void:
	for p in [_hl_pool, _tg_pool, _it_pool]:
		for q in p:
			q.visible = false
	_hover_quad.visible = false

func on_turn_start(u: BoardUnit) -> void:
	mode = Mode.MOVE_READY
	acted = false
	busy = false
	_sel_ring.visible = true
	_compute_reachable()
	hud.update_vitals(knight)
	hud.refresh_buttons(self)
	if _demo:
		_demo_play.call_deferred()

## Bot de demonstração/validação (rodar com ++ --demo).
func _demo_play() -> void:
	await get_tree().create_timer(0.4).timeout
	if TurnManager.game_ended or mode == Mode.NONE or TurnManager.active != knight:
		return
	if not board.chest_looted and BoardGrid.chebyshev(knight.grid_pos, board.chest_cell) <= 1:
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
	enemies.sort_custom(func(a, b): return BoardGrid.chebyshev(knight.grid_pos, a.grid_pos) < BoardGrid.chebyshev(knight.grid_pos, b.grid_pos))
	var goal: Vector2i = enemies[0].grid_pos
	if reach["dist"].size() > 1:
		var best := knight.grid_pos
		var best_d := 9999
		for c in reach["dist"].keys():
			if c == knight.grid_pos:
				continue
			var d: int = BoardGrid.chebyshev(c, goal)
			if d < best_d:
				best_d = d
				best = c
		if best != knight.grid_pos:
			await _do_move(best)
			await get_tree().create_timer(0.25).timeout
			var t2 := _enemies_in_range()
			if not t2.is_empty():
				t2.sort_custom(func(a, b): return a.hp < b.hp)
				await _execute_attack(t2[0])
				return
	do_pass()

func on_turn_end() -> void:
	mode = Mode.NONE
	busy = false
	_sel_ring.visible = false
	_hide_all()

func _compute_reachable() -> void:
	reach = BoardGrid.compute_reachable(knight.grid_pos, knight.moves_left)
	var cells: Array = reach["dist"].keys()
	cells.erase(knight.grid_pos)
	_pool_show(_hl_pool, cells, "37e0ff")
	var it_cells: Array = []
	if not board.chest_looted and BoardGrid.chebyshev(knight.grid_pos, board.chest_cell) <= 1:
		it_cells.append(board.chest_cell)
	_pool_show(_it_pool, it_cells, "ffd166")

# ------------------------------------------------------------------ input --

func _unhandled_input(event: InputEvent) -> void:
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
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return null
	var origin := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	if dir.y >= -0.001:
		return null
	var t := -origin.y / dir.y
	var p := origin + dir * t
	return BoardGrid.cell_of(p)

func _update_hover(screen_pos: Vector2) -> void:
	var c = _mouse_cell(screen_pos)
	if c == null or not BoardGrid.is_walkable(c):
		_hover_quad.visible = false
		return
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
			var in_range: bool = BoardGrid.chebyshev(knight.grid_pos, c) <= knight.attack_range
			if in_range:
				if mode == Mode.TARGET_ATTACK:
					_execute_attack(unit_here)
				else:
					_execute_skill(unit_here)
			else:
				EventBus.log_msg.emit("Alvo fora de alcance.", "#ffb84d")
		else:
			EventBus.log_msg.emit("Selecione um inimigo (casa vermelha).", "#8a8f9c")
		return
	# Modo MOVE_READY
	if unit_here != null and unit_here.team == "enemy":
		if BoardGrid.chebyshev(knight.grid_pos, c) <= knight.attack_range:
			_execute_attack(unit_here)
		else:
			EventBus.log_msg.emit("Inimigo longe demais. Use ATACAR após se aproximar.", "#ffb84d")
		return
	if c == board.chest_cell and not board.chest_looted:
		if BoardGrid.chebyshev(knight.grid_pos, c) <= 1:
			_loot_chest()
		else:
			EventBus.log_msg.emit("O baú está longe. Aproxime-se dele.", "#ffb84d")
		return
	if reach["dist"].has(c):
		_do_move(c)
	elif BoardGrid.is_walkable(c):
		EventBus.log_msg.emit("Casa fora do seu movimento (%d restantes)." % knight.moves_left, "#ffb84d")

# ------------------------------------------------------------------ ações --

func _do_move(cell: Vector2i) -> void:
	busy = true
	_hide_all()
	var path: Array = BoardGrid.path_from_reachable(reach, cell)
	var dist: int = path.size()
	BoardGrid.move_unit(knight, cell)
	await knight.animate_move(path)
	knight.moves_left -= dist
	_check_reveal(cell)
	hud.update_vitals(knight)
	busy = false
	if knight.moves_left > 0 and not acted:
		_compute_reachable()
	else:
		_hide_all()

func _check_reveal(cell: Vector2i) -> void:
	var idx: int = board.room_index_at(cell)
	if idx < 0:
		return
	if board.is_revealed(idx):
		return
	board.reveal_room(idx)
	if board.ROOMS[idx]["name"] == "Câmara do Boss" and not _boss_shown:
		_boss_shown = true
		var boss = board.get_boss_unit()
		if boss != null and boss.alive:
			hud.show_boss_bar(boss)

func try_attack() -> void:
	if mode == Mode.NONE or busy or acted:
		return
	var targets := _enemies_in_range()
	if targets.is_empty():
		EventBus.log_msg.emit("Nenhum inimigo ao alcance da espada.", "#ffb84d")
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
	if knight.mana < UnitDefs.KNIGHT_SKILL_COST:
		EventBus.log_msg.emit("Mana insuficiente para %s." % UnitDefs.KNIGHT_SKILL_LABEL, "#ffb84d")
		return
	var targets := _enemies_in_range()
	if targets.is_empty():
		EventBus.log_msg.emit("Nenhum inimigo adjacente para a habilidade.", "#ffb84d")
		return
	mode = Mode.TARGET_SKILL
	var cells: Array = []
	for t in targets:
		cells.append(t.grid_pos)
	_pool_show(_tg_pool, cells, "ff4d4d")
	EventBus.log_msg.emit("%s preparado — escolha o alvo." % UnitDefs.KNIGHT_SKILL_LABEL, "#ffd166")

func _enemies_in_range() -> Array:
	var out: Array = []
	for c in BoardGrid.occupied.keys():
		var u = BoardGrid.occupied[c]
		if is_instance_valid(u) and u.alive and u.team == "enemy":
			if BoardGrid.chebyshev(knight.grid_pos, c) <= knight.attack_range:
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
	knight.mana -= UnitDefs.KNIGHT_SKILL_COST
	hud.update_vitals(knight)
	hud.refresh_buttons(self)
	await CombatSystem.attack(knight, target, UnitDefs.KNIGHT_SKILL_LABEL, UnitDefs.KNIGHT_SKILL_DMG)
	busy = false
	TurnManager.end_hero_turn()

func do_defend() -> void:
	if mode == Mode.NONE or busy or acted:
		return
	acted = true
	CombatSystem.defend(knight)
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
	EventBus.log_msg.emit("Cavaleiro passa a vez.", "#8a8f9c")
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
