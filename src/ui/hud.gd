extends Control
## HUD Fase 8 — ordem topo, retratos clicáveis, vitals, ações, log, dados

@onready var _turn_box: HBoxContainer = $TopBar/TurnOrder
@onready var _vitals_box: VBoxContainer = $BottomBar/HBox/Vitals
@onready var _actions_box: HBoxContainer = $BottomBar/HBox/Actions
@onready var _log: RichTextLabel = $BottomBar/HBox/Log
@onready var _dice_label: Label = $CenterDice

var _board: Node = null

func _ready() -> void:
	add_to_group("hud")
	# conecta sinais
	if has_node("/root/TurnManager"):
		var tm: Node = get_node("/root/TurnManager")
		tm.connect("turn_changed", _on_turn_changed)
		tm.connect("round_ended", _on_round_ended)
	if has_node("/root/CombatSystem"):
		var cs: Node = get_node("/root/CombatSystem")
		cs.connect("attack_resolved", _on_attack_resolved)
	if has_node("/root/DiceManager"):
		var dm: Node = get_node("/root/DiceManager")
		dm.connect("roll_done", _on_roll_done)
	# ações
	_setup_actions()
	# tenta achar board
	_board = get_tree().get_first_node_in_group("board") as Node
	if _board == null and get_tree().current_scene:
		_board = get_tree().current_scene.find_child("Board", true, false) as Node
	_update_turn_order()
	_update_vitals()
	print("[HUD] pronto")

func _setup_actions() -> void:
	if _actions_box == null:
		return
	for c: Node in _actions_box.get_children():
		c.queue_free()
	var btns: Array = [
		["Atacar", _on_atacar],
		["Habilidade", _on_habilidade],
		["Defender (+4 CA)", _on_defender],
		["Dispersar", _on_dispersar],
		["Passar Vez", _on_passar],
		["Rolar Dados", _on_rolar],
	]
	for pair: Array in btns:
		var b: Button = Button.new()
		b.text = pair[0] as String
		b.custom_minimum_size = Vector2(110, 32)
		b.pressed.connect(pair[1] as Callable)
		_actions_box.add_child(b)

func _update_turn_order() -> void:
	if _turn_box == null:
		return
	for c: Node in _turn_box.get_children():
		c.queue_free()
	var tm: Node = get_node_or_null("/root/TurnManager")
	if tm == null or not tm.has_method("current_unit"):
		return
	var order: Array = tm.get("order") as Array if tm.get("order") != null else []
	var cur: Node = tm.call("current_unit") as Node
	for u: Node in order:
		var btn: Button = Button.new()
		var def: Resource = u.get("definition") as Resource
		var name: String = String(def.get("display_name")) if def else "?"
		var hp: int = int(u.get("current_hp")) if u.get("current_hp") != null else 0
		var max_hp: int = int(def.get("hp_max")) if def else 0
		btn.text = "%s\n%d/%d" % [name, hp, max_hp]
		btn.custom_minimum_size = Vector2(90, 48)
		var col: Color = Color(0.5,0.5,0.5)
		if def:
			var f: int = int(def.get("faction"))
			if f == 0: col = Color(0.20,0.45,0.85)
			elif f == 1: col = Color(0.80,0.25,0.22)
			else: col = Color(0.55,0.25,0.78)
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = col
		if u == cur:
			style.border_color = Color(1,0.9,0.2)
			style.border_width_left = 3; style.border_width_right = 3; style.border_width_top = 3; style.border_width_bottom = 3
		btn.add_theme_stylebox_override("normal", style)
		btn.pressed.connect(func() -> void: _on_portrait_clicked(u))
		_turn_box.add_child(btn)

func _update_vitals() -> void:
	if _vitals_box == null:
		return
	for c: Node in _vitals_box.get_children():
		c.queue_free()
	var board: Node = _board
	if board == null:
		board = get_tree().get_first_node_in_group("board") as Node
	if board == null:
		return
	var units: Array = board.call("get_units") as Array if board.has_method("get_units") else []
	for u: Node in units:
		var def: Resource = u.get("definition") as Resource
		var name: String = String(def.get("display_name")) if def else "?"
		var hp: int = int(u.get("current_hp")) if u.get("current_hp") != null else 0
		var max_hp: int = int(def.get("hp_max")) if def else 0
		var ca: int = int(def.get("ca")) if def else 0
		var lbl: Label = Label.new()
		lbl.text = "%s HP %d/%d CA %d" % [name, hp, max_hp, ca]
		var f: int = int(def.get("faction")) if def else 0
		if f == 0: lbl.modulate = Color(0.6,0.8,1)
		elif f == 1: lbl.modulate = Color(1,0.6,0.6)
		else: lbl.modulate = Color(0.8,0.6,1)
		_vitals_box.add_child(lbl)

func _on_turn_changed(unit: Node, team: String) -> void:
	_update_turn_order()
	_update_vitals()
	_log_add("[b]Turno: %s (%s)[/b]" % [String(unit.get("definition").get("display_name")), team], Color(1,0.9,0.3))
	# fade retratos ao trocar de andar
	var bg: Node = get_node_or_null("/root/BoardGrid")
	if bg and unit.get("grid_pos") != null:
		var floor_idx: int = int((unit.get("grid_pos") as Vector3i).z)
		if bg.get("active_floor_index") != null and int(bg.get("active_floor_index")) != floor_idx:
			# fade
			var tw: Tween = create_tween()
			modulate.a = 0.5
			tw.tween_property(self, "modulate:a", 1.0, 0.25)

func _on_round_ended(round: int) -> void:
	_log_add("— Round %d —" % round, Color(0.7,0.7,0.7))

func _on_attack_resolved(att: Node, def: Node, res: Dictionary) -> void:
	var hit: bool = bool(res.get("hit"))
	var crit: bool = bool(res.get("crit"))
	var fail: bool = bool(res.get("fail"))
	var dmg: int = int(res.get("dmg"))
	var roll: int = int(res.get("roll"))
	var total: int = int(res.get("total"))
	var ca: int = int(res.get("ca_eff"))
	var col: Color = Color(0.3,1,0.3) if hit else Color(1,0.3,0.3)
	var txt: String = "%s → %s D20 %d (%d) vs CA %d %s dmg %d" % [
		String(att.get("definition").get("display_name")),
		String(def.get("definition").get("display_name")),
		roll, total, ca, "CRIT! " if crit else ("FALHA! " if fail else ("ACERTO " if hit else "ERRO ")), dmg
	]
	_log_add(txt, col)
	_update_vitals()
	_update_turn_order()

func _on_roll_done(sides: int, result: int, is_crit: bool, is_fail: bool, label: String) -> void:
	var col: Color = Color(1,1,0.5)
	if is_crit: col = Color(1,0.85,0.2)
	if is_fail: col = Color(1,0.3,0.3)
	_log_add("D%d=%d %s" % [sides, result, label], col)
	show_dice(sides, result, is_crit, is_fail, label)

func show_dice(sides: int, result: int, is_crit: bool, is_fail: bool, label: String) -> void:
	if _dice_label == null:
		return
	var txt: String = "D%d: %d" % [sides, result]
	if label != "":
		txt += " %s" % label
	if is_crit:
		txt += " CRÍTICO!"
	if is_fail:
		txt += " FALHA!"
	_dice_label.text = txt
	_dice_label.visible = true
	_dice_label.modulate = Color(1,1,0.5) if not is_crit and not is_fail else (Color(1,0.9,0.2) if is_crit else Color(1,0.3,0.3))
	var tw: Tween = create_tween()
	_dice_label.scale = Vector2(1.5,1.5)
	tw.tween_property(_dice_label, "scale", Vector2.ONE, 0.25)
	tw.tween_callback(func() -> void:
		await get_tree().create_timer(1.2).timeout
		_dice_label.visible = false
	)

func _log_add(text: String, color: Color) -> void:
	if _log == null:
		return
	var hex: String = color.to_html(false)
	_log.append_text("[color=#%s]%s[/color]\n" % [hex, text])
	# auto scroll
	await get_tree().process_frame
	_log.scroll_to_line(_log.get_line_count())

func _on_portrait_clicked(unit: Node) -> void:
	print("[HUD] retrato clicado ", String(unit.get("definition").get("display_name")))
	# foca câmera no herói (Main tem método)
	var main: Node = get_tree().current_scene as Node
	if main and main.has_method("_focus_on_unit"):
		main.call("_focus_on_unit", unit)
	else:
		# fallback: seleciona unidade
		if main and main.has_method("_select_unit"):
			main.call("_select_unit", unit)

func _on_atacar() -> void:
	_log_add("Atacar: clique em inimigo adjacente", Color(1,0.7,0.3))
	var main: Node = get_tree().current_scene as Node
	if main:
		main.set_meta("action_mode", "attack")

func _on_habilidade() -> void:
	var main: Node = get_tree().current_scene as Node
	var sel: Node = main.get("_selected_unit") as Node if main and main.get("_selected_unit") != null else null
	if sel and String(sel.get("definition").get("display_name")).contains("Rowan"):
		if sel.has_method("transform_toggle"):
			sel.call("transform_toggle")
			_log_add("Fúria do Urso!", Color(0.4,0.9,0.4))
			_update_vitals()
	else:
		_log_add("Habilidade: Maga Missil / Druida Urso", Color(0.6,0.8,1))

func _on_defender() -> void:
	var main: Node = get_tree().current_scene as Node
	if main:
		main.set("_is_defending", true)
	_log_add("Defender +4 CA", Color(0.5,0.7,1))

func _on_dispersar() -> void:
	var main: Node = get_tree().current_scene as Node
	if main:
		main.set("_is_dispersar", true)
	_log_add("Dispersar — sem oportunidade", Color(0.7,0.9,0.7))

func _on_passar() -> void:
	var tm: Node = get_node_or_null("/root/TurnManager")
	if tm and tm.has_method("next_turn"):
		tm.call("next_turn")
		_log_add("Passou vez", Color(0.8,0.8,0.8))

func _on_rolar() -> void:
	var main: Node = get_tree().current_scene as Node
	if main and main.has_method("_on_roll_pressed"):
		main.call("_on_roll_pressed")
