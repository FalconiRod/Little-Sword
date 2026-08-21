class_name TacticalCamera
extends Node3D
## Câmera orbital tática pesada/cinematográfica, estilo Baldur's Gate 3 / Solasta.
##
## Hierarquia (montada em código em setup(), pois o projeto não usa cenas):
##   TacticalCamera (Node3D)  <- PAN (X/Z do tabuleiro)
##     └── Pivot              <- gira em yaw (Y) e pitch (X)
##           └── SpringArm3D  <- distância/zoom com colisão real
##                 └── Camera3D

# ---------------------------------------------------------------------------
# CONFIGURAÇÃO EXPOSTA
# ---------------------------------------------------------------------------

@export_group("Rotação (orbit)")
## Graus de rotação por pixel de movimento do mouse. Baixo = pesado/lento.
@export var rotation_sensitivity: float = 0.12
## Taxa de suavização exponencial: quanto maior, mais responsivo.
@export var rotation_smoothing: float = 8.0
## Limites de pitch (vertical), em graus.
@export var pitch_min_deg: float = 25.0
@export var pitch_max_deg: float = 75.0
## Botão do mouse usado para orbitar. Neste projeto: ESQUERDO
## (direito fica reservado para cancelar a mira).
@export var orbit_mouse_button: int = MOUSE_BUTTON_LEFT

@export_group("Zoom")
@export var zoom_step: float = 1.2
@export var zoom_min: float = 4.0
@export var zoom_max: float = 22.0
@export var zoom_smoothing: float = 6.0

@export_group("Pan")
@export var pan_speed: float = 10.0
@export var pan_acceleration: float = 6.0
@export var pan_deceleration: float = 10.0
@export var middle_mouse_pan_sensitivity: float = 0.02
var _pan_limits := Rect2(0, 0, 26, 30)

# ---------------------------------------------------------------------------
# ESTADO INTERNO
# ---------------------------------------------------------------------------

var cam: Camera3D
var _pivot: Node3D
var _spring_arm: SpringArm3D

var _yaw_current: float = deg_to_rad(45.0)
var _yaw_target: float = deg_to_rad(45.0)
var _pitch_current: float = deg_to_rad(45.0)
var _pitch_target: float = deg_to_rad(45.0)

var _zoom_current: float = 18.3
var _zoom_target: float = 18.3

var _pan_velocity: Vector2 = Vector2.ZERO
var _pan_input_dir: Vector2 = Vector2.ZERO

var _is_orbiting: bool = false
var _is_panning_mmb: bool = false
var _shake := 0.0
var _auto_orbit := false


func setup(bounds: Rect2) -> void:
	_pan_limits = bounds
	_auto_orbit = OS.get_cmdline_user_args().has("--orbit")

	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	add_child(_pivot)

	_spring_arm = SpringArm3D.new()
	_spring_arm.spring_length = _zoom_current
	_spring_arm.margin = 0.5
	_spring_arm.collision_mask = 2
	var sphere := SphereShape3D.new()
	sphere.radius = 0.6
	_spring_arm.shape = sphere
	_pivot.add_child(_spring_arm)

	cam = Camera3D.new()
	cam.fov = 40.0
	_spring_arm.add_child(cam)
	cam.current = true

	_apply_rotation()
	_apply_zoom()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == orbit_mouse_button:
			_is_orbiting = event.pressed
			if event.pressed:
				return
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_is_panning_mmb = event.pressed
			if event.pressed:
				return
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_target = clamp(_zoom_target - zoom_step, zoom_min, zoom_max)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_target = clamp(_zoom_target + zoom_step, zoom_min, zoom_max)
	elif event is InputEventMouseMotion:
		if _is_orbiting:
			_yaw_target -= event.relative.x * rotation_sensitivity * 0.01
			_pitch_target -= event.relative.y * rotation_sensitivity * 0.01
			_pitch_target = clamp(
				_pitch_target, deg_to_rad(pitch_min_deg), deg_to_rad(pitch_max_deg)
			)
		elif _is_panning_mmb:
			var right: Vector3 = global_transform.basis.x
			var forward: Vector3 = -global_transform.basis.z
			right.y = 0.0
			forward.y = 0.0
			right = right.normalized()
			forward = forward.normalized()
			var delta_pan: Vector3 = (
				right * -event.relative.x + forward * event.relative.y
			) * middle_mouse_pan_sensitivity * (_zoom_current / 12.0)
			position += delta_pan
			_clamp_pan_position()


func _process(delta: float) -> void:
	if _auto_orbit:
		_yaw_target += 0.5 * delta
	if Input.is_key_pressed(KEY_Q):
		_yaw_target += 1.8 * delta
	if Input.is_key_pressed(KEY_E):
		_yaw_target -= 1.8 * delta

	_process_keyboard_pan_input()
	_apply_rotation_smoothing(delta)
	_apply_zoom_smoothing(delta)
	_apply_pan_smoothing(delta)

	if _shake > 0.005:
		cam.h_offset = randf_range(-1, 1) * _shake * 0.25
		cam.v_offset = randf_range(-1, 1) * _shake * 0.25
		_shake = lerpf(_shake, 0.0, minf(1.0, delta * 9.0))
	else:
		cam.h_offset = 0.0
		cam.v_offset = 0.0


# ---------------------------------------------------------------------------
# ROTAÇÃO
# ---------------------------------------------------------------------------

func _apply_rotation_smoothing(delta: float) -> void:
	var t: float = 1.0 - exp(-rotation_smoothing * delta)
	_yaw_current = lerp_angle(_yaw_current, _yaw_target, t)
	_pitch_current = lerp(_pitch_current, _pitch_target, t)
	_apply_rotation()


func _apply_rotation() -> void:
	if _pivot == null:
		return
	_pivot.rotation.y = _yaw_current
	# Pitch positivo = olhar de cima para baixo; a mola se estende no +Z do
	# pivô, então inclinar a cabeça para BAIXO exige rotação X negativa.
	_pivot.rotation.x = -_pitch_current


# ---------------------------------------------------------------------------
# ZOOM
# ---------------------------------------------------------------------------

func _apply_zoom_smoothing(delta: float) -> void:
	var t: float = 1.0 - exp(-zoom_smoothing * delta)
	_zoom_current = lerp(_zoom_current, _zoom_target, t)
	_apply_zoom()


func _apply_zoom() -> void:
	if _spring_arm != null:
		_spring_arm.spring_length = _zoom_current


# ---------------------------------------------------------------------------
# PAN (teclado com aceleração/desaceleração — sensação de peso)
# ---------------------------------------------------------------------------

func _process_keyboard_pan_input() -> void:
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1.0
	_pan_input_dir = dir.normalized() if dir.length() > 0.001 else Vector2.ZERO


func _apply_pan_smoothing(delta: float) -> void:
	var desired_velocity: Vector2 = _pan_input_dir * pan_speed * (_zoom_current / 12.0)
	var accel: float = (
		pan_acceleration if _pan_input_dir != Vector2.ZERO else pan_deceleration
	)
	_pan_velocity = _pan_velocity.move_toward(desired_velocity, accel * delta)

	if _pan_velocity.length_squared() < 0.000001:
		return

	var right: Vector3 = global_transform.basis.x
	var forward: Vector3 = -global_transform.basis.z
	right.y = 0.0
	forward.y = 0.0
	forward = forward.normalized()
	right = right.normalized()

	position += (right * _pan_velocity.x + forward * -_pan_velocity.y) * delta
	_clamp_pan_position()


func _clamp_pan_position() -> void:
	position.x = clamp(position.x, _pan_limits.position.x - 4.0, _pan_limits.end.x + 4.0)
	position.z = clamp(position.z, _pan_limits.position.y - 4.0, _pan_limits.end.y + 6.0)


func set_focus(p: Vector3) -> void:
	position = p
	_clamp_pan_position()


func shake(strength: float) -> void:
	_shake = maxf(_shake, strength)


func set_zoom_target(value: float) -> void:
	_zoom_target = clamp(value, zoom_min, zoom_max)
