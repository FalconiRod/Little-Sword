extends Node3D

@onready var _board: Node = $Board
@onready var _editor: Control = $CanvasLayer/MapEditor
@onready var _camera_pivot: Node3D = $CameraPivot
@onready var _camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var _label_info: Label = $CanvasLayer/InfoLabel

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
		_label_info.text = "Little Sword REFEITO — FASE 1 | TILE=%.1f | Board %dx%d | G: Gerar Grid" % [_get_tile(), _board.get("width"), _board.get("height")]
	print_rich("[color=cyan][Main][/color] FASE 1 pronta. TILE=", _get_tile(), " Board ", _board.get("width"), "x", _board.get("height"))
	_print_debug_info()
	# screenshot debug após 0.5s + re-log de camera após física
	await get_tree().create_timer(0.5).timeout
	await get_tree().physics_frame
	await get_tree().physics_frame
	_print_debug_info()
	_take_debug_screenshot()
	# em headless, encerra após screenshot para validar
	if OS.has_feature("headless"):
		await get_tree().create_timer(0.3).timeout
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

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		_yaw -= mm.relative.x * 0.3
		_pitch = clamp(_pitch - mm.relative.y * 0.3, -85.0, -15.0)
		_update_camera()
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dist = max(6.0, _dist - 1.0)
			_update_camera()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dist = min(35.0, _dist + 1.0)
			_update_camera()
	elif event is InputEventKey and event.pressed:
		var ke: InputEventKey = event as InputEventKey
		if ke.keycode == KEY_G:
			print("[Main] G pressionado")
			if _board and _board.has_method("regenerate_and_bake"):
				await _board.call("regenerate_and_bake")
				_print_debug_info()
		elif ke.keycode == KEY_R:
			_yaw = -45.0
			_pitch = -50.0
			_dist = 18.0
			_update_camera()
		elif ke.keycode == KEY_P:
			_take_debug_screenshot()

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
