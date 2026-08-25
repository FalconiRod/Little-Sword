extends Control
class_name MapEditor

signal grid_generated

@onready var _btn_generate: Button = $Panel/VBox/BtnGenerate
@onready var _label_stats: Label = $Panel/VBox/LabelStats

var _board: Node = null

func _ready() -> void:
	print("[MapEditor] pronto btn=", _btn_generate, " label=", _label_stats)
	if _btn_generate:
		_btn_generate.pressed.connect(_on_generate_pressed)
	# tenta achar board automaticamente se Main nao bindou
	if _board == null:
		await get_tree().process_frame
		_board = _find_board()
		print("[MapEditor] board auto-find=", _board)
	_update_stats()

func _find_board() -> Node:
	var b: Node = get_tree().get_first_node_in_group("board") as Node
	if b:
		return b
	if get_tree().current_scene:
		var found: Node = get_tree().current_scene.find_child("Board", true, false) as Node
		if found:
			return found
	return null

func bind_board(board: Node) -> void:
	_board = board
	print("[MapEditor] bind_board=", _board)
	_update_stats()

func _on_generate_pressed() -> void:
	print("[MapEditor] Gerar Grid clicado board=", _board)
	if _board == null:
		_board = _find_board()
		print("[MapEditor] retry find board=", _board)
	if _board == null:
		push_warning("[MapEditor] Nenhum Board encontrado para Gerar Grid")
		if _label_stats:
			_label_stats.text = "ERRO: Board nao encontrado"
		return
	_btn_generate.disabled = true
	_btn_generate.text = "Gerando..."
	print("[MapEditor] chamando regenerate_and_bake")
	await _board.call("regenerate_and_bake")
	_btn_generate.disabled = false
	_btn_generate.text = "Gerar Grid"
	_update_stats()
	grid_generated.emit()
	print("[MapEditor] grid_generated emit")

func _update_stats() -> void:
	if _label_stats == null:
		return
	var bg: Node = null
	if has_node("/root/BoardGrid"):
		bg = get_node("/root/BoardGrid")
	if bg and bg.has_method("bake_stats"):
		var s: String = bg.call("bake_stats") as String
		_label_stats.text = s
		print("[MapEditor] stats=", s)
	else:
		_label_stats.text = "BoardGrid: aguardando bake..."
		print("[MapEditor] aguardando bake, bg=", bg)
