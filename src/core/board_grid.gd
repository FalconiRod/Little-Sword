extends Node
## Grid tático 3D do tabuleiro: células Vector3i(x, y, andar).
## Cada casa guarda walkable/bloqueio-de-visão/elevação; escadas ligam
## andares diferentes. Peças ocupam exatamente uma casa (regra de mesa).

const TILE := 2.0
const FLOOR_H := 7.0   ## separação vertical entre andares (visual de mesa)
const ELEV_H := 0.55   ## altura por nível de elevação (plataformas)

var tiles := {}      ## Vector3i -> {w: bool, losb: bool, elev: int, y?: float}
var occupied := {}   ## Vector3i -> BoardUnit
var special := {}    ## Vector3i -> String ("r" = runas)

## Maior degrau transponivel entre celulas vizinhas (escada com N>=2
## degraus entre andares fica dentro disso; plataformas tambem).
const STEP_MAX_DY := 2.5

func reset() -> void:
	tiles.clear()
	occupied.clear()
	special.clear()

func set_tile(c: Vector3i, walkable: bool, blocks_los := false, elev := 0) -> void:
	var prev_y: float = tiles[c]["y"] if tiles.has(c) and tiles[c].has("y") \
			else 0.0
	tiles[c] = {"w": walkable, "losb": blocks_los, "elev": elev, "y": prev_y}

## Altura ABSOLUTA da celula (degraus de escada usam y customizado).
func set_height(c: Vector3i, y: float) -> void:
	if tiles.has(c):
		tiles[c]["y"] = y

func height_at(c: Vector3i) -> float:
	if tiles.has(c) and tiles[c].has("y") and tiles[c]["y"] != 0.0:
		return tiles[c]["y"]
	return c.z * FLOOR_H + elev_at(c) * ELEV_H

# ---------------------------------------------------------------- consulta --

func is_walkable(c: Vector3i) -> bool:
	return tiles.has(c) and tiles[c]["w"]

func is_free(c: Vector3i) -> bool:
	return is_walkable(c) and not occupied.has(c)

func unit_at(c: Vector3i):
	return occupied.get(c)

func place(u, c: Vector3i) -> void:
	occupied[c] = u
	u.grid_pos = c

func clear_cell(c: Vector3i) -> void:
	occupied.erase(c)

func move_unit(u, c: Vector3i) -> void:
	clear_cell(u.grid_pos)
	occupied[c] = u
	u.grid_pos = c

func elev_at(c: Vector3i) -> int:
	return int(tiles[c]["elev"]) if tiles.has(c) else 0

func world_pos(c: Vector3i) -> Vector3:
	return Vector3(c.x * TILE, height_at(c), c.y * TILE)

static func chebyshev(a: Vector3i, b: Vector3i) -> int:
	return max(abs(a.x - b.x), abs(a.y - b.y))

## Vizinhos com degrau transponivel: ortogonais no MESMO andar e, quando
## as alturas casarem (Δy real <= limite), também célula adjacente no
## andar de cima/baixo — é assim que o topo da escada conecta ao andar de
## destino. Sem teleporte: tudo vira passo normal do BFS.
func neighbors(c: Vector3i) -> Array:
	var out: Array = []
	for off in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0)]:
		for dz in [0, 1, -1]:
			var n: Vector3i = c + off + Vector3i(0, 0, dz)
			if is_walkable(n) and absf(height_at(n) - height_at(c)) <= STEP_MAX_DY:
				out.append(n)
	return out

## Linha de visão: apenas dentro do mesmo andar; amostra o segmento entre os
## centros das casas (na altura da elevação) e qualquer parede bloqueia.
func has_line_of_sight(a: Vector3i, b: Vector3i) -> bool:
	if a.z != b.z:
		return false
	var wa := world_pos(a) + Vector3(0, 0.6, 0)
	var wb := world_pos(b) + Vector3(0, 0.6, 0)
	var dist := wa.distance_to(wb)
	if dist < 0.01:
		return true
	var steps := int(ceil(dist / (TILE * 0.25)))
	for i in range(1, steps):
		var p := wa.lerp(wb, float(i) / float(steps))
		var cc := Vector3i(roundi(p.x / TILE), roundi(p.z / TILE), a.z)
		if tiles.has(cc) and tiles[cc]["losb"]:
			return false
	return true

## BFS multinível: anda no mesmo andar (degrau <= 1) e usa escadas.
## ignore_units=true ignora ocupantes (roteamento global, p.ex. IA/bot).
func compute_reachable(start: Vector3i, max_steps: int, ignore_units := false) -> Dictionary:
	var dist := {start: 0}
	var came := {start: start}
	var frontier: Array = [start]
	while not frontier.is_empty():
		var cur: Vector3i = frontier.pop_front()
		var d: int = dist[cur]
		if d >= max_steps:
			continue
		for n in neighbors(cur):
			if dist.has(n):
				continue
			if not (is_free(n) if not ignore_units else is_walkable(n)):
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
		cur = reach["came"][cur]
	return path
