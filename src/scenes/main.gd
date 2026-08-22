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
	camera_rig.position = Vector3(BoardGrid.TILE * 6.0, 0, BoardGrid.TILE * 5.0)
	camera_rig.setup(Rect2(-BoardGrid.TILE, -BoardGrid.TILE,
		BoardGrid.TILE * 16.0, BoardGrid.TILE * 14.0))
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
	ctl.init(knight, env, hud)
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
