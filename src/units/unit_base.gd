class_name BoardUnit
extends Node3D
## Uma peça de tabuleiro (miniatura). Nunca anda livre: move-se por células,
## com pequenos saltos, como uma figura sobre a mesa.

var id := ""
var display_name := ""
var team := "enemy"
var max_hp := 1
var hp := 1
var max_mana := 0
var mana := 0
var base_ac := 10
var ac := 10
var base_atk_bonus := 0
var atk_bonus := 0
var dmg := "1d6"
var move_max := 4
var moves_left := 0
var attack_range := 1
var vision_range := 0
var strength := 10
var dexterity := 10
var intelligence := 10
var grid_pos := Vector3i.ZERO
var floor_index := 0
var defending := false
var alerted := false
var alive := true
var base_visual_id := ""
var shifted := false
var level := 1
var dmg_bonus := 0
var kills := 0
var last_striker = null

var visual: Node3D
var _bar_root: Node3D
var _fg_mesh: QuadMesh
var _fg_mat: StandardMaterial3D
var _bar_h := 2.0

func setup(uid: String, cell: Vector3i) -> void:
	id = uid
	var d := UnitDefs.def(uid)
	display_name = d["display_name"]
	team = d["team"]
	max_hp = d["max_hp"]
	hp = max_hp
	max_mana = d["max_mana"]
	mana = max_mana
	base_ac = d["ac"]
	ac = base_ac
	base_atk_bonus = d["atk_bonus"]
	atk_bonus = base_atk_bonus
	dmg = d["dmg"]
	move_max = d["move_max"]
	attack_range = d["attack_range"]
	vision_range = d["vision_range"]
	strength = d["strength"]
	dexterity = d["dexterity"]
	intelligence = d["intelligence"]
	_bar_h = d["bar_h"]
	base_visual_id = uid
	floor_index = cell.z
	position = BoardGrid.world_pos(cell)
	if team == "hero":
		rotation.y = PI
	BoardGrid.place(self, cell)
	_build()

## Troca a miniatura por outra forma (ex.: druida vira urso).
func set_visual_id(vname: String, mark_shifted := true) -> void:
	if visual != null:
		remove_child(visual)
		visual.queue_free()
	visual = UnitVisuals.build(vname)
	add_child(visual)
	shifted = mark_shifted

## Volta a forma original.
func revert_visual() -> void:
	if not shifted:
		return
	set_visual_id(base_visual_id, false)

func _build() -> void:
	visual = UnitVisuals.build(id)
	add_child(visual)
	_bar_root = Node3D.new()
	_bar_root.position = Vector3(0, _bar_h, 0)
	add_child(_bar_root)
	var bg_mesh := QuadMesh.new()
	bg_mesh.size = Vector2(1.0, 0.13)
	var bg_mat := StandardMaterial3D.new()
	bg_mat.albedo_color = Color(0.1, 0.03, 0.05, 0.85)
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bg_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bg_mat.no_depth_test = true
	bg_mat.render_priority = 20
	var bg := MeshInstance3D.new()
	bg.mesh = bg_mesh
	bg.material_override = bg_mat
	_bar_root.add_child(bg)
	_fg_mesh = QuadMesh.new()
	_fg_mesh.size = Vector2(0.92, 0.09)
	_fg_mat = StandardMaterial3D.new()
	_fg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_fg_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_fg_mat.no_depth_test = true
	_fg_mat.render_priority = 21
	var fg := MeshInstance3D.new()
	fg.mesh = _fg_mesh
	fg.material_override = _fg_mat
	fg.name = "FG"
	_bar_root.add_child(fg)
	refresh_bar()
	_add_fake_shadow()
	EventBus.turn_started.connect(_on_turn_started)

func _on_turn_started(unit, _round_num: int) -> void:
	set_active_ring(unit == self and alive)

## Sombra fake: disco com gradiente radial que ancora a peca no chao
## (nao acompanha o bobbing da miniatura).
func _add_fake_shadow() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(0.82, 0.82)
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0.40))
	grad.set_color(1, Color(0, 0, 0, 0.0))
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill = GradientTexture2D.FILL_RADIAL
	gtex.fill_from = Vector2(0.5, 0.5)
	gtex.fill_to = Vector2(0.5, 0.0)
	gtex.width = 128
	gtex.height = 128
	var m := StandardMaterial3D.new()
	m.albedo_texture = gtex
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.material_override = m
	mi.position.y = 0.015
	add_child(mi)

var _ring: MeshInstance3D
var _ring_tween: Tween

## Anel pulsante sob a peca cujo turno esta ativo.
func set_active_ring(on: bool) -> void:
	if on:
		if _ring == null:
			var torus := TorusMesh.new()
			torus.inner_radius = 0.40
			torus.outer_radius = 0.50
			var m := StandardMaterial3D.new()
			m.albedo_color = Color.html("#ffd166")
			m.emission_enabled = true
			m.emission = Color.html("#ffd166")
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_ring = MeshInstance3D.new()
			_ring.mesh = torus
			_ring.material_override = m
			_ring.position.y = 0.03
			add_child(_ring)
		if not (_ring_tween and _ring_tween.is_valid()):
			_ring_tween = create_tween().set_loops()
			_ring_tween.tween_property(_ring, "scale", Vector3.ONE * 1.10, 0.55) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			_ring_tween.tween_property(_ring, "scale", Vector3.ONE, 0.55) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	elif _ring != null:
		if _ring_tween and _ring_tween.is_valid():
			_ring_tween.kill()
		_ring.queue_free()
		_ring = null

func effective_ac() -> int:
	return ac + (4 if defending else 0)

func refresh_bar() -> void:
	if _fg_mesh == null:
		return
	var ratio := clampf(float(hp) / float(max_hp), 0.0, 1.0)
	_fg_mesh.size = Vector2(max(0.02, 0.92 * ratio), 0.09)
	for child in _bar_root.get_children():
		if child.name == "FG":
			child.position.x = -(0.92 - 0.92 * ratio) / 2.0
	_fg_mat.albedo_color = Color(0.85, 0.2, 0.2).lerp(Color(0.3, 0.85, 0.3), ratio)

var _rot_tween: Tween

func face_towards(wp: Vector3) -> void:
	var dir := wp - position
	if Vector2(dir.x, dir.z).length() <= 0.01:
		return
	var target := atan2(dir.x, dir.z)
	if _rot_tween and _rot_tween.is_valid():
		_rot_tween.kill()
	# Menor caminho angular: evita a peca "dar a volta" ao cruzar +-180 graus.
	var start := rotation.y
	var delta := wrapf(target - start, -PI, PI)
	_rot_tween = create_tween()
	_rot_tween.tween_method(func(a: float) -> void: rotation.y = a,
		start, start + delta, 0.12)

## Investida curta na direcao do alvo e volta ao lugar (impacto fisico).
func animate_lunge(target_wp: Vector3) -> void:
	var dir := target_wp - global_position
	dir.y = 0.0
	if dir.length() < 0.01:
		return
	dir = dir.normalized()
	var base := global_position
	var tw := create_tween()
	tw.tween_property(self, "global_position", base + dir * 0.55, 0.09) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "global_position", base, 0.16) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

## Abate por heroi: sobe de nivel (+3 PV, +1 dano).
func gain_kill() -> void:
	kills += 1
	level += 1
	max_hp += 3
	hp = mini(max_hp, hp + 3)
	dmg_bonus += 1
	refresh_bar()
	spawn_float_text("NIVEL %d! +3 PV" % level, "#ffd166")
	EventBus.log_msg.emit("%s subiu para o nivel %d! (+3 PV, +1 dano)" % [display_name, level], "#ffd166")

## Recuo curto na direcao oposta ao atacante (vende o impacto).
func animate_recoil(from_wp: Vector3) -> void:
	var dir := global_position - from_wp
	dir.y = 0.0
	if dir.length() < 0.01:
		return
	dir = dir.normalized()
	var base := global_position
	var tw := create_tween()
	tw.tween_property(self, "global_position", base + dir * 0.28, 0.07) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "global_position", base, 0.14) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

## Movimento de peça: saltos curtos célula a célula. Quando um passo do
## caminho é um salto de escada (célula pareada), dispara a transição de
## andar naquele ponto. `from_cell` = célula de origem do movimento.
func animate_move(path: Array, from_cell = null) -> void:
	var prev: Vector3i = from_cell if from_cell != null else grid_pos
	for c in path:
		if BoardGrid.stair_pair(prev) == c and prev != c:
			floor_index = c.z
			EventBus.unit_changed_floor.emit(self, floor_index)
			if team == "hero":
				EventBus.log_msg.emit("Você muda de andar (%s)." %
						["desce" if c.z < prev.z else "sobe"], "#c9a227")
			else:
				EventBus.log_msg.emit("%s usa a escada." % display_name, "#c9a227")
		var wp: Vector3 = BoardGrid.world_pos(c)
		face_towards(wp)
		var dur := 0.17
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(self, "position:x", wp.x, dur)
		tw.tween_property(self, "position:z", wp.z, dur)
		tw.tween_property(self, "position:y", wp.y, dur)
		var th := create_tween()
		th.tween_property(self, "position:y", wp.y + 0.3, dur * 0.5) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		th.tween_property(self, "position:y", wp.y, dur * 0.5) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await tw.finished
		prev = c
	position = BoardGrid.world_pos(grid_pos)
	EventBus.unit_moved.emit(self)
	# Parar sobre a escada NÃO cruza (v0.6.2): pisar nela é como pisar em
	# qualquer célula. A travessia é sempre explícita: ou o caminho executa
	# o salto pareado (destino em outro andar), ou quem está EM PÉ na
	# célula clica nela de novo (try_cross_stairs).

## Atravessa a escada em que a unidade está EM PÉ.
## Custa 1 de movimento e desembarca no primeiro grid LIVRE à frente da
## escada no andar de destino. Retorna: 0 = cruzou, 1 = sem movimento,
## 2 = saída bloqueada no destino (ou célula não é escada).
func try_cross_stairs() -> int:
	if not BoardGrid.stair_links.has(grid_pos):
		return 2
	var pair: Vector3i = BoardGrid.stair_pair(grid_pos)
	if moves_left < 1:
		return 1
	var landing = BoardGrid.stair_landing(pair)
	if landing == null:
		return 2
	moves_left -= 1
	var from_z := grid_pos.z
	change_floor(landing)
	if team == "hero":
		EventBus.log_msg.emit("Você %s pela escada." %
				["desce" if pair.z < from_z else "sobe"], "#c9a227")
	else:
		EventBus.log_msg.emit("%s usa a escada." % display_name, "#c9a227")
	return 0

## Ponto ÚNICO de mudança de andar (escadas). Reposiciona no grid e no
## mundo e dispara unit_changed_floor.
func change_floor(cell: Vector3i) -> void:
	BoardGrid.move_unit(self, cell)
	floor_index = cell.z
	position = BoardGrid.world_pos(cell)
	EventBus.unit_changed_floor.emit(self, floor_index)

func take_damage(amount: int) -> void:
	hp = maxi(0, hp - amount)
	EventBus.unit_damaged.emit(self, amount)
	spawn_float_text("-%d" % amount, "#ff5b5b")
	refresh_bar()
	if hp <= 0:
		die()

func heal(amount: int) -> void:
	var before := hp
	hp = mini(max_hp, hp + amount)
	var gained := hp - before
	if gained > 0:
		EventBus.unit_healed.emit(self, gained)
		spawn_float_text("+%d" % gained, "#6bff8f")
	refresh_bar()

func die() -> void:
	if not alive:
		return
	alive = false
	set_active_ring(false)
	# Abate por heroi rende nivel: +3 PV e +1 de dano.
	if last_striker != null and is_instance_valid(last_striker) \
			and last_striker.get("team") == "hero":
		last_striker.gain_kill()
	BoardGrid.clear_cell(grid_pos)
	EventBus.unit_died.emit(self)
	EventBus.log_msg.emit("%s foi derrotado!" % display_name, "#ff6b6b")
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(visual, "scale", Vector3.ONE * 0.02, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "position:y", -0.35, 0.5)
	tw.chain().tween_callback(queue_free)

func spawn_float_text(txt: String, col_hex: String) -> void:
	var l := Label3D.new()
	l.text = txt
	l.font_size = 64
	l.pixel_size = 0.012
	l.modulate = Color.html(col_hex)
	l.outline_size = 16
	l.outline_modulate = Color(0, 0, 0, 0.9)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	add_child(l)
	l.position = Vector3(0, _bar_h + 0.35, 0)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(l, "position:y", l.position.y + 1.1, 0.95).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.45)
	t.chain().tween_callback(l.queue_free)
