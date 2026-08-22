class_name GameHUD
extends CanvasLayer
## Interface estilo RPG moderno: retrato e barras à esquerda, botões embaixo,
## ordem de turno à direita, log de combate, popups de dados, barra do boss,
## inventário modal e tela de fim de jogo.

const GOLD := "c9a227"
const PANEL_BG := Color(0.055, 0.05, 0.09, 0.93)

var knight: BoardUnit
var ctl
var roster: Array = []

var title_lbl: Label
var turn_lbl: Label
var round_lbl: Label
var hp_bar: ProgressBar
var mp_bar: ProgressBar
var hp_lbl: Label
var mp_lbl: Label
var stat_lbl: Label
var status_lbl: Label
var btn_attack: Button
var btn_skill: Button
var btn_defend: Button
var btn_item: Button
var btn_pass: Button
var order_rows: Array = []
var log_rtl: RichTextLabel
var boss_panel: PanelContainer
var boss_bar: ProgressBar
var boss_lbl: Label
var boss_ref = null
var popup_lbl: Label
var popup_sub: Label
var banner_lbl: Label
var inv_panel: PanelContainer
var inv_list: VBoxContainer
var over_layer: Control
var _popup_tween: Tween

func _ready() -> void:
	_build_top_left()
	_build_portrait()
	_build_bottom_bar()
	_build_order_panel()
	_build_log()
	_build_popup()
	_build_banner()
	_build_boss_bar()
	_build_inventory()
	_build_game_over()
	_build_hints()
	EventBus.log_msg.connect(_on_log)
	EventBus.dice_rolled.connect(_on_dice)
	EventBus.turn_started.connect(_on_turn_started)
	EventBus.round_started.connect(_on_round)
	EventBus.banner.connect(_show_banner)
	EventBus.game_over.connect(_on_game_over)
	EventBus.inventory_changed.connect(_refresh_inventory_if_open)

func bind_units(knight_unit: BoardUnit, units_roster: Array) -> void:
	knight = knight_unit
	roster = units_roster
	_build_order_rows()
	update_vitals(knight)

func bind_controller(c) -> void:
	ctl = c

# ------------------------------------------------------------------ build --

func _sb(bg := PANEL_BG, border := Color.html(GOLD), bw := 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb

func _label(text: String, size: int, col: String, parent: Node) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color.html(col))
	parent.add_child(l)
	return l

func _build_top_left() -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _sb())
	p.position = Vector2(14, 14)
	add_child(p)
	var v := VBoxContainer.new()
	p.add_child(v)
	title_lbl = _label("LITTLE SWORD", 26, GOLD, v)
	_label("Masmorra Antiga — RPG Tático de Tabuleiro", 13, "8a8f9c", v)
	round_lbl = _label("Rodada 1", 15, "e8e2d0", v)
	turn_lbl = _label("Preparando...", 19, "7fd1ff", v)

func _build_portrait() -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _sb())
	p.position = Vector2(14, 130)
	p.custom_minimum_size = Vector2(330, 0)
	add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	v.add_child(top)
	var face := PanelContainer.new()
	face.custom_minimum_size = Vector2(84, 84)
	face.add_theme_stylebox_override("panel", _sb(Color(0.1, 0.09, 0.16), Color.html("37e0ff"), 2))
	top.add_child(face)
	var fc := CenterContainer.new()
	face.add_child(fc)
	var fl := _label("CAV", 30, "37e0ff", fc)
	fl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var nv := VBoxContainer.new()
	nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nv.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(nv)
	_label("Cavaleiro — Nível 1", 18, "e8e2d0", nv)
	hp_lbl = _label("PV 40/40", 14, "ff8a8a", nv)
	mp_lbl = _label("Mana 10/10", 14, "7fb8ff", nv)
	hp_bar = _bar(v, "b32020")
	mp_bar = _bar(v, "2456b3")
	stat_lbl = _label("FOR 15   DES 12   INT 10   CA 16", 14, "c9b26a", v)
	status_lbl = _label("", 14, "7fd1ff", v)

func _bar(parent: Node, hex: String) -> ProgressBar:
	var b := ProgressBar.new()
	b.min_value = 0
	b.max_value = 100
	b.value = 100
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, 16)
	var bg := _sb(Color(0.08, 0.08, 0.12), Color(0, 0, 0, 0), 0)
	bg.set_corner_radius_all(3)
	var fill := _sb(Color.html(hex), Color(0, 0, 0, 0), 0)
	fill.set_corner_radius_all(3)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fill)
	parent.add_child(b)
	return b

func _mk_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(150, 46)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 16)
	for st in ["normal", "hover", "pressed", "disabled"]:
		var s := _sb(Color(0.1, 0.09, 0.16, 0.97), Color.html(GOLD))
		if st == "pressed":
			s.bg_color = Color(0.16, 0.14, 0.24)
		if st == "disabled":
			s.bg_color = Color(0.07, 0.07, 0.1, 0.8)
			s.border_color = Color(0.25, 0.23, 0.18)
		b.add_theme_stylebox_override(st, s)
	b.add_theme_color_override("font_color", Color.html("e8e2d0"))
	b.add_theme_color_override("font_hover_color", Color.html(GOLD))
	b.add_theme_color_override("font_disabled_color", Color(0.45, 0.44, 0.42))
	b.pressed.connect(cb)
	return b

func _build_bottom_bar() -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _sb())
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	p.offset_bottom = -14
	add_child(p)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	p.add_child(h)
	btn_attack = _mk_button("[1] ATACAR", func(): ctl.try_attack())
	btn_skill = _mk_button("[2] HABILIDADE", func(): ctl.try_skill())
	btn_defend = _mk_button("[3] DEFENDER", func(): ctl.do_defend())
	btn_item = _mk_button("[4] INVENTARIO", func(): toggle_inventory(ctl))
	btn_pass = _mk_button("[5] PASSAR VEZ", func(): ctl.do_pass())
	for b in [btn_attack, btn_skill, btn_defend, btn_item, btn_pass]:
		h.add_child(b)

func _build_order_panel() -> void:
	var p := PanelContainer.new()
	p.name = "OrderPanel"
	p.add_theme_stylebox_override("panel", _sb())
	p.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	p.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	p.offset_right = -14
	p.offset_left = -240
	p.offset_top = 14
	add_child(p)
	var v := VBoxContainer.new()
	v.name = "List"
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	_label("ORDEM DE TURNO", 16, GOLD, v)

func _build_order_rows() -> void:
	var v := get_node("OrderPanel/List") as VBoxContainer
	order_rows.clear()
	for entry in roster:
		var u = entry["unit"]
		var row := PanelContainer.new()
		var dot_hex := "37e0ff" if u.team == "hero" else ("ff5544" if u.id != "boss_knight" else "b04dff")
		row.add_theme_stylebox_override("panel", _sb(Color(0.09, 0.08, 0.14, 0.8), Color(0.2, 0.2, 0.28)))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		row.add_child(h)
		var dot := ColorRect.new()
		dot.color = Color.html(dot_hex)
		dot.custom_minimum_size = Vector2(12, 12)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(dot)
		var lbl := _label(entry["name"], 14, "cfc8b8", h)
		order_rows.append({"row": row, "lbl": lbl, "unit": u})
		v.add_child(row)
	_refresh_order_highlight()

func _refresh_order_highlight() -> void:
	for r in order_rows:
		var row: PanelContainer = r["row"]
		var lbl: Label = r["lbl"]
		var u = r["unit"]
		var is_cur: bool = TurnManager.active == u
		var dead: bool = (not is_instance_valid(u)) or (not u.alive)
		var sb := _sb(
			Color(0.14, 0.12, 0.06, 0.95) if is_cur else Color(0.09, 0.08, 0.14, 0.8),
			Color.html(GOLD) if is_cur else Color(0.2, 0.2, 0.28),
			2 if is_cur else 1
		)
		row.add_theme_stylebox_override("panel", sb)
		lbl.add_theme_color_override("font_color",
			Color(0.4, 0.38, 0.36) if dead else (Color.html(GOLD) if is_cur else Color.html("cfc8b8")))

func _build_log() -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _sb())
	p.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	p.offset_left = 14
	p.offset_top = -210
	p.offset_bottom = -14
	p.custom_minimum_size = Vector2(430, 196)
	add_child(p)
	log_rtl = RichTextLabel.new()
	log_rtl.bbcode_enabled = true
	log_rtl.scroll_following = true
	log_rtl.add_theme_font_size_override("normal_font_size", 13)
	p.add_child(log_rtl)

func _build_popup() -> void:
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.offset_top = -160
	c.visible = true
	add_child(c)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(v)
	popup_lbl = _label("", 64, GOLD, v)
	popup_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup_sub = _label("", 18, "e8e2d0", v)
	popup_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup_lbl.modulate.a = 0.0
	popup_sub.modulate.a = 0.0

func _build_banner() -> void:
	var c := CenterContainer.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	c.grow_horizontal = Control.GROW_DIRECTION_BOTH
	c.offset_top = 90
	add_child(c)
	banner_lbl = _label("", 34, "7fd1ff", c)
	banner_lbl.modulate.a = 0.0

func _build_boss_bar() -> void:
	boss_panel = PanelContainer.new()
	boss_panel.add_theme_stylebox_override("panel", _sb(Color(0.09, 0.03, 0.1, 0.94), Color.html("b04dff"), 2))
	boss_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	boss_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	boss_panel.offset_top = 14
	boss_panel.custom_minimum_size = Vector2(480, 0)
	boss_panel.visible = false
	add_child(boss_panel)
	var v := VBoxContainer.new()
	boss_panel.add_child(v)
	boss_lbl = _label("CAVALEIRO ANCESTRAL", 17, "d9a8ff", v)
	boss_bar = _bar(v, "7a1699")

func _build_hints() -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _sb(Color(0.05, 0.05, 0.08, 0.75), Color(0.25, 0.23, 0.18), 1))
	p.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	p.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	p.offset_right = -14
	p.offset_bottom = -14
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(p)
	var l := _label("Setas/WASD: mover pelo mapa    Mouse: angulo da visao    Roda: zoom", 12, "8a8f9c", p)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _build_inventory() -> void:
	inv_panel = PanelContainer.new()
	inv_panel.add_theme_stylebox_override("panel", _sb())
	inv_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	inv_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	inv_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	inv_panel.custom_minimum_size = Vector2(600, 0)
	inv_panel.visible = false
	inv_panel.z_index = 50
	add_child(inv_panel)

func _build_game_over() -> void:
	over_layer = Control.new()
	over_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	over_layer.visible = false
	over_layer.z_index = 100
	add_child(over_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	over_layer.add_child(dim)
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	over_layer.add_child(c)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	c.add_child(v)
	var big := Label.new()
	big.name = "BigLabel"
	big.text = "VITÓRIA"
	big.add_theme_font_size_override("font_size", 72)
	big.add_theme_color_override("font_color", Color.html(GOLD))
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(big)
	var sub := Label.new()
	sub.name = "SubLabel"
	sub.text = ""
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", Color.html("cfc8b8"))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var cc := CenterContainer.new()
	v.add_child(cc)
	var again := _mk_button("JOGAR NOVAMENTE", _restart)
	cc.add_child(again)

# ------------------------------------------------------------------ fluxo --

func update_vitals(u: BoardUnit) -> void:
	if u == null:
		return
	hp_bar.value = 100.0 * float(u.hp) / float(maxi(1, u.max_hp))
	mp_bar.value = 100.0 * float(u.mana) / float(maxi(1, u.max_mana))
	hp_lbl.text = "PV %d/%d" % [u.hp, u.max_hp]
	mp_lbl.text = "Mana %d/%d" % [u.mana, u.max_mana]
	stat_lbl.text = "FOR %d   DES %d   INT %d   CA %d" % [u.strength, u.dexterity, u.intelligence, u.effective_ac()]
	var parts: Array[String] = []
	if u.defending:
		parts.append("Defendendo (+4 CA)")
	if TurnManager.active == u and u.moves_left > 0 and not TurnManager.game_ended:
		parts.append("Movimento restante: %d casas" % u.moves_left)
	status_lbl.text = "  •  ".join(parts)

func refresh_buttons(c) -> void:
	ctl = c
	var active_ok: bool = TurnManager.active == knight and not TurnManager.game_ended and ctl != null and not ctl.busy
	var can_act: bool = active_ok and not ctl.acted and ctl.mode != 0
	btn_attack.disabled = not can_act
	btn_skill.disabled = not can_act or knight.mana < UnitDefs.KNIGHT_SKILL_COST
	btn_defend.disabled = not can_act
	btn_item.disabled = not can_act
	btn_pass.disabled = not active_ok

func show_boss_bar(boss) -> void:
	boss_ref = boss
	boss_panel.visible = true
	_sync_boss()

func _sync_boss() -> void:
	if boss_ref != null and is_instance_valid(boss_ref):
		boss_bar.value = 100.0 * float(boss_ref.hp) / float(boss_ref.max_hp)
		boss_lbl.text = "CAVALEIRO ANCESTRAL   (%d/%d)" % [boss_ref.hp, boss_ref.max_hp]

func toggle_inventory(controller) -> void:
	inv_panel.visible = not inv_panel.visible
	if inv_panel.visible:
		_rebuild_inventory(controller)

func _refresh_inventory_if_open() -> void:
	if inv_panel.visible:
		_rebuild_inventory(ctl)

func _rebuild_inventory(controller) -> void:
	for child in inv_panel.get_children():
		child.queue_free()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	inv_panel.add_child(v)
	_label("INVENTÁRIO", 24, GOLD, v)
	_label("Equipamento", 15, "7fd1ff", v)
	for slot in ["weapon", "armor", "accessory"]:
		var id: String = InventorySystem.equipped[slot]
		var item_name: String = InventorySystem.ITEMS[id]["name"] if id != "" else "— vazio —"
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		v.add_child(h)
		var slot_l := _label("[%s]" % InventorySystem.SLOT_NAMES[slot], 14, "c9b26a", h)
		slot_l.custom_minimum_size = Vector2(120, 0)
		var name_l := _label(item_name, 14, "e8e2d0", h)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if id != "":
			var rm := _mk_small("Remover", func(): InventorySystem.unequip(slot); _rebuild_inventory(ctl))
			h.add_child(rm)
	_label("Mochila", 15, "7fd1ff", v)
	if InventorySystem.storage.is_empty():
		_label("(vazia)", 13, "6a6f7c", v)
	for id in InventorySystem.storage:
		var item: Dictionary = InventorySystem.ITEMS[id]
		var h2 := HBoxContainer.new()
		v.add_child(h2)
		var n := _label("%s — %s" % [item["name"], item["desc"]], 14, "e8e2d0", h2)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var eq := _mk_small("Equipar", func(): InventorySystem.equip(id); _rebuild_inventory(ctl))
		h2.add_child(eq)
	_label("Consumíveis", 15, "7fd1ff", v)
	var h3 := HBoxContainer.new()
	v.add_child(h3)
	var pot := _label("Poção de Vida x%d — Recupera 15 PV" % InventorySystem.potions, 14, "6bff8f", h3)
	pot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var use := _mk_small("Usar", func():
		if ctl != null and ctl.use_item_potion():
			toggle_inventory(ctl)
	)
	use.disabled = InventorySystem.potions <= 0
	h3.add_child(use)
	var cc := CenterContainer.new()
	v.add_child(cc)
	cc.add_child(_mk_small("Fechar", func(): inv_panel.hide()))

func _mk_small(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 13)
	var s := _sb(Color(0.12, 0.11, 0.18), Color.html(GOLD))
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	b.add_theme_stylebox_override("normal", s)
	b.add_theme_stylebox_override("hover", _sb(Color(0.18, 0.16, 0.26), Color.html(GOLD)))
	b.add_theme_stylebox_override("pressed", _sb(Color(0.22, 0.2, 0.3), Color.html(GOLD)))
	b.add_theme_color_override("font_color", Color.html("e8e2d0"))
	b.pressed.connect(cb)
	return b

# ------------------------------------------------------------------ sinais --

func _on_log(text: String, color: String) -> void:
	log_rtl.append_text("[color=#%s]%s[/color]\n" % [color, text])

func _on_dice(sides: int, result: int, total: int, label: String) -> void:
	_play_dice_popup(sides, result, total, label)

func _play_dice_popup(sides: int, result: int, total: int, label: String) -> void:
	if _popup_tween != null and _popup_tween.is_valid():
		_popup_tween.kill()
	popup_lbl.text = "D%d" % sides
	popup_sub.text = label
	popup_lbl.modulate.a = 1.0
	popup_sub.modulate.a = 1.0
	_popup_tween = create_tween()
	for i in 5:
		_popup_tween.tween_callback(func():
			popup_lbl.text = "%d" % randi_range(1, sides))
		_popup_tween.tween_interval(0.055)
	_popup_tween.tween_callback(func():
		popup_lbl.text = str(result) if total == result else "%d + %d" % [result, total - result])
	_popup_tween.tween_interval(0.75)
	_popup_tween.tween_property(popup_lbl, "modulate:a", 0.0, 0.25)
	_popup_tween.parallel().tween_property(popup_sub, "modulate:a", 0.0, 0.25)

func _on_turn_started(unit, round_num: int) -> void:
	turn_lbl.text = "Turno atual: %s" % unit.display_name
	turn_lbl.add_theme_color_override("font_color",
		Color.html("37e0ff") if unit.team == "hero" else Color.html("ff6b6b"))
	_show_banner("VEZ DE %s" % unit.display_name.to_upper())
	_refresh_order_highlight()
	update_vitals(knight)
	refresh_buttons(ctl)
	if unit.team != "hero":
		pass

func _on_round(n: int) -> void:
	round_lbl.text = "Rodada %d" % maxi(1, n)
	_show_banner("RODADA %d" % maxi(1, n))

func _show_banner(text: String) -> void:
	banner_lbl.text = text
	var t := create_tween()
	t.tween_property(banner_lbl, "modulate:a", 1.0, 0.2)
	t.tween_interval(1.1)
	t.tween_property(banner_lbl, "modulate:a", 0.0, 0.35)

func _process(_delta: float) -> void:
	if boss_panel.visible:
		_sync_boss()
	if TurnManager.active == knight:
		update_vitals(knight)
	_refresh_order_throttled(_delta)

var _hl_acc := 0.0
func _refresh_order_throttled(delta: float) -> void:
	_hl_acc += delta
	if _hl_acc > 0.5:
		_hl_acc = 0.0
		refresh_buttons(ctl)

func _on_game_over(victory: bool) -> void:
	over_layer.visible = true
	var big := over_layer.find_child("BigLabel", true, false) as Label
	var sub := over_layer.find_child("SubLabel", true, false) as Label
	if victory:
		big.text = "VITÓRIA!"
		big.add_theme_color_override("font_color", Color.html(GOLD))
		sub.text = "O Cavaleiro Ancestral caiu. A masmorra é sua."
	else:
		big.text = "DERROTA"
		big.add_theme_color_override("font_color", Color.html("ff5544"))
		sub.text = "Sua miniatura tombou no tabuleiro..."

func _restart() -> void:
	TurnManager.reset()
	InventorySystem.reset()
	get_tree().reload_current_scene()
