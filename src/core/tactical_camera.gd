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
## Ajustável em jogo com as teclas - e = (set_sensitivity).
@export var rotation_sensitivity: float = 0.12
const SENS_MIN := 0.04
const SENS_MAX := 0.30
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
## Distância máxima calculada para enquadrar o mapa inteiro de cima.
@export var zoom_max: float = 46.0
@export var zoom_smoothing: float = 6.0

@export_group("Pan")
@export var pan_speed: float = 10.0
@export var pan_acceleration: float = 6.0
@export var pan_deceleration: float = 10.0
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

# Padrão target-interpolado: NUNCA escrevemos position direto no pan;
# tudo escreve em _pan_target e a posição real persegue com atraso
# (camera lag estilo BG3). Quanto menor PAN_LAG, mais pesado o deslize.
const PAN_LAG := 3.2

var _pan_position: Vector3 = Vector3.ZERO
var _pan_target: Vector3 = Vector3.ZERO

var _pan_velocity: Vector2 = Vector2.ZERO
var _pan_input_dir: Vector2 = Vector2.ZERO

var _follow_target: Node3D = null
var following := false

var _is_orbiting: bool = false
var _is_orbiting_yaw: bool = false
var _shake := 0.0
var _auto_orbit := false


func setup(bounds: Rect2) -> void:
	_pan_limits = bounds
	_auto_orbit = OS.get_cmdline_user_args().has("--orbit")
	_pan_position = position
	_pan_target = position

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
		if event.button_index == orbit_mouse_button or event.button_index == MOUSE_BUTTON_MIDDLE:
			# Esquerdo OU meio arrastando: girar livremente (estilo BG3/vídeo).
			_is_orbiting = event.pressed
			if event.pressed:
				return
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			# Direito arrastando gira pros lados (yaw); clique sem arrasto
			# é tratado pelo PlayerController como cancelar mira.
			_is_orbiting_yaw = event.pressed
			if event.pressed:
				return
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			var step := zoom_step * clampf(_zoom_current / 12.0, 1.0, 3.0)
			_zoom_target = clamp(_zoom_target - step, zoom_min, zoom_max)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			var step := zoom_step * clampf(_zoom_current / 12.0, 1.0, 3.0)
			_zoom_target = clamp(_zoom_target + step, zoom_min, zoom_max)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_MINUS:
				set_sensitivity(rotation_sensitivity - 0.02)
			KEY_EQUAL:
				set_sensitivity(rotation_sensitivity + 0.02)
			KEY_HOME:
				if _follow_target != null:
					set_follow(_follow_target, true)
					EventBus.log_msg.emit("Câmera recentrada no herói.", "8fd3ff")
	elif event is InputEventMouseMotion:
		if _is_orbiting:
			_yaw_target -= event.relative.x * rotation_sensitivity * 0.01
			_pitch_target -= event.relative.y * rotation_sensitivity * 0.01
			_pitch_target = clamp(
				_pitch_target, deg_to_rad(pitch_min_deg), deg_to_rad(pitch_max_deg)
			)
		elif _is_orbiting_yaw:
			_yaw_target -= event.relative.x * rotation_sensitivity * 0.01


func _process(delta: float) -> void:
	if _auto_orbit:
		_yaw_target += 0.5 * delta
	if Input.is_key_pressed(KEY_Q):
		_yaw_target += 1.8 * delta
	if Input.is_key_pressed(KEY_E):
		_yaw_target -= 1.8 * delta

	_update_follow()
	_process_keyboard_pan_input()
	_apply_rotation_smoothing(delta)
	_apply_zoom_smoothing(delta)
	_apply_pan_smoothing(delta)

	# Interpolação final da posição (o "deslizar" até o alvo).
	_pan_position = _pan_position.lerp(_pan_target, 1.0 - exp(-PAN_LAG * delta))
	position = _pan_position

	if _shake > 0.005:
		cam.h_offset = randf_range(-1, 1) * _shake * 0.25
		cam.v_offset = randf_range(-1, 1) * _shake * 0.25
		_shake = lerpf(_shake, 0.0, minf(1.0, delta * 9.0))
	else:
		cam.h_offset = 0.0
		cam.v_offset = 0.0


## Follow com atraso natural: apenas atualiza o ALVO; o lag nasce do
## PAN_LAG na interpolação de _pan_position.
func _update_follow() -> void:
	if following and _follow_target != null:
		var p := _follow_target.global_position
		_pan_target.x = p.x
		_pan_target.z = p.z
		_clamp_pan_target()


func set_follow(target: Node3D, enabled: bool = true) -> void:
	_follow_target = target
	following = enabled and target != null
	if following:
		set_focus(_follow_target.global_position)


func stop_follow() -> void:
	following = false


## Ajusta a sensibilidade do mouse em jogo (- / =). O arrasto de pan
## acompanha proporcionalmente para os dois gestos "sentirem" igual.
func set_sensitivity(v: float) -> void:
	rotation_sensitivity = clampf(v, SENS_MIN, SENS_MAX)
	var pct := int(round(rotation_sensitivity / 0.12 * 100.0))
	EventBus.log_msg.emit("Sensibilidade do mouse: %d%%" % pct, "8fd3ff")


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

	if _pan_input_dir != Vector2.ZERO:
		stop_follow()

	if _pan_velocity.length_squared() < 0.000001:
		return

	var right: Vector3 = global_transform.basis.x
	var forward: Vector3 = -global_transform.basis.z
	right.y = 0.0
	forward.y = 0.0
	forward = forward.normalized()
	right = right.normalized()

	_pan_target += (right * _pan_velocity.x + forward * -_pan_velocity.y) * delta
	_clamp_pan_target()


func _clamp_pan_target() -> void:
	_pan_target.x = clamp(_pan_target.x, _pan_limits.position.x - 4.0, _pan_limits.end.x + 4.0)
	_pan_target.z = clamp(_pan_target.z, _pan_limits.position.y - 4.0, _pan_limits.end.y + 6.0)


func set_focus(p: Vector3) -> void:
	_pan_target = p
	_clamp_pan_target()


func shake(strength: float) -> void:
	_shake = maxf(_shake, strength)


func set_zoom_target(value: float) -> void:
	_zoom_target = clamp(value, zoom_min, zoom_max)
