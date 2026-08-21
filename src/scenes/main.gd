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

func _build_board() -> void:
	board = BoardBuilder.new()
	board.name = "Board"
	add_child(board)
	board.build()

func _spawn_units() -> void:
	knight = _make_unit("knight", BoardGrid.spawns["K"][0])
	units.append(knight)
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
	if unit == knight:
		camera_rig.set_follow(knight, true)

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
