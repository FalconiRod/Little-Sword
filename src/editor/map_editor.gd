extends Node
## EDITOR DE MAPA (v1): rearranjar props, modelos GLB e spawns dentro do jogo.
## F1 abre/fecha o painel. Edicoes ficam em user://map_edits_<mapa>.json e
## sao aplicadas POR CIMA da geracao atual (nada do mapa original e destruido).

const SAVE_NAME := "map_edits_%s.json"
const PROPS := ["pillar", "rubble", "chest_prop", "runes", "lever_base", "torch"]
const SPAWN_KEYS := [["K", "Heroi"], ["M", "Maga"], ["W", "Druida"],
		["g", "Goblin"], ["a", "Arqueiro"], ["B", "Chefe"]]
const MODES := [["prop", "Props"], ["glb", "Modelos GLB"], ["spawn", "Spawns"],
		["erase", "Apagar"]]

var active := false
var env: Node = null
var mode := "prop"
var prop_idx := 0
var glb_idx := 0
var spawn_key := "K"
var edits := {"props": [], "glbs": [], "spawns": {}}
var _placed := {}          # Vector3i -> {node, kind, data}
var _spawn_marks := {}     # Vector3i -> node
var _glbs: Array = []
var _ui: CanvasLayer = null
var _cursor_quad: MeshInstance3D = null
var _hover_cell = null

func _ready() -> void:
	_scan_glbs()
	load_edits()

# --------------------------------------------------------------- sessao ----

func begin_session(environment: Node) -> void:
	env = environment
	apply_edits_to(environment)

func _scan_glbs() -> void:
	_glbs.clear()
	var stack: Array = ["res://assets/models"]
	while not stack.is_empty():
		var dir_path: String = stack.pop_back()
		var d := DirAccess.open(dir_path)
		if d == null:
			continue
		d.list_dir_begin()
		var f := d.get_next()
		while f != "":
			var full := dir_path.path_join(f)
			if d.current_is_dir():
				stack.append(full)
			elif f.get_extension() == "glb":
				_glbs.append(full)
			f = d.get_next()
	_glbs.sort()

# ------------------------------------------------------------ entrada ------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_F1:
		active = not active
		if active:
			_build_ui()
		else:
			_teardown_ui()
		EventBus.log_msg.emit(
				"Editor de mapa %s." % ["ABERTO" if active else "fechado"],
				"#7fd4ff")
		get_viewport().set_input_as_handled()
		return
	if not active or env == null:
		return
	if event is InputEventMouseMotion:
		_update_hover(_pick_cell(event.position))
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_apply_tool(_pick_cell(event.position))
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_erase_at(_pick_cell(event.position))
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_adjust_scale(0.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_adjust_scale(-0.1)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R:
				_rotate_at(_hover_cell)
			KEY_G:
				_cycle_mode(1)

func _pick_cell(screen_pos: Vector2):
	var cam := get_viewport().get_camera_3d()
	if cam == null or env == null:
		return null
	var origin := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.0005:
		return null
	var best = null
	var best_t := INF
	for f in maxi(1, env.floors_n):
		var plane_y: float = f * BoardGrid.FLOOR_H + 0.12
		var t := (plane_y - origin.y) / dir.y
		if t <= 0.01 or t >= best_t:
			continue
		var p := origin + dir * t
		var c := BoardGrid.world_to_cell(p, f)
		if BoardGrid.tiles.has(c):
			best = c
			best_t = t
	return best

# ------------------------------------------------------------- ferramentas --

func _apply_tool(c) -> void:
	if c == null:
		return
	match mode:
		"prop":
			_place_prop(PROPS[prop_idx], c, 0.0)
		"glb":
			if not _glbs.is_empty():
				_place_glb(_glbs[glb_idx], c, 0.0, 1.0)
		"spawn":
			_set_spawn(spawn_key, c)
		"erase":
			_erase_at(c)

func _walkable_flag_for(prop_name: String) -> bool:
	for ch in env.LEGEND:
		if env.LEGEND[ch][0] == prop_name:
			return env.LEGEND[ch][1]
	return true

func _floor_node(c: Vector3i) -> Node3D:
	return env.get_node_or_null("Floor%d" % c.z)

func _place_prop(prop_name: String, c: Vector3i, yaw_deg: float,
		silent := false) -> void:
	if _placed.has(c) or not BoardGrid.is_walkable(c):
		if not silent:
			EventBus.log_msg.emit("Celula ocupada ou bloqueada.", "#ff6b6b")
		return
	var piece := TilePiece.build(prop_name)
	if piece == null:
		return
	var fl := _floor_node(c)
	if fl == null:
		piece.free()
		return
	fl.add_child(piece)
	piece.position = BoardGrid.world_pos(c)
	piece.rotation.y = deg_to_rad(yaw_deg)
	_placed[c] = {"node": piece, "kind": "prop",
			"data": {"t": prop_name, "c": [c.x, c.y, c.z], "yaw": yaw_deg}}
	BoardGrid.set_tile(c, _walkable_flag_for(prop_name),
			BoardGrid.tiles[c]["losb"] if BoardGrid.tiles.has(c) else false)
	if not silent:
		EventBus.log_msg.emit("Prop %s em %s" % [prop_name, c], "#7fd4ff")

func _place_glb(path: String, c: Vector3i, yaw_deg: float, scl: float,
		silent := false) -> void:
	if _placed.has(c) or not BoardGrid.is_walkable(c):
		if not silent:
			EventBus.log_msg.emit("Celula ocupada ou bloqueada.", "#ff6b6b")
		return
	var ps: PackedScene = load(path)
	if ps == null:
		return
	var inst: Node3D = ps.instantiate()
	var box := AABB()
	for m in _find_meshes(inst):
		box = box.merge(m.get_aabb())
	var holder := Node3D.new()
	if box.size.y > 0.001:
		var s := 1.4 * scl / box.size.y
		inst.scale = Vector3(s, s, s)
		inst.position = -box.get_center() * s
	holder.add_child(inst)
	var fl := _floor_node(c)
	if fl == null:
		holder.free()
		return
	fl.add_child(holder)
	holder.position = BoardGrid.world_pos(c)
	holder.rotation.y = deg_to_rad(yaw_deg)
	_placed[c] = {"node": holder, "kind": "glb",
			"data": {"p": path, "c": [c.x, c.y, c.z], "yaw": yaw_deg, "s": scl}}
	if not silent:
		EventBus.log_msg.emit("GLB em %s" % c, "#7fd4ff")

func _find_meshes(n: Node) -> Array:
	var out: Array = []
	if n is MeshInstance3D:
		out.append(n)
	for ch in n.get_children():
		out.append_array(_find_meshes(ch))
	return out

func _set_spawn(key: String, c: Vector3i) -> void:
	edits["spawns"][key] = [c.x, c.y, c.z]
	_draw_spawn_mark(key, c)
	EventBus.log_msg.emit("Spawn %s = %s" % [key, c], "#ffd166")

func _draw_spawn_mark(key: String, c: Vector3i) -> void:
	if _spawn_marks.has(c):
		_spawn_marks[c].queue_free()
		_spawn_marks.erase(c)
	var m := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.32
	cyl.bottom_radius = 0.32
	cyl.height = 0.06
	m.mesh = cyl
	var col := Color(0.3, 0.85, 0.4) if key in ["K", "M", "W"] \
			else Color(0.9, 0.25, 0.25)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(col.r, col.g, col.b, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.material_override = mat
	var fl := _floor_node(c)
	if fl == null:
		return
	fl.add_child(m)
	m.position = BoardGrid.world_pos(c) + Vector3(0, 0.16, 0)
	_spawn_marks[c] = m

func _erase_at(c) -> void:
	if c == null:
		return
	if _placed.has(c):
		_placed[c]["node"].queue_free()
		_placed.erase(c)
		BoardGrid.set_tile(c, true,
				BoardGrid.tiles[c]["losb"] if BoardGrid.tiles.has(c) else false)
		EventBus.log_msg.emit("Item removido em %s" % c, "#ffb84d")
	elif _spawn_marks.has(c):
		_spawn_marks[c].queue_free()
		_spawn_marks.erase(c)
		for k in edits["spawns"].keys():
			var v: Array = edits["spawns"][k]
			if Vector3i(v[0], v[1], v[2]) == c:
				edits["spawns"].erase(k)

func _rotate_at(c) -> void:
	if c == null or not _placed.has(c):
		return
	var e = _placed[c]
	e["data"]["yaw"] = fposmod(e["data"]["yaw"] + 45.0, 360.0)
	e["node"].rotation.y = deg_to_rad(e["data"]["yaw"])

func _adjust_scale(d: float) -> void:
	if _hover_cell == null or not _placed.has(_hover_cell):
		return
	var e = _placed[_hover_cell]
	if e["kind"] != "glb":
		return
	e["data"]["s"] = clampf(e["data"]["s"] + d, 0.3, 4.0)
	var path: String = e["data"]["p"]
	var dat: Dictionary = e["data"].duplicate()
	var c := Vector3i(dat["c"][0], dat["c"][1], dat["c"][2])
	e["node"].queue_free()
	_placed.erase(_hover_cell)
	_place_glb(path, c, dat["yaw"], dat["s"], true)

func _cycle_mode(d: int) -> void:
	var names: Array = []
	for m in MODES:
		names.append(m[0])
	mode = names[(names.find(mode) + d + names.size()) % names.size()]
	_refresh_ui()

# ---------------------------------------------------------------- cursor ---

func _update_hover(c) -> void:
	_hover_cell = c
	if c == null:
		if _cursor_quad != null:
			_cursor_quad.visible = false
		return
	if _cursor_quad == null:
		_cursor_quad = MeshInstance3D.new()
		var q := PlaneMesh.new()
		q.size = Vector2(BoardGrid.TILE * 0.96, BoardGrid.TILE * 0.96)
		_cursor_quad.mesh = q
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.83, 0.2, 0.35)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_cursor_quad.material_override = mat
	add_child(_cursor_quad)
	_cursor_quad.visible = true
	_cursor_quad.position = BoardGrid.world_pos(c) + Vector3(0, 0.14, 0)

# ------------------------------------------------------- persistencia ------

func _save_path() -> String:
	return SAVE_NAME % (env.map_id if env != null else "default")

func save_edits() -> void:
	var out := {"props": [], "glbs": [], "spawns": edits["spawns"]}
	for c in _placed:
		var e = _placed[c]
		out[e["kind"] + "s"].append(e["data"])
	var f := FileAccess.open("user://" + _save_path(), FileAccess.WRITE)
	if f == null:
		EventBus.log_msg.emit("Editor: falha ao salvar!", "#ff6b6b")
		return
	f.store_string(JSON.stringify(out, "\t"))
	f.close()
	EventBus.log_msg.emit("Mapa salvo em %s" %
			OS.get_user_data_dir().path_join(_save_path()), "#8fdc7f")

func load_edits() -> void:
	var p := "user://" + _save_path()
	if not FileAccess.file_exists(p):
		return
	var f := FileAccess.open(p, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		edits = parsed

## Reaplica as edicoes salvas por cima do mapa recem-gerado.
func apply_edits_to(environment: Node) -> void:
	env = environment
	for d in edits.get("props", []):
		_place_prop(d["t"], Vector3i(d["c"][0], d["c"][1], d["c"][2]),
				d.get("yaw", 0.0), true)
	for d in edits.get("glbs", []):
		_place_glb(d["p"], Vector3i(d["c"][0], d["c"][1], d["c"][2]),
				d.get("yaw", 0.0), d.get("s", 1.0), true)
	for k in edits["spawns"].keys():
		var v: Array = edits["spawns"][k]
		environment.spawns[k] = [Vector3i(v[0], v[1], v[2])]
		_draw_spawn_mark(k, Vector3i(v[0], v[1], v[2]))
	if not (edits.get("props", []).is_empty()
			and edits.get("glbs", []).is_empty()
			and edits["spawns"].is_empty()):
		EventBus.log_msg.emit("Edicoes de mapa carregadas.", "#7fd4ff")

# -------------------------------------------------------------------- UI ---

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 95
	add_child(_ui)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -300
	panel.offset_top = 12
	panel.offset_right = -12
	_ui.add_child(panel)
	var vb := VBoxContainer.new()
	panel.add_child(vb)
	var title := Label.new()
	title.text = "EDITOR DE MAPA  (F1 fecha)"
	vb.add_child(title)
	for m in MODES:
		var b := Button.new()
		b.name = "mode_" + m[0]
		b.pressed.connect(func() -> void: mode = m[0]; _refresh_ui())
		vb.add_child(b)
	var prop_label := Label.new()
	prop_label.name = "prop_label"
	vb.add_child(prop_label)
	for i in PROPS.size():
		var b := Button.new()
		b.name = "prop_%d" % i
		b.pressed.connect(func() -> void: prop_idx = i; mode = "prop"; _refresh_ui())
		vb.add_child(b)
	var glb_label := Label.new()
	glb_label.name = "glb_label"
	vb.add_child(glb_label)
	for i in _glbs.size():
		var b := Button.new()
		b.name = "glb_%d" % i
		b.text = "[ ] " + _glbs[i].get_file()
		b.pressed.connect(func() -> void: glb_idx = i; mode = "glb"; _refresh_ui())
		vb.add_child(b)
	for sk in SPAWN_KEYS:
		var b := Button.new()
		b.name = "spawn_" + sk[0]
		b.pressed.connect(func() -> void:
			spawn_key = sk[0]; mode = "spawn"; _refresh_ui())
		vb.add_child(b)
	var hint := Label.new()
	hint.name = "hint"
	hint.text = "Clique: colocar | Direito: apagar\nR: girar | Roda: escala (GLB)\nG: trocar modo"
	vb.add_child(hint)
	var save_b := Button.new()
	save_b.text = "SALVAR MAPA"
	save_b.pressed.connect(save_edits)
	vb.add_child(save_b)
	_refresh_ui()

func _refresh_ui() -> void:
	if _ui == null:
		return
	for m in MODES:
		var b := _ui.get_node_or_null("PanelContainer/VBoxContainer/mode_" + m[0])
		if b != null:
			b.text = ("[x] " if mode == m[0] else "[  ] ") + m[1]
	var pl = _ui.get_node_or_null("PanelContainer/VBoxContainer/prop_label")
	if pl != null:
		pl.text = "--- Props ---"
	for i in PROPS.size():
		var b = _ui.get_node_or_null("PanelContainer/VBoxContainer/prop_%d" % i)
		if b != null:
			b.text = ("[x] " if mode == "prop" and prop_idx == i else "[  ] ") + PROPS[i]
	var gl = _ui.get_node_or_null("PanelContainer/VBoxContainer/glb_label")
	if gl != null:
		gl.text = "--- Modelos (%d) ---" % _glbs.size()
	for i in _glbs.size():
		var b = _ui.get_node_or_null("PanelContainer/VBoxContainer/glb_%d" % i)
		if b != null:
			b.text = ("[x] " if mode == "glb" and glb_idx == i else "[  ] ") \
					+ _glbs[i].get_file()
	for sk in SPAWN_KEYS:
		var b = _ui.get_node_or_null("PanelContainer/VBoxContainer/spawn_" + sk[0])
		if b != null:
			var mark := ""
			if edits["spawns"].has(sk[0]):
				var v: Array = edits["spawns"][sk[0]]
				mark = " @%s,%s,%s" % [v[0], v[1], v[2]]
			b.text = ("[x] " if mode == "spawn" and spawn_key == sk[0]
					else "[  ] ") + "Spawn " + sk[1] + mark

func _teardown_ui() -> void:
	if _ui != null:
		_ui.queue_free()
		_ui = null
