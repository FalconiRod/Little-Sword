extends Control
class_name MapEditor
## MapEditor — stub Fase 1 (seção 7).

signal grid_generated

@onready var _btn_generate: Button = $Panel/VBox/BtnGenerate
@onready var _label_stats: Label = $Panel/VBox/LabelStats

var _board: Node = null

func _ready() -> void:
	if _btn_generate:
		_btn_generate.pressed.connect(_on_generate_pressed)
	_update_stats()

func bind_board(board: Node) -> void:
	_board = board
	_update_stats()

func _on_generate_pressed() -> void:
	if _board == null:
		_board = get_tree().get_first_node_in_group("board") as Node
		if _board == null:
			_board = get_tree().current_scene.find_child("Board", true, false) as Node
	if _board == null:
		push_warning("[MapEditor] Nenhum Board encontrado para Gerar Grid")
		return
	_btn_generate.disabled = true
	_btn_generate.text = "Gerando..."
	await _board.call("regenerate_and_bake")
	_btn_generate.disabled = false
	_btn_generate.text = "Gerar Grid"
	_update_stats()
	grid_generated.emit()

func _update_stats() -> void:
	if _label_stats == null:
		return
	if has_node("/root/BoardGrid"):
		var bg: Node = get_node("/root/BoardGrid")
		if bg.has_method("bake_stats"):
			_label_stats.text = bg.call("bake_stats") as String
		else:
			_label_stats.text = "BoardGrid: aguardando bake..."
	else:
		_label_stats.text = "BoardGrid não carregado"
