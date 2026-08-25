extends Node
## Grid tático 3D do tabuleiro: células Vector3i(x, y, andar).
## Cada casa guarda walkable/bloqueio-de-visão/elevação; escadas ligam
## andares diferentes. Peças ocupam exatamente uma casa (regra de mesa).

const TILE := 2.0
const FLOOR_H := 7.0   ## separação vertical entre andares (visual de mesa)
const ELEV_H := 0.55   ## altura por nível de elevação (plataformas)

var tiles := {}        ## Vector3i -> {w: bool, losb: bool, elev: int}
var stair_links := {}  ## Vector3i -> Vector3i (par base<->topo, bidirecional)
var occupied := {}     ## Vector3i -> BoardUnit
var special := {}      ## Vector3i -> String ("r" = runas)

func reset() -> void:
	tiles.clear()
	stair_links.clear()
	occupied.clear()
	special.clear()

func set_tile(c: Vector3i, walkable: bool, blocks_los := false, elev := 0) -> void:
	tiles[c] = {"w": walkable, "losb": blocks_los, "elev": elev}

## Registra par de células ligadas por escada (base no andar de baixo,
## topo no de cima). Ambas são células normais; a travessia é discreta
## (try_cross_stairs), não faz parte do caminho do BFS.
func add_stair_link(a: Vector3i, b: Vector3i) -> void:
	if a.z == b.z:
		push_error("Stair link precisa de andares diferentes: %s" % str([a, b]))
		return
	if a.z > b.z:
		var t := a
		a = b
		b = t
	stair_links[a] = b
	stair_links[b] = a

## Célula pareada da escada (ou a própria célula se não é escada).
func stair_pair(c: Vector3i) -> Vector3i:
	return stair_links.get(c, c)

# ---------------------------------------------------------------- consulta --

func is_walkable(c: Vector3i) -> bool:
	return tiles.has(c) and tiles[c]["w"]

func is_free(c: Vector3i) -> bool:
	return is_walkable(c) and not occupied.has(c)

## Primeiro grid LIVRE à frente da escada no andar de destino (desembarque):
## procura vizinhos ortogonais e depois diagonais da célula pareada, ordem
## fixa. null se TODAS as saídas estiverem bloqueadas.
func stair_landing(cell: Vector3i):
	for off in [Vector3i(0, -1, 0), Vector3i(0, 1, 0),
			Vector3i(-1, 0, 0), Vector3i(1, 0, 0),
			Vector3i(-1, -1, 0), Vector3i(1, -1, 0),
			Vector3i(-1, 1, 0), Vector3i(1, 1, 0)]:
		var c: Vector3i = cell + off
		if is_free(c):
			return c
	return null

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
	var e: int = elev_at(c)
	return Vector3(c.x * TILE + TILE * 0.5,
			c.z * FLOOR_H + e * ELEV_H + surface_h(c),
			c.y * TILE + TILE * 0.5)

## Altura EXTRA de superficie por celula (editor: subir em cima de
## elevacoes/colinas — o personagem fica no topo do modelo, mesma casa).
var _surface := {}   # Vector3i -> float

func set_surface(c: Vector3i, h: float) -> void:
	if h <= 0.001:
		_surface.erase(c)
	else:
		_surface[c] = h

func surface_h(c: Vector3i) -> float:
	return _surface.get(c, 0.0)

## CONVENÇÃO ÚNICA DE COORDENADAS (v0.9.2): a célula (col, row) ocupa o
## quadrado [col*TILE, col*TILE+TILE] × [row*TILE, row*TILE+TILE]; seu
## CENTRO fica em col*TILE + TILE/2 — coincidindo com as linhas impressas
## na folha e com o shader de grade. TODA conversão posição<->célula do
## jogo passa por este par (grid_to_world / world_to_cell); nada de
## round/floor avulso em outros arquivos.
func grid_to_world(cell: Vector3i) -> Vector3:
	return world_pos(cell)

func world_to_cell(p: Vector3, floor_idx := 0) -> Vector3i:
	return Vector3i(floori(p.x / TILE), floori(p.z / TILE), floor_idx)

static func chebyshev(a: Vector3i, b: Vector3i) -> int:
	return max(abs(a.x - b.x), abs(a.y - b.y))

## Vizinhos ortogonais no mesmo andar respeitando degrau máximo de 1
## nível de elevação + célula pareada da escada (custo normal de passo;
## a transição visual dispara quando o caminho executa esse salto).
func neighbors(c: Vector3i) -> Array:
	var out: Array = []
	for off in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0)]:
		var n: Vector3i = c + off
		if is_walkable(n) and abs(elev_at(n) - elev_at(c)) <= 1:
			out.append(n)
	var p: Vector3i = stair_links.get(c, c)
	if p != c and is_walkable(p):
		out.append(p)
	return out

## Mapa de distância ATÉ `goal` considerando escadas como passo único
## (entrar na célula pareada custa +1). Camadas: BFS no andar do alvo,
## propaga pelos pares e repete no andar de cada lado. Usado por IA/bot
## para perseguir alvos em outros andares.
func dist_to_goal(goal: Vector3i, ignore_units := true) -> Dictionary:
	var out := {}
	var queue: Array = []
	var d0: Dictionary = compute_reachable(goal, 99, ignore_units)["dist"]
	for c in d0:
		out[c] = d0[c]
		queue.append([c, d0[c]])
	while not queue.is_empty():
		var item: Array = queue.pop_front()
		var c: Vector3i = item[0]
		var d: int = item[1]
		var pair: Vector3i = stair_links.get(c, c)
		if pair == c or out.has(pair):
			continue
		out[pair] = d + 1
		queue.append([pair, d + 1])
		var dn: Dictionary = compute_reachable(pair, 99, ignore_units)["dist"]
		for cc in dn:
			if not out.has(cc):
				out[cc] = d + 1 + dn[cc]
				queue.append([cc, d + 1 + dn[cc]])
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
		var cc := world_to_cell(p, a.z)
		if tiles.has(cc) and tiles[cc]["losb"]:
			return false
	return true

## BFS dentro do andar (degrau <= 1 entre plataformas).
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

## PROMPT DEFINITIVO — Bake por raycast (fonte única de verdade)
func bake_from_physics(env: Node3D, map_bounds: Rect2, floors_n: int) -> void:
	tiles.clear()
	_surface.clear()
	var space: PhysicsDirectSpaceState3D = env.get_world_3d().direct_space_state
	if space == null:
		push_warning("BoardGrid.bake: sem space")
		return
	var min_x: int = int(floor(map_bounds.position.x / TILE))
	var min_y: int = int(floor(map_bounds.position.y / TILE))
	var max_x: int = int(ceil((map_bounds.position.x + map_bounds.size.x) / TILE)) - 1
	var max_y: int = int(ceil((map_bounds.position.y + map_bounds.size.y) / TILE)) - 1
	for f in floors_n:
		for x in range(min_x, max_x + 1):
			for y in range(min_y, max_y + 1):
				var c := Vector3i(x, y, f)
				var center := Vector3(x * TILE + TILE * 0.5, 0, y * TILE + TILE * 0.5)
				var from := Vector3(center.x, f * FLOOR_H + 8.0, center.z)
				var to := Vector3(center.x, f * FLOOR_H - 4.0, center.z)
				var q := PhysicsRayQueryParameters3D.create(from, to, 1)
				q.collide_with_bodies = true
				var hit: Dictionary = space.intersect_ray(q)
				if hit.is_empty():
					set_tile(c, false, true, 0)
					continue
				var pos: Vector3 = hit["position"]
				var col: Object = hit["collider"]
				var walkable := true
				var blocks_los := false
				if col is Node and (col as Node).has_meta("walkable"):
					walkable = bool((col as Node).get_meta("walkable"))
				if col is Node and (col as Node).has_meta("blocks_los"):
					blocks_los = bool((col as Node).get_meta("blocks_los"))
				var h: float = pos.y - f * FLOOR_H
				var elev: int = clampi(int(round(h / ELEV_H)), 0, 8)
				var clearance_from := pos + Vector3(0, 0.1, 0)
				var clearance_to := pos + Vector3(0, 1.8, 0)
				var q2 := PhysicsRayQueryParameters3D.create(clearance_from, clearance_to, 1)
				q2.collide_with_bodies = true
				var hit2: Dictionary = space.intersect_ray(q2)
				if not hit2.is_empty():
					walkable = false
				set_tile(c, walkable, blocks_los, elev)
				if h > 0.01:
					set_surface(c, h - elev * ELEV_H)
