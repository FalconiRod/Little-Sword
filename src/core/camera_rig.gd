class_name CameraRig
extends Node3D
## Câmera isométrica da mesa digital: pan relativo à direção de visão,
## órbita livre ao redor do tabuleiro (Q/E ou botão do meio), zoom no scroll
## e tremida em impactos.

var cam: Camera3D
var _base_offset := Vector3(9.0, 13.5, 9.0)
var _zoom := 1.0
var _zoom_target := 1.0
var _yaw := 0.0
var _yaw_target := 0.0
var _shake := 0.0
var _dragging := false
var _bounds := Rect2(0, 0, 26, 30)
var _auto_orbit := false

func setup(bounds: Rect2) -> void:
	_bounds = bounds
	_auto_orbit = OS.get_cmdline_user_args().has("--orbit")
	cam = Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	cam.current = true
	_apply()

func _process(delta: float) -> void:
	if _auto_orbit:
		_yaw_target += 0.5 * delta
	var k_rot := 0.0
	if Input.is_key_pressed(KEY_Q):
		k_rot += 1.0
	if Input.is_key_pressed(KEY_E):
		k_rot -= 1.0
	_yaw_target += k_rot * 1.8 * delta

	var pan := Vector2.ZERO
	var fwd := Vector3(sin(_yaw), 0, cos(_yaw))
	var right := Vector3(cos(_yaw), 0, -sin(_yaw))
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		pan.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		pan.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		pan.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		pan.x += 1.0
	if pan != Vector2.ZERO:
		var move := (right * pan.x + fwd * pan.y).normalized() * 10.0 * delta
		position.x = clampf(position.x + move.x, _bounds.position.x - 4.0, _bounds.end.x + 4.0)
		position.z = clampf(position.z + move.z, _bounds.position.y - 4.0, _bounds.end.y + 6.0)

	_zoom = lerpf(_zoom, _zoom_target, minf(1.0, delta * 10.0))
	_yaw = lerpf(_yaw, _yaw_target, minf(1.0, delta * 14.0))
	_apply()

	if _shake > 0.005:
		cam.h_offset = randf_range(-1, 1) * _shake * 0.25
		cam.v_offset = randf_range(-1, 1) * _shake * 0.25
		_shake = lerpf(_shake, 0.0, minf(1.0, delta * 9.0))
	else:
		cam.h_offset = 0.0
		cam.v_offset = 0.0

func _apply() -> void:
	if cam == null:
		return
	var offset := (_base_offset * _zoom).rotated(Vector3.UP, _yaw)
	cam.position = offset
	cam.look_at(Vector3.ZERO)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_zoom_target = clampf(_zoom_target - 0.08, 0.65, 1.7)
			MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_target = clampf(_zoom_target + 0.08, 0.65, 1.7)
			MOUSE_BUTTON_MIDDLE:
				_dragging = true
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_MIDDLE:
		_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		_yaw_target += event.relative.x * 0.008

func shake(strength: float) -> void:
	_shake = maxf(_shake, strength)
