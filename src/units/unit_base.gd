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
var grid_pos := Vector2i.ZERO
var defending := false
var alerted := false
var alive := true

var visual: Node3D
var _bar_root: Node3D
var _fg_mesh: QuadMesh
var _fg_mat: StandardMaterial3D
var _bar_h := 2.0

func setup(uid: String, cell: Vector2i) -> void:
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
	position = BoardGrid.world_pos(cell)
	if team == "hero":
		rotation.y = PI
	BoardGrid.place(self, cell)
	_build()

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

func face_towards(wp: Vector3) -> void:
	var dir := wp - position
	if Vector2(dir.x, dir.z).length() > 0.01:
		rotation.y = atan2(dir.x, dir.z)

## Movimento de peça: saltos curtos célula a célula.
func animate_move(path: Array) -> void:
	for c in path:
		var wp: Vector3 = BoardGrid.world_pos(c)
		face_towards(wp)
		var dur := 0.17
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(self, "position:x", wp.x, dur)
		tw.tween_property(self, "position:z", wp.z, dur)
		var th := create_tween()
		th.tween_property(self, "position:y", 0.3, dur * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		th.tween_property(self, "position:y", 0.0, dur * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await tw.finished
	position.y = 0.0
	EventBus.unit_moved.emit(self)

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
