extends Control
class_name MapEditor
## Fase 6 — Editor reestruturado (Seção 7)

signal grid_generated

var _board: Node = null

# — UI refs (criados em _build_ui)
var _edit_name: LineEdit
var _opt_type: OptionButton
var _opt_func: OptionButton
var _list_results: ItemList
var _list_placed: ItemList
var _lbl_selected: Label
var _opt_rot: OptionButton
var _spin_scale: SpinBox
var _chk_adv: CheckButton
var _spin_sx: SpinBox
var _spin_sy: SpinBox
var _spin_sz: SpinBox
var _btn_generate: Button
var _btn_remove: Button
var _label_stats: Label
var _chk_edit_mode: CheckButton

# — dados
var _catalog: Array = []
var _filtered: Array = []
var _placed: Array = [] # Array[Dictionary {node:Node, entry:Dictionary, cell:Vector3i, rot:int, scale:Vector3}]
var _selected_catalog: int = -1
var _selected_placed: int = -1

const CD = preload("res://src/resources/character_definition.gd")
const TYPES: Array[String] = ["Todos", "Chão", "Parede", "Porta", "Coluna", "Obstáculo", "Personagem", "Prop decorativo"]
const FUNCS: Array[String] = ["Todas", "Bloqueia movimento", "Bloqueia visão", "Elevação", "Decorativo", "Spawn de personagem"]

func _ready() -> void:
	_build_catalog()
	_build_ui()
	_apply_filters()
	_refresh_placed_list()
	# tenta achar board
	if _board == null:
		await get_tree().process_frame
		_board = _find_board()
	_update_stats()

func _find_board() -> Node:
	var b: Node = get_tree().get_first_node_in_group("board") as Node
	if b: return b
	if get_tree().current_scene:
		return get_tree().current_scene.find_child("Board", true, false) as Node
	return null

func bind_board(board: Node) -> void:
	_board = board
	_update_stats()
	_refresh_placed_list()

func _build_catalog() -> void:
	_catalog.clear()
	# — Chão
	_catalog.append({"name":"Chão Grama","type":"Chão","funcs":["Decorativo"],"color":Color(0.32,0.62,0.30),"scene":"res://src/board/floor_piece.tscn","res":"grass"})
	_catalog.append({"name":"Chão Pedra","type":"Chão","funcs":["Decorativo"],"color":Color(0.60,0.60,0.62),"scene":"res://src/board/floor_piece.tscn","res":"stone"})
	# — Parede
	_catalog.append({"name":"Parede","type":"Parede","funcs":["Bloqueia movimento","Bloqueia visão"],"color":Color(0.68,0.64,0.58),"scene":"res://src/board/wall_piece.tscn"})
	# — Portas
	_catalog.append({"name":"Porta Fechada","type":"Porta","funcs":["Bloqueia movimento","Bloqueia visão"],"color":Color(0.55,0.35,0.15),"scene":"res://src/board/door_piece.tscn","state":0})
	_catalog.append({"name":"Porta Aberta","type":"Porta","funcs":["Decorativo"],"color":Color(0.62,0.42,0.20),"scene":"res://src/board/door_piece.tscn","state":1})
	_catalog.append({"name":"Porta Trancada","type":"Porta","funcs":["Bloqueia movimento","Bloqueia visão"],"color":Color(0.85,0.15,0.15),"scene":"res://src/board/door_piece.tscn","state":2})
	# — Coluna
	_catalog.append({"name":"Coluna","type":"Coluna","funcs":["Bloqueia movimento","Bloqueia visão"],"color":Color(0.72,0.72,0.70),"scene":"res://src/board/column_piece.tscn"})
	# — Obstáculos (tabela)
	_catalog.append({"name":"Decor Pequeno","type":"Obstáculo","funcs":["Decorativo"],"color":Color(0.45,0.75,0.45),"scene":"res://src/board/prop_obstacle.tscn","otype":0})
	_catalog.append({"name":"Obstáculo Grande","type":"Obstáculo","funcs":["Bloqueia movimento","Bloqueia visão"],"color":Color(0.45,0.45,0.48),"scene":"res://src/board/prop_obstacle.tscn","otype":1})
	_catalog.append({"name":"Mureta (meia +2 CA)","type":"Obstáculo","funcs":["Bloqueia movimento","Decorativo"],"color":Color(0.78,0.70,0.55),"scene":"res://src/board/prop_obstacle.tscn","otype":2})
	_catalog.append({"name":"Muro (alto)","type":"Obstáculo","funcs":["Bloqueia movimento","Bloqueia visão"],"color":Color(0.35,0.35,0.40),"scene":"res://src/board/prop_obstacle.tscn","otype":3})
	# — Personagens
	_catalog.append({"name":"Cavaleiro","type":"Personagem","funcs":["Spawn de personagem","Bloqueia movimento"],"color":Color(0.20,0.45,0.85),"scene":"res://src/units/board_unit.tscn","char":"cavaleiro"})
	_catalog.append({"name":"Maga Elara","type":"Personagem","funcs":["Spawn de personagem"],"color":Color(0.25,0.60,0.85),"scene":"res://src/units/board_unit.tscn","char":"maga"})
	_catalog.append({"name":"Druida Rowan","type":"Personagem","funcs":["Spawn de personagem"],"color":Color(0.30,0.65,0.35),"scene":"res://src/units/board_unit.tscn","char":"druida"})
	_catalog.append({"name":"Goblin Guerreiro","type":"Personagem","funcs":["Spawn de personagem","Bloqueia movimento"],"color":Color(0.80,0.25,0.22),"scene":"res://src/units/board_unit.tscn","char":"goblin_guerreiro"})
	_catalog.append({"name":"Goblin Arqueiro","type":"Personagem","funcs":["Spawn de personagem"],"color":Color(0.85,0.35,0.25),"scene":"res://src/units/board_unit.tscn","char":"goblin_arqueiro"})
	_catalog.append({"name":"Boss Ancestral","type":"Personagem","funcs":["Spawn de personagem","Bloqueia movimento","Bloqueia visão"],"color":Color(0.55,0.25,0.78),"scene":"res://src/units/board_unit.tscn","char":"boss"})

func _build_ui() -> void:
	var panel: Panel = get_node_or_null("Panel") as Panel
	if panel == null:
		panel = Panel.new()
		panel.name = "Panel"
		add_child(panel)
		panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var vbox: VBoxContainer = panel.get_node_or_null("VBox") as VBoxContainer
	if vbox == null:
		# limpa filhos antigos
		for c: Node in panel.get_children():
			c.queue_free()
		vbox = VBoxContainer.new()
		vbox.name = "VBox"
		panel.add_child(vbox)
		vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		vbox.offset_left = 12
		vbox.offset_top = 12
		vbox.offset_right = -12
		vbox.offset_bottom = -12
	else:
		for c: Node in vbox.get_children():
			c.queue_free()
	# — Título
	var title: Label = Label.new()
	title.text = "Painel de Edição — FASE 6"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	# — Modo edição toggle
	_chk_edit_mode = CheckButton.new()
	_chk_edit_mode.text = "Modo Edição (clique no tabuleiro coloca peça)"
	_chk_edit_mode.button_pressed = true
	_chk_edit_mode.toggled.connect(func(pressed: bool) -> void: print("[MapEditor] modo edicao ", pressed))
	vbox.add_child(_chk_edit_mode)
	# — Filtros
	var lbl_f: Label = Label.new()
	lbl_f.text = "Filtros"
	vbox.add_child(lbl_f)
	_edit_name = LineEdit.new()
	_edit_name.placeholder_text = "Filtro por NOME (busca texto)"
	_edit_name.text_submitted.connect(func(_t: String) -> void: _apply_filters())
	_edit_name.text_changed.connect(func(_t: String) -> void: _apply_filters())
	vbox.add_child(_edit_name)
	_opt_type = OptionButton.new()
	for t: String in TYPES:
		_opt_type.add_item(t)
	_opt_type.selected = 0
	_opt_type.item_selected.connect(func(_i: int) -> void: _apply_filters())
	vbox.add_child(_opt_type)
	var lbl_type: Label = Label.new()
	lbl_type.text = "Filtro por TIPO"
	vbox.add_child(lbl_type)
	# move opt_type after label? já adicionado
	_opt_func = OptionButton.new()
	for f: String in FUNCS:
		_opt_func.add_item(f)
	_opt_func.selected = 0
	_opt_func.item_selected.connect(func(_i: int) -> void: _apply_filters())
	vbox.add_child(_opt_func)
	var lbl_func: Label = Label.new()
	lbl_func.text = "Filtro por FUNÇÃO"
	vbox.add_child(lbl_func)
	# — Lista resultados
	var lbl_res: Label = Label.new()
	lbl_res.text = "Lista de resultados (nome + cor)"
	vbox.add_child(lbl_res)
	_list_results = ItemList.new()
	_list_results.custom_minimum_size = Vector2(0, 120)
	_list_results.item_selected.connect(_on_result_selected)
	vbox.add_child(_list_results)
	# — Peças já colocadas
	var lbl_placed: Label = Label.new()
	lbl_placed.text = "Peças já colocadas (clique para selecionar)"
	vbox.add_child(lbl_placed)
	_list_placed = ItemList.new()
	_list_placed.custom_minimum_size = Vector2(0, 80)
	_list_placed.item_selected.connect(_on_placed_selected)
	vbox.add_child(_list_placed)
	# — Transformação
	_lbl_selected = Label.new()
	_lbl_selected.text = "Nenhuma peça selecionada"
	vbox.add_child(_lbl_selected)
	var h_rot: HBoxContainer = HBoxContainer.new()
	var lbl_rot: Label = Label.new()
	lbl_rot.text = "Rotação (90°)"
	h_rot.add_child(lbl_rot)
	_opt_rot = OptionButton.new()
	_opt_rot.add_item("0°")
	_opt_rot.add_item("90°")
	_opt_rot.add_item("180°")
	_opt_rot.add_item("270°")
	_opt_rot.item_selected.connect(_on_rot_changed)
	h_rot.add_child(_opt_rot)
	vbox.add_child(h_rot)
	var h_scale: HBoxContainer = HBoxContainer.new()
	var lbl_sc: Label = Label.new()
	lbl_sc.text = "Escala uniforme"
	h_scale.add_child(lbl_sc)
	_spin_scale = SpinBox.new()
	_spin_scale.min_value = 0.5
	_spin_scale.max_value = 2.0
	_spin_scale.step = 0.1
	_spin_scale.value = 1.0
	_spin_scale.value_changed.connect(_on_scale_uniform_changed)
	h_scale.add_child(_spin_scale)
	vbox.add_child(h_scale)
	_chk_adv = CheckButton.new()
	_chk_adv.text = "Eixos independentes (avançado)"
	_chk_adv.toggled.connect(_on_adv_toggled)
	vbox.add_child(_chk_adv)
	var h_xyz: HBoxContainer = HBoxContainer.new()
	h_xyz.name = "HXYZ"
	_spin_sx = SpinBox.new()
	_spin_sx.min_value = 0.5; _spin_sx.max_value = 2.0; _spin_sx.step = 0.1; _spin_sx.value = 1.0
	_spin_sx.value_changed.connect(_on_scale_xyz_changed)
	h_xyz.add_child(_spin_sx)
	_spin_sy = SpinBox.new()
	_spin_sy.min_value = 0.5; _spin_sy.max_value = 2.0; _spin_sy.step = 0.1; _spin_sy.value = 1.0
	_spin_sy.value_changed.connect(_on_scale_xyz_changed)
	h_xyz.add_child(_spin_sy)
	_spin_sz = SpinBox.new()
	_spin_sz.min_value = 0.5; _spin_sz.max_value = 2.0; _spin_sz.step = 0.1; _spin_sz.value = 1.0
	_spin_sz.value_changed.connect(_on_scale_xyz_changed)
	h_xyz.add_child(_spin_sz)
	h_xyz.visible = false
	vbox.add_child(h_xyz)
	_btn_remove = Button.new()
	_btn_remove.text = "Remover peça selecionada"
	_btn_remove.pressed.connect(_on_remove)
	vbox.add_child(_btn_remove)
	# — Gerar Grid
	_btn_generate = Button.new()
	_btn_generate.text = "Gerar Grid"
	_btn_generate.pressed.connect(_on_generate_pressed)
	vbox.add_child(_btn_generate)
	_label_stats = Label.new()
	_label_stats.text = "BoardGrid: aguardando bake..."
	vbox.add_child(_label_stats)
	var hint: Label = Label.new()
	hint.text = "T: urso | G: grid | PgUp/Dn: andar | Clique: editar/mover"
	vbox.add_child(hint)

func _apply_filters() -> void:
	if _list_results == null:
		return
	_filtered.clear()
	var name_f: String = _edit_name.text.strip_edges().to_lower() if _edit_name else ""
	var type_f: String = TYPES[_opt_type.selected] if _opt_type else "Todos"
	var func_f: String = FUNCS[_opt_func.selected] if _opt_func else "Todas"
	for e: Dictionary in _catalog:
		if name_f != "" and not String(e["name"]).to_lower().contains(name_f):
			continue
		if type_f != "Todos" and String(e["type"]) != type_f:
			continue
		if func_f != "Todas" and not (func_f in (e["funcs"] as Array)):
			continue
		_filtered.append(e)
	_refresh_results_list()

func _refresh_results_list() -> void:
	if _list_results == null:
		return
	_list_results.clear()
	for e: Dictionary in _filtered:
		var idx: int = _list_results.add_item(String(e["name"]))
		var col: Color = e["color"] as Color
		_list_results.set_item_custom_bg_color(idx, Color(col.r, col.g, col.b, 0.25))
		_list_results.set_item_tooltip(idx, "%s | %s | %s" % [e["name"], e["type"], ", ".join(e["funcs"])])
	if _filtered.size() > 0 and _selected_catalog == -1:
		_list_results.select(0)
		_on_result_selected(0)

func _refresh_placed_list() -> void:
	if _list_placed == null:
		return
	_list_placed.clear()
	for i: int in range(_placed.size()):
		var p: Dictionary = _placed[i] as Dictionary
		var e: Dictionary = p["entry"] as Dictionary
		var cell: Vector3i = p["cell"] as Vector3i
		var txt: String = "%d: %s @ %s" % [i, e["name"], str(cell)]
		var idx: int = _list_placed.add_item(txt)
		var col: Color = e["color"] as Color
		_list_placed.set_item_custom_bg_color(idx, Color(col.r, col.g, col.b, 0.30))

func _on_result_selected(idx: int) -> void:
	_selected_catalog = idx
	_selected_placed = -1
	if _list_placed:
		_list_placed.deselect_all()
	var e: Dictionary = _filtered[idx] as Dictionary
	_lbl_selected.text = "Catálogo: %s (clique no tabuleiro para colocar)" % e["name"]
	# carrega transform padrão
	_opt_rot.selected = 0
	_spin_scale.value = 1.0
	_spin_sx.value = 1.0; _spin_sy.value = 1.0; _spin_sz.value = 1.0

func _on_placed_selected(idx: int) -> void:
	_selected_placed = idx
	_selected_catalog = -1
	if _list_results:
		_list_results.deselect_all()
	var p: Dictionary = _placed[idx] as Dictionary
	var e: Dictionary = p["entry"] as Dictionary
	var node: Node = p["node"] as Node
	_lbl_selected.text = "Selecionada: %s @ %s" % [e["name"], str(p["cell"])]
	# carrega valores atuais da peça (não reseta)
	var rot_steps: int = int(p.get("rot", 0))
	_opt_rot.selected = rot_steps
	var sc: Vector3 = p.get("scale", Vector3.ONE) as Vector3
	if is_equal_approx(sc.x, sc.y) and is_equal_approx(sc.y, sc.z):
		_spin_scale.value = sc.x
	else:
		_chk_adv.button_pressed = true
		_spin_sx.value = sc.x; _spin_sy.value = sc.y; _spin_sz.value = sc.z
	# destaca no tabuleiro (modula)
	_highlight_placed(node)

func _highlight_placed(node: Node) -> void:
	for p: Dictionary in _placed:
		var n: Node = p["node"] as Node
		if n and n.has_node("MeshInstance3D"):
			var mi: MeshInstance3D = n.get_node("MeshInstance3D") as MeshInstance3D
			if mi and mi.mesh and mi.mesh.surface_get_material(0):
				var mat: StandardMaterial3D = mi.mesh.surface_get_material(0) as StandardMaterial3D
				if n == node:
					mat.emission_enabled = true
					mat.emission = Color(1, 0.9, 0.3)
					mat.emission_energy_multiplier = 0.6
				else:
					mat.emission_enabled = false

func _on_rot_changed(idx: int) -> void:
	if _selected_placed == -1:
		return
	var p: Dictionary = _placed[_selected_placed] as Dictionary
	p["rot"] = idx
	var node: Node = p["node"] as Node
	if node:
		node.rotation.y = deg_to_rad(float(idx * 90))
		# para parede/porta, muda edge_dir
		if node.has_method("configure") or node.get("edge_dir") != null:
			var dirs: Array[String] = ["north","east","south","west"]
			var d: String = dirs[idx % 4]
			node.set("edge_dir", d)
			# re-aplica posição
			if node.has_method("_place_at_edge"):
				node.call("_place_at_edge")

func _on_scale_uniform_changed(val: float) -> void:
	if _chk_adv and _chk_adv.button_pressed:
		return
	if _selected_placed == -1:
		return
	var p: Dictionary = _placed[_selected_placed] as Dictionary
	p["scale"] = Vector3(val, val, val)
	var node: Node = p["node"] as Node
	if node:
		node.scale = Vector3(val, val, val)
		# protege orgânicas: escala uniforme evita distorção

func _on_adv_toggled(pressed: bool) -> void:
	var hxyz: Control = get_node_or_null("Panel/VBox/HXYZ") as Control
	if hxyz:
		hxyz.visible = pressed
	if not pressed and _selected_placed != -1:
		# volta para uniforme
		var v: float = _spin_scale.value
		_spin_sx.value = v; _spin_sy.value = v; _spin_sz.value = v
		_on_scale_uniform_changed(v)

func _on_scale_xyz_changed(_v: float) -> void:
	if not _chk_adv.button_pressed or _selected_placed == -1:
		return
	var p: Dictionary = _placed[_selected_placed] as Dictionary
	var sc: Vector3 = Vector3(_spin_sx.value, _spin_sy.value, _spin_sz.value)
	p["scale"] = sc
	var node: Node = p["node"] as Node
	if node:
		node.scale = sc

func _on_remove() -> void:
	if _selected_placed == -1:
		return
	var p: Dictionary = _placed[_selected_placed] as Dictionary
	var node: Node = p["node"] as Node
	if is_instance_valid(node):
		node.queue_free()
	_placed.remove_at(_selected_placed)
	_selected_placed = -1
	_lbl_selected.text = "Removida"
	_refresh_placed_list()

# — API para Main chamar ao clicar no tabuleiro
func handle_board_click(cell: Vector3i) -> bool:
	print("[MapEditor] handle_board_click ", cell, " modo=", _chk_edit_mode.button_pressed if _chk_edit_mode else false, " catalog=", _selected_catalog)
	if _chk_edit_mode == null or not _chk_edit_mode.button_pressed:
		return false
	# se tem peça selecionada na lista de colocadas e clicou em outro lugar? Não move, só coloca nova ou seleciona
	var existing: int = _find_placed_at(cell)
	if existing != -1:
		# seleciona existente (reselecionável)
		_list_placed.select(existing)
		_on_placed_selected(existing)
		return true
	if _selected_catalog == -1:
		# tenta selecionar por clique direto
		return false
	# coloca nova peça do catálogo na célula clicada
	var entry: Dictionary = _filtered[_selected_catalog] as Dictionary
	_place_entry(entry, cell)
	return true

func _find_placed_at(cell: Vector3i) -> int:
	for i: int in range(_placed.size()):
		var p: Dictionary = _placed[i] as Dictionary
		if p["cell"] == cell:
			return i
		# para paredes/portas checa edge_cell
		var node: Node = p["node"] as Node
		if node and node.get("edge_cell") != null and node.get("edge_cell") == cell:
			return i
	return -1

func _place_entry(entry: Dictionary, cell: Vector3i) -> void:
	if _board == null:
		_board = _find_board()
	if _board == null:
		return
	var scene_path: String = entry["scene"] as String
	var scene: PackedScene = load(scene_path) as PackedScene
	if scene == null:
		push_error("Scene não encontrada: " + scene_path)
		return
	var node: Node = scene.instantiate()
	# configura por tipo
	match String(entry["type"]):
		"Chão":
			var th: Resource = null
			if entry["res"] == "grass":
				th = load("res://src/resources/floor_theme.gd").new()
				th.set("albedo_color", Color(0.32,0.62,0.30))
			else:
				th = load("res://src/resources/floor_theme.gd").new()
				th.set("albedo_color", Color(0.60,0.60,0.62))
			node.set("theme", th)
			node.set("cell", cell)
		"Parede":
			node.set("edge_cell", cell)
			node.set("edge_dir", "north")
		"Porta":
			node.set("edge_cell", cell)
			node.set("edge_dir", "north")
			node.set("state", int(entry.get("state", 0)))
		"Coluna":
			node.set("cell", cell)
		"Obstáculo":
			var def: Resource = load("res://src/resources/prop_obstacle_definition.gd").new()
			def.set("type", int(entry.get("otype", 1)))
			node.set("definition", def)
			node.set("cell", cell)
		"Personagem":
			var char_key: String = entry.get("char", "cavaleiro") as String
			var def2: Resource = null
			match char_key:
				"cavaleiro": def2 = CD.create_cavaleiro()
				"maga": def2 = CD.create_maga()
				"druida": def2 = CD.create_druida()
				"goblin_guerreiro": def2 = CD.create_goblin_guerreiro()
				"goblin_arqueiro": def2 = CD.create_goblin_arqueiro()
				"boss": def2 = CD.create_boss()
				_: def2 = CD.create_cavaleiro()
			node.set("definition", def2)
			node.set("grid_pos", cell)
		_:
			node.set("cell", cell)
	_board.add_child(node)
	var rot_steps: int = _opt_rot.selected if _opt_rot else 0
	node.rotation.y = deg_to_rad(float(rot_steps * 90))
	var sc: float = _spin_scale.value if _spin_scale else 1.0
	if _chk_adv and _chk_adv.button_pressed:
		node.scale = Vector3(_spin_sx.value, _spin_sy.value, _spin_sz.value)
	else:
		node.scale = Vector3(sc, sc, sc)
	_placed.append({"node": node, "entry": entry, "cell": cell, "rot": rot_steps, "scale": node.scale})
	_refresh_placed_list()
	# seleciona a recém colocada
	_selected_placed = _placed.size() - 1
	_list_placed.select(_selected_placed)
	_on_placed_selected(_selected_placed)
	print("[MapEditor] colocada ", entry["name"], " em ", cell)

func _on_generate_pressed() -> void:
	if _board == null:
		_board = _find_board()
	if _board == null:
		push_warning("[MapEditor] Nenhum Board encontrado")
		return
	_btn_generate.disabled = true
	_btn_generate.text = "Gerando..."
	await _board.call("regenerate_and_bake") if _board.has_method("regenerate_and_bake") else null
	# se editor tem peças, não regenera demo; faz bake manual
	var bg: Node = get_node_or_null("/root/BoardGrid")
	if bg and bg.has_method("bake_from_physics"):
		var tile: float = float(bg.get("TILE")) if bg.get("TILE") != null else 2.0
		var w: int = int(_board.get("width")) if _board.get("width") != null else 10
		var h: int = int(_board.get("height")) if _board.get("height") != null else 10
		var bounds: Rect2 = Rect2(0,0,float(w)*tile,float(h)*tile)
		var floors: int = int(_board.get("floors_n")) if _board.get("floors_n") != null else 1
		bg.call("bake_from_physics", _board, bounds, floors)
	_btn_generate.disabled = false
	_btn_generate.text = "Gerar Grid"
	_update_stats()
	grid_generated.emit()

func _update_stats() -> void:
	if _label_stats == null:
		return
	var bg: Node = get_node_or_null("/root/BoardGrid")
	if bg and bg.has_method("bake_stats"):
		_label_stats.text = bg.call("bake_stats") as String
	else:
		_label_stats.text = "BoardGrid: aguardando bake..."
