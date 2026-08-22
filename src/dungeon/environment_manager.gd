class_name EnvironmentManager
extends Node3D
## Dungeon Kit: carrega mapas modulares. Cada mapa é uma lista de andares
## em ASCII; cada char vira peça do catálogo TilePiece ou componente
## (Door). Novos mapas = novas entradas em MAPS. Zero código extra.
##
## Legenda:
##  # parede   . pedra   , tapete   m musgo   P coluna   o entulho
##  ~ buraco   = ponte   T baú     R runas    L alavanca
##  D porta    H porta trancada (abre por alavanca/evento)
##  X passagem secreta (parede disfarçada)
##  S degrau de escada reta (células contíguas formam a escada)
##  K cavaleiro  M maga  W druida  g goblin  a arqueiro  B boss

var map_id := ""
var map_name := ""
var floors_n := 1
var spawns := {}          ## char -> Array[Vector3i]
var chest_cell := Vector3i.ZERO
var chest_looted := false
var doors: Array[DungeonDoor] = []
var levers := {}          ## Vector3i -> true
var active_floor_index := -1   ## -1 = nenhum andar mostrado ainda
var _floor_nodes: Array[Node3D] = []
var s_cells: Array = []        ## células 'S' (degraus) deste mapa
var s_set := {}                ## Vector3i -> true (busca rápida)

const LEGEND := {
	"#": ["wall_stone", false, true],
	".": ["floor_stone", true, false],
	",": ["floor_carpet", true, false],
	"m": ["floor_moss", true, false],
	"P": ["pillar", false, true],
	"o": ["rubble", false, false],
	"~": ["pit", false, false],
	"=": ["bridge_plank", true, false],
	"T": ["chest_prop", false, false],
	"R": ["runes", true, false],
	"L": ["lever_base", false, false],
}

func load_map(id: String) -> bool:
	if not MAPS.has(id):
		return false
	var def: Dictionary = MAPS[id]
	map_id = id
	map_name = def["name"]
	floors_n = def["floors"].size()
	spawns.clear()
	doors.clear()
	levers.clear()
	chest_looted = false
	chest_cell = Vector3i.ZERO
	active_floor_index = -1
	_floor_nodes.clear()
	s_cells.clear()
	s_set.clear()
	BoardGrid.reset()

	for f in def["floors"].size():
		var flnode := Node3D.new()
		flnode.name = "Floor%d" % f
		add_child(flnode)
		_floor_nodes.append(flnode)

	for f in def["floors"].size():
		var fl: Dictionary = def["floors"][f]
		var rows: Array = fl["rows"]
		for y in rows.size():
			var row: String = rows[y]
			for x in row.length():
				_place_char(row[x], Vector3i(x, y, f))

	_build_stairs()
	_setup_atmosphere()
	_scatter_torches()
	set_active_floor(0)
	EventBus.log_msg.emit("Mapa: %s" % map_name, "#c9a227")
	return true

## Escadas retas: agrupa células 'S' contíguas (linha/coluna) numa escada.
## Cada degrau é célula REAL do grid com altura crescente; o topo conecta
## a uma célula normal do andar de cima. Sem teleporte, sem rotação livre.
func _build_stairs() -> void:
	var used := {}
	for c in s_cells:
		if used.has(c):
			continue
		var run: Array = [c]
		var axis := Vector3i.ZERO
		for ax in [Vector3i(1, 0, 0), Vector3i(0, 1, 0)]:
			var r: Array = [c]
			for dir in [1, -1]:
				var n: Vector3i = c + ax * dir
				while s_set.has(n):
					r.append(n)
					n += ax * dir
			if r.size() > run.size():
				run = r.duplicate()
				axis = ax
		for cc in run:
			used[cc] = true
		if axis == Vector3i.ZERO:
			EventBus.log_msg.emit("Escada isolada ignorada em %s" % str(c), "#ff6b6b")
			continue
		_orient_stair(run, axis)

func _orient_stair(run: Array, axis: Vector3i) -> void:
	var f: int = run[0].z
	# Testa os dois sentidos; vale o que tiver aproximação pisável no
	# andar de origem E célula andável no andar de cima após o topo.
	var orders: Array = []
	for fw: Vector3i in [axis, -axis]:
		var r: Array = run.duplicate()
		if fw == -axis:
			r.reverse()
		orders.append({"run": r, "fwd": fw})
	var chosen := {}
	for o in orders:
		var r: Array = o["run"]
		var fw: Vector3i = o["fwd"]
		var base: Vector3i = r[0]
		var top: Vector3i = r[r.size() - 1]
		if not BoardGrid.is_walkable(base - fw):
			continue
		var landing: Vector3i = Vector3i(top.x + fw.x, top.y + fw.y, f + 1)
		if not BoardGrid.is_walkable(landing):
			continue
		chosen = {"run": r, "fwd": fw}
		break
	if chosen.is_empty():
		EventBus.log_msg.emit("Escada em %s sem aproximacao/destino validos." % str(run[0]), "#ff6b6b")
		return
	var run_ok: Array = chosen["run"]
	var fwd: Vector3i = chosen["fwd"]
	var n: int = run_ok.size()
	for i in n:
		var cc: Vector3i = run_ok[i]
		var y: float = BoardGrid.FLOOR_H * float(i + 1) / float(n + 1)
		BoardGrid.set_height(cc, y)
		var piece := TilePiece.step_piece(y, 0.0 if fwd.x != 0 else PI / 2)
		_floor_nodes[f].add_child(piece)
		piece.position = Vector3(cc.x * BoardGrid.TILE, 0.0, cc.y * BoardGrid.TILE)
	var top: Vector3i = run_ok[n - 1]
	var landing := Vector3i(top.x + fwd.x, top.y + fwd.y, f + 1)
	EventBus.log_msg.emit("Escada de %s para %s" % [str(run_ok[0]), str(landing)], "#8fd3ff")

## Mostra apenas o andar ativo (esconde os outros; NÃO descarrega da
## memória) e avisa câmera/HUD via active_floor_changed.
func set_active_floor(f: int) -> void:
	if f == active_floor_index or f < 0 or f >= _floor_nodes.size():
		return
	active_floor_index = f
	for i in _floor_nodes.size():
		_floor_nodes[i].visible = i == f
	EventBus.active_floor_changed.emit(f)

## Iluminação de mesa: ambiente frio fraco + "lua" direcional com sombra.
func _setup_atmosphere() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.html("0a0c14")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.html("707896")
	env.ambient_light_energy = 0.9
	env.fog_enabled = true
	env.fog_light_color = Color.html("161a2a")
	env.fog_density = 0.006
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "MoonLight"
	sun.rotation_degrees = Vector3(-52, -28, 0)
	sun.light_color = Color.html("cfd6ff")
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	add_child(sun)

## Tochas nas paredes viradas para casas livres — aquecem o cenário.
func _scatter_torches() -> void:
	var dirs := [Vector3i(0, 1, 0), Vector3i(1, 0, 0),
			Vector3i(0, -1, 0), Vector3i(-1, 0, 0)]
	var spots: Array = []
	for c in BoardGrid.tiles.keys():
		if BoardGrid.tiles[c]["w"] or not BoardGrid.tiles[c]["losb"]:
			continue
		if (c.x * 31 + c.y * 17 + c.z * 7) % 3 != 0:
			continue
		for d in dirs:
			if BoardGrid.is_walkable(c + d):
				spots.append([c, d])
				break
	spots.shuffle()
	var placed := 0
	for s in spots:
		if placed >= 30:
			break
		var c: Vector3i = s[0]
		var d: Vector3i = s[1]
		var t := TilePiece.build("torch")
		_floor_nodes[c.z].add_child(t)
		t.position = BoardGrid.world_pos(c)
		t.rotation.y = atan2(float(d.x), float(d.y))
		var l := OmniLight3D.new()
		l.light_color = Color.html("ffb454")
		l.light_energy = 2.4
		l.omni_range = 5.5
		l.omni_attenuation = 1.3
		l.shadow_enabled = false
		l.position = Vector3(0, 1.75, 0.35).rotated(Vector3.UP, t.rotation.y)
		t.add_child(l)
		var tw := t.create_tween().set_loops()
		tw.tween_property(l, "light_energy", randf_range(1.7, 2.1),
				randf_range(0.16, 0.38))
		tw.tween_property(l, "light_energy", 2.5, randf_range(0.1, 0.28))
		placed += 1

# ----------------------------------------------------------------- interno --

func _place_char(ch: String, c: Vector3i) -> void:
	if "KMgWaB".contains(ch):
		if not spawns.has(ch):
			spawns[ch] = []
		spawns[ch].append(c)
		_tile("floor_stone", c)
		return
	match ch:
		"D":
			_tile("floor_stone", c)
			_door(c, false, "", false, "")
		"H":
			_tile("floor_stone", c)
			_door(c, true, "lever", false, "")
		"X":
			_tile("wall_stone", c)
			_door(c, true, "", true, "")
		"L":
			_tile("floor_stone", c)
			_piece("lever_base", c)
			levers[c] = true
		"T":
			_tile("floor_stone", c)
			_piece("chest_prop", c)
			chest_cell = c
		"S":
			# Degrau de escada reta: piso pisável; alturas/visuais montados
			# depois em _build_stairs() agrupando as células contíguas.
			_tile("floor_stone", c)
			s_cells.append(c)
			s_set[c] = true
		_:
			if LEGEND.has(ch):
				var p: Array = LEGEND[ch]
				BoardGrid.set_tile(c, p[1], p[2])
				_piece(p[0], c)
				if p[0] == "runes":
					BoardGrid.special[c] = "r"
			else:
				BoardGrid.set_tile(c, false, true)
				_piece("wall_stone", c)

func _tile(pid: String, c: Vector3i) -> void:
	var p: Dictionary = TilePiece.PROPS[pid]
	BoardGrid.set_tile(c, p["w"], p["losb"])

func _piece(pid: String, c: Vector3i) -> void:
	var n := TilePiece.build(pid)
	_floor_nodes[c.z].add_child(n)
	n.position = BoardGrid.world_pos(c)
	n.name = "%s_%d_%d_%d" % [pid, c.x, c.y, c.z]

func _door(c: Vector3i, locked: bool, key: String, disguised: bool,
		id := "") -> void:
	var d := DungeonDoor.new()
	_floor_nodes[c.z].add_child(d)
	d.position = BoardGrid.world_pos(c)
	d.setup(c, locked, key, disguised, id)
	doors.append(d)

# --------------------------------------------------------------- consulta --

## Porta ou alavanca interativa numa casa? (para clique adjacente)
func interactive_at(c: Vector3i):
	for d in doors:
		if d.cell == c:
			return d
	if levers.has(c):
		return {"lever": true}
	return null

func pull_lever(_lever_cell: Vector3i) -> void:
	var opened_any := false
	for d in doors:
		if d.state == DungeonDoor.State.LOCKED and not d.disguised \
				and d.key_id == "lever":
			d.unlock_by_event()
			opened_any = true
		elif d.state == DungeonDoor.State.LOCKED and d.disguised:
			d.unlock_by_event()
			opened_any = true
	if not opened_any:
		EventBus.log_msg.emit("A alavanda range, mas nada acontece.", "#8a8f9c")
	EventBus.shake_requested.emit(0.18)

func loot_chest() -> void:
	chest_looted = true

# ================================================================== MAPAS ===

const MAPS := {
	# -------------------------------------------------- Fortaleza de Pedra --
	"stone_keep": {
		"name": "Fortaleza de Pedra — 3 Andares",
		"floors": [
			{ # Térreo: salão de entrada + cripta com runas e baú
				"rows": [
					"############",
					"#K.M.,..#g.#",
					"#..P...D.o.#",
					"#W....,#.#.#",
					"####D###.g.#",
					"#..m.,.#.S.#",
					"#T.R.m.D.S##",
					"#..m...#.S##",
					"############",
				],
			},
			{ # Segundo andar: corredor dos arqueiros
				"rows": [
					"############",
					"#a......P..#",
					"#..,.S..o..#",
					"#P..DS.....#",
					"#.....o....#",
					"######D#####",
					"#g.......P.#",
					"#..........#",
					"#########..#",
				],
			},
			{ # Câmara do boss: ponte sobre o abismo
				"rows": [
					"##########",
					"#B.P....R#",
					"#~=~=..,.#",
					"#=~~=.P..#",
					"#...=D...#",
					"##########",
				],
			},
		],
	},

	# ----------------------------------------------------- Torre Abandonada --
	"tower": {
		"name": "Torre Abandonada",
		"floors": [
			{
				"rows": [
					"#########",
					"#K..M..a#",
					"#..P.,..#",
					"#..,S,..#",
					"#..PS,..#",
					"#g.....g#",
					"#########",
				],
			},
			{
				"rows": [
					"#########",
					"#B..P...#",
					"#......,#",
					"#..,,,..#",
					"#....o..#",
					"#T......#",
					"#########",
				],
			},
		],
	},

	# --------------------------------------------------------- Casa Forta ---
	"house": {
		"name": "Casa Fortificada",
		"floors": [
			{
				"rows": [
					"###########",
					"#K.M.,.D.g#",
					"#.P...,.o.#",
					"#..L.H...T#",
					"#W.D.,..g.#",
					"###########",
				],
			},
		],
	},

	# ------------------------------------------------------------ Cripta ----
	"crypt": {
		"name": "Cripta dos Segredos",
		"floors": [
			{
				"rows": [
					"###########",
					"#K.M.,..#T#",
					"#.P..,.#X.#",
					"#..,..,#.S#",
					"#L.D..,..S#",
					"#.m..g.,..#",
					"###########",
				],
			},
			{
				"rows": [
					"###########",
					"#R.m...m.R#",
					"#..P.o.P..#",
					"#g..,.,..g#",
					"#..,.,....#",
					"###########",
				],
			},
		],
	},
}
