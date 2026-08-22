extends Node3D
## Orquestrador principal: monta o tabuleiro, spawna as miniaturas,
## liga câmera, HUD, IA e dispara o gerenciador de turnos.

const KnightScene := preload("res://src/units/unit_base.gd")

var board: BoardBuilder
var camera_rig: TacticalCamera
var hud: GameHUD
var ctl: PlayerController
var ai: EnemyAI
var units: Array = []
var knight: BoardUnit

func _ready() -> void:
	randomize()
	var args := OS.get_cmdline_user_args()
	if args.has("--demo"):
		Engine.time_scale = 3.0
	BoardGrid.setup(BoardBuilder.MAP)
	_build_board()
	_spawn_units()
	_build_camera()
	_build_ui()
	_wire_systems()
	await get_tree().process_frame
	await get_tree().process_frame
	TurnManager.start_game()
	if OS.get_cmdline_user_args().has("--clicktest"):
		_clicktest()
	if OS.get_cmdline_user_args().has("--skilltest"):
		_skilltest()

## Teste das habilidades novas: projétil da maga e forma de urso da druida.
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
		elif u.team == "enemy" and foe == null:
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

## Teste automatizado: injeta um clique sintético numa casa alcançável
## e verifica se o herói anda (valida cadeia input -> raycast -> movimento).
func _clicktest() -> void:
	await get_tree().create_timer(0.5).timeout
	get_viewport().size = Vector2i(1280, 720)
	await get_tree().process_frame
	var target: Vector2i = knight.grid_pos
	for off in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]:
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

func _build_board() -> void:
	board = BoardBuilder.new()
	board.name = "Board"
	add_child(board)
	board.build()

func _spawn_units() -> void:
	knight = _make_unit("knight", BoardGrid.spawns["K"][0])
	units.append(knight)
	# O grupo nasce ao lado do cavaleiro (casas livres adjacentes).
	var party := {"mage": "Maga Elara entra na masmorra!", "druid": "Druida Rowan entra na masmorra!"}
	var kcell: Vector2i = knight.grid_pos
	var spots: Array = [kcell + Vector2i(-1, 0), kcell + Vector2i(0, -1),
			kcell + Vector2i(1, 0), kcell + Vector2i(0, 1)]
	var si := 0
	for id in party.keys():
		while si < spots.size() and not BoardGrid.is_free(spots[si]):
			si += 1
		if si >= spots.size():
			break
		var ally := _make_unit(id, spots[si])
		units.append(ally)
		EventBus.log_msg.emit(party[id], "#9dff6b")
		si += 1
	for c in BoardGrid.spawns.get("g", []):
		var g := _make_unit("goblin_warrior", c)
		units.append(g)
	if BoardGrid.spawns.has("a"):
		var a := _make_unit("goblin_archer", BoardGrid.spawns["a"][0])
		units.append(a)
	var boss: BoardUnit = null
	if BoardGrid.spawns.has("B"):
		boss = _make_unit("boss_knight", BoardGrid.spawns["B"][0])
		units.append(boss)
	board.boss_unit = boss
	InventorySystem.apply_to_unit(knight)

func _make_unit(id: String, cell: Vector2i) -> BoardUnit:
	var u: BoardUnit = KnightScene.new()
	u.name = id + "_" + str(cell.x) + "_" + str(cell.y)
	add_child(u)
	u.setup(id, cell)
	return u

func _build_camera() -> void:
	camera_rig = TacticalCamera.new()
	add_child(camera_rig)
	camera_rig.position = BoardGrid.world_pos(Vector2i(BoardGrid.w / 2, BoardGrid.h / 2))
	camera_rig.setup(Rect2(0, 0, BoardGrid.w * BoardGrid.TILE, BoardGrid.h * BoardGrid.TILE))
	EventBus.shake_requested.connect(camera_rig.shake)
	camera_rig.set_follow(knight, true)
	EventBus.turn_started.connect(_on_turn_started)

func _on_turn_started(unit, _round_num: int) -> void:
	if unit.team == "hero":
		camera_rig.set_follow(unit, true)

func _build_ui() -> void:
	hud = GameHUD.new()
	add_child(hud)
	ctl = PlayerController.new()
	add_child(ctl)
	ctl.init(knight, board, hud)
	hud.bind_controller(ctl)
	var roster: Array = []
	for u in units:
		roster.append({"name": u.display_name, "unit": u})
	hud.bind_units(knight, roster)

func _wire_systems() -> void:
	ai = EnemyAI.new()
	add_child(ai)
	if OS.get_cmdline_user_args().has("--demo"):
		EventBus.log_msg.connect(func(t: String, _c: String): print("[LOG] ", t))
		EventBus.game_over.connect(func(v: bool): print("[FIM] vitoria=", v))
	EventBus.unit_damaged.connect(func(u, _amt):
		if u == knight:
			hud.update_vitals(knight))
	EventBus.unit_healed.connect(func(u, _amt):
		if u == knight:
			hud.update_vitals(knight))
	EventBus.inventory_changed.connect(func():
		InventorySystem.apply_to_unit(knight)
		hud.update_vitals(knight))
	EventBus.turn_ended.connect(func(_u): hud.refresh_buttons(ctl))
	EventBus.unit_moved.connect(func(_u): hud.refresh_buttons(ctl))
	TurnManager.setup(units, ctl, ai)
