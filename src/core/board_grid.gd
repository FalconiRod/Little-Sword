extends Node
## Modelo do tabuleiro: grid lógico, ocupação por peças e pathfinding BFS.
## Coordenada de célula = Vector2i(x, z). Mundo = célula * TILE.

const TILE := 2.0

var w: int = 0
var h: int = 0
var walkable: Dictionary = {}   # Vector2i -> true
var special: Dictionary = {}    # Vector2i -> "T"|"C"|"r"
var occupied: Dictionary = {}   # Vector2i -> BoardUnit
var spawns: Dictionary = {}     # char -> Array[Vector2i]

func setup(lines: Array) -> void:
	walkable.clear()
	special.clear()
	occupied.clear()
	spawns.clear()
	h = lines.size()
	w = 0
	for z in h:
		var row: String = lines[z]
		w = max(w, row.length())
		for x in row.length():
			var ch := row[x]
			var c := Vector2i(x, z)
			if ch == "#":
				continue
			walkable[c] = true
			if ch != ".":
				special[c] = ch
				if "KgaB".contains(ch):
					if not spawns.has(ch):
						spawns[ch] = []
					spawns[ch].append(c)

func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < w and c.y < h

func is_walkable(c: Vector2i) -> bool:
	return walkable.has(c)

func is_free(c: Vector2i) -> bool:
	return is_walkable(c) and not occupied.has(c)

func unit_at(c: Vector2i):
	return occupied.get(c, null)

func place(u, c: Vector2i) -> void:
	u.grid_pos = c
	occupied[c] = u

func clear_cell(c: Vector2i) -> void:
	occupied.erase(c)

func move_unit(u, dest: Vector2i) -> void:
	clear_cell(u.grid_pos)
	place(u, dest)

func world_pos(c: Vector2i) -> Vector3:
	return Vector3(c.x * TILE, 0.0, c.y * TILE)

func cell_of(world: Vector3) -> Vector2i:
	return Vector2i(int(round(world.x / TILE)), int(round(world.z / TILE)))

func neighbors4(c: Vector2i) -> Array:
	var out: Array = []
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		out.append(c + d)
	return out

func chebyshev(a: Vector2i, b: Vector2i) -> int:
	return max(abs(a.x - b.x), abs(a.y - b.y))

## Linha de visão: amostra o segmento entre os centros das células;
## qualquer parede no caminho bloqueia.
func has_line_of_sight(a: Vector2i, b: Vector2i) -> bool:
	var wa := world_pos(a) + Vector3(0, 0.5, 0)
	var wb := world_pos(b) + Vector3(0, 0.5, 0)
	var dist := wa.distance_to(wb)
	if dist < 0.01:
		return true
	var steps := int(ceil(dist / (TILE * 0.25)))
	for i in range(1, steps):
		var p := wa.lerp(wb, float(i) / float(steps))
		if not is_walkable(cell_of(p)):
			return false
	return true

## Células alcançáveis com `max_steps` passos ortogonais,
## desviando de peças. Retorna {dist, came} para reconstruir caminho.
func compute_reachable(start: Vector2i, max_steps: int) -> Dictionary:
	var dist := {start: 0}
	var came := {start: start}
	var frontier: Array = [start]
	while not frontier.is_empty():
		var cur: Vector2i = frontier.pop_front()
		var d: int = dist[cur]
		if d >= max_steps:
			continue
		for n in neighbors4(cur):
			if dist.has(n):
				continue
			if not is_free(n):
				continue
			dist[n] = d + 1
			came[n] = cur
			frontier.append(n)
	return {"dist": dist, "came": came}

## Caminho completo até o objetivo ignorando limite de movimento
## (usado pela IA para perseguir). Não atravessa peças.
func find_path(start: Vector2i, goal: Vector2i) -> Array:
	var out: Array = []
	if not is_walkable(goal) or start == goal:
		return out
	var came := {start: start}
	var q: Array = [start]
	while not q.is_empty():
		var cur: Vector2i = q.pop_front()
		if cur == goal:
			break
		for n in neighbors4(cur):
			if came.has(n):
				continue
			if not is_walkable(n):
				continue
			if occupied.has(n) and n != goal:
				continue
			came[n] = cur
			q.append(n)
	if not came.has(goal):
		return out
	var cur := goal
	while cur != start:
		out.push_front(cur)
		cur = came[cur]
	return out

## Reconstrói caminho a partir do resultado de compute_reachable.
func path_from_reachable(reach: Dictionary, goal: Vector2i) -> Array:
	var out: Array = []
	if not reach["dist"].has(goal):
		return out
	var came: Dictionary = reach["came"]
	var start: Vector2i = reach["dist"].keys()[0]
	var cur := goal
	while cur != start:
		out.push_front(cur)
		cur = came[cur]
	return out
