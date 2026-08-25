extends Node3D

@onready var _board: Node = $Board
@onready var _editor: Control = $CanvasLayer/MapEditor
@onready var _camera_pivot: Node3D = $CameraPivot
@onready var _camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var _label_info: Label = $CanvasLayer/InfoLabel

var _yaw: float = -45.0
var _pitch: float = -50.0
var _dist: float = 18.0

func _ready() -> void:
	if _editor and _editor.has_method("bind_board") and _board:
		_editor.call("bind_board", _board)
	_update_camera()
	if _label_info and _board:
		_label_info.text = "Little Sword REFEITO — FASE 1 | TILE=2.0 | Board %dx%d | Arraste esquerdo: orbita | Roda: zoom | G: Gerar Grid" % [_board.get("width"), _board.get("height")]
	print_rich("[color=cyan][Main][/color] FASE 1 pronta. TILE=", BoardGrid.TILE, " Board ", _board.get("width"), "x", _board.get("height"))

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
			if _board and _board.has_method("regenerate_and_bake"):
				await _board.call("regenerate_and_bake")
		elif ke.keycode == KEY_R:
			_yaw = -45.0
			_pitch = -50.0
			_dist = 18.0
			_update_camera()

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
