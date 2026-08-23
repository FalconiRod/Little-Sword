extends Node3D
## Orquestrador principal: carrega o mapa do Dungeon Kit, spawna o grupo,
## liga câmera, HUD, IA e dispara o gerenciador de turnos.

const UnitScene := preload("res://src/units/unit_base.gd")

var env: EnvironmentManager
var camera_rig: TacticalCamera
var hud: GameHUD
var ctl: PlayerController
var ai: EnemyAI
var units: Array = []
var knight: BoardUnit
var boss: BoardUnit
var _boss_bar_shown := false

func _ready() -> void:
	randomize()
	var args := OS.get_cmdline_user_args()
	if args.has("--demo"):
		Engine.time_scale = 3.0
	var map_id := "stone_keep"
	for a in args:
		if a.begins_with("--map="):
			map_id = a.substr(6)
	env = EnvironmentManager.new()
	env.name = "Environment"
	add_child(env)
	if not env.load_map(map_id):
		push_error("Mapa nao encontrado: " + map_id)
		env.load_map("stone_keep")
	MapEditor.begin_session(env)
	_spawn_units()
	_build_camera()
	_build_ui()
	_wire_systems()
	await get_tree().process_frame
	await get_tree().process_frame
	TurnManager.start_game()
	if args.has("--clicktest"):
		_clicktest()
	if args.has("--skilltest"):
		_skilltest()
	if args.has("--editortest"):
		_editortest()
	if args.has("--stairtest"):
		_stairtest()
	if args.has("--combattest"):
		_combattest()

# ------------------------------------------------------------------ testes --

## Teste automatizado: injeta um clique sintético numa casa alcançável
## e verifica se o herói anda (valida cadeia input -> raycast -> movimento).
func _clicktest() -> void:
	await get_tree().create_timer(0.5).timeout
	get_viewport().size = Vector2i(1280, 720)
	await get_tree().process_frame
	var target: Vector3i = knight.grid_pos
	for off in [Vector3i(0, -1, 0), Vector3i(-1, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 1, 0)]:
		if BoardGrid.is_free(knight.grid_pos + off):
			target = knight.grid_pos + off
			break
	var cam := get_viewport().get_camera_3d()
	var wp := BoardGrid.world_pos(target) + Vector3(0, 0.1, 0)
	var sp := cam.unproject_position(wp)
	# Com stretch canvas_items, push_input espera coordenadas de JANELA;
	# o motor converte janela->viewport pelo inverso do final_transform.
	var wpos: Vector2 = get_viewport().get_final_transform() * sp
	if not cam.is_position_behind(wp):
		print("CLICKTEST cell=", target, " screen=", wpos)
		for pressed in [true, false]:
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = pressed
			ev.position = wpos
			ev.global_position = wpos
			get_viewport().push_input(ev)
			await get_tree().process_frame
	else:
		print("CLICKTEST FAIL celula atras da camera")
	await get_tree().create_timer(4.0).timeout
	print("CLICKTEST RESULT pos=", knight.grid_pos, " esperada=", target,
		" moves_left=", knight.moves_left,
		" => ", "OK" if knight.grid_pos == target else "FALHOU")

## Teste das habilidades especiais: projétil da maga e forma de urso.
func _skilltest() -> void:
	await get_tree().create_timer(1.0).timeout
	var mage: BoardUnit = null
	var druid: BoardUnit = null
	var foe: BoardUnit = null
	for u in units:
		if u.id == "mage":
			mage = u
		elif u.id == "druid":
			druid = u
		elif u.team == "enemy" and foe == null and u.alive:
			foe = u
	if mage == null or druid == null or foe == null:
		print("SKILLTEST FAIL unidades ausentes")
		return
	var hp0: int = foe.hp
	await CombatSystem.attack(mage, foe, "Míssil Ardente", "2d10+2", "projectile_red")
	print("SKILLTEST projectile dano=", hp0 - foe.hp)
	await CombatSystem.attack(druid, foe, "Fúria do Urso", "1d12+3", "", "druid_bear")
	print("SKILLTEST transform shifted=", druid.shifted)
	await get_tree().create_timer(1.2).timeout
	druid.revert_visual()
	print("SKILLTEST revert shifted=", druid.shifted)
	print("SKILLTEST RESULT OK")

## Teste da escada (StairsLink v0.6.2): usa a TORRE (par [[4,3,0],[4,3,1]]).
## Contrato: move_unit(dest=path[-1]) ANTES de animate_move.
## Regras: pisar/parar na escada NUNCA cruza; o salto pareado no meio do
## caminho cruza; em pé na célula, try_cross_stairs() cruza custando 1 MP.
func _stairtest() -> void:
	await get_tree().create_timer(0.5).timeout
	var base := Vector3i(4, 3, 0)
	var top := Vector3i(4, 3, 1)
	if not BoardGrid.stair_links.has(base):
		print("STAIRTEST FAIL par ausente")
		return
	# Isola o herói ao lado da escada.
	knight.grid_pos = Vector3i(5, 3, 0)
	BoardGrid.move_unit(knight, knight.grid_pos)
	# (1) terminar sobre a base NÃO cruza: fica em pé na escada.
	knight.moves_left = 3
	BoardGrid.move_unit(knight, base)
	await knight.animate_move([base], Vector3i(5, 3, 0))
	var ok1: bool = knight.grid_pos == base and knight.floor_index == 0 \
			and knight.moves_left == 3 \
			and is_equal_approx(knight.position.y, BoardGrid.world_pos(base).y)
	print("STAIRTEST 1 para-na-escada pos=", knight.grid_pos,
			" ml=", knight.moves_left, " => ", "OK" if ok1 else "FALHOU")
	# (2) caminho que executa o SALTO pareado cruza no meio do caminho.
	knight.moves_left = 5
	BoardGrid.move_unit(knight, top)
	await knight.animate_move([base, top], Vector3i(5, 3, 0))
	var ok2: bool = knight.grid_pos == top and knight.floor_index == 1 \
			and is_equal_approx(knight.position.y, BoardGrid.world_pos(top).y)
	print("STAIRTEST 2 salto-no-caminho pos=", knight.grid_pos,
			" => ", "OK" if ok2 else "FALHOU")
	# (3) chegou pelo salto: nenhuma cruzada extra de volta.
	var ok3: bool = knight.floor_index == 1 and knight.moves_left == 5
	print("STAIRTEST 3 sem-dupla ml=", knight.moves_left,
			" => ", "OK" if ok3 else "FALHOU")
	# (4) EM PÉ na célula com movimento: travessia desembarca À FRENTE.
	knight.moves_left = 2
	var landing = BoardGrid.stair_landing(base)
	var crossed: int = knight.try_cross_stairs()
	var ok4: bool = crossed == 0 and knight.grid_pos == landing \
			and knight.floor_index == 0 and knight.moves_left == 1 \
			and is_equal_approx(knight.position.y, BoardGrid.world_pos(landing).y)
	print("STAIRTEST 4 cross-explicito pos=", knight.grid_pos,
			" esperado=", landing, " ml=", knight.moves_left,
			" => ", "OK" if ok4 else "FALHOU")
	# (5) sem movimento a travessia é negada e nada muda.
	BoardGrid.move_unit(knight, top)
	knight.grid_pos = top
	knight.floor_index = 1
	knight.position = BoardGrid.world_pos(top)
	knight.moves_left = 0
	var denied: int = knight.try_cross_stairs()
	var ok5: bool = denied == 1 and knight.grid_pos == top \
			and knight.floor_index == 1 and knight.moves_left == 0
	print("STAIRTEST 5 negado pos=", knight.grid_pos,
			" => ", "OK" if ok5 else "FALHOU")
	# (6) 8 saídas ocupadas => desembarca EM PÉ na célula pareada (fallback).
	knight.moves_left = 3
	var fakes: Array[Vector3i] = []
	for off in [Vector3i(0, -1, 0), Vector3i(0, 1, 0), Vector3i(-1, 0, 0),
			Vector3i(1, 0, 0), Vector3i(-1, -1, 0), Vector3i(1, -1, 0),
			Vector3i(-1, 1, 0), Vector3i(1, 1, 0)]:
		var c: Vector3i = base + off
		if BoardGrid.is_free(c):
			BoardGrid.occupied[c] = knight
			fakes.append(c)
	var res6: int = knight.try_cross_stairs()
	for c3 in fakes:
		BoardGrid.clear_cell(c3)
	var ok6a: bool = res6 == 0 and knight.grid_pos == base \
			and knight.floor_index == 0 and knight.moves_left == 2 \
			and is_equal_approx(knight.position.y, BoardGrid.world_pos(base).y)
	# Janela de frames: nenhum tween órfão pode puxar o herói de volta.
	await get_tree().create_timer(0.5).timeout
	var ok6b: bool = is_equal_approx(knight.position.y,
			BoardGrid.world_pos(base).y) \
			and is_equal_approx(camera_rig.position.y,
					BoardGrid.world_pos(base).y)
	print("STAIRTEST 6 fallback-par res=", res6, " pos=", knight.grid_pos,
			" => ", "OK" if ok6a and ok6b else "FALHOU")
	# (7) par TAMBÉM ocupado => código 2, unidade espera na escada.
	BoardGrid.move_unit(knight, top)
	knight.grid_pos = top
	knight.floor_index = 1
	knight.position = BoardGrid.world_pos(top)
	knight.moves_left = 2
	var fakes2: Array[Vector3i] = []
	for off in [Vector3i(0, -1, 0), Vector3i(0, 1, 0), Vector3i(-1, 0, 0),
			Vector3i(1, 0, 0), Vector3i(-1, -1, 0), Vector3i(1, -1, 0),
			Vector3i(-1, 1, 0), Vector3i(1, 1, 0)]:
		var c4: Vector3i = base + off
		if BoardGrid.is_free(c4):
			BoardGrid.occupied[c4] = knight
			fakes2.append(c4)
	BoardGrid.occupied[base] = knight
	var res7: int = knight.try_cross_stairs()
	BoardGrid.clear_cell(base)
	for c5 in fakes2:
		BoardGrid.clear_cell(c5)
	var ok7: bool = res7 == 2 and knight.grid_pos == top \
			and knight.floor_index == 1 and knight.moves_left == 2
	print("STAIRTEST 7 total-bloqueada res=", res7,
			" => ", "OK" if ok7 else "FALHOU")
	# (8) FLUXO REAL DO JOGO: anda até a escada e cruza NO MESMO FRAME.
	# Regressão BUG-021: o tween do arco do último passo sobrescrevia o
	# change_floor e puxava o herói de volta para o andar de baixo.
	knight.grid_pos = Vector3i(5, 3, 0)
	BoardGrid.move_unit(knight, Vector3i(5, 3, 0))
	knight.floor_index = 0
	knight.position = BoardGrid.world_pos(Vector3i(5, 3, 0))
	knight.moves_left = 3
	BoardGrid.move_unit(knight, base)
	var up_landing = BoardGrid.stair_landing(top)
	await knight.animate_move([base], Vector3i(5, 3, 0))
	var res8: int = knight.try_cross_stairs()
	await get_tree().create_timer(0.5).timeout
	var ok8: bool = res8 == 0 and knight.grid_pos == up_landing \
			and knight.floor_index == 1 \
			and is_equal_approx(knight.position.y,
					BoardGrid.world_pos(up_landing).y)
	print("STAIRTEST 8 fluxo-real res=", res8, " pos=", knight.grid_pos,
			" fi=", knight.floor_index,
			" y=", snappedf(knight.position.y, 0.01),
			" => ", "OK" if ok8 else "FALHOU")
	var all_ok := ok1 and ok2 and ok3 and ok4 and ok5 \
			and ok6a and ok6b and ok7 and ok8
	print("STAIRTEST RESULT ", "OK" if all_ok else "FALHOU")

# ------------------------------------------------------------------ build --

## Teste das regras táticas de combate (v0.8.0): flanqueio, cobertura,
## ataque de oportunidade e Dispersar. Rodar com:
##   --combattest --map=tower
func _combattest() -> void:
	await get_tree().create_timer(0.5).timeout
	var goblin = null
	var ally = null
	for u in units:
		if not is_instance_valid(u) or not u.alive:
			continue
		if u.team == "enemy" and goblin == null and u.id == "goblin_warrior":
			goblin = u
		elif u.team == "hero" and u != knight and ally == null:
			ally = u
	if goblin == null or ally == null:
		print("COMBATTEST FAIL unidades ausentes")
		return
	goblin.alerted = true
	goblin.disengaging = false
	knight.disengaging = false
	var T := Vector3i(4, 2, 0)
	# (1) FLANQUEIO: sem aliado oposto = 0; com aliado no lado oposto = +2.
	_ct_pose(goblin, T)
	_ct_pose(knight, T + Vector3i(0, -1, 0))
	_ct_pose(ally, Vector3i(1, 5, 0))
	var f0: int = CombatSystem.flank_bonus(knight, goblin)
	_ct_pose(ally, T + Vector3i(0, 1, 0))
	var f2: int = CombatSystem.flank_bonus(knight, goblin)
	print("COMBATTEST 1 flanqueio sem=", f0, " com=", f2, " => ",
			"OK" if f0 == 0 and f2 == 2 else "FALHOU")
	# (2) COBERTURA: diagonal com parede no canto do alvo = +2;
	#     adjacente lateral sem obstáculo = 0.
	_ct_pose(goblin, T)
	_ct_pose(knight, Vector3i(3, 1, 0))   # diagonal NW; canto N do alvo é '#'
	var c_diag: int = CombatSystem.cover_ac(knight, goblin)
	_ct_pose(knight, T + Vector3i(1, 1, 0))  # diagonal SE; cantos livres
	var c_diag_free: int = CombatSystem.cover_ac(knight, goblin)
	print("COMBATTEST 2 cobertura canto=", c_diag, " livre=", c_diag_free,
			" => ", "OK" if c_diag == 2 and c_diag_free == 0 else "FALHOU")
	# (3) OPORTUNIDADE: sair da adjacência do goblin alertado provoca 1 golpe.
	_ct_begin_aoo()
	_ct_pose(goblin, Vector3i(5, 1, 0))
	_ct_pose(knight, Vector3i(5, 2, 0))
	await knight.animate_move([Vector3i(5, 3, 0), Vector3i(5, 4, 0)],
			Vector3i(5, 2, 0))
	var n_ao := _ct_end_aoo()
	# (4) DISPERSAR: mesmo movimento com disengaging ativo não provoca nada.
	_ct_begin_aoo()
	_ct_pose(goblin, Vector3i(5, 1, 0))
	_ct_pose(knight, Vector3i(5, 2, 0))
	knight.disengaging = true
	await knight.animate_move([Vector3i(5, 3, 0), Vector3i(5, 4, 0)],
			Vector3i(5, 2, 0))
	knight.disengaging = false
	var n_dis := _ct_end_aoo()
	print("COMBATTEST 3 oportunidade=", n_ao, " dispersar=", n_dis,
			" => ", "OK" if n_ao >= 1 and n_dis == 0 else "FALHOU")
	print("COMBATTEST RESULT ",
			"OK" if f0 == 0 and f2 == 2 and c_diag == 2 and c_diag_free == 0 \
					and n_ao >= 1 and n_dis == 0 else "FALHOU")

## Teste do editor de mapa: abre F1, clica celula vazia, coloca prop,
## fecha F1 e deixa turnos fluirem (detecta congelamento ao sair).
func _editortest() -> void:
	await get_tree().create_timer(1.0).timeout
	var vp := get_viewport()
	print("ET1 toggle ON")
	_push_key(KEY_F1)
	await get_tree().process_frame
	await get_tree().process_frame
	print("ET2 active=", MapEditor.active, " ui=", MapEditor._ui != null,
			" glbs=", MapEditor.glb_list.size())
	MapEditor.mode = "select"
	var empty := knight.grid_pos + Vector3i(0, 1, 0)
	if not BoardGrid.is_walkable(empty):
		empty = knight.grid_pos + Vector3i(1, 0, 0)
	print("ET3 clique celula VAZIA modo select ", empty)
	_click_cell(empty)
	await _et_wait(0.3)
	print("ET4 placed=", MapEditor._placed.size(),
			" selected=", MapEditor.selected_key)
	MapEditor.mode = "prop"
	MapEditor.cat_item["prop"] = CAT_PROPS_IDX_RUBBLE()
	var target := knight.grid_pos + Vector3i(1, 0, 0)
	if not BoardGrid.is_walkable(target) or target == empty:
		for off in [Vector3i(-1, 0, 0), Vector3i(0, -1, 0), Vector3i(0, 1, 0)]:
			if BoardGrid.is_walkable(knight.grid_pos + off):
				target = knight.grid_pos + off
				break
	print("ET5 colocar rubble em ", target)
	_click_cell(target)
	await _et_wait(0.3)
	MapEditor._rotate_selected(90.0)
	MapEditor._set_uniform(1.5)
	await get_tree().process_frame
	print("ET6 placed=", MapEditor._placed.size(), " em_target=",
			MapEditor._placed.has(target),
			" selected=", MapEditor.selected_key,
			" rot=", MapEditor._placed[target]["data"]["rot"],
			" s=", MapEditor._placed[target]["data"]["s"])
	print("ET7 mover unidade nativa (goblin)")
	var gu: Vector3i = env.spawns["g"][0]
	var gdest := gu
	for off in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, -1, 0),
			Vector3i(0, 1, 0)]:
		if BoardGrid.is_free(gu + off) and BoardGrid.is_walkable(gu + off):
			gdest = gu + off
			break
	MapEditor.mode = "select"
	_click_cell(gu)
	await get_tree().process_frame
	_click_cell(gdest)
	await get_tree().process_frame
	var goblin = BoardGrid.unit_at(gdest)
	print("ET7b goblin_em_destino=" + str(goblin != null) +
			" spawn_salvo=" + str(MapEditor.edits["spawns"].has("g")) +
			" celula=" + str(MapEditor.edits["spawns"].get("g", [])))
	print("ET7 salvar")
	print("ET8c trocar piso da casa alvo")
	var fcell := Vector3i(-1, -1, -1)
	for off in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1),
			Vector3i(0, 0, -1), Vector3i(0, 1, 0)]:
		var cc: Vector3i = target + off
		if BoardGrid.is_walkable(cc) and not MapEditor._placed.has(cc):
			fcell = cc
			break
	if fcell.x >= 0:
		MapEditor.mode = "floor"
		MapEditor.cat_item["floor"] = 1
		_click_cell(fcell)
		await get_tree().process_frame
		print("ET8d floor_override=", MapEditor._floor_overrides.has(fcell))
	MapEditor.mode = "select"
	MapEditor.save_edits()
	await _et_wait(0.2)
	print("ET9a duplicar selecao (carimbo)")
	MapEditor.mode = "select"
	_click_cell(target)
	await get_tree().process_frame
	MapEditor._arm_duplicate()
	var dcell := Vector3i(-1, -1, -1)
	for off in [Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(-1, 0, 0)]:
		var dc: Vector3i = target + off
		if BoardGrid.is_walkable(dc) and not MapEditor._placed.has(dc):
			dcell = dc
			break
	if dcell.x >= 0:
		_click_cell(dcell)
		await get_tree().process_frame
		print("ET9b copia_em=" + str(MapEditor._placed.has(dcell)))
		print("ET9c desfazendo...")
		MapEditor._undo_last()
		await get_tree().process_frame
		print("ET9d pos_undo_copia=" + str(MapEditor._placed.has(dcell)))
	else:
		print("ET9b sem casa livre p/ carimbo")
	MapEditor._dup_src = null
	print("ET8 toggle OFF")
	_push_key(KEY_F1)
	await get_tree().process_frame
	print("ET9 active=", MapEditor.active)
	for i in 10:
		await get_tree().create_timer(1.0).timeout
		print("ET10 vivo t=%d turnos_ok" % (i + 1))
	print("EDITORTEST RESULT OK")

func CAT_PROPS_IDX_RUBBLE() -> int:
	return MapEditor.CAT_PROPS.find("rubble")

func _push_key(keycode: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.pressed = true
	get_viewport().push_input(ev)
	var ev2 := InputEventKey.new()
	ev2.keycode = keycode
	ev2.pressed = false
	get_viewport().push_input(ev2)

func _click_cell(cell: Vector3i) -> void:
	var wp := BoardGrid.world_pos(cell) + Vector3(0, 0.15, 0)
	var cam := get_viewport().get_camera_3d()
	if cam == null or cam.is_position_behind(wp):
		print("ET: camera nao ve a celula ", cell)
		return
	var sp: Vector2 = get_viewport().get_final_transform() \
			* cam.unproject_position(wp)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = sp
		ev.global_position = sp
		get_viewport().push_input(ev)

func _et_wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

func _ct_pose(u, c: Vector3i) -> void:
	BoardGrid.move_unit(u, c)
	u.grid_pos = c
	u.position = BoardGrid.world_pos(c)

var _ct_aoo_n := 0

func _ct_begin_aoo() -> void:
	_ct_aoo_n = 0
	EventBus.dice_rolled.connect(_ct_on_dice)

func _ct_on_dice(sides: int, roll: int, total: int, label: String) -> void:
	if label.begins_with("Oportunidade"):
		_ct_aoo_n += 1

func _ct_end_aoo() -> int:
	if EventBus.dice_rolled.is_connected(_ct_on_dice):
		EventBus.dice_rolled.disconnect(_ct_on_dice)
	return _ct_aoo_n

# ------------------------------------------------------------------ build --

func _spawn_units() -> void:
	knight = _make_unit("knight", env.spawns["K"][0])
	units.append(knight)
	for pair in [["mage", "M"], ["druid", "W"]]:
		if env.spawns.has(pair[1]) and not env.spawns[pair[1]].is_empty():
			units.append(_make_unit(pair[0], env.spawns[pair[1]][0]))
	EventBus.log_msg.emit("O grupo entra em %s!" % env.map_name, "#c9a227")
	for c in env.spawns.get("g", []):
		units.append(_make_unit("goblin_warrior", c))
	if env.spawns.has("a") and not env.spawns["a"].is_empty():
		units.append(_make_unit("goblin_archer", env.spawns["a"][0]))
	boss = null
	if env.spawns.has("B") and not env.spawns["B"].is_empty():
		boss = _make_unit("boss_knight", env.spawns["B"][0])
		units.append(boss)
	# Rotacoes definidas no editor (Q/E sobre unidade selecionada).
	var rots: Dictionary = MapEditor.edits.get("unit_rot", {})
	for u in units:
		var key: String = MapEditor.UNIT_KEY.get(u.id, "")
		if key != "" and rots.has(key):
			u.rotation.y = deg_to_rad(float(rots[key]))
	InventorySystem.apply_to_unit(knight)

func _make_unit(id: String, cell: Vector3i) -> BoardUnit:
	var u: BoardUnit = UnitScene.new()
	u.name = id + "_" + str(cell.x) + "_" + str(cell.y) + "_" + str(cell.z)
	add_child(u)
	u.setup(id, cell)
	return u

func _build_camera() -> void:
	camera_rig = TacticalCamera.new()
	add_child(camera_rig)
	# Limites de pan/zoom derivados do mapa (suporta mesas 50×50/70×50).
	var b := env.map_bounds().grow(BoardGrid.TILE)
	camera_rig.position = Vector3(
		BoardGrid.world_pos(knight.grid_pos).x, 0,
		BoardGrid.world_pos(knight.grid_pos).z)
	camera_rig.setup(b)
	EventBus.shake_requested.connect(camera_rig.shake)
	camera_rig.set_follow(knight, true)
	env.set_active_floor(knight.grid_pos.z)
	_apply_floor_visibility()
	EventBus.turn_started.connect(_on_turn_started)

## A câmera SEMPRE mostra o andar da unidade em foco.
func _on_turn_started(unit, _round_num: int) -> void:
	if unit.team == "hero":
		await _go_to_unit(unit)

## Clique em retrato (estilo BG3): mesmo andar = pan suave; outro andar =
## fade curto que esconde a troca de laje, focando já sobre o novo andar.
func _go_to_unit(u) -> void:
	if u == null or not is_instance_valid(u):
		return
	var f: int = u.grid_pos.z
	if f != env.active_floor_index:
		await hud.fade_swap(func():
			env.set_active_floor(f)
			_apply_floor_visibility()
			camera_rig.snap_focus(u.global_position))
	else:
		camera_rig.focus_on(u.global_position)

func _apply_floor_visibility() -> void:
	for u in units:
		if is_instance_valid(u):
			u.visible = u.grid_pos.z == env.active_floor_index

func _build_ui() -> void:
	hud = GameHUD.new()
	add_child(hud)
	ctl = PlayerController.new()
	add_child(ctl)
	ctl.init(knight, env, hud)
	hud.bind_controller(ctl)
	var roster: Array = []
	for u in units:
		roster.append({"name": u.display_name, "unit": u})
	hud.env_ref = env
	hud.bind_units(knight, roster)
	hud.portrait_clicked.connect(_go_to_unit)
	EventBus.unit_changed_floor.connect(_on_unit_changed_floor)
	EventBus.active_floor_changed.connect(func(_f): _apply_floor_visibility())

## Travessia de escada: sincroniza andar ativo + câmera NA HORA (v0.7.0).
## Sem isso o herói ficava invisível (z != active_floor) e o andar antigo
## permanecia visível até o próximo clique/turno — causa raiz do
## "piso flutuando" e do clique extra para "completar" a ida.
func _on_unit_changed_floor(u, _f: int) -> void:
	_apply_floor_visibility()
	if u != knight:
		return
	var f: int = knight.grid_pos.z
	if f == env.active_floor_index:
		return
	await hud.fade_swap(func():
		env.set_active_floor(f)
		_apply_floor_visibility()
		camera_rig.snap_focus(knight.global_position))

func _wire_systems() -> void:
	ai = EnemyAI.new()
	add_child(ai)
	if OS.get_cmdline_user_args().has("--demo"):
		EventBus.log_msg.connect(func(t: String, _c: String): print("[LOG] ", t))
		EventBus.game_over.connect(func(v: bool): print("[FIM] vitoria=", v))
		EventBus.round_started.connect(func(n: int):
			var s := ""
			for u in units:
				if is_instance_valid(u) and u.alive:
					s += "%s@%s%s " % [u.id, u.grid_pos, "!" if u.alerted else ""]
			print("[R%d] %s" % [n, s]))
	EventBus.unit_damaged.connect(_on_unit_damaged_vitals)
	EventBus.unit_healed.connect(_on_unit_healed_vitals)
	EventBus.inventory_changed.connect(func():
		InventorySystem.apply_to_unit(knight)
		hud.update_vitals(knight))
	EventBus.turn_ended.connect(func(_u): hud.refresh_buttons(ctl))
	EventBus.unit_moved.connect(func(_u): hud.refresh_buttons(ctl))
	TurnManager.setup(units, ctl, ai)

func _on_unit_damaged_vitals(u, _amt) -> void:
	if u.team == "hero":
		hud.update_vitals(ctl.knight)
	if u == boss and not _boss_bar_shown:
		_boss_bar_shown = true
		hud.show_boss_bar(boss)

func _on_unit_healed_vitals(u, _amt) -> void:
	if u.team == "hero":
		hud.update_vitals(ctl.knight)
