class_name CameraRig
extends Node3D
## Câmera isométrica da mesa digital: ângulo fixo, pan por teclado,
## zoom pelo scroll e tremida em impactos.

var cam: Camera3D
var _base_offset := Vector3(9.0, 13.5, 9.0)
var _zoom := 1.0
var _shake := 0.0
var _bounds := Rect2(0, 0, 26, 30)

func setup(bounds: Rect2) -> void:
	_bounds = bounds
	cam = Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	cam.position = _base_offset
	cam.look_at(Vector3.ZERO)
	cam.current = true

func _process(delta: float) -> void:
	var pan := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		pan.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		pan.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		pan.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		pan.x += 1.0
	if pan != Vector2.ZERO:
		position.x = clampf(position.x + pan.x * 10.0 * delta, _bounds.position.x - 4.0, _bounds.end.x + 4.0)
		position.z = clampf(position.z + pan.y * 10.0 * delta, _bounds.position.y - 4.0, _bounds.end.y + 6.0)
	if _shake > 0.005:
		cam.h_offset = randf_range(-1, 1) * _shake * 0.25
		cam.v_offset = randf_range(-1, 1) * _shake * 0.25
		_shake = lerpf(_shake, 0.0, minf(1.0, delta * 9.0))
	else:
		cam.h_offset = 0.0
		cam.v_offset = 0.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_zoom(_zoom - 0.08)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_zoom(_zoom + 0.08)

func _set_zoom(v: float) -> void:
	_zoom = clampf(v, 0.65, 1.7)
	var t := create_tween()
	t.tween_property(cam, "position", _base_offset * _zoom, 0.12)

func shake(strength: float) -> void:
	_shake = maxf(_shake, strength)
