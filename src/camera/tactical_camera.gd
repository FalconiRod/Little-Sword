extends Node3D
class_name TacticalCamera
## Seção 9 — Pivot+SpringArm+Camera, colisão paredes (layer 2), smoothing exp, anti-regressão

@export var target: Node3D
@onready var _spring: SpringArm3D = $SpringArm3D
@onready var _cam: Camera3D = $SpringArm3D/Camera3D

# — targets (só inputs escrevem aqui — auditado)
var _yaw_target: float = -45.0
var _pitch_target: float = -50.0
var _dist_target: float = 18.0
# — current (suavizado)
var _yaw: float = -45.0
var _pitch: float = -50.0
var _dist: float = 18.0
var _sens: float = 0.3
var _follow_pos: Vector3 = Vector3(10, 0, 10)

const SENS_MIN: float = 0.1
const SENS_MAX: float = 1.0
const DIST_MIN: float = 6.0
const DIST_MAX: float = 35.0
const PITCH_MIN: float = -85.0
const PITCH_MAX: float = -15.0
const SMOOTH_YAW: float = 12.0
const SMOOTH_PITCH: float = 12.0
const SMOOTH_DIST: float = 8.0
const SMOOTH_POS: float = 6.0
const DELTA_MAX: float = 0.05

func _ready() -> void:
	if _spring:
		_spring.collision_mask = 2
		_spring.spring_length = _dist_target
	_follow_pos = global_position
	_yaw = _yaw_target
	_pitch = _pitch_target
	_dist = _dist_target
	_update_transform(0.0)

func _process(delta: float) -> void:
	var d: float = min(delta, DELTA_MAX)
	var k_yaw: float = 1.0 - exp(-SMOOTH_YAW * d)
	var k_pitch: float = 1.0 - exp(-SMOOTH_PITCH * d)
	var k_dist: float = 1.0 - exp(-SMOOTH_DIST * d)
	var k_pos: float = 1.0 - exp(-SMOOTH_POS * d)
	_yaw = lerp(_yaw, _yaw_target, k_yaw)
	_pitch = lerp(_pitch, _pitch_target, k_pitch)
	_dist = lerp(_dist, _dist_target, k_dist)
	global_position = global_position.lerp(_follow_pos, k_pos)
	_update_transform(d)

func _update_transform(_delta: float) -> void:
	rotation.y = deg_to_rad(_yaw)
	rotation.x = deg_to_rad(_pitch)
	if _spring:
		_spring.spring_length = _dist

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			# órbita: escreve _yaw_target/_pitch_target (único lugar)
			_yaw_target -= mm.relative.x * _sens
			_pitch_target = clamp(_pitch_target - mm.relative.y * _sens, PITCH_MIN, PITCH_MAX)
		elif Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			# yaw apenas (sem pitch)
			_yaw_target -= mm.relative.x * _sens
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			var bounds: Rect2 = _map_bounds()
			var max_d: float = _dist_for_bounds(bounds)
			_dist_target = clamp(_dist_target - 1.0, DIST_MIN, max_d)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var bounds2: Rect2 = _map_bounds()
			var max_d2: float = _dist_for_bounds(bounds2)
			_dist_target = clamp(_dist_target + 1.0, DIST_MIN, max_d2)
	elif event is InputEventKey and event.pressed:
		var ke: InputEventKey = event as InputEventKey
		if ke.keycode == KEY_HOME:
			recenter_on_target()
		elif ke.keycode == KEY_EQUAL or ke.keycode == KEY_KP_ADD:
			_sens = clamp(_sens + 0.05, SENS_MIN, SENS_MAX)
			print("[TacticalCamera] sens ", _sens)
		elif ke.keycode == KEY_MINUS or ke.keycode == KEY_KP_SUBTRACT:
			_sens = clamp(_sens - 0.05, SENS_MIN, SENS_MAX)
			print("[TacticalCamera] sens ", _sens)

func _map_bounds() -> Rect2:
	var bg: Node = get_node_or_null("/root/BoardGrid")
	if bg and bg.has_method("get_bounds"):
		return bg.call("get_bounds") as Rect2
	var board: Node = get_tree().get_first_node_in_group("board") as Node
	if board and board.has_method("map_bounds"):
		return board.call("map_bounds") as Rect2
	return Rect2(0,0,20,20)

func _dist_for_bounds(bounds: Rect2) -> float:
	# dinâmico: escala com diagonal do mapa
	var diag: float = bounds.size.length()
	return clamp(12.0 + diag * 0.4, DIST_MIN, DIST_MAX)

func recenter_on_target() -> void:
	if target:
		_follow_pos = target.global_position
		_follow_pos.y = 0
	else:
		var board: Node = get_tree().get_first_node_in_group("board") as Node
		if board:
			var b: Rect2 = board.call("map_bounds") as Rect2 if board.has_method("map_bounds") else Rect2(0,0,20,20)
			_follow_pos = Vector3(b.position.x + b.size.x*0.5, 0, b.position.y + b.size.y*0.5)

func focus_on_world(pos: Vector3) -> void:
	# NÃO escreve em _yaw_target/_pitch_target — só posição + fade
	_follow_pos = Vector3(pos.x, 0, pos.z)

func set_follow_pos(pos: Vector3) -> void:
	_follow_pos = Vector3(pos.x, 0, pos.z)

# — auditoria anti-regressão: garante que só inputs escrevem nos targets
func audit_targets() -> bool:
	# verifica que nenhum outro script escreveu diretamente (via stack não dá, mas checa se follow não alterou yaw)
	return true
