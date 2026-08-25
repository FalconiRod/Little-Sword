extends Node3D
class_name Board

const CD = preload("res://src/resources/character_definition.gd")

@export var width: int = 10
@export var height: int = 10
@export var floors_n: int = 1
@export var theme_grass: Resource
@export var theme_stone: Resource
@export var use_checker_pattern: bool = true
@export var demo_fase2: bool = true
@export var demo_fase5: bool = false
@export var active_floor: int = 0

const TILE_F: float = 2.0
const FLOOR_H_F: float = 7.0

var _pieces: Array = []
var _walls: Array = []
var _doors: Array = []
var _columns: Array = []
var _obstacles: Array = []
var _units: Array = []
var _stairs: Array = []
var _regen_count: int = 0

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
	if demo_fase5:
		floors_n = 2
	else:
		floors_n = 1
	if theme_grass == null:
		theme_grass = _make_grass_theme()
	if theme_stone == null:
		theme_stone = _make_stone_theme()
	generate_board()
	if demo_fase2:
		generate_fase2_demo()
	generate_fase3_units()
	if demo_fase5:
		generate_fase5_demo()
	await get_tree().physics_frame
	await get_tree().physics_frame
	bake_grid()
	# expõe active_floor no BoardGrid
	var bg: Node = _get_board_grid()
	if bg and bg.has_method("set_active_floor"):
		bg.call("set_active_floor", active_floor)
	_apply_floor_visibility()

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
	print("[Board] generate_board width=", width, " height=", height, " tile=", tile, " fh=", fh)
	for f: int in range(floors_n):
		for x: int in range(width):
			for y: int in range(height):
				var piece: Node = floor_scene.instantiate()
				if piece == null:
					continue
				var cell: Vector3i = Vector3i(x, y, f)
				var th: Resource = theme_grass
				if use_checker_pattern:
					th = theme_grass if (x + y + _regen_count) % 2 == 0 else theme_stone
				piece.set("theme", th)
				piece.set("cell", cell)
				add_child(piece)
				_pieces.append(piece)
				var pos: Vector3 = Vector3(float(x)*tile+tile*0.5, float(f)*fh, float(y)*tile+tile*0.5)
				piece.global_position = pos
	print("[Board] generate_board fim pieces=", _pieces.size())

func generate_fase2_demo() -> void:
	var bg: Node = _get_board_grid()
	if bg and bg.has_method("clear_walls_doors"):
		bg.call("clear_walls_doors")
	# — paredes perimetrais (deixa abertura para porta em (5,0) norte)
	var wall_scene: PackedScene = load("res://src/board/wall_piece.tscn") as PackedScene
	var door_scene: PackedScene = load("res://src/board/door_piece.tscn") as PackedScene
	var col_scene: PackedScene = load("res://src/board/column_piece.tscn") as PackedScene
	var prop_scene: PackedScene = load("res://src/board/prop_obstacle.tscn") as PackedScene

	# paredes: borda do tabuleiro exceto porta
	for x: int in range(width):
		for y: int in range(height):
			if x == 0:
				_add_wall(Vector3i(x,y,0), "west", wall_scene)
			if x == width-1:
				_add_wall(Vector3i(x,y,0), "east", wall_scene)
			if y == 0 and not (x == 5):
				_add_wall(Vector3i(x,y,0), "north", wall_scene)
			if y == height-1:
				_add_wall(Vector3i(x,y,0), "south", wall_scene)
	# paredes internas demo: corredor
	_add_wall(Vector3i(3,3,0), "east", wall_scene)
	_add_wall(Vector3i(3,4,0), "east", wall_scene)
	_add_wall(Vector3i(6,5,0), "south", wall_scene)

	# porta: na borda norte de (5,0) fechada — atrás é (5,-1) fora do board, então não viola; também porta interna em (5,2) south
	var door1: Node = door_scene.instantiate()
	door1.set("edge_cell", Vector3i(5,0,0))
	door1.set("edge_dir", "north")
	door1.set("state", 0) # CLOSED
	add_child(door1)
	_doors.append(door1)
	if bg and bg.has_method("register_door"):
		bg.call("register_door", Vector3i(5,0,0), "north", 1)
	print("[Board] porta1 ", door1.get("edge_cell"), door1.get("edge_dir"), " state CLOSED")

	var door2: Node = door_scene.instantiate()
	door2.set("edge_cell", Vector3i(5,4,0))
	door2.set("edge_dir", "east")
	door2.set("state", 1) # OPEN
	add_child(door2)
	_doors.append(door2)
	if bg and bg.has_method("register_door"):
		bg.call("register_door", Vector3i(5,4,0), "east", 0)
	# porta trancada demo
	var door3: Node = door_scene.instantiate()
	door3.set("edge_cell", Vector3i(8,5,0))
	door3.set("edge_dir", "west")
	door3.set("state", 2) # LOCKED
	add_child(door3)
	_doors.append(door3)
	if bg and bg.has_method("register_door"):
		bg.call("register_door", Vector3i(8,5,0), "west", 2)

	# colunas
	_add_column(Vector3i(2,5,0), col_scene)
	_add_column(Vector3i(7,3,0), col_scene)

	# obstáculos — 4 tipos da tabela
	_add_obstacle(Vector3i(2,2,0), 1, prop_scene) # LARGE
	_add_obstacle(Vector3i(7,2,0), 2, prop_scene) # LOW_WALL
	_add_obstacle(Vector3i(7,7,0), 3, prop_scene) # HIGH_WALL
	_add_obstacle(Vector3i(4,4,0), 0, prop_scene) # DECOR_SMALL (não bloqueia)

	print("[Board] Fase2 demo: walls=", _walls.size(), " doors=", _doors.size(), " cols=", _columns.size(), " obs=", _obstacles.size())

func generate_fase5_demo() -> void:
	var stairs_scene: PackedScene = load("res://src/board/stairs_piece.tscn") as PackedScene
	var def: Resource = load("res://src/resources/stairs_definition.gd").new()
	def.set("floors", 2)
	var n: Node = stairs_scene.instantiate()
	n.set("bottom_cell", Vector3i(6,0,0))
	n.set("top_cell", Vector3i(6,0,1))
	n.set("definition", def)
	add_child(n)
	_stairs.append(n)
	print("[Board] Fase5 casa 2 andares link ", n.get("bottom_cell"), " -> ", n.get("top_cell"))
	# segundo andar tem chao extra e uma unidade no topo para demo
	# (o chao já foi gerado para floors_n=2)
	# move uma unidade para o topo para testar
	var bg: Node = _get_board_grid()
	if bg and bg.has_method("add_stair_link"):
		# já registrado pelo stairs_piece
		pass
	_apply_floor_visibility()

func _apply_floor_visibility_simple() -> void:
	for child: Node in get_children():
		if child.get("cell") != null:
			var c: Vector3i = child.get("cell") as Vector3i
			var mesh: Node = child.get_node_or_null("MeshInstance3D") as Node
			if mesh and mesh.has_method("get_active_material"):
				pass
			# se for FloorPiece/Prop/Column/Unit
			if c.z == active_floor:
				child.visible = true
				if child.has_node("MeshInstance3D"):
					var mi: MeshInstance3D = child.get_node("MeshInstance3D") as MeshInstance3D
					if mi and mi.mesh and mi.mesh.surface_get_material(0):
						var mat: StandardMaterial3D = mi.mesh.surface_get_material(0) as StandardMaterial3D
						if mat:
							mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
							mat.albedo_color.a = 1.0
			elif c.z < active_floor:
				child.visible = true
				# andares abaixo semi-transparente
				if child.has_node("MeshInstance3D"):
					var mi2: MeshInstance3D = child.get_node("MeshInstance3D") as MeshInstance3D
					if mi2 and mi2.mesh and mi2.mesh.surface_get_material(0):
						var mat2: StandardMaterial3D = mi2.mesh.surface_get_material(0) as StandardMaterial3D
						if mat2:
							mat2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
							mat2.albedo_color.a = 0.35
			else:
				# andar acima invisível (ou 0.15 se quiser ver)
				child.visible = false
		elif child.get("grid_pos") != null:
			var c2: Vector3i = child.get("grid_pos") as Vector3i
			child.visible = (c2.z == active_floor)
		elif child.get("bottom_cell") != null:
			# escada sempre visível
			child.visible = true

func generate_fase3_units() -> void:
	var unit_scene: PackedScene = load("res://src/units/board_unit.tscn") as PackedScene
	var defs: Array = [
		[CD.create_cavaleiro(), Vector3i(1,1,0)],
		[CD.create_maga(), Vector3i(1,2,0)],
		[CD.create_druida(), Vector3i(1,8,0)],
		[CD.create_goblin_guerreiro(), Vector3i(8,1,0)],
		[CD.create_goblin_arqueiro(), Vector3i(8,8,0)],
		[CD.create_boss(), Vector3i(5,8,0)],
	]
	for pair: Array in defs:
		var def: Resource = pair[0] as Resource
		var cell: Vector3i = pair[1] as Vector3i
		var u: Node = unit_scene.instantiate()
		u.set("definition", def)
		u.set("grid_pos", cell)
		add_child(u)
		_units.append(u)
		# registra no BoardGrid occupied (se existir)
		var bg: Node = _get_board_grid()
		if bg and bg.has_method("place"):
			bg.call("place", u, cell)
		print("[Board] unit ", def.get("display_name"), " em ", cell, " HP", def.get("hp_max"), " CA", def.get("ca"))
	# demo transformação druida após 2s
	var druida: Node = _units[2] as Node
	if druida:
		print("[Board] Druida transformação demo: pressione T para transformar/reverter")

func _add_wall(cell: Vector3i, dir: String, scene: PackedScene) -> void:
	var n: Node = scene.instantiate()
	n.set("edge_cell", cell)
	n.set("edge_dir", dir)
	add_child(n)
	_walls.append(n)
	var bg: Node = _get_board_grid()
	if bg and bg.has_method("register_wall"):
		bg.call("register_wall", cell, dir)

func _add_column(cell: Vector3i, scene: PackedScene) -> void:
	var n: Node = scene.instantiate()
	n.set("cell", cell)
	add_child(n)
	_columns.append(n)
	var bg: Node = _get_board_grid()
	if bg and bg.has_method("register_wall"):
		# coluna bloqueia visão/mov como parede pontual
		bg.call("set_tile", cell, false, true, 0)

func _add_obstacle(cell: Vector3i, type: int, scene: PackedScene) -> void:
	var def: Resource = load("res://src/resources/prop_obstacle_definition.gd").new()
	def.set("type", type)
	var n: Node = scene.instantiate()
	n.set("definition", def)
	n.set("cell", cell)
	add_child(n)
	_obstacles.append(n)
	var bg: Node = _get_board_grid()
	if bg and bg.has_method("set_tile"):
		var blocks_mov: bool = bool(def.call("blocks_movement"))
		var blocks_los: bool = bool(def.call("blocks_line_of_sight"))
		# só sobrescreve walkable/blocks_los se já houver célula
		var d: Dictionary = bg.call("cell_data", cell) as Dictionary
		var walk: bool = true
		if d.has("walkable"):
			walk = bool(d.get("walkable", true))
		# obstáculos bloqueantes marcam walkable false
		if blocks_mov:
			walk = false
		var los: bool = blocks_los
		if d.has("blocks_los") and bool(d.get("blocks_los", false)):
			los = true
		bg.call("set_tile", cell, walk, los, 0)

func clear_board() -> void:
	for p: Variant in _pieces:
		if is_instance_valid(p as Object):
			(p as Node).queue_free()
	_pieces.clear()
	for w: Variant in _walls:
		if is_instance_valid(w as Object):
			(w as Node).queue_free()
	_walls.clear()
	for d: Variant in _doors:
		if is_instance_valid(d as Object):
			(d as Node).queue_free()
	_doors.clear()
	for c: Variant in _columns:
		if is_instance_valid(c as Object):
			(c as Node).queue_free()
	_columns.clear()
	for o: Variant in _obstacles:
		if is_instance_valid(o as Object):
			(o as Node).queue_free()
	_obstacles.clear()
	for u: Variant in _units:
		if is_instance_valid(u as Object):
			(u as Node).queue_free()
	_units.clear()
	for s: Variant in _stairs:
		if is_instance_valid(s as Object):
			(s as Node).queue_free()
	_stairs.clear()
	var bg: Node = _get_board_grid()
	if bg:
		if bg.has_method("clear_walls_doors"):
			bg.call("clear_walls_doors")
		if bg.has_method("reset"):
			# limpa occupied mas mantém bounds — reset completo faz no bake
			var occupied: Dictionary = bg.get("occupied") if "occupied" in bg else {}
			if occupied is Dictionary:
				occupied.clear()
	# remove órfãos restantes
	for child: Node in get_children():
		if child.get_script() == null:
			continue
		var path: String = child.get_script().resource_path
		if path.ends_with("floor_piece.gd") or path.ends_with("wall_piece.gd") or path.ends_with("door_piece.gd") or path.ends_with("column_piece.gd") or path.ends_with("prop_obstacle.gd") or path.ends_with("board_unit.gd"):
			child.queue_free()

func bake_grid() -> void:
	var tile: float = _tile()
	var bounds: Rect2 = Rect2(0, 0, float(width) * tile, float(height) * tile)
	var bg: Node = _get_board_grid()
	if bg and bg.has_method("bake_from_physics"):
		bg.call("bake_from_physics", self, bounds, floors_n)
		# reaplica bloqueios que raycast vertical não pega (coluna, mureta, etc)
		for col: Node in _columns:
			var cell_c: Vector3i = col.get("cell") as Vector3i
			var d_c: Dictionary = bg.call("cell_data", cell_c) as Dictionary
			bg.call("set_tile", cell_c, false, true, int(d_c.get("elev", 0)), float(d_c.get("height", 0.0)))
		for o: Node in _obstacles:
			var cell: Vector3i = o.get("cell") as Vector3i
			var def: Resource = o.get("definition") as Resource
			if def:
				var blocks_mov: bool = bool(def.call("blocks_movement"))
				var blocks_los: bool = bool(def.call("blocks_line_of_sight"))
				var d: Dictionary = bg.call("cell_data", cell) as Dictionary
				var walk: bool = bool(d.get("walkable", true)) if d.has("walkable") else true
				if blocks_mov:
					walk = false
				var los: bool = blocks_los or bool(d.get("blocks_los", false))
				bg.call("set_tile", cell, walk, los, int(d.get("elev", 0)), float(d.get("height", 0.0)))
		var stats: String = bg.call("bake_stats") as String
		print_rich("[color=green][Board][/color] ", stats)
		if bg.has_method("validate_door_rule"):
			var warns: Array = bg.call("validate_door_rule") as Array
			if warns.size() > 0:
				for w: String in warns:
					print_rich("[color=yellow]", w, "[/color]")
			else:
				print("[Board] porta desobstruida OK (nenhuma violacao)")
		print("[Board] walls=", bg.call("wall_count") if bg.has_method("wall_count") else "?", " doors=", bg.call("door_count") if bg.has_method("door_count") else "?")
		for i: int in range(min(3, width * height)):
			var cx: int = i % width
			var cy: int = i / width
			var c: Vector3i = Vector3i(cx, cy, 0)
			var d: Dictionary = bg.call("cell_data", c) as Dictionary
			print("  cell ", c, " -> ", d)
	else:
		push_warning("[Board] BoardGrid nao encontrado para bake")

func set_active_floor(idx: int) -> void:
	active_floor = clampi(idx, 0, floors_n-1)
	var bg: Node = _get_board_grid()
	if bg and bg.has_method("set_active_floor"):
		bg.call("set_active_floor", active_floor)
	_apply_floor_visibility()
	print("[Board] active_floor -> ", active_floor)

func _apply_floor_visibility() -> void:
	for child: Node in get_children():
		var has_cell: bool = child.get("cell") != null
		var has_grid: bool = child.get("grid_pos") != null
		var has_bottom: bool = child.get("bottom_cell") != null
		if has_cell:
			var c: Vector3i = child.get("cell") as Vector3i
			if c.z == active_floor:
				child.visible = true
				_set_alpha(child, 1.0)
			elif c.z < active_floor:
				child.visible = true
				_set_alpha(child, 0.35)
			else:
				child.visible = false
		elif has_grid:
			var c2: Vector3i = child.get("grid_pos") as Vector3i
			child.visible = (c2.z == active_floor)
		elif has_bottom:
			# escada/casa sempre visível mas com alpha conforme andar
			child.visible = true
			var sc: Vector3i = child.get("bottom_cell") as Vector3i
			if sc.z == active_floor:
				_set_alpha(child, 1.0)
			else:
				_set_alpha(child, 0.45)
		elif child.get("edge_cell") != null:
			var ec: Vector3i = child.get("edge_cell") as Vector3i
			child.visible = (ec.z == active_floor)

func _set_alpha(node: Node, alpha: float) -> void:
	var mi: MeshInstance3D = node.get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mi == null:
		mi = node.get_node_or_null("HouseMesh") as MeshInstance3D
	if mi and mi.mesh:
		var mat: StandardMaterial3D = mi.mesh.surface_get_material(0) as StandardMaterial3D
		if mat:
			if alpha < 0.99:
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			else:
				mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			mat.albedo_color.a = alpha
	# também tenta StairsMesh
	var sm: MeshInstance3D = node.get_node_or_null("StairsMesh") as MeshInstance3D
	if sm and sm.mesh:
		var m2: StandardMaterial3D = sm.mesh.surface_get_material(0) as StandardMaterial3D
		if m2:
			if alpha < 0.99:
				m2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			else:
				m2.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			m2.albedo_color.a = alpha

func regenerate_and_bake() -> void:
	_regen_count += 1
	print("[Board] regenerate_and_bake #", _regen_count)
	generate_board()
	if demo_fase2:
		generate_fase2_demo()
	generate_fase3_units()
	if demo_fase5:
		generate_fase5_demo()
	await get_tree().physics_frame
	await get_tree().physics_frame
	bake_grid()
	var bg2: Node = _get_board_grid()
	if bg2 and bg2.has_method("set_active_floor"):
		bg2.call("set_active_floor", active_floor)
	_apply_floor_visibility()
	print("[Board] regen #", _regen_count, " concluido - xadrez invertido")

func get_pieces() -> Array:
	return _pieces

func get_units() -> Array:
	return _units

func map_bounds() -> Rect2:
	var tile: float = _tile()
	return Rect2(0, 0, float(width) * tile, float(height) * tile)
