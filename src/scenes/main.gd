extends Node3D

@onready var _board: Node = $Board
@onready var _editor: Control = $CanvasLayer/MapEditor
@onready var _camera_pivot: Node3D = $CameraPivot
@onready var _camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var _label_info: Label = $CanvasLayer/InfoLabel
@onready var _movement: Node = $MovementManager
@onready var _btn_roll: Button = $CanvasLayer/BtnRoll

var _selected_unit: Node = null
var _reachable: Dictionary = {}
var _highlights: Array[Node3D] = []
var _last_roll: int = 0
var _last_steps: int = 0

var _yaw: float = -45.0
var _pitch: float = -50.0
var _dist: float = 18.0

func _get_tile() -> float:
	if has_node("/root/BoardGrid") and get_node("/root/BoardGrid").get("TILE") != null:
		return float(get_node("/root/BoardGrid").get("TILE"))
	return 2.0

func _ready() -> void:
	print("[Main] _ready board=", _board, " editor=", _editor, " pivot=", _camera_pivot)
	if _editor and _editor.has_method("bind_board") and _board:
		_editor.call("bind_board", _board)
	if _btn_roll:
		_btn_roll.pressed.connect(_on_roll_pressed)
		_btn_roll.visible = false
	_update_camera()
	if _label_info and _board:
		_label_info.text = "Little Sword REFEITO — FASE 8 | HUD ordem topo | Retratos | Ações | Log | Dados"
	print_rich("[color=cyan][Main][/color] FASE 8 pronta. TILE=", _get_tile(), " Board ", _board.get("width"), "x", _board.get("height"), " floors=", _board.get("floors_n"))
	await get_tree().create_timer(0.2).timeout
	if has_node("/root/TurnManager"):
		var tm: Node = get_node("/root/TurnManager")
		if tm.has_method("setup"):
			tm.call("setup", _board)
	_print_debug_info()
	# screenshot debug após 0.5s + re-log de camera após física
	await get_tree().create_timer(0.5).timeout
	await get_tree().physics_frame
	await get_tree().physics_frame
	_print_debug_info()
	_take_debug_screenshot()
	# em headless, testa G + movimento
	if DisplayServer.get_name() == "headless":
		print("[Main] HEADLESS test: simulando G")
		_trigger_regenerate()
		await get_tree().create_timer(0.5).timeout
		await get_tree().physics_frame
		await get_tree().physics_frame
		print("[Main] HEADLESS test G concluido")
		# teste movimento: cavaleiro (1,1) -> (1,4) se alcançável
		var bg: Node = get_node_or_null("/root/BoardGrid")
		var cav: Node = _get_unit_at_cell(Vector3i(1,1,0))
		if cav:
			print("[Main] HEADLESS movimento cavaleiro ", cav.get("grid_pos"))
			_select_unit(cav)
			await get_tree().create_timer(0.2).timeout
			_on_roll_pressed()
			await get_tree().create_timer(0.2).timeout
			var dest: Vector3i = Vector3i(1,4,0)
			var d: Dictionary = _reachable.get("dist", {}) as Dictionary
			print("[Main] HEADLESS dest ", dest, " reachable ", d.has(dest), " roll ", _last_roll, " steps ", _last_steps)
			if d.has(dest):
				var path: Array = []
				if _movement and _movement.has_method("get_movement_path"):
					path = _movement.call("get_movement_path", _reachable, dest) as Array
				print("[Main] HEADLESS path ", path)
				_move_selected_to(dest)
				var wait: float = float(path.size()) * 0.35 + 0.5
				await get_tree().create_timer(wait).timeout
				print("[Main] HEADLESS pos final ", cav.get("grid_pos"), " esperado ", dest, " ok ", cav.get("grid_pos") == dest)
		# teste editor: coloca Mureta em (3,3)
		if _editor and _editor.has_method("handle_board_click"):
			print("[Main] HEADLESS editor teste colocando Mureta em (3,3)")
			var before: int = int(_editor.get("_placed").size()) if "_placed" in _editor else -1
			var filtered: Array = _editor.get("_filtered") as Array
			var idx_mureta: int = -1
			for i: int in range(filtered.size()):
				var e: Dictionary = filtered[i] as Dictionary
				if String(e["name"]).contains("Mureta"):
					idx_mureta = i
					break
			if idx_mureta != -1:
				_editor.call("_on_result_selected", idx_mureta)
				var handled: bool = _editor.call("handle_board_click", Vector3i(3,3,0)) as bool
				await get_tree().create_timer(0.3).timeout
				var after: int = int(_editor.get("_placed").size()) if "_placed" in _editor else -1
				print("[Main] HEADLESS editor placed before ", before, " after ", after, " handled ", handled)
				var handled2: bool = _editor.call("handle_board_click", Vector3i(3,3,0)) as bool
				print("[Main] HEADLESS editor reselecao ", handled2, " selected_placed ", _editor.get("_selected_placed"))
		# teste combate: cavaleiro vs goblin adjacente
		var cav2: Node = _get_unit_at_cell(Vector3i(1,4,0))
		if cav2 == null:
			cav2 = _get_unit_at_cell(Vector3i(1,1,0))
		var gob: Node = _get_unit_at_cell(Vector3i(8,1,0))
		if gob == null:
			# procura qualquer goblin
			var units: Array = _board.call("get_units") as Array if _board.has_method("get_units") else []
			for u: Node in units:
				var d: Resource = u.get("definition") as Resource
				if int(d.get("faction")) == 1:
					gob = u
					break
		if cav2 and gob:
			var bg2: Node = get_node_or_null("/root/BoardGrid")
			# teleporta gob para adjacente (2,4) se livre
			var target_cell: Vector3i = Vector3i(2,4,0)
			if bg2 and bg2.has_method("is_walkable") and bool(bg2.call("is_walkable", target_cell)) and not bg2.call("unit_at", target_cell):
				var old: Vector3i = gob.get("grid_pos") as Vector3i
				bg2.call("clear_cell", old)
				gob.set("grid_pos", target_cell)
				gob.global_position = bg2.call("grid_to_world", target_cell) as Vector3
				bg2.call("place", gob, target_cell)
				print("[Main] HEADLESS teleport gob ", old, " -> ", target_cell)
			var combat: Node = get_node_or_null("/root/CombatSystem")
			if combat and combat.has_method("can_attack") and bool(combat.call("can_attack", cav2, gob)):
				print("[Main] HEADLESS combate cavaleiro -> goblin")
				var res: Dictionary = combat.call("attack", cav2, gob, {}) as Dictionary
				print("[Main] HEADLESS combate result hit ", res.get("hit"), " dmg ", res.get("dmg"), " hp gob ", gob.get("current_hp"))
				# testa flanqueio: coloca maga em (1,5) oposta?
				# testa cobertura: mureta em (3,3) não afeta este combate
			else:
				print("[Main] HEADLESS não pode atacar ", cav2.get("grid_pos"), " -> ", gob.get("grid_pos"))
		# testa TurnManager
		var tm: Node = get_node_or_null("/root/TurnManager")
		if tm:
			print("[Main] HEADLESS TurnManager ordem ", tm.get("order").size() if tm.get("order") != null else 0, " current ", tm.call("current_unit").get("definition").get("display_name") if tm.call("current_unit") else "null")
		get_tree().quit()

func _print_debug_info() -> void:
	if _board:
		print("[Main] board pieces=", _board.call("get_pieces").size() as int, " bounds=", _board.call("map_bounds"))
	if _camera_pivot:
		print("[Main] pivot pos=", _camera_pivot.global_position, " rot=", _camera_pivot.rotation_degrees)
	if _camera:
		print("[Main] cam global pos=", _camera.global_position, " fov=", _camera.fov)
	var bg: Node = get_node_or_null("/root/BoardGrid")
	if bg:
		print("[Main] BoardGrid stats=", bg.call("bake_stats"))

func _take_debug_screenshot() -> void:
	# Screenshot desabilitado em headless (dummy renderer sem textura)
	if DisplayServer.get_name() == "headless":
		return
	var vp: Viewport = get_viewport()
	if vp == null:
		return
	var tex: ViewportTexture = vp.get_texture() as ViewportTexture
	if tex == null:
		return
	var img: Image = tex.get_image() as Image
	if img == null or img.is_empty():
		return
	var dir: String = "D:/PROJETOS/Little Sword — Tactical Board RPG REFEITO/screenshots"
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var path: String = dir + "/debug_fase1_%d.png" % [Time.get_ticks_msec()]
	var err: int = img.save_png(path)
	print("[Main] screenshot salvo=", path, " err=", err)

var _is_regenerating: bool = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		# só orbita se não está movendo unidade e arrasto > 5px
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		if mm.relative.length() > 2.0:
			_yaw -= mm.relative.x * 0.3
			_pitch = clamp(_pitch - mm.relative.y * 0.3, -85.0, -15.0)
			_update_camera()
			return
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_dist = max(6.0, _dist - 1.0)
			_update_camera()
			return
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_dist = min(35.0, _dist + 1.0)
			_update_camera()
			return
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_handle_left_click()
			return
	elif event is InputEventKey and event.pressed and not event.echo:
		var ke: InputEventKey = event as InputEventKey
		if ke.keycode == KEY_G:
			print("[Main] G _unhandled_input")
			_trigger_regenerate()
		elif ke.keycode == KEY_T:
			print("[Main] T druida transform")
			_trigger_druida()
		elif ke.keycode == KEY_D:
			_is_defending = true
			print("[Main] Defender +4 CA até próximo turno")
			if _label_info:
				_label_info.text = "Defendendo +4 CA"
		elif ke.keycode == KEY_F:
			_is_dispersar = true
			print("[Main] Dispersar — próximo movimento sem oportunidade")
			if _label_info:
				_label_info.text = "Dispersar — sem ataque de oportunidade"
		elif ke.keycode == KEY_A:
			print("[Main] Atacar — clique em inimigo adjacente")
		elif ke.keycode == KEY_PAGEUP or ke.keycode == KEY_KP_ADD:
			_change_floor(1)
		elif ke.keycode == KEY_PAGEDOWN or ke.keycode == KEY_KP_SUBTRACT:
			_change_floor(-1)
		elif ke.keycode == KEY_R:
			print("[Main] R pressionado")
			_yaw = -45.0
			_pitch = -50.0
			_dist = 18.0
			_update_camera()
		elif ke.keycode == KEY_P:
			_take_debug_screenshot()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var ke: InputEventKey = event as InputEventKey
		if ke.keycode == KEY_G:
			print("[Main] G _input")
			_trigger_regenerate()
		elif ke.keycode == KEY_T:
			print("[Main] T _input")
			_trigger_druida()
		elif ke.keycode == KEY_PAGEUP:
			_change_floor(1)
		elif ke.keycode == KEY_PAGEDOWN:
			_change_floor(-1)

func _trigger_regenerate() -> void:
	if _is_regenerating:
		return
	if _board == null or not _board.has_method("regenerate_and_bake"):
		return
	_is_regenerating = true
	print("[Main] G TRIGGER regenerate_and_bake")
	if _label_info:
		_label_info.text = "Regenerando grid..."
	# chama async sem bloquear caller
	var callable: Callable = func() -> void:
		await _board.call("regenerate_and_bake")
		_print_debug_info()
		if _editor and _editor.has_method("_update_stats"):
			_editor.call("_update_stats")
		var tm: Node = get_node_or_null("/root/TurnManager")
		if tm and tm.has_method("setup"):
			tm.call("setup", _board)
		if _label_info and _board:
			_label_info.text = "Little Sword REFEITO — FASE 7 | TILE=%.1f | Board %dx%d | OK %s" % [_get_tile(), _board.get("width"), _board.get("height"), Time.get_time_string_from_system()]
		_is_regenerating = false
		print("[Main] regenerate concluido")
	callable.call()

func _change_floor(delta: int) -> void:
	if _board == null or not _board.has_method("set_active_floor"):
		return
	var cur: int = int(_board.get("active_floor")) if _board.get("active_floor") != null else 0
	var nxt: int = cur + delta
	_board.call("set_active_floor", nxt)
	# camera fade (exponencial já em update_camera, aqui só log)
	var bg: Node = get_node_or_null("/root/BoardGrid")
	var af: int = int(bg.get("active_floor_index")) if bg and bg.get("active_floor_index") != null else nxt
	print("[Main] andar -> ", af)
	if _label_info and _board:
		_label_info.text = "Andar %d | G/T/PgUp/Dn | clique para mover" % [af]
	# retrato fade simulado: modula InfoLabel
	if _label_info:
		var tw: Tween = create_tween()
		_label_info.modulate.a = 0.3
		tw.tween_property(_label_info, "modulate:a", 1.0, 0.25)

func _trigger_druida() -> void:
	if _board == null:
		return
	for u: Node in _board.get_children():
		if u.get_script() and u.get_script().resource_path.ends_with("board_unit.gd"):
			var d: Resource = u.get("definition") as Resource
			if d and String(d.get("display_name")).contains("Rowan"):
				if u.has_method("transform_toggle"):
					u.call("transform_toggle")
					print("[Main] druida toggle feito")
				return
	var units: Array = _board.call("get_units") as Array if _board.has_method("get_units") else []
	for u: Variant in units:
		var n: Node = u as Node
		if n and n.has_method("transform_toggle"):
			var d: Resource = n.get("definition") as Resource
			if d and String(d.get("display_name")).contains("Rowan"):
				n.call("transform_toggle")
				return

func _get_cell_under_mouse() -> Variant:
	if _camera == null:
		return null
	var mouse: Vector2 = get_viewport().get_mouse_position()
	var origin: Vector3 = _camera.project_ray_origin(mouse)
	var dir: Vector3 = _camera.project_ray_normal(mouse)
	if abs(dir.y) < 0.001:
		return null
	var bg: Node = get_node_or_null("/root/BoardGrid")
	var af: int = int(bg.get("active_floor_index")) if bg and bg.get("active_floor_index") != null else 0
	var floor_y: float = float(af) * 7.0
	var t: float = (floor_y - origin.y) / dir.y
	if t < 0:
		# tenta chão 0
		t = -origin.y / dir.y
		af = 0
	if t < 0:
		return null
	var hit: Vector3 = origin + dir * t
	if bg and bg.has_method("world_to_cell"):
		return bg.call("world_to_cell", hit, af)
	return null

func _get_unit_via_ray() -> Node:
	if _camera == null:
		return null
	var mouse: Vector2 = get_viewport().get_mouse_position()
	var origin: Vector3 = _camera.project_ray_origin(mouse)
	var dir: Vector3 = _camera.project_ray_normal(mouse)
	var to: Vector3 = origin + dir * 100.0
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if space == null:
		return null
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, to, 8)
	q.collide_with_areas = true
	q.collide_with_bodies = false
	var hit: Dictionary = space.intersect_ray(q)
	if hit.is_empty():
		return null
	var col: Object = hit["collider"] as Object
	if col is Node:
		var n: Node = col as Node
		# PickArea -> parent BoardUnit
		if n.has_method("get_parent"):
			var p: Node = n.get_parent() as Node
			if p and p.get_script() and String(p.get_script().resource_path).ends_with("board_unit.gd"):
				return p
			# se for Area3D direta, pega parent
			if p and p.get("grid_pos") != null:
				return p
		# fallback: se col for próprio BoardUnit (caso tenha StaticBody)
		if n.get("grid_pos") != null:
			return n
	return null

func _get_unit_at_cell(cell: Vector3i) -> Node:
	var via_ray: Node = _get_unit_via_ray()
	if via_ray:
		return via_ray
	var bg: Node = get_node_or_null("/root/BoardGrid")
	if bg and bg.has_method("unit_at"):
		var u: Node = bg.call("unit_at", cell) as Node
		if u:
			return u
	for child: Node in _board.get_children():
		if child.get_script() and child.get_script().resource_path.ends_with("board_unit.gd"):
			if child.get("grid_pos") == cell:
				return child
	return null

var _is_defending: bool = false
var _is_dispersar: bool = false

func _handle_left_click() -> void:
	var cell_var: Variant = _get_cell_under_mouse()
	if cell_var == null:
		return
	var cell: Vector3i = cell_var as Vector3i
	print("[Main] clique cell ", cell)
	if _editor and _editor.has_method("handle_board_click"):
		var handled: bool = _editor.call("handle_board_click", cell) as bool
		if handled:
			print("[Main] editor consumiu clique ", cell)
			return
	if _selected_unit and _selected_unit.get_meta("is_moving") == true:
		return
	# verifica turno
	var tm: Node = get_node_or_null("/root/TurnManager")
	if tm and tm.has_method("is_hero_turn") and not bool(tm.call("is_hero_turn")):
		print("[Main] não é turno do herói")
		return
	var unit_at: Node = _get_unit_at_cell(cell)
	if _selected_unit == null:
		if unit_at != null:
			# só seleciona herói no turno do herói
			if tm and not _is_hero_unit(unit_at):
				print("[Main] não é herói")
				return
			_select_unit(unit_at)
		else:
			print("[Main] nenhum unidade em ", cell)
	else:
		if unit_at == _selected_unit:
			_clear_selection()
			return
		if unit_at != null:
			# ataque?
			var combat: Node = get_node_or_null("/root/CombatSystem")
			if combat and combat.has_method("can_attack") and bool(combat.call("can_attack", _selected_unit, unit_at)):
				_do_attack(_selected_unit, unit_at)
				return
			_clear_selection()
			if _is_hero_unit(unit_at):
				_select_unit(unit_at)
			return
		if _reachable.has("dist") and (_reachable["dist"] as Dictionary).has(cell):
			_move_selected_to(cell)
		else:
			print("[Main] destino ", cell, " fora do alcance (", _last_steps, " casas)")
			_clear_selection()

func _is_hero_unit(u: Node) -> bool:
	var def: Resource = u.get("definition") as Resource
	return def and int(def.get("faction")) == 0

func _do_attack(att: Node, def: Node) -> void:
	var combat: Node = get_node_or_null("/root/CombatSystem")
	if combat == null:
		return
	var opts: Dictionary = {}
	if _is_defending:
		opts["defending"] = true
	var res: Dictionary = combat.call("attack", att, def, opts) as Dictionary
	_clear_highlights()
	_selected_unit = null
	# alerta AI
	var ai: Node = get_node_or_null("/root/EnemyAI")
	if ai and ai.has_method("on_attacked"):
		ai.call("on_attacked", att, def)
	if int(def.get("current_hp")) <= 0:
		print("[Main] %s morreu!" % String(def.get("definition").get("display_name")))
		var bg: Node = get_node_or_null("/root/BoardGrid")
		if bg and bg.has_method("clear_cell"):
			bg.call("clear_cell", def.get("grid_pos"))
		def.queue_free()
		var tm2: Node = get_node_or_null("/root/TurnManager")
		if tm2 and tm2.has_method("remove_dead"):
			tm2.call("remove_dead", def)
	# passa turno após ataque
	await get_tree().create_timer(0.4).timeout
	var tm3: Node = get_node_or_null("/root/TurnManager")
	if tm3 and tm3.has_method("next_turn"):
		tm3.call("next_turn")

func _select_unit(unit: Node) -> void:
	_selected_unit = unit
	var def: Resource = unit.get("definition") as Resource
	_last_roll = 0
	_last_steps = 0
	_reachable = {}
	_clear_highlights()
	# destaca seleção sem movimento ainda
	var bg: Node = get_node_or_null("/root/BoardGrid")
	var w: Vector3 = bg.call("grid_to_world", unit.get("grid_pos") as Vector3i) as Vector3 if bg else Vector3.ZERO
	var m: Node3D = MeshInstance3D.new()
	var pl: PlaneMesh = PlaneMesh.new()
	pl.size = Vector2(1.8,1.8)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.95,0.85,0.25,0.75)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pl.material = mat
	(m as MeshInstance3D).mesh = pl
	m.position = w + Vector3(0,0.03,0)
	m.rotation.x = deg_to_rad(-90)
	add_child(m)
	_highlights.append(m)
	if _btn_roll:
		_btn_roll.visible = true
		_btn_roll.text = "Rolar Dados (%s)" % String(def.get("display_name"))
	if _label_info:
		_label_info.text = "%s selecionado | clique Rolar Dados para sortear movimento" % String(def.get("display_name"))
	print("[Main] selecionou ", def.get("display_name"), " aguarde Rolar Dados")

func _on_roll_pressed() -> void:
	if _selected_unit == null:
		print("[Main] nenhum selecionado para rolar")
		return
	var def: Resource = _selected_unit.get("definition") as Resource
	var is_hero: bool = int(def.get("faction")) == 0
	var steps: int = 0
	var roll: int = 0
	if is_hero:
		var res: Dictionary = DiceManager.roll_hero_movement() as Dictionary
		roll = res["roll"] as int
		steps = res["steps"] as int
	else:
		steps = DiceManager.enemy_steps(def) as int
		roll = -1
	_last_roll = roll
	_last_steps = steps
	var bg: Node = get_node_or_null("/root/BoardGrid")
	if bg and bg.has_method("compute_reachable"):
		_reachable = bg.call("compute_reachable", _selected_unit.get("grid_pos") as Vector3i, steps, false) as Dictionary
	else:
		_reachable = {}
	_show_highlights(_reachable)
	var label: String = ""
	if is_hero:
		label = "%s D6=%d → %d casas | clique destino verde" % [def.get("display_name"), roll, steps]
	else:
		label = "%s (inimigo) %d casas | clique destino" % [def.get("display_name"), steps]
	if _label_info:
		_label_info.text = label
	if _btn_roll:
		_btn_roll.visible = false
	print("[Main] rolou ", def.get("display_name"), " roll ", roll, " steps ", steps, " reachable ", (_reachable["dist"] as Dictionary).size() if _reachable.has("dist") else 0)

func _clear_selection() -> void:
	_selected_unit = null
	_reachable = {}
	_clear_highlights()
	if _btn_roll:
		_btn_roll.visible = false
	if _label_info and _board:
		_label_info.text = "Little Sword REFEITO — FASE 7 | D20 vs CA | Clique unidade → Rolar Dados | A/D/F | G/T"
	print("[Main] seleção limpa")

func _show_highlights(reach: Dictionary) -> void:
	_clear_highlights()
	if not reach.has("dist"):
		return
	var dist: Dictionary = reach["dist"] as Dictionary
	var bg: Node = get_node_or_null("/root/BoardGrid")
	for cell_var: Variant in dist.keys():
		var cell: Vector3i = cell_var as Vector3i
		if cell == _selected_unit.get("grid_pos"):
			continue
		var world: Vector3 = bg.call("grid_to_world", cell) as Vector3 if bg else Vector3(float(cell.x)*2+1,0,float(cell.y)*2+1)
		var marker: Node3D = MeshInstance3D.new()
		var plane: PlaneMesh = PlaneMesh.new()
		plane.size = Vector2(1.6, 1.6)
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = Color(0.30, 0.85, 0.35, 0.55)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		plane.material = mat
		(marker as MeshInstance3D).mesh = plane
		marker.position = world + Vector3(0, 0.02, 0)
		marker.rotation.x = deg_to_rad(-90)
		add_child(marker)
		_highlights.append(marker)
	# destaca origem em amarelo
	if _selected_unit:
		var orig: Vector3i = _selected_unit.get("grid_pos") as Vector3i
		var w: Vector3 = bg.call("grid_to_world", orig) as Vector3 if bg else Vector3.ZERO
		var m2: Node3D = MeshInstance3D.new()
		var pl2: PlaneMesh = PlaneMesh.new()
		pl2.size = Vector2(1.8,1.8)
		var mat2: StandardMaterial3D = StandardMaterial3D.new()
		mat2.albedo_color = Color(0.95,0.85,0.25,0.75)
		mat2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		pl2.material = mat2
		(m2 as MeshInstance3D).mesh = pl2
		m2.position = w + Vector3(0,0.03,0)
		m2.rotation.x = deg_to_rad(-90)
		add_child(m2)
		_highlights.append(m2)

func _clear_highlights() -> void:
	for h: Node3D in _highlights:
		if is_instance_valid(h):
			h.queue_free()
	_highlights.clear()

func _move_selected_to(dest: Vector3i) -> void:
	if _selected_unit == null:
		return
	var path: Array = []
	if _movement and _movement.has_method("get_movement_path"):
		path = _movement.call("get_movement_path", _reachable, dest) as Array
	else:
		var bg: Node = get_node_or_null("/root/BoardGrid")
		if bg and bg.has_method("path_from_reachable"):
			path = bg.call("path_from_reachable", _reachable, dest) as Array
	print("[Main] movendo ", _selected_unit.get("definition").get("display_name"), " path ", path, " -> ", dest)
	# oportunidade antes de sair
	var from: Vector3i = _selected_unit.get("grid_pos") as Vector3i
	var combat: Node = get_node_or_null("/root/CombatSystem")
	if combat and combat.has_method("check_opportunity") and not path.is_empty():
		var first_step: Vector3i = path[0] as Vector3i
		var opps: Array = combat.call("check_opportunity", _selected_unit, from, first_step, {"dispersar": _is_dispersar}) as Array
		for opp: Node in opps:
			print("[Main] oportunidade de ", String(opp.get("definition").get("display_name")))
			combat.call("attack", opp, _selected_unit, {})
			if int(_selected_unit.get("current_hp")) <= 0:
				print("[Main] unidade morreu por oportunidade")
				_clear_highlights()
				_selected_unit = null
				return
	_is_dispersar = false
	_clear_highlights()
	var unit: Node = _selected_unit
	_selected_unit = null
	if _label_info:
		_label_info.text = "Movendo..."
	if _movement and _movement.has_method("move_unit"):
		_movement.call("move_unit", unit, path)
		await _movement.movement_finished
		_print_debug_info()
		if _label_info:
			_label_info.text = "Chegou em %s | A: atacar | D: defender | F: dispersar | G/T" % [str(dest)]
		# passa turno após mover (herói)
		var tm: Node = get_node_or_null("/root/TurnManager")
		if tm and tm.has_method("next_turn") and _is_hero_unit(unit):
			await get_tree().create_timer(0.3).timeout
			tm.call("next_turn")
	else:
		unit.set("grid_pos", dest)
		unit.global_position = get_node("/root/BoardGrid").call("grid_to_world", dest) as Vector3
		get_node("/root/BoardGrid").call("place", unit, dest)

func _focus_on_unit(unit: Node) -> void:
	if unit == null or _camera_pivot == null:
		return
	var pos: Vector3 = unit.global_position
	# move pivot to unit com tween
	var tw: Tween = create_tween()
	tw.tween_property(_camera_pivot, "global_position", Vector3(pos.x, _camera_pivot.global_position.y, pos.z), 0.35)
	# fade retrato
	var hud: Node = get_tree().get_first_node_in_group("hud") as Node
	if hud:
		var fade: Control = hud.get_node_or_null("PortraitFade") as Control
		if fade:
			fade.visible = true
			fade.modulate.a = 0.0
			var tw2: Tween = create_tween()
			tw2.tween_property(fade, "modulate:a", 0.4, 0.15)
			tw2.tween_property(fade, "modulate:a", 0.0, 0.15)

func _update_camera() -> void:
	if _camera_pivot == null:
		return
	_camera_pivot.rotation.y = deg_to_rad(_yaw)
	_camera_pivot.rotation.x = deg_to_rad(_pitch)
	var arm: SpringArm3D = _camera_pivot.get_node_or_null("SpringArm3D") as SpringArm3D
	if arm:
		arm.spring_length = _dist
	if _camera and arm == null:
		_camera.position = Vector3(0, 0, _dist)
