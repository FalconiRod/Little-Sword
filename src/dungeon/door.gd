class_name DungeonDoor
extends Node3D
## Porta interativa do kit de mesa: fechada bloqueia casa + visão;
## abre com clique adjacente, chave ou evento (alavanca).
## Estados: LOCKED -> CLOSED <-> OPEN.

signal opened(door)
signal closed(door)

enum State { OPEN, CLOSED, LOCKED }

var cell := Vector3i.ZERO
var state: int = State.CLOSED
var key_id := ""          ## "" = não trancada; "iron_key" exige item; "lever:<id>" exige alavanca
var disguised := false    ## passagem secreta: parece parede até destrancar
var door_id := ""

var _panel: MeshInstance3D
var _tween: Tween

func setup(c: Vector3i, p_locked := false, p_key := "", p_disguised := false,
		p_id := "") -> void:
	cell = c
	door_id = p_id
	key_id = p_key
	disguised = p_disguised
	state = State.LOCKED if p_locked else State.CLOSED
	_build()
	_apply_grid()

func is_passable() -> bool:
	return state == State.OPEN

func can_open_with(item_id: String) -> bool:
	if state == State.LOCKED and key_id.begins_with("item:"):
		return item_id == key_id.substr(5)
	return true

## Alavanca/evento destranca portas ligadas por id.
func unlock_by_event() -> void:
	if state != State.LOCKED:
		return
	state = State.CLOSED
	EventBus.log_msg.emit("Um mecanismo antigo ecoa... algo se abriu!", "#ffd166")
	if disguised:
		_reveal_secret()
	open()

func try_toggle(has_item := "") -> String:
	## Retorna "" em sucesso ou a mensagem de erro.
	match state:
		State.OPEN:
			close()
			return ""
		State.CLOSED:
			open()
			return ""
		State.LOCKED:
			if key_id == "":
				return ""
			if key_id.begins_with("item:") and has_item == key_id.substr(5):
				state = State.CLOSED
				open()
				EventBus.log_msg.emit("A chave gira e a tranca cede.", "#ffd166")
				return ""
			return "Trancada."
	return ""

func open() -> void:
	if state == State.OPEN:
		return
	state = State.OPEN
	_apply_grid()
	_animate(90.0)
	opened.emit(self)

func close() -> void:
	if state == State.CLOSED:
		return
	state = State.CLOSED
	_apply_grid()
	_animate(0.0)
	closed.emit(self)

# ------------------------------------------------------------------ interno -

func _build() -> void:
	var frame_m := StandardMaterial3D.new()
	frame_m.albedo_color = Color.html("3c3c46")
	frame_m.roughness = 0.8
	for sx in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.16, 1.5, 0.24)
		post.mesh = bm
		post.material_override = frame_m
		post.position = Vector3(sx * 0.86, 0.75, 0)
		add_child(post)
	var top := MeshInstance3D.new()
	var tbm := BoxMesh.new()
	tbm.size = Vector3(1.9, 0.16, 0.26)
	top.mesh = tbm
	top.material_override = frame_m
	top.position = Vector3(0, 1.56, 0)
	add_child(top)

	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color.html(disguised if false else "6b4626")
	pm.roughness = 0.9
	_panel = MeshInstance3D.new()
	var pbm := BoxMesh.new()
	pbm.size = Vector3(1.6, 1.42, 0.1)
	_panel.mesh = pbm
	_panel.material_override = pm
	_panel.position = Vector3(0, 0.71, 0)
	add_child(_panel)
	if disguised:
		_panel.material_override.albedo_color = Color.html("4a4a56")
		_panel.visible = true
	else:
		_panel.rotation_degrees.y = 90.0 if state == State.OPEN else 0.0

func _reveal_secret() -> void:
	disguised = false

func _apply_grid() -> void:
	var blocked: bool = state != State.OPEN
	BoardGrid.set_tile(cell, not blocked, blocked, BoardGrid.elev_at(cell))

func _animate(target_yaw: float) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_panel, "rotation_degrees:y", target_yaw, 0.35) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
