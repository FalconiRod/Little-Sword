class_name CameraRig
extends Node3D
## Câmera orbital de mesa digital — como um jogador circulando em torno de
## um tabuleiro real de D&D e inspecionando miniaturas de perto.
##
## Órbita esférica (yaw/pitch/distância) ao redor de um pivô com interpolação
## exponencial suave; colisão com paredes resolvida por amostragem no grid
## (sem física). Padrão: visão isométrica tática; mínimo: ângulo cinematográfico
## rente à mesa; máximo: vista quase zenital.

var cam: Camera3D

var yaw := deg_to_rad(45.0)
var pitch := deg_to_rad(47.0)
var dist := 18.3

var _yaw_t := yaw
var _pitch_t := pitch
var _dist_t := dist
var _pivot_t := Vector3.ZERO

const PITCH_MIN := 12.0
const PITCH_MAX := 85.0
const DIST_MIN := 4.2
const DIST_MAX := 34.0

var _shake := 0.0
var _bounds := Rect2(0, 0, 26, 30)
var _auto_orbit := false

func setup(bounds: Rect2) -> void:
	_bounds = bounds
	_auto_orbit = OS.get_cmdline_user_args().has("--orbit")
	_pivot_t = position
	cam = Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	cam.current = true
	_apply(true)

func set_focus(p: Vector3) -> void:
	_pivot_t = p

func _process(delta: float) -> void:
	var s := 1.0 - exp(-10.0 * delta)

	if _auto_orbit:
		_yaw_t += 0.5 * delta
	if Input.is_key_pressed(KEY_Q):
		_yaw_t += 1.8 * delta
	if Input.is_key_pressed(KEY_E):
		_yaw_t -= 1.8 * delta

	# Pan relativo à direção da câmera.
	var f := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right := Vector3.UP.cross(f)
	var pan := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		pan.y += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		pan.y -= 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		pan.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		pan.x += 1.0
	if pan != Vector2.ZERO:
		var k := 10.0 * delta * (dist / 18.0)
		_pivot_t += (right * pan.x + f * pan.y) * k
	_clamp_pivot()

	yaw += (_yaw_t - yaw) * s
	pitch += (_pitch_t - pitch) * s
	dist += (_dist_t - dist) * s
	position += (_pivot_t - position) * s

	_apply(false)

	if _shake > 0.005:
		cam.h_offset = randf_range(-1, 1) * _shake * 0.25
		cam.v_offset = randf_range(-1, 1) * _shake * 0.25
		_shake = lerpf(_shake, 0.0, minf(1.0, delta * 9.0))
	else:
		cam.h_offset = 0.0
		cam.v_offset = 0.0

func _clamp_pivot() -> void:
	_pivot_t.x = clampf(_pivot_t.x, _bounds.position.x - 4.0, _bounds.end.x + 4.0)
	_pivot_t.z = clampf(_pivot_t.z, _bounds.position.y - 4.0, _bounds.end.y + 6.0)

## Posiciona a câmera na esfera do pivô e resolve colisão com paredes.
func _apply(instant: bool) -> void:
	if cam == null:
		return
	var horiz := cos(pitch) * dist
	var offset := Vector3(sin(yaw) * horiz, sin(pitch) * dist, cos(yaw) * horiz)
	var desired := position + offset
	var final_pos := desired if instant else _collide(position, desired)
	cam.global_position = final_pos
	cam.look_at(position + Vector3(0, 0.6, 0))

## Amostra o segmento pivô->câmera: se atravessar célula de parede abaixo da
## altura das paredes, aproxima a câmera para antes do bloqueio.
func _collide(from: Vector3, to: Vector3) -> Vector3:
	var dir := to - from
	var ln := dir.length()
	if ln < 0.5:
		return to
	dir /= ln
	var steps := int(ceil(ln / 0.45))
	for i in range(1, steps + 1):
		var d := ln * float(i) / float(steps)
		var p := from + dir * d
		if p.y >= 2.1:
			continue
		var c := BoardGrid.cell_of(p)
		if BoardGrid.in_bounds(c) and not BoardGrid.is_walkable(c):
			return from + dir * maxf(1.2, d - 0.55)
	return to

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_dist_t = clampf(_dist_t * 0.90, DIST_MIN, DIST_MAX)
			MOUSE_BUTTON_WHEEL_DOWN:
				_dist_t = clampf(_dist_t / 0.90, DIST_MIN, DIST_MAX)
	elif event is InputEventMouseMotion:
		var mask := int(event.button_mask)
		if mask & MOUSE_BUTTON_MASK_LEFT:
			_yaw_t += event.relative.x * 0.006
			_pitch_t = clampf(_pitch_t + event.relative.y * 0.006, deg_to_rad(PITCH_MIN), deg_to_rad(PITCH_MAX))
		elif mask & MOUSE_BUTTON_MASK_MIDDLE:
			var k := dist * 0.0017
			var f := Vector3(-sin(yaw), 0.0, -cos(yaw))
			var right := Vector3.UP.cross(f)
			_pivot_t -= right * event.relative.x * k
			_pivot_t += f * event.relative.y * k
			_clamp_pivot()

func shake(strength: float) -> void:
	_shake = maxf(_shake, strength)
