extends Node3D
class_name Board

@export var width: int = 10
@export var height: int = 10
@export var floors_n: int = 1
@export var theme_grass: Resource
@export var theme_stone: Resource
@export var use_checker_pattern: bool = true

const TILE_F: float = 2.0
const FLOOR_H_F: float = 7.0

var _pieces: Array = []

func _get_board_grid() -> Node:
	if has_node("/root/BoardGrid"):
		return get_node("/root/BoardGrid")
	return null

func _tile() -> float:
	var bg: Node = _get_board_grid()
	if bg and "TILE" in bg:
		return float(bg.get("TILE"))
	return TILE_F

func _floor_h() -> float:
	var bg: Node = _get_board_grid()
	if bg and "FLOOR_H" in bg:
		return float(bg.get("FLOOR_H"))
	return FLOOR_H_F

func _ready() -> void:
	if theme_grass == null:
		theme_grass = _make_grass_theme()
	if theme_stone == null:
		theme_stone = _make_stone_theme()
	generate_board()
	await get_tree().physics_frame
	await get_tree().physics_frame
	bake_grid()

func _make_grass_theme() -> Resource:
	var t: Resource = load("res://src/resources/floor_theme.gd").new()
	t.set("theme_name", "Grama")
	t.set("albedo_color", Color(0.32, 0.62, 0.30))
	t.set("roughness", 0.95)
	t.set("thickness", 0.15)
	t.set("editor_chip_color", Color(0.32, 0.62, 0.30))
	return t

func _make_stone_theme() -> Resource:
	var t: Resource = load("res://src/resources/floor_theme.gd").new()
	t.set("theme_name", "Pedra")
	t.set("albedo_color", Color(0.60, 0.60, 0.62))
	t.set("roughness", 0.85)
	t.set("thickness", 0.15)
	t.set("editor_chip_color", Color(0.60, 0.60, 0.62))
	return t

func generate_board() -> void:
	clear_board()
	var floor_scene: PackedScene = load("res://src/board/floor_piece.tscn") as PackedScene
	if floor_scene == null:
		push_error("[Board] floor_piece.tscn nao carregou")
		return
	var tile: float = _tile()
	var fh: float = _floor_h()
	print("[Board] generate_board width=", width, " height=", height, " tile=", tile, " fh=", fh, " scene=", floor_scene)
	for f: int in range(floors_n):
		for x: int in range(width):
			for y: int in range(height):
				var piece: Node = floor_scene.instantiate()
				if piece == null:
					push_error("[Board] instantiate falhou")
					continue
				var cell: Vector3i = Vector3i(x, y, f)
				var th: Resource = theme_grass
				if use_checker_pattern:
					th = theme_grass if (x + y) % 2 == 0 else theme_stone
				piece.set("theme", th)
				piece.set("cell", cell)
				add_child(piece)
				_pieces.append(piece)
				var pos: Vector3 = Vector3(
					float(x) * tile + tile * 0.5,
					float(f) * fh,
					float(y) * tile + tile * 0.5
				)
				piece.global_position = pos
	print("[Board] generate_board fim pieces=", _pieces.size(), " children=", get_child_count())

func clear_board() -> void:
	for p: Variant in _pieces:
		if is_instance_valid(p as Object):
			(p as Node).queue_free()
	_pieces.clear()
	for c: Node in get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("floor_piece.gd"):
			c.queue_free()

func bake_grid() -> void:
	var tile: float = _tile()
	var bounds: Rect2 = Rect2(0, 0, float(width) * tile, float(height) * tile)
	var bg: Node = _get_board_grid()
	if bg and bg.has_method("bake_from_physics"):
		bg.call("bake_from_physics", self, bounds, floors_n)
		var stats: String = bg.call("bake_stats") as String
		print_rich("[color=green][Board][/color] ", stats)
		for i: int in range(min(3, width * height)):
			var cx: int = i % width
			var cy: int = i / width
			var c: Vector3i = Vector3i(cx, cy, 0)
			var d: Dictionary = bg.call("cell_data", c) as Dictionary
			print("  cell ", c, " -> ", d)
	else:
		push_warning("[Board] BoardGrid nao encontrado para bake")

func regenerate_and_bake() -> void:
	generate_board()
	await get_tree().physics_frame
	await get_tree().physics_frame
	bake_grid()

func get_pieces() -> Array:
	return _pieces

func map_bounds() -> Rect2:
	var tile: float = _tile()
	return Rect2(0, 0, float(width) * tile, float(height) * tile)
