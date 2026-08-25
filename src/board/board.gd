extends Node3D
class_name Board
## Board — gerencia peças de chão e dispara o bake do BoardGrid.
## Seção 3: cada célula é uma FloorPiece com colisão real; BoardGrid é
## gerado por raycast (fonte única de verdade).

@export var width: int = 10
@export var height: int = 10
@export var floors_n: int = 1
@export var theme_grass: Resource
@export var theme_stone: Resource
@export var use_checker_pattern: bool = true

var _pieces: Array = []

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
	for f: int in range(floors_n):
		for x: int in range(width):
			for y: int in range(height):
				var piece: Node = floor_scene.instantiate()
				var cell: Vector3i = Vector3i(x, y, f)
				var th: Resource = theme_grass
				if use_checker_pattern:
					th = theme_grass if (x + y) % 2 == 0 else theme_stone
				piece.set("theme", th)
				piece.set("cell", cell)
				add_child(piece)
				_pieces.append(piece)
				piece.global_position = Vector3(
					float(x) * BoardGrid.TILE + BoardGrid.TILE * 0.5,
					float(f) * BoardGrid.FLOOR_H,
					float(y) * BoardGrid.TILE + BoardGrid.TILE * 0.5
				)

func clear_board() -> void:
	for p: Variant in _pieces:
		if is_instance_valid(p as Object):
			(p as Node).queue_free()
	_pieces.clear()
	for c: Node in get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("floor_piece.gd"):
			c.queue_free()

func bake_grid() -> void:
	var bounds: Rect2 = Rect2(0, 0, float(width) * BoardGrid.TILE, float(height) * BoardGrid.TILE)
	BoardGrid.bake_from_physics(self, bounds, floors_n)
	var stats: String = BoardGrid.bake_stats()
	print_rich("[color=green][Board][/color] ", stats)
	for i: int in range(min(3, width * height)):
		var cx: int = i % width
		var cy: int = i / width
		var c: Vector3i = Vector3i(cx, cy, 0)
		var d: Dictionary = BoardGrid.cell_data(c)
		print("  cell ", c, " -> ", d)

func regenerate_and_bake() -> void:
	generate_board()
	await get_tree().physics_frame
	await get_tree().physics_frame
	bake_grid()

func get_pieces() -> Array:
	return _pieces

func map_bounds() -> Rect2:
	return Rect2(0, 0, float(width) * BoardGrid.TILE, float(height) * BoardGrid.TILE)
