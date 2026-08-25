extends Node3D

@onready var _board: Node = $Board
@onready var _editor: Control = $CanvasLayer/MapEditor
@onready var _camera_pivot: Node3D = $CameraPivot
@onready var _camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var _label_info: Label = $CanvasLayer/InfoLabel
@onready var _movement: Node = $MovementManager

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
	_update_camera()
	if _label_info and _board:
		var af: int = int(_board.get("active_floor")) if _board.get("active_floor") != null else 0
		_label_info.text = "Little Sword REFEITO — FASE 5 | TILE=%.1f | %dx%d | Andar %d | Clique→mover | G/T/PgUp/Dn" % [_get_tile(), _board.get("width"), _board.get("height"), af]
	print_rich("[color=cyan][Main][/color] FASE 5 gaveta (escadas removidas) — FASE 4 pronta. TILE=", _get_tile(), " Board ", _board.get("width"), "x", _board.get("height"), " floors=", _board.get("floors_n"))
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
			var dest: Vector3i = Vector3i(1,4,0)
			var d: Dictionary = _reachable.get("dist", {}) as Dictionary
			print("[Main] HEADLESS dest ", dest, " reachable ", d.has(dest))
			if d.has(dest):
				var path: Array = []
				if _movement and _movement.has_method("get_movement_path"):
					path = _movement.call("get_movement_path", _reachable, dest) as Array
				print("[Main] HEADLESS path ", path)
				_move_selected_to(dest)
				# aguarda movimento pulo (0.28 por célula + pausa)
				var wait: float = float(path.size()) * 0.35 + 0.5
				await get_tree().create_timer(wait).timeout
				print("[Main] HEADLESS pos final ", cav.get("grid_pos"), " esperado ", dest, " ok ", cav.get("grid_pos") == dest)
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
		if _label_info and _board:
			_label_info.text = "Little Sword REFEITO — FASE 1 | TILE=%.1f | Board %dx%d | OK %s" % [_get_tile(), _board.get("width"), _board.get("height"), Time.get_time_string_from_system()]
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

func _get_unit_at_cell(cell: Vector3i) -> Node:
	var bg: Node = get_node_or_null("/root/BoardGrid")
	if bg and bg.has_method("unit_at"):
		return bg.call("unit_at", cell) as Node
	for child: Node in _board.get_children():
		if child.get_script() and child.get_script().resource_path.ends_with("board_unit.gd"):
			if child.get("grid_pos") == cell:
				return child
	return null

func _handle_left_click() -> void:
	var cell_var: Variant = _get_cell_under_mouse()
	if cell_var == null:
		return
	var cell: Vector3i = cell_var as Vector3i
	print("[Main] clique cell ", cell)
	# se já movendo, ignora
	if _selected_unit and _selected_unit.get_meta("is_moving") == true:
		return
	var unit_at: Node = _get_unit_at_cell(cell)
	if _selected_unit == null:
		if unit_at != null:
			_select_unit(unit_at)
		else:
			print("[Main] nenhum unidade em ", cell)
	else:
		# já tem seleção
		if unit_at == _selected_unit:
			_clear_selection()
			return
		if unit_at != null:
			# trocar seleção
			_clear_selection()
			_select_unit(unit_at)
			return
		# tenta mover para célula vazia
		if _reachable.has("dist") and (_reachable["dist"] as Dictionary).has(cell):
			_move_selected_to(cell)
		else:
			print("[Main] destino ", cell, " fora do alcance (", _last_steps, " casas)")
			_clear_selection()

func _select_unit(unit: Node) -> void:
	_selected_unit = unit
	var def: Resource = unit.get("definition") as Resource
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
		_reachable = bg.call("compute_reachable", unit.get("grid_pos"), steps, false) as Dictionary
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
	print("[Main] selecionou ", def.get("display_name"), " roll ", roll, " steps ", steps, " reachable ", (_reachable["dist"] as Dictionary).size() if _reachable.has("dist") else 0)

func _clear_selection() -> void:
	_selected_unit = null
	_reachable = {}
	_clear_highlights()
	if _label_info and _board:
		_label_info.text = "Little Sword REFEITO — FASE 4 | Clique unidade → destino | G: Grid | T: Urso"
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
		# fallback via BoardGrid
		var bg: Node = get_node_or_null("/root/BoardGrid")
		if bg and bg.has_method("path_from_reachable"):
			path = bg.call("path_from_reachable", _reachable, dest) as Array
	print("[Main] movendo ", _selected_unit.get("definition").get("display_name"), " path ", path, " -> ", dest)
	_clear_highlights()
	var unit: Node = _selected_unit
	_selected_unit = null
	if _label_info:
		_label_info.text = "Movendo..."
	if _movement and _movement.has_method("move_unit"):
		_movement.call("move_unit", unit, path)
		# aguarda sinal
		await _movement.movement_finished
		_print_debug_info()
		if _label_info:
			_label_info.text = "Chegou em %s | G: Grid | T: Urso | clique outra unidade" % [str(dest)]
	else:
		# fallback instantâneo
		unit.set("grid_pos", dest)
		unit.global_position = get_node("/root/BoardGrid").call("grid_to_world", dest) as Vector3
		get_node("/root/BoardGrid").call("place", unit, dest)

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
