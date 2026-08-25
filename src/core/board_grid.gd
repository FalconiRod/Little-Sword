extends Node
## BoardGrid — fonte ÚNICA de verdade do grid tático.
##
## Convenções fixas (seção 2 do PROMPT MESTRE):
##   TILE = 2.0  -> cada célula mede 2x2 unidades.
##   célula (col, row, floor) ocupa [col*2, col*2+2] × [row*2, row*2+2];
##   centro = col*TILE + TILE/2.
##   Conversão grid_to_world() / world_to_cell() existe SOMENTE aqui.
##   Proibido fazer floor/round de coordenada em qualquer outro arquivo.

const TILE: float = 2.0
const FLOOR_H: float = 7.0
const ELEV_H: float = 0.55
const WALKABLE_CLEARANCE: float = 1.8
const RAY_FROM_OFFSET: float = 2.5
const RAY_TO_OFFSET: float = 4.0

## Dados por célula: Vector3i(col, row, floor) -> CellData
var _cells: Dictionary = {}  # Vector3i -> Dictionary
var _walls: Dictionary = {} # String key "x,y,z:dir" -> true
var _doors: Array = [] # Array[Dictionary {edge:Vector3i, dir:String, state:int, behind:Vector3i}]
var occupied: Dictionary = {} # Vector3i -> BoardUnit (Fase3)
var stair_links: Dictionary = {} # Vector3i -> Vector3i bidirecional
var active_floor_index: int = 0
var _bounds: Rect2 = Rect2(0, 0, 10, 10)
var _floors_n: int = 1

# -- Estrutura interna de célula --
# {
#   walkable: bool,
#   blocks_los: bool,
#   cover: int,        # 0 none, 2 meia, 99 total
#   height: float,
#   elev: int,
#   has_floor: bool
# }

func reset() -> void:
	_cells.clear()
	_walls.clear()
	_doors.clear()
	occupied.clear()
	stair_links.clear()
	active_floor_index = 0
	_bounds = Rect2(0, 0, 10, 10)
	_floors_n = 1

func add_stair_link(a: Vector3i, b: Vector3i) -> void:
	if a.z == b.z:
		push_error("Stair precisa andares diferentes %s" % str([a,b]))
		return
	if a.z > b.z:
		var t: Vector3i = a
		a = b
		b = t
	stair_links[a] = b
	stair_links[b] = a

func stair_pair(cell: Vector3i) -> Vector3i:
	return stair_links.get(cell, cell)

func try_cross_stairs(cell: Vector3i) -> Variant:
	var dest: Vector3i = stair_links.get(cell, cell)
	if dest == cell:
		return null
	if not is_walkable(dest):
		return null
	# célula atrás da escada no andar destino deve estar livre (regra similar porta)
	return dest

func set_active_floor(idx: int) -> void:
	active_floor_index = clampi(idx, 0, max(0, _floors_n -1))

func place(unit: Node, cell: Vector3i) -> void:
	occupied[cell] = unit
	if unit.has_method("place_at"):
		unit.set("grid_pos", cell)

func clear_cell(cell: Vector3i) -> void:
	occupied.erase(cell)

func unit_at(cell: Vector3i) -> Node:
	return occupied.get(cell, null)

func is_free(cell: Vector3i) -> bool:
	return is_walkable(cell) and not occupied.has(cell)

func clear_walls_doors() -> void:
	_walls.clear()
	_doors.clear()
	stair_links.clear()

func _wall_key(cell: Vector3i, dir: String) -> String:
	return "%d,%d,%d:%s" % [cell.x, cell.y, cell.z, dir]

func register_wall(cell: Vector3i, dir: String) -> void:
	_walls[_wall_key(cell, dir)] = true
	# também registra inversa na célula vizinha
	var n: Vector3i = _neighbor_in_dir(cell, dir)
	if n != cell:
		var inv: String = _opposite_dir(dir)
		_walls[_wall_key(n, inv)] = true

func register_door(edge_cell: Vector3i, dir: String, state: int) -> void:
	var behind: Vector3i = _neighbor_in_dir(edge_cell, dir)
	_doors.append({"edge": edge_cell, "dir": dir, "state": state, "behind": behind})
	# porta fechada/trancada conta como parede
	if state != 0: # 0 = OPEN (DoorPiece.State.OPEN)
		register_wall(edge_cell, dir)

func _neighbor_in_dir(cell: Vector3i, dir: String) -> Vector3i:
	match dir:
		"north": return cell + Vector3i(0, -1, 0)
		"south": return cell + Vector3i(0, 1, 0)
		"west": return cell + Vector3i(-1, 0, 0)
		"east": return cell + Vector3i(1, 0, 0)
		_: return cell

func _opposite_dir(dir: String) -> String:
	match dir:
		"north": return "south"
		"south": return "north"
		"west": return "east"
		"east": return "west"
		_: return dir

func has_wall_between(a: Vector3i, b: Vector3i) -> bool:
	if a.z != b.z:
		return false
	var dx: int = b.x - a.x
	var dy: int = b.y - a.y
	if abs(dx) + abs(dy) != 1:
		return false
	if dx == 1:
		return _walls.has(_wall_key(a, "east")) or _walls.has(_wall_key(b, "west"))
	if dx == -1:
		return _walls.has(_wall_key(a, "west")) or _walls.has(_wall_key(b, "east"))
	if dy == 1:
		return _walls.has(_wall_key(a, "south")) or _walls.has(_wall_key(b, "north"))
	if dy == -1:
		return _walls.has(_wall_key(a, "north")) or _walls.has(_wall_key(b, "south"))
	return false

func is_wall_blocking(cell: Vector3i, dir: String) -> bool:
	return _walls.has(_wall_key(cell, dir))

func validate_door_rule() -> Array[String]:
	var warnings: Array[String] = []
	for d: Dictionary in _doors:
		var behind: Vector3i = d["behind"] as Vector3i
		if _cells.has(behind):
			var data: Dictionary = _cells[behind] as Dictionary
			if not bool(data.get("walkable", false)):
				var msg: String = "[BoardGrid] REGRA VIOLADA: porta em %s %s tem celula atras %s bloqueada (walkable=false) — remover obstaculo" % [str(d["edge"]), d["dir"], str(behind)]
				warnings.append(msg)
				push_warning(msg)
	return warnings

func get_bounds() -> Rect2:
	return _bounds

func get_floors_n() -> int:
	return _floors_n

func get_cells() -> Dictionary:
	return _cells

# ------------------------------------------------------------------ #
# CONVERSÃO CANÔNICA — ÚNICO LUGAR DO PROJETO
# ------------------------------------------------------------------ #

## Centro mundial da célula (inclui altura de superfície + elevação).
func grid_to_world(cell: Vector3i) -> Vector3:
	var base_y: float = float(cell.z) * FLOOR_H
	var h: float = _surface_height(cell)
	return Vector3(
		float(cell.x) * TILE + TILE * 0.5,
		base_y + h,
		float(cell.y) * TILE + TILE * 0.5
	)

## Mundo -> célula (floor_idx explícito; z do mundo não infere andar).
func world_to_cell(p: Vector3, floor_idx: int = 0) -> Vector3i:
	return Vector3i(
		floori(p.x / TILE),
		floori(p.z / TILE),
		floor_idx
	)

## Alias para compatibilidade com código legado.
func world_pos(cell: Vector3i) -> Vector3:
	return grid_to_world(cell)

# -- Altura de superfície extra (para colinas orgânicas) --
var _surface: Dictionary = {} # Vector3i -> float

func set_surface(cell: Vector3i, h: float) -> void:
	if h <= 0.001:
		_surface.erase(cell)
	else:
		_surface[cell] = h

func _surface_height(cell: Vector3i) -> float:
	# Se bake registrou height, usa ele; senão fallback para _surface
	if _cells.has(cell):
		var d: Dictionary = _cells[cell] as Dictionary
		var height: float = float(d.get("height", 0.0))
		var floor_base: float = float(cell.z) * FLOOR_H
		return height - floor_base
	return float(_surface.get(cell, 0.0))

func get_height(cell: Vector3i) -> float:
	if _cells.has(cell):
		return float((_cells[cell] as Dictionary).get("height", float(cell.z) * FLOOR_H))
	return float(cell.z) * FLOOR_H + float(_surface.get(cell, 0.0))

# ------------------------------------------------------------------ #
# CONSULTA
# ------------------------------------------------------------------ #

func is_walkable(cell: Vector3i) -> bool:
	if not _cells.has(cell):
		return false
	return bool((_cells[cell] as Dictionary).get("walkable", false))

func blocks_los(cell: Vector3i) -> bool:
	if not _cells.has(cell):
		return false
	return bool((_cells[cell] as Dictionary).get("blocks_los", false))

func has_floor(cell: Vector3i) -> bool:
	if not _cells.has(cell):
		return false
	return bool((_cells[cell] as Dictionary).get("has_floor", false))

func cell_data(cell: Vector3i) -> Dictionary:
	if _cells.has(cell):
		return (_cells[cell] as Dictionary).duplicate()
	return {}

# ------------------------------------------------------------------ #
# ESCRITA MANUAL (usado só por testes ou fallback)
# ------------------------------------------------------------------ #

func set_tile(cell: Vector3i, walkable: bool, blocks_los_flag: bool = false, elev: int = 0, height: float = 0.0, cover: int = 0) -> void:
	var floor_base: float = float(cell.z) * FLOOR_H
	var h: float = height if height != 0.0 else floor_base + float(elev) * ELEV_H
	var cur_cover: int = cover
	if _cells.has(cell):
		var cur: Dictionary = _cells[cell] as Dictionary
		if cur.has("cover"):
			cur_cover = maxi(cur_cover, int(cur.get("cover", 0)))
	_cells[cell] = {
		"walkable": walkable,
		"blocks_los": blocks_los_flag,
		"cover": cur_cover,
		"height": h,
		"elev": elev,
		"has_floor": walkable or blocks_los_flag or h != floor_base,
	}

# ------------------------------------------------------------------ #
# BAKE POR RAYCAST — fonte única de verdade (seção 3-B)
# ------------------------------------------------------------------ #

## Gera o grid a partir de colisão real.
## env: Node3D que contém as peças (precisa ter get_world_3d()).
## map_bounds: retângulo em coordenadas de mundo (x,z) cobrindo o tabuleiro.
## floors_n: número de andares.
func bake_from_physics(env: Node3D, map_bounds: Rect2, floors_n: int) -> void:
	_cells.clear()
	_surface.clear()
	# NÃO limpa _walls/_doors aqui — Board registra manualmente após gerar peças
	_bounds = map_bounds
	_floors_n = floors_n

	var space: PhysicsDirectSpaceState3D = env.get_world_3d().direct_space_state
	if space == null:
		push_warning("[BoardGrid] bake_from_physics: sem PhysicsDirectSpaceState3D")
		return

	var min_x: int = int(floor(map_bounds.position.x / TILE))
	var min_y: int = int(floor(map_bounds.position.y / TILE))
	var max_x: int = int(ceil((map_bounds.position.x + map_bounds.size.x) / TILE)) - 1
	var max_y: int = int(ceil((map_bounds.position.y + map_bounds.size.y) / TILE)) - 1

	# Fallback se bounds for vazio/zero
	if map_bounds.size.x <= 0.01 or map_bounds.size.y <= 0.01:
		min_x = 0
		min_y = 0
		max_x = 9
		max_y = 9
		_bounds = Rect2(0, 0, 10 * TILE, 10 * TILE)

	for f: int in range(floors_n):
		for cx: int in range(min_x, max_x + 1):
			for cy: int in range(min_y, max_y + 1):
				var cell: Vector3i = Vector3i(cx, cy, f)
				var center_x: float = float(cx) * TILE + TILE * 0.5
				var center_z: float = float(cy) * TILE + TILE * 0.5
				var base_y: float = float(f) * FLOOR_H

				var from: Vector3 = Vector3(center_x, base_y + RAY_FROM_OFFSET, center_z)
				var to: Vector3 = Vector3(center_x, base_y - RAY_TO_OFFSET, center_z)

				var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 1)
				q.collide_with_bodies = true
				q.collide_with_areas = false

				var hit: Dictionary = space.intersect_ray(q)

				if hit.is_empty():
					_cells[cell] = {
						"walkable": false,
						"blocks_los": false,
						"height": base_y,
						"elev": 0,
						"has_floor": false,
					}
					continue

				var pos: Vector3 = hit["position"] as Vector3
				var col: Object = hit["collider"] as Object

				var walkable: bool = true
				var blocks_los_flag: bool = false

				if col is Node and (col as Node).has_meta("walkable"):
					walkable = bool((col as Node).get_meta("walkable"))
				if col is Node and (col as Node).has_meta("blocks_los"):
					blocks_los_flag = bool((col as Node).get_meta("blocks_los"))

				var h: float = pos.y
				var rel_h: float = h - base_y
				var elev: int = clampi(int(round(rel_h / ELEV_H)), 0, 8)
				var cover: int = 0
				if col is Node and (col as Node).has_meta("cover_bonus"):
					cover = int((col as Node).get_meta("cover_bonus"))
				# Checa espaço livre acima (margem andável) — também captura blocks_los/cover de obstáculo
				var clearance_from: Vector3 = pos + Vector3(0, 0.1, 0)
				var clearance_to: Vector3 = pos + Vector3(0, WALKABLE_CLEARANCE, 0)
				var q2: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(clearance_from, clearance_to, 1)
				q2.collide_with_bodies = true
				q2.collide_with_areas = false
				var hit2: Dictionary = space.intersect_ray(q2)
				if not hit2.is_empty():
					walkable = false
					var col2: Object = hit2["collider"] as Object
					if col2 is Node:
						if col2.has_meta("blocks_los") and bool(col2.get_meta("blocks_los")):
							blocks_los_flag = true
						if col2.has_meta("cover_bonus"):
							cover = maxi(cover, int(col2.get_meta("cover_bonus")))
						if col2.has_meta("cover"):
							cover = maxi(cover, int(col2.get_meta("cover")))

				_cells[cell] = {
					"walkable": walkable,
					"blocks_los": blocks_los_flag,
					"cover": cover,
					"height": h,
					"elev": elev,
					"has_floor": true,
				}

				# Guarda altura fracionária extra para visual
				var frac: float = rel_h - float(elev) * ELEV_H
				if abs(frac) > 0.01:
					_surface[cell] = frac

## Debug: estatísticas do bake
func bake_stats() -> String:
	var total: int = _cells.size()
	var walk: int = 0
	var blocked: int = 0
	for k: Variant in _cells.keys():
		var d: Dictionary = _cells[k] as Dictionary
		if bool(d.get("walkable", false)):
			walk += 1
		else:
			blocked += 1
	return "BoardGrid bake: total=%d walkable=%d blocked=%d bounds=%s floors=%d" % [total, walk, blocked, str(_bounds), _floors_n]

# ------------------------------------------------------------------ #
# HELPERS DE NAVEGAÇÃO (BFS simples, para fases futuras)
# ------------------------------------------------------------------ #

func neighbors(cell: Vector3i) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for off: Vector3i in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0)]:
		var n: Vector3i = cell + off
		if is_walkable(n):
			var ea: int = int((_cells[cell] as Dictionary).get("elev", 0)) if _cells.has(cell) else 0
			var eb: int = int((_cells[n] as Dictionary).get("elev", 0)) if _cells.has(n) else 0
			if abs(eb - ea) <= 1:
				if not has_wall_between(cell, n):
					out.append(n)
	var stair: Vector3i = stair_links.get(cell, cell)
	if stair != cell and is_walkable(stair):
		out.append(stair)
	return out

func compute_reachable(start: Vector3i, max_steps: int, ignore_units: bool = true) -> Dictionary:
	var dist: Dictionary = {start: 0}
	var came: Dictionary = {start: start}
	var frontier: Array[Vector3i] = [start]
	while not frontier.is_empty():
		var cur: Vector3i = frontier.pop_front()
		var d: int = dist[cur] as int
		if d >= max_steps:
			continue
		for n: Vector3i in neighbors(cur):
			if dist.has(n):
				continue
			if not ignore_units and occupied.has(n):
				continue
			if has_wall_between(cur, n):
				continue
			dist[n] = d + 1
			came[n] = cur
			frontier.append(n)
	return {"dist": dist, "came": came}

func path_from_reachable(reach: Dictionary, dest: Vector3i) -> Array:
	if not reach["dist"].has(dest):
		return []
	var path: Array = []
	var cur: Vector3i = dest
	while cur != reach["came"][cur]:
		path.push_front(cur)
		cur = reach["came"][cur] as Vector3i
	return path

func has_line_of_sight(a: Vector3i, b: Vector3i) -> bool:
	if a.z != b.z:
		return false
	var wa: Vector3 = grid_to_world(a) + Vector3(0, 0.6, 0)
	var wb: Vector3 = grid_to_world(b) + Vector3(0, 0.6, 0)
	var dist_f: float = wa.distance_to(wb)
	if dist_f < 0.01:
		return true
	var steps: int = int(ceil(dist_f / (TILE * 0.25)))
	var prev: Vector3i = a
	for i: int in range(1, steps):
		var p: Vector3 = wa.lerp(wb, float(i) / float(steps))
		var cc: Vector3i = world_to_cell(p, a.z)
		if blocks_los(cc):
			return false
		if i > 1 and has_wall_between(prev, cc):
			return false
		prev = cc
	# também verifica parede entre a e primeiro sample, e último sample e b
	if has_wall_between(a, world_to_cell(wa.lerp(wb, 1.0/float(steps)), a.z)):
		return false
	if has_wall_between(world_to_cell(wa.lerp(wb, float(steps-1)/float(steps)), a.z), b):
		return false
	return true

func wall_count() -> int:
	return _walls.size()

func door_count() -> int:
	return _doors.size()
