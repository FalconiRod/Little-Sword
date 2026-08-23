extends Node
## EDITOR DE MAPA v2 — biblioteca de pecas por categoria + painel de
## transformacao da peca selecionada (rotacao 90graus, escala uniforme
## por padrao e por-eixo apenas em modo avancado), troca de piso por
## celula, colocacao de escadas (par) e persistencia em JSON aplicada
## POR CIMA da geracao do mapa (edicao de INSTANCIA, nunca da definicao
## compartilhada do catalogo TilePiece).
## F1 abre/fecha. Enquanto aberto: input do jogo bloqueado e turnos/IA
## ficam em espera (TurnManager consulta MapEditor.active).

const SAVE_NAME := "map_edits_%s.json"

## Biblioteca por categoria (nomes = ids do catalogo TilePiece).
const CAT_FLOORS := ["floor_stone", "floor_carpet", "floor_moss", "bridge_plank"]
const CAT_WALLS := ["wall_stone", "pillar"]
const CAT_OBSTACLES := ["rubble"]
const CAT_PROPS := ["chest_prop", "torch", "lever_base"]
const MODES := [["select", "Selecionar"], ["floor", "Trocar chao"],
	["structure", "Paredes/Colunas"], ["obstacle", "Obstaculos"],
	["prop", "Props"], ["glb", "Modelos GLB"], ["stairs", "Escada"],
	["erase", "Apagar"]]
const SPAWN_KEYS := [["K", "Heroi"], ["M", "Maga"], ["W", "Druida"],
	["g", "Goblin"], ["a", "Arqueiro"], ["B", "Chefe"]]

var active := false
var env: Node = null
var mode := "select"
var cat_item := {}          # modo -> indice do item ativo na categoria
var spawn_key := "K"
var glb_list: Array = []
var selected_key = null     # Vector3i da peca selecionada (instancia)
var _pending_stair = null   # primeira celula do par de escada

var edits := {"props": [], "glbs": [], "floors": [], "stairs": [],
	"spawns": {}}
var _placed := {}           # Vector3i -> {node, kind, data, fit}
var _floor_overrides := {}  # Vector3i -> {node, data} (troca de piso)
var _spawn_marks := {}
var _ui: CanvasLayer = null
var _cursor_quad: MeshInstance3D = null
var _hover_cell = null
var _icon_cache := {}       # id -> ImageTexture
var _icon_queue: Array = []

func _ready() -> void:
	_scan_glbs()
	load_edits()

func begin_session(environment: Node) -> void:
	env = environment
	apply_edits_to(environment)

# ------------------------------------------------------------ entrada ------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_F1:
		_toggle()
		get_viewport().set_input_as_handled()
		return
	if not active or env == null:
		return
	if event is InputEventMouseMotion:
		_update_hover(_pick_cell(event.position))
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_apply_tool(_pick_cell(event.position))
			MOUSE_BUTTON_RIGHT:
				_erase_at(_pick_cell(event.position))
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_Q:
				_rotate_selected(-90.0)
			KEY_E:
				_rotate_selected(90.0)
			KEY_G:
				_cycle_mode(1)
			KEY_ESCAPE:
				_select(null)

func _toggle() -> void:
	active = not active
	selected_key = null
	_pending_stair = null
	if active:
		_build_ui()
	else:
		_teardown_ui()
	EventBus.log_msg.emit("Editor de mapa %s." %
			["ABERTO (turnos em espera)" if active else "fechado"], "#7fd4ff")

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

func _cycle_mode(d: int) -> void:
	var names: Array = []
	for m in MODES:
		names.append(m[0])
	mode = names[(names.find(mode) + d + names.size()) % names.size()]
	_refresh_ui()

func _cat_items(mode_name: String) -> Array:
	match mode_name:
		"floor": return CAT_FLOORS
		"structure": return CAT_WALLS
		"obstacle": return CAT_OBSTACLES
		"prop": return CAT_PROPS
		"glb": return glb_list
	return []

func _active_item(mode_name: String) -> int:
	return cat_item.get(mode_name, 0)

# ------------------------------------------------------------- selecao -----

func _select(key) -> void:
	selected_key = key
	_refresh_transform_ui()

func _sel_entry() -> Variant:
	if selected_key != null and _placed.has(selected_key):
		return _placed[selected_key]
	return null

func _apply_transform(e, rot: float, su: float, adv: Vector3, fit: float) -> void:
	e["node"].rotation.y = deg_to_rad(rot)
	e["node"].scale = Vector3.ONE * su * adv * fit

func _rotate_selected(delta_deg: float) -> void:
	var e = _sel_entry()
	if e == null:
		return
	e["data"]["rot"] = fposmod(float(e["data"].get("rot", 0.0)) + delta_deg, 360.0)
	_apply_transform(e, e["data"]["rot"], float(e["data"].get("s", 1.0)),
			_adv_v(e["data"]), float(e.get("fit", 1.0)))

func _set_uniform(v: float) -> void:
	var e = _sel_entry()
	if e == null:
		return
	e["data"]["s"] = v
	_apply_transform(e, float(e["data"].get("rot", 0.0)), v,
			_adv_v(e["data"]), float(e.get("fit", 1.0)))

func _set_axis(axis: int, v: float) -> void:
	var e = _sel_entry()
	if e == null:
		return
	var adv: Array = e["data"].get("adv", [1, 1, 1])
	adv[axis] = v
	_apply_transform(e, float(e["data"].get("rot", 0.0)),
			float(e["data"].get("s", 1.0)),
			Vector3(float(adv[0]), float(adv[1]), float(adv[2])),
			float(e.get("fit", 1.0)))

# ------------------------------------------------------------- ferramentas --

func _apply_tool(c) -> void:
	if c == null:
		return
	match mode:
		"select":
			if _placed.has(c):
				_select(c)
			elif BoardGrid.stair_links.has(c):
				EventBus.log_msg.emit("Escada: selecione os degraus colocados.", "#ffb84d")
			else:
				_select(null)
		"floor":
			_place_floor(_cat_items("floor")[_active_item("floor")], c)
		"structure":
			_place_piece(_cat_items("structure")[_active_item("structure")], c,
					"struct")
		"obstacle":
			_place_piece("rubble", c, "struct")
		"prop":
			_place_piece(_cat_items("prop")[_active_item("prop")], c, "prop")
		"glb":
			if not glb_list.is_empty():
				_place_glb(glb_list[_active_item("glb")], c)
		"stairs":
			_stairs_click(c)
		"erase":
			_erase_at(c)

func _floor_node(c: Vector3i) -> Node3D:
	return env.get_node_or_null("Floor%d" % c.z)

func _register(kind: String, node: Node3D, c: Vector3i, data: Dictionary,
		fit := 1.0) -> void:
	node.position = BoardGrid.world_pos(c)
	node.rotation.y = deg_to_rad(float(data.get("rot", 0.0)))
	node.scale = Vector3.ONE * float(data.get("s", 1.0)) \
			* _adv_v(data) * fit
	_placed[c] = {"node": node, "kind": kind, "data": data, "fit": fit}

func _place_piece(id: String, c: Vector3i, kind: String) -> void:
	if _placed.has(c):
		EventBus.log_msg.emit("Celula ja ocupada pelo editor.", "#ff6b6b")
		return
	if not BoardGrid.is_walkable(c):
		EventBus.log_msg.emit("So sobre casas andaveis.", "#ff6b6b")
		return
	var piece := TilePiece.build(id)
	if piece == null:
		return
	var fl := _floor_node(c)
	if fl == null:
		piece.free()
		return
	fl.add_child(piece)
	_register(kind, piece, c, {"id": id, "c": [c.x, c.y, c.z],
			"rot": 0.0, "s": 1.0, "adv": [1, 1, 1]})
	# Pecas estruturais alteram o grid (bloqueio) pela tabela do catalogo;
	# props decorativos nao mexem no pathing.
	if kind == "struct":
		var meta: Dictionary = TilePiece.PROPS.get(id, {})
		BoardGrid.set_tile(c, meta.get("w", true), BoardGrid.tiles[c]["losb"])
	_select(c)
	EventBus.log_msg.emit("%s em %s" % [id, c], "#7fd4ff")

func _place_floor(id: String, c: Vector3i) -> void:
	if not BoardGrid.is_walkable(c):
		EventBus.log_msg.emit("So sobre casas andaveis.", "#ff6b6b")
		return
	# Troca SOMENTE o piso da celula: overrides de piso vivem em registro
	# proprio, preservando prop/obstaculo ja colocado ali.
	if _floor_overrides.has(c):
		_floor_overrides[c]["node"].queue_free()
	var piece := TilePiece.build(id)
	if piece == null:
		return
	var fl := _floor_node(c)
	if fl == null:
		piece.free()
		return
	fl.add_child(piece)
	piece.position = BoardGrid.world_pos(c) + Vector3(0, 0.02, 0)
	_floor_overrides[c] = {"node": piece,
			"data": {"id": id, "c": [c.x, c.y, c.z]}}
	EventBus.log_msg.emit("Piso -> %s em %s" % [id, c], "#7fd4ff")

func _place_glb(path: String, c: Vector3i) -> void:
	if _placed.has(c):
		EventBus.log_msg.emit("Celula ja ocupada pelo editor.", "#ff6b6b")
		return
	if not BoardGrid.is_walkable(c):
		EventBus.log_msg.emit("So sobre casas andaveis.", "#ff6b6b")
		return
	var ps: PackedScene = load(path)
	if ps == null:
		return
	var inst: Node3D = ps.instantiate()
	var box := AABB()
	for m in _find_meshes(inst):
		box = box.merge(m.get_aabb())
	var holder := Node3D.new()
	holder.add_child(inst)
	var fl := _floor_node(c)
	if fl == null:
		holder.free()
		return
	fl.add_child(holder)
	var fit := 1.0
	if box.size.y > 0.001:
		fit = 1.4 / box.size.y
		inst.position = -box.get_center() * fit
	_register("glb", holder, c, {"p": path, "c": [c.x, c.y, c.z],
			"rot": 0.0, "s": 1.0, "adv": [1, 1, 1]}, fit)
	_select(c)
	EventBus.log_msg.emit("GLB em %s (roda=escala, Q/E=gira)" % c, "#7fd4ff")

func _find_meshes(n: Node) -> Array:
	var out: Array = []
	if n is MeshInstance3D:
		out.append(n)
	for ch in n.get_children():
		out.append_array(_find_meshes(ch))
	return out

func _stairs_click(c: Vector3i) -> void:
	if _pending_stair == null:
		_pending_stair = c
		EventBus.log_msg.emit("Escada: base em %s. Clique no topo (outro andar)." % c,
				"#ffd166")
		return
	var a: Vector3i = _pending_stair
	_pending_stair = null
	if a == c or a.z == c.z:
		EventBus.log_msg.emit("Par invalido: precisa de andares diferentes.", "#ff6b6b")
		return
	if BoardGrid.stair_links.has(a) or BoardGrid.stair_links.has(c):
		EventBus.log_msg.emit("Uma das celulas ja tem escada.", "#ff6b6b")
		return
	BoardGrid.add_stair_link(a, c)
	for pair in [[a, "stairs_prop"], [c, "stairs_top"]]:
		var pc: Vector3i = pair[0]
		var piece := TilePiece.build(pair[1])
		var fl := _floor_node(pc)
		if fl != null:
			fl.add_child(piece)
			_register("stair", piece, pc, {"pair": [a, c],
					"c": [pc.x, pc.y, pc.z]})
	edits["stairs"].append([[a.x, a.y, a.z], [c.x, c.y, c.z]])
	EventBus.log_msg.emit("Escada criada: %s <-> %s" % [a, c], "#8fdc7f")

func _set_spawn(key: String, c: Vector3i) -> void:
	edits["spawns"][key] = [c.x, c.y, c.z]
	_draw_spawn_mark(key, c)
	EventBus.log_msg.emit("Spawn %s = %s (aplica ao reiniciar)" % [key, c], "#ffd166")

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
		var e = _placed[c]
		e["node"].queue_free()
		if e["kind"] == "struct":
			BoardGrid.set_tile(c, true,
					BoardGrid.tiles[c]["losb"] if BoardGrid.tiles.has(c) else false)
		if e["kind"] == "stair":
			var other = BoardGrid.stair_pair(c)
			BoardGrid.stair_links.erase(c)
			for kk in _placed.keys().duplicate():
				if _placed[kk]["kind"] == "stair" and kk != c:
					_placed[kk]["node"].queue_free()
					_placed.erase(kk)
			BoardGrid.stair_links.erase(other) if other != c else null
			_remove_stair_from_edits(c)
		if selected_key != null and selected_key == c:
			_select(null)
		_placed.erase(c)
		EventBus.log_msg.emit("Item removido em %s" % c, "#ffb84d")
	elif _floor_overrides.has(c):
		_floor_overrides[c]["node"].queue_free()
		_floor_overrides.erase(c)
		EventBus.log_msg.emit("Piso restaurado em %s" % c, "#ffb84d")
	elif _spawn_marks.has(c):
		_spawn_marks[c].queue_free()
		_spawn_marks.erase(c)
		for k in edits["spawns"].keys():
			var v: Array = edits["spawns"][k]
			if Vector3i(v[0], v[1], v[2]) == c:
				edits["spawns"].erase(k)

func _remove_stair_from_edits(c: Vector3i) -> void:
	for i in range(edits["stairs"].size() - 1, -1, -1):
		var pr: Array = edits["stairs"][i]
		var a := Vector3i(pr[0][0], pr[0][1], pr[0][2])
		var b := Vector3i(pr[1][0], pr[1][1], pr[1][2])
		if a == c or b == c:
			edits["stairs"].remove_at(i)

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
	var sel: bool = _hover_cell == selected_key
	var mat: StandardMaterial3D = _cursor_quad.material_override
	mat.albedo_color = Color(0.3, 1.0, 0.5, 0.45) if sel \
			else Color(1.0, 0.83, 0.2, 0.35)
	_cursor_quad.visible = true
	_cursor_quad.position = BoardGrid.world_pos(c) + Vector3(0, 0.14, 0)

# ------------------------------------------------------- persistencia ------

func _save_path() -> String:
	return SAVE_NAME % (env.map_id if env != null else "default")

func save_edits() -> void:
	var out := {"props": [], "glbs": [], "floors": [], "stairs": [],
			"spawns": edits["spawns"]}
	for c in _placed:
		var e = _placed[c]
		match e["kind"]:
			"struct":
				out["props"].append(_merge({"id": e["data"]["id"],
						"struct": true}, e["data"]))
			"prop":
				out["props"].append(e["data"])
			"glb":
				out["glbs"].append(e["data"])
	for c in _floor_overrides:
		out["floors"].append(_floor_overrides[c]["data"])
	out["stairs"] = edits["stairs"]
	var f := FileAccess.open("user://" + _save_path(), FileAccess.WRITE)
	if f == null:
		EventBus.log_msg.emit("Editor: falha ao salvar!", "#ff6b6b")
		return
	f.store_string(JSON.stringify(out, "\t"))
	f.close()
	# Validacao D14 (portas desobstruidas): avisa, nao trava.
	env._validate_doors()
	EventBus.log_msg.emit("Mapa salvo: %s (validacao de portas executada)" %
			OS.get_user_data_dir().path_join(_save_path()), "#8fdc7f")

func _merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := b.duplicate()
	for k in a:
		out[k] = a[k]
	return out

func load_edits() -> void:
	var p := "user://" + _save_path()
	if not FileAccess.file_exists(p):
		return
	var f := FileAccess.open(p, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		edits = parsed

## Reaplica edicoes salvas por cima do mapa recem-gerado (instancias).
func apply_edits_to(environment: Node) -> void:
	env = environment
	for d in edits.get("props", []):
		var c := Vector3i(d["c"][0], d["c"][1], d["c"][2])
		_silent_place(_item_id(d), c, _norm_item(d))
	for d in edits.get("glbs", []):
		var c := Vector3i(d["c"][0], d["c"][1], d["c"][2])
		_silent_glb(d.get("p", ""), c, _norm_item(d))
	for d in edits.get("floors", []):
		_silent_floor(_item_id(d), Vector3i(d["c"][0], d["c"][1], d["c"][2]))
	for pr in edits.get("stairs", []):
		var a := Vector3i(pr[0][0], pr[0][1], pr[0][2])
		var b := Vector3i(pr[1][0], pr[1][1], pr[1][2])
		if not BoardGrid.stair_links.has(a) and not BoardGrid.stair_links.has(b):
			BoardGrid.add_stair_link(a, b)
			for pair in [[a, "stairs_prop"], [b, "stairs_top"]]:
				var pc: Vector3i = pair[0]
				var piece := TilePiece.build(pair[1])
				var fl := _floor_node(pc)
				if fl != null:
					fl.add_child(piece)
					_register("stair", piece, pc, {"pair": [a, b],
							"c": [pc.x, pc.y, pc.z]})
	for k in edits["spawns"].keys():
		var v: Array = edits["spawns"][k]
		environment.spawns[k] = [Vector3i(v[0], v[1], v[2])]
		_draw_spawn_mark(k, Vector3i(v[0], v[1], v[2]))
	var total: int = int(edits.get("props", []).size()) \
			+ int(edits.get("glbs", []).size()) \
			+ int(edits.get("floors", []).size()) \
			+ int(edits.get("stairs", []).size()) \
			+ int(edits["spawns"].size())
	if total > 0:
		EventBus.log_msg.emit("Edicoes de mapa carregadas (%d)." % total, "#7fd4ff")

## Compat v1->v2: "t" antigo virou "id", "yaw" virou "rot".
func _item_id(d: Dictionary) -> String:
	return str(d.get("id", d.get("t", "rubble")))

func _norm_item(d: Dictionary) -> Dictionary:
	var out := d.duplicate()
	out["id"] = _item_id(out)
	if out.has("t"):
		out.erase("t")
	if out.has("yaw") and not out.has("rot"):
		out["rot"] = out["yaw"]
		out.erase("yaw")
	if not out.has("rot"):
		out["rot"] = 0.0
	if not out.has("s"):
		out["s"] = 1.0
	if not out.has("adv"):
		out["adv"] = [1, 1, 1]
	return out

func _silent_place(id: String, c: Vector3i, data: Dictionary) -> void:
	if _placed.has(c) or not BoardGrid.is_walkable(c):
		return
	var piece := TilePiece.build(id)
	if piece == null:
		return
	var fl := _floor_node(c)
	if fl == null:
		piece.free()
		return
	fl.add_child(piece)
	data["c"] = [c.x, c.y, c.z]
	_register("struct" if data.get("struct", false) else "prop", piece, c, data)
	if data.get("struct", false):
		var meta: Dictionary = TilePiece.PROPS.get(id, {})
		BoardGrid.set_tile(c, meta.get("w", true), BoardGrid.tiles[c]["losb"])

func _silent_glb(path: String, c: Vector3i, data: Dictionary) -> void:
	if path == "" or _placed.has(c) or not BoardGrid.is_walkable(c):
		return
	var ps: PackedScene = load(path)
	if ps == null:
		return
	var inst: Node3D = ps.instantiate()
	var box := AABB()
	for m in _find_meshes(inst):
		box = box.merge(m.get_aabb())
	var holder := Node3D.new()
	holder.add_child(inst)
	var fl := _floor_node(c)
	if fl == null:
		holder.free()
		return
	fl.add_child(holder)
	var fit := 1.0
	if box.size.y > 0.001:
		fit = 1.4 / box.size.y
		inst.position = -box.get_center() * fit
	data["c"] = [c.x, c.y, c.z]
	_register("glb", holder, c, data, fit)

func _silent_floor(id: String, c: Vector3i) -> void:
	var piece := TilePiece.build(id)
	if piece == null:
		return
	var fl := _floor_node(c)
	if fl == null:
		piece.free()
		return
	fl.add_child(piece)
	piece.position = BoardGrid.world_pos(c) + Vector3(0, 0.02, 0)

# -------------------------------------------------------------------- UI ---

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 95
	add_child(_ui)
	var sc := ScrollContainer.new()
	sc.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	sc.offset_left = -320
	sc.offset_top = 12
	sc.offset_right = -12
	sc.offset_bottom = -12
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_ui.add_child(sc)
	var vb := VBoxContainer.new()
	vb.name = "VB"
	vb.custom_minimum_size = Vector2(295, 0)
	sc.add_child(vb)
	_add_label(vb, "title", "EDITOR DE MAPA (F1 fecha)")
	for m in MODES:
		var b := Button.new()
		b.name = "mode_" + m[0]
		b.pressed.connect(func() -> void: mode = m[0]; _refresh_ui())
		vb.add_child(b)
	_add_label(vb, "lib_title", "--- Biblioteca ---")
	for cat in [["structure", CAT_WALLS], ["obstacle", CAT_OBSTACLES],
			["prop", CAT_PROPS], ["floor", CAT_FLOORS]]:
		_add_label(vb, "cat_" + cat[0], cat[0])
		for i in cat[1].size():
			var id: String = cat[1][i]
			var b := Button.new()
			b.name = "item_%s_%d" % [cat[0], i]
			b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.pressed.connect(func() -> void:
				mode = cat[0]; cat_item[cat[0]] = i; _refresh_ui())
			vb.add_child(b)
	_add_label(vb, "cat_glb", "modelos GLB")
	for i in glb_list.size():
		var b := Button.new()
		b.name = "item_glb_%d" % i
		b.pressed.connect(func() -> void:
			mode = "glb"; cat_item["glb"] = i; _refresh_ui())
		vb.add_child(b)
	_add_label(vb, "cat_spawns", "spawns (clique = marca)")
	for sk in SPAWN_KEYS:
		var b := Button.new()
		b.name = "spawn_" + sk[0]
		b.pressed.connect(func() -> void:
			spawn_key = sk[0]
			if _hover_cell != null:
				_set_spawn(sk[0], _hover_cell)
			_refresh_ui())
		vb.add_child(b)
	_add_label(vb, "tf_title", "--- Transformacao ---")
	_add_label(vb, "tf_sel", "nenhuma peca selecionada")
	var rot_row := HBoxContainer.new()
	rot_row.name = "tf_rot"
	vb.add_child(rot_row)
	var bm := Button.new(); bm.text = "-90 (Q)"
	bm.pressed.connect(func() -> void: _rotate_selected(-90.0))
	rot_row.add_child(bm)
	var bp := Button.new(); bp.text = "+90 (E)"
	bp.pressed.connect(func() -> void: _rotate_selected(90.0))
	rot_row.add_child(bp)
	_add_label(vb, "tf_s_label", "Escala uniforme")
	var sl := HSlider.new()
	sl.name = "tf_s"
	sl.min_value = 0.3
	sl.max_value = 3.0
	sl.step = 0.05
	sl.value = 1.0
	sl.custom_minimum_size = Vector2(280, 20)
	sl.value_changed.connect(func(v: float) -> void: _set_uniform(v))
	vb.add_child(sl)
	var adv_cb := CheckBox.new()
	adv_cb.name = "tf_adv"
	adv_cb.text = "Eixos independentes (avancado - distorce!)"
	adv_cb.pressed.connect(func() -> void: _refresh_transform_ui())
	vb.add_child(adv_cb)
	for ax in [["X", 0], ["Y", 1], ["Z", 2]]:
		_add_label(vb, "tf_ax%d_l" % ax[1], "")
		var sa := HSlider.new()
		sa.name = "tf_ax%d" % ax[1]
		sa.min_value = 0.3
		sa.max_value = 3.0
		sa.step = 0.05
		sa.custom_minimum_size = Vector2(280, 20)
		var axis: int = ax[1]
		sa.value_changed.connect(func(v: float) -> void: _set_axis(axis, v))
		vb.add_child(sa)
	var del := Button.new()
	del.name = "tf_del"
	del.text = "EXCLUIR peca selecionada"
	del.pressed.connect(func() -> void: _erase_at(selected_key))
	vb.add_child(del)
	_add_label(vb, "hint", "Clique: usar ferramenta | Direito: apagar\n" +
			"Q/E gira | G troca modo | Esc: desselecionar")
	var save_b := Button.new()
	save_b.text = "SALVAR MAPA"
	save_b.pressed.connect(save_edits)
	vb.add_child(save_b)
	_refresh_ui()
	_refresh_transform_ui()
	_queue_icons()

func _add_label(vb: VBoxContainer, name_: String, txt: String) -> void:
	var l := Label.new()
	l.name = name_
	l.text = txt
	vb.add_child(l)

func _q(n: String) -> Control:
	if _ui == null:
		return null
	return _ui.get_node_or_null(NodePath("ScrollContainer/VB/" + n))

func _refresh_ui() -> void:
	if _ui == null:
		return
	for m in MODES:
		var b: Control = _q("mode_" + m[0])
		if b is Button:
			b.text = ("[x] " if mode == m[0] else "[  ] ") + m[1]
	for cat in [["structure", CAT_WALLS], ["obstacle", CAT_OBSTACLES],
			["prop", CAT_PROPS], ["floor", CAT_FLOORS], ["glb", glb_list]]:
		for i in cat[1].size():
			var b: Control = _q("item_%s_%d" % [cat[0], i])
			if b is Button:
				var id = cat[1][i]
				var label: String = id.get_file() if cat[0] == "glb" else str(id)
				var mark: bool = mode == cat[0] and _active_item(cat[0]) == i
				b.text = ("[x] " if mark else "[  ] ") + label
				if _icon_cache.has(label):
					b.icon = _icon_cache[label]
	for sk in SPAWN_KEYS:
		var b: Control = _q("spawn_" + sk[0])
		if b is Button:
			var extra := ""
			if edits["spawns"].has(sk[0]):
				var v: Array = edits["spawns"][sk[0]]
				extra = " @%s,%s,%s" % [v[0], v[1], v[2]]
			b.text = ("[x] " if spawn_key == sk[0] else "[  ] ") \
					+ "Spawn " + sk[1] + extra

func _refresh_transform_ui() -> void:
	var l: Control = _q("tf_sel")
	var e = _sel_entry()
	var has := e != null
	if l is Label:
		l.text = "selecionado: %s em %s" % [
				e["data"].get("id", e["data"].get("p", "?")).get_file()
				if has else "-", str(selected_key) if has else "-"]
	var adv: Control = _q("tf_adv")
	var show_ax: bool = adv != null and adv is CheckBox \
			and adv.button_pressed and has
	for ax in [0, 1, 2]:
		var lab: Control = _q("tf_ax%d_l" % ax)
		var sld: Control = _q("tf_ax%d" % ax)
		if lab is Label:
			lab.visible = show_ax
			lab.text = ["Eixo X", "Eixo Y (altura)", "Eixo Z"][ax]
		if sld != null:
			sld.visible = show_ax
			if has and sld is HSlider:
				sld.set_value_no_signal(e["data"].get("adv", [1, 1, 1])[ax])
	if has:
		var sld: Control = _q("tf_s")
		if sld is HSlider:
			sld.set_value_no_signal(e["data"].get("s", 1.0))
	_update_hover(_hover_cell)

# Thumbnails: mesmo principio do retrato de personagem - um SubViewport
# rende a peca uma vez; resultado vira icone do botao (sem arte 2D).
func _queue_icons() -> void:
	for cat in [CAT_WALLS, CAT_OBSTACLES, CAT_PROPS, CAT_FLOORS]:
		for id in cat:
			if not _icon_cache.has(id):
				_icon_queue.append(id)

func _process(_delta: float) -> void:
	if _icon_queue.is_empty() or not active:
		return
	var id: String = _icon_queue.pop_front()
	if not _icon_cache.has(id):
		var tex = await _render_icon_scene(id)
		if tex != null:
			_icon_cache[id] = tex
			_refresh_ui()

func _render_icon_scene(id: String) -> Texture2D:
	var piece := TilePiece.build(id)
	if piece == null:
		return null
	var vp := SubViewport.new()
	vp.size = Vector2i(72, 72)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)
	var root := Node3D.new()
	vp.add_child(root)
	root.add_child(piece)
	var aabb := AABB()
	for m in _find_meshes(piece):
		aabb = aabb.merge(m.get_aabb())
	if aabb.size.length() < 0.001:
		aabb = AABB(Vector3(-0.5, 0, -0.5), Vector3.ONE)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.position = aabb.get_center() + Vector3(0.9, 0.9, 1.1) \
			* aabb.size.length()
	cam.look_at(aabb.get_center())
	cam.near = 0.01
	cam.far = aabb.size.length() * 6.0
	var sun := DirectionalLight3D.new()
	root.add_child(sun)
	sun.rotation_degrees = Vector3(-45, 30, 0)
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	piece.queue_free()
	return ImageTexture.create_from_image(img)

# ------------------------------------------------------- scan de modelos ---

func _scan_glbs() -> void:
	glb_list.clear()
	var stack: Array = ["res://src/assets", "res://assets/models"]
	while not stack.is_empty():
		var dir_path: String = stack.pop_back()
		var d := DirAccess.open(dir_path)
		if d == null:
			continue
		d.list_dir_begin()
		var fn := d.get_next()
		while fn != "":
			var full := dir_path.path_join(fn)
			if d.current_is_dir():
				stack.append(full)
			elif fn.get_extension() == "glb":
				glb_list.append(full)
			fn = d.get_next()
	glb_list.sort()

## adv chega como Array (JSON); Vector3 nao tem construtor de Array.
func _adv_v(d: Dictionary) -> Vector3:
	var a: Array = d.get("adv", [1, 1, 1])
	return Vector3(float(a[0]), float(a[1]), float(a[2]))

func _teardown_ui() -> void:
	if _ui != null:
		_ui.queue_free()
		_ui = null
