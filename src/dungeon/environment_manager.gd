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
##  S célula da escada (base ou topo — par definido em "stairs")
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

# ------------------------------------------------------- modo PISO-FOLHA ----
## Estética battle-grid: o chão é uma "folha impressa" gigante (textura do
## usuário repetida N células por folha, alinhada à origem) e as peças de
## piso deixam de nascer uma a uma. Paredes/props continuam sendo miniaturas
## EM CIMA da folha. Mapas ativam com "sheet" na definição; sem a chave,
## tudo funciona como antes (regressão zero).
const SHEET_FLOOR_IDS := ["floor_stone", "floor_carpet", "floor_moss"]
const GRID_SHADER_CODE := "
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back;
uniform vec3 line_color : source_color = vec3(0.13, 0.09, 0.05);
uniform float cells_per_sheet = 10.0;
uniform float line_px = 1.4;
uniform float opacity : hint_range(0.0, 1.0) = 0.5;
varying vec2 grid_uv;
void vertex() {
	grid_uv = UV * cells_per_sheet;
}
void fragment() {
	vec2 d = abs(fract(grid_uv) - 0.5);
	vec2 w = fwidth(grid_uv) * max(line_px, 0.1);
	vec2 a = smoothstep(vec2(0.5) - w, vec2(0.5), d);
	ALBEDO = line_color;
	ALPHA = max(a.x, a.y) * opacity;
}
"
var _sheet_active := false
var _sheet_cells: Array = []   ## por andar: Array[Vector3i] que ganham folha

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
	# MAPS é const (somente leitura); mapas procedurais recebem cópia
	# gravável com as linhas geradas antes do uso.
	if def.has("proc") and def["floors"].is_empty():
		def = def.duplicate(true)
		def["floors"] = [{"rows": _gen_proc_rows(def["proc"])}]
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
	_sheet_active = def.has("sheet")
	_sheet_cells.clear()
	for f in floors_n:
		_sheet_cells.append([])
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

	if _sheet_active:
		# Preferência: GLB de tile repetido (MultiMesh); sem modelo,
		# cai para o piso-folha texturizado.
		if not (def.has("tile_glb") and _build_tile_multimeshes(def["tile_glb"])):
			_build_sheet_floors(def["sheet"])
	for st in def.get("stairs", []):
		var a := Vector3i(st[0][0], st[0][1], st[0][2])
		var b := Vector3i(st[1][0], st[1][1], st[1][2])
		BoardGrid.add_stair_link(a, b)
		_spawn_stairs_visual(a, b)
		for cel in [a, b]:
			if not BoardGrid.is_walkable(cel):
				push_warning("[MAPA %s] Escada: célula do par inválida ou bloqueada: %s"
						% [map_id, cel])

	# PARTE 2: porta precisa de eixo de passagem livre dos DOIS lados.
	_validate_doors()

	_setup_atmosphere(def.get("outdoor", false))
	_scatter_torches()
	set_active_floor(0)
	EventBus.log_msg.emit("Mapa: %s" % map_name, "#c9a227")
	return true

## Visual da escada: coluna espiral na célula base + marcador âmbar na
## célula do topo. A travessia em si é try_cross_stairs (transição).
func _spawn_stairs_visual(base: Vector3i, top: Vector3i) -> void:
	var prop := TilePiece.build("stairs_prop")
	_floor_nodes[base.z].add_child(prop)
	prop.position = BoardGrid.world_pos(base)
	var mark := TilePiece.build("stairs_top")
	_floor_nodes[top.z].add_child(mark)
	mark.position = BoardGrid.world_pos(top)

## Mostra apenas o andar ativo (esconde os outros; NÃO descarrega da
## memória) e avisa câmera/HUD via active_floor_changed.
func set_active_floor(f: int) -> void:
	if f == active_floor_index or f < 0 or f >= _floor_nodes.size():
		return
	active_floor_index = f
	for i in _floor_nodes.size():
		_floor_nodes[i].visible = i == f
	EventBus.active_floor_changed.emit(f)

## Regra de mapa: a porta precisa de UM eixo (H ou V) com as duas células
## adjacentes caminháveis — é por ali que ela "abre". Eixo fechado pelos
## dois lados (porta em linha de parede) é ignorado. Violações viram
## push_warning para pegar erro de configuração cedo, nunca silêncio.
## Portas disfarçadas ('X', passagem secreta) ficam fora da regra.
func _validate_doors() -> void:
	var door_cells := {}
	for d in doors:
		door_cells[d.cell] = true
	for d in doors:
		if d.disguised:
			continue
		var c: Vector3i = d.cell
		var axes := [
			[Vector3i(1, 0, 0), Vector3i(-1, 0, 0)],
			[Vector3i(0, 1, 0), Vector3i(0, -1, 0)],
		]
		var has_opening := false
		for axis in axes:
			var n1: Vector3i = c + axis[0]
			var n2: Vector3i = c + axis[1]
			if not (BoardGrid.is_walkable(n1) and BoardGrid.is_walkable(n2)):
				continue  # eixo não é o de passagem (parede dos dois lados)
			has_opening = true
			for n in [n1, n2]:
				if door_cells.has(n):
					push_warning("[MAPA %s] Porta em %s encostada em outra porta (%s)"
							% [map_id, c, n])
		if not has_opening:
			push_warning("[MAPA %s] Porta em %s sem passagem livre nos dois lados"
					% [map_id, c])

## Iluminação de mesa: ambiente frio fraco + "lua" direcional com sombra.
## Mapas externos (outdoor) recebem céu + sol de dia.
func _setup_atmosphere(outdoor := false) -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sun := DirectionalLight3D.new()
	if outdoor:
		env.background_mode = Environment.BG_SKY
		var sm := ProceduralSkyMaterial.new()
		sm.sky_top_color = Color.html("2e5c9e")
		sm.sky_horizon_color = Color.html("9db8cf")
		sm.ground_bottom_color = Color.html("22291d")
		sm.ground_horizon_color = Color.html("7f977c")
		sm.sun_angle_max = 20.0
		var sky := Sky.new()
		sky.sky_material = sm
		env.sky = sky
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color.html("93a3b4")
		env.ambient_light_energy = 0.75
		env.fog_enabled = true
		env.fog_light_color = Color.html("b9cbd9")
		env.fog_density = 0.0012
		sun.name = "SunLight"
		sun.rotation_degrees = Vector3(-38, -32, 0)
		sun.light_color = Color.html("ffe9bd")
		sun.light_energy = 0.62
	else:
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color.html("0a0c14")
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color.html("707896")
		env.ambient_light_energy = 0.9
		env.fog_enabled = true
		env.fog_light_color = Color.html("161a2a")
		env.fog_density = 0.006
		sun.name = "MoonLight"
		sun.rotation_degrees = Vector3(-52, -28, 0)
		sun.light_color = Color.html("cfd6ff")
		sun.light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	add_child(we)
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
	# Folha cobre toda a mesa (parede/árvore são miniaturas EM CIMA dela);
	# só o abismo ('~') fica sem folha.
	if ch != "~":
		_sheet_cells[c.z].append(c)
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
			# Célula de escada (base ou topo do par em "stairs"):
			# piso normal; o prop visual nasce de _spawn_stairs_visual.
			_tile("floor_stone", c)
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
	# Modo folha: pisos não geram peça individual (a malha única desenha).
	if _sheet_active and pid in SHEET_FLOOR_IDS:
		return
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

# ------------------------------------------------------------ piso-folha ----

## Tabuleiro em GLB: UM modelo de UMA casa repetido via MultiMesh
## (1 draw call por andar). O modelo é escalado uniformemente para caber
## num pé exato de TILE × TILE, centralizado na célula, com o TOPO da
## malha em y=0 (altura onde as peças ficam). Retorna false se não houver
## GLB utilizável — o chamador cai para o piso-folha texturizado.
## Troca o GLB do battlemat em tempo de execucao (editor de mapa):
## remove os MultiMesh atuais e reconstrui todas as casas com o novo tile.
func set_battle_mat(glb_path: String) -> bool:
	if not _sheet_active or glb_path == "":
		return false
	for f in _floor_nodes.size():
		for ch in _floor_nodes[f].get_children():
			if ch.name.begins_with("BoardTiles"):
				ch.free()
	return _build_tile_multimeshes_glb(glb_path)

func _build_tile_multimeshes(dir_path: String) -> bool:
	var glb := _find_first_glb(dir_path)
	if glb == "":
		return false
	_mat_glb_default = glb
	return _build_tile_multimeshes_glb(glb)

var _mat_glb_default := ""

func get_default_mat() -> String:
	return _mat_glb_default

func _build_tile_multimeshes_glb(glb: String) -> bool:
	var packed: PackedScene = load(glb)
	if packed == null:
		return false
	var inst := packed.instantiate()
	var meshes: Array = []
	_collect_meshes(inst, Transform3D.IDENTITY, meshes)
	if meshes.is_empty():
		inst.free()
		push_warning("[MAPA %s] GLB sem malha: %s" % [map_id, glb])
		return false
	if meshes.size() > 1:
		push_warning("[MAPA %s] GLB com %d malhas; usando a primeira: %s"
				% [map_id, meshes.size(), glb])
	var entry: Array = meshes[0]
	var mesh: Mesh = entry[0]
	var xf: Transform3D = entry[1]
	var aabb := mesh.get_aabb()
	var span: float = maxf(aabb.size.x, aabb.size.z)
	if span <= 0.0001:
		inst.free()
		return false
	var s := BoardGrid.TILE / span
	# base: escala uniforme + compensação do canto do AABB + topo em y=0.
	var base := Transform3D(Basis.from_scale(Vector3(s, s, s)),
			Vector3(-(aabb.position.x + aabb.size.x * 0.5) * s,
					-aabb.end.y * s,
					-(aabb.position.z + aabb.size.z * 0.5) * s))
	_tile_base = base
	_tile_xf = xf
	for f in floors_n:
		var cells: Array = _sheet_cells[f]
		if cells.is_empty():
			continue
		# NOVO: cada casa é um Node3D individual editável (rotação/troca por celula)
		# Mantém performance: 900 tiles × ~2 tris = 1.8k tris, leve. Cada tile pode ser
		# selecionado no editor (Q/E gira) e trocado por outro .glb de tilesets/.
		for c in cells:
			var holder := Node3D.new()
			holder.name = "Tile_%d_%d_%d" % [c.x, c.y, c.z]
			holder.position = Vector3(c.x * BoardGrid.TILE + BoardGrid.TILE * 0.5,
					BoardGrid.world_pos(c).y,
					c.y * BoardGrid.TILE + BoardGrid.TILE * 0.5)
			holder.set_meta("tile_cell", c)
			holder.set_meta("tile_glb", glb)
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			mi.transform = base * xf
			holder.add_child(mi)
			# Colisão para picking do editor (raycast layer 4)
			var body := StaticBody3D.new()
			body.collision_layer = 4
			body.collision_mask = 0
			body.set_meta("tile_cell", c)
			var shape := BoxShape3D.new()
			shape.size = Vector3(BoardGrid.TILE * 0.92, 0.3, BoardGrid.TILE * 0.92)
			var cs := CollisionShape3D.new()
			cs.shape = shape
			body.add_child(cs)
			holder.add_child(body)
			_floor_nodes[f].add_child(holder)
			_base_tiles[c] = holder
	inst.free()
	EventBus.log_msg.emit("Tabuleiro montado casa a casa (%s) — %d tiles editáveis."
			% [glb.get_file(), _base_tiles.size()], "#8a8f9c")
	return true

## Base do tile GLB guardada p/ manipulacao por celula (editor de mapa).
var _tile_base := Transform3D.IDENTITY
var _tile_xf := Transform3D.IDENTITY
var _base_tiles := {}  # Vector3i -> Node3D (tile base editável por celula)

## Esconde/restaura o tile base de UMA celula: suporta tanto MultiMesh antigo
## quanto tiles individuais novos (editáveis).
func set_sheet_cell_hidden(c: Vector3i, hidden: bool) -> void:
	if c.z >= _floor_nodes.size():
		return
	# Novo: tiles individuais
	if _base_tiles.has(c):
		var holder: Node3D = _base_tiles[c]
		if is_instance_valid(holder):
			holder.visible = not hidden
		return
	# Legado: MultiMesh (saves antigos)
	var mmi := _floor_nodes[c.z].get_node_or_null("BoardTiles%d" % c.z)
	if mmi == null:
		return
	var idx: int = _sheet_cells[c.z].find(c)
	if idx < 0:
		return
	var mm: MultiMesh = mmi.multimesh
	var t := Transform3D(Basis(),
			Vector3(c.x * BoardGrid.TILE + BoardGrid.TILE * 0.5,
					BoardGrid.world_pos(c).y + (-999.0 if hidden else 0.0),
					c.y * BoardGrid.TILE + BoardGrid.TILE * 0.5))
	mm.set_instance_transform(idx, t * _tile_base * _tile_xf)

## Gira um tile base individual (Q/E no editor)
func rotate_base_tile(c: Vector3i, deg: float) -> void:
	if not _base_tiles.has(c):
		return
	var holder: Node3D = _base_tiles[c]
	if is_instance_valid(holder):
		holder.rotation.y = deg_to_rad(deg)

## Troca o tileset de UMA casa (pasta raiz tilesets/)
func swap_base_tile(c: Vector3i, new_glb: String) -> bool:
	if not _base_tiles.has(c):
		return false
	var holder: Node3D = _base_tiles[c]
	if not is_instance_valid(holder):
		return false
	var packed: PackedScene = load(new_glb)
	if packed == null:
		return false
	var inst := packed.instantiate()
	var meshes: Array = []
	_collect_meshes(inst, Transform3D.IDENTITY, meshes)
	if meshes.is_empty():
		inst.free()
		return false
	var entry: Array = meshes[0]
	var mesh: Mesh = entry[0]
	var xf: Transform3D = entry[1]
	var aabb := mesh.get_aabb()
	var span: float = maxf(aabb.size.x, aabb.size.z)
	if span <= 0.0001:
		inst.free()
		return false
	var s := BoardGrid.TILE / span
	var base := Transform3D(Basis.from_scale(Vector3(s, s, s)),
			Vector3(-(aabb.position.x + aabb.size.x * 0.5) * s,
					-aabb.end.y * s,
					-(aabb.position.z + aabb.size.z * 0.5) * s))
	# Troca o MeshInstance
	for ch in holder.get_children():
		if ch is MeshInstance3D:
			(ch as MeshInstance3D).mesh = mesh
			(ch as MeshInstance3D).transform = base * xf
			break
	holder.set_meta("tile_glb", new_glb)
	holder.position = Vector3(c.x * BoardGrid.TILE + BoardGrid.TILE * 0.5,
			BoardGrid.world_pos(c).y,
			c.y * BoardGrid.TILE + BoardGrid.TILE * 0.5)
	var is_water := new_glb.to_lower().contains("agua") or new_glb.to_lower().contains("water")
	if is_water:
		for ch in holder.get_children():
			if ch is MeshInstance3D:
				var mi: MeshInstance3D = ch as MeshInstance3D
				var tr: Transform3D = mi.transform
				tr.basis.y *= 0.15
				mi.transform = tr
				break
	BoardGrid.set_tile(c, not is_water, false, BoardGrid.elev_at(c))
	inst.free()
	return true

func _find_first_glb(dir_path: String) -> String:
	if dir_path == "":
		return ""
	# Prioridade: tile_bosque.glb é o padrão leve (711KB); agua*.glb tem 48MB
	# e trava se for usado como battlemat repetido 900×. Só use agua se
	# o usuário trocar manualmente pelo editor.
	if dir_path == "res://src/assets/tilesets":
		var pref := dir_path.path_join("tile_bosque.glb")
		if FileAccess.file_exists(pref):
			return pref
	var d := DirAccess.open(dir_path)
	if d == null:
		return ""
	d.list_dir_begin()
	var fname := d.get_next()
	var fallback := ""
	while fname != "":
		if not d.current_is_dir() and fname.to_lower().ends_with(".glb"):
			var p := dir_path.path_join(fname)
			# Evita agua gigante como padrão automático
			if fname.to_lower().begins_with("agua"):
				if fallback == "":
					fallback = p
			else:
				d.list_dir_end()
				return p
		fname = d.get_next()
	d.list_dir_end()
	return fallback

func _collect_meshes(n: Node, xf: Transform3D, out: Array) -> void:
	var local := xf
	if n is Node3D:
		local = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		out.append([(n as MeshInstance3D).mesh, local])
	for ch in n.get_children():
		_collect_meshes(ch, local, out)

## Constrói, por andar, UMA malha com todos os quads de chão da mesa.
## UV em coordenadas de mundo divididas pelo tamanho da folha
## (cells_per_sheet * TILE): a textura repete alinhada à grade e as 20×20
## células impressas na arte coincidem com as células lógicas em qualquer
## dimensão de mapa. Grade vetorial entra como next_pass por cima.
func _build_sheet_floors(cfg: Dictionary) -> void:
	var tex_path: String = cfg.get("tex", "")
	var cps := float(cfg.get("cells_per_sheet", 20.0))
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.95
	mat.metallic = 0.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var tex: Texture2D = null
	if tex_path != "" and ResourceLoader.exists(tex_path):
		tex = load(tex_path)
	if tex == null:
		push_error("[MAPA %s] Textura de folha ausente: %s" % [map_id, tex_path])
		mat.albedo_color = Color.html("5a6b4a")
	else:
		mat.albedo_texture = tex
		mat.uv1_triplanar = false
	if cfg.get("grid", true):
		var sh := Shader.new()
		sh.code = GRID_SHADER_CODE
		var sm := ShaderMaterial.new()
		sm.shader = sh
		sm.set_shader_parameter("cells_per_sheet", cps)
		sm.set_shader_parameter("opacity", float(cfg.get("grid_opacity", 0.45)))
		mat.next_pass = sm
	var sheet_world := cps * BoardGrid.TILE
	for f in floors_n:
		var cells: Array = _sheet_cells[f]
		if cells.is_empty():
			continue
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for c in cells:
			var y: float = BoardGrid.world_pos(c).y
			# Célula ocupa [col*TILE, col*TILE+TILE]: as linhas impressas da
			# textura (múltiplos de cells_per_sheet*TILE) caem nas BORDAS.
			var x0: float = c.x * BoardGrid.TILE
			var x1: float = x0 + BoardGrid.TILE
			var z0: float = c.y * BoardGrid.TILE
			var z1: float = z0 + BoardGrid.TILE
			var u0: float = x0 / sheet_world
			var u1: float = x1 / sheet_world
			var v0: float = z0 / sheet_world
			var v1: float = z1 / sheet_world
			# CCW visto de cima (+Y): A(x0,z0) B(x0,z1) C(x1,z1) D(x1,z0)
			_vertex_quad(st, Vector3(x0, y, z0), Vector2(u0, v0),
					Vector3(x0, y, z1), Vector2(u0, v1),
					Vector3(x1, y, z1), Vector2(u1, v1),
					Vector3(x1, y, z0), Vector2(u1, v0))
		st.generate_tangents()
		var mesh := st.commit()
		var mi := MeshInstance3D.new()
		mi.name = "SheetFloor%d" % f
		mi.mesh = mesh
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_floor_nodes[f].add_child(mi)
	EventBus.log_msg.emit("Mesa forrada com folhas de %d×%d células."
			% [int(cps), int(cps)], "#8a8f9c")

static func _vertex_quad(st: SurfaceTool,
		a: Vector3, ua: Vector2, b: Vector3, ub: Vector2,
		c: Vector3, uc: Vector2, d: Vector3, ud: Vector2) -> void:
	for tri in [[a, ua, b, ub, c, uc], [a, ua, c, uc, d, ud]]:
		for i in range(0, 6, 2):
			st.set_normal(Vector3.UP)
			st.set_uv(tri[i + 1])
			st.add_vertex(tri[i])

## Retângulo do mapa em coordenadas de mundo (centro das células extremas),
## para a câmera dimensionar pan/zoom sozinha.
func map_bounds() -> Rect2:
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for c in BoardGrid.tiles.keys():
		mn.x = minf(mn.x, c.x)
		mn.y = minf(mn.y, c.y)
		mx.x = maxf(mx.x, c.x)
		mx.y = maxf(mx.y, c.y)
	if mn.x > mx.x:
		return Rect2(0, 0, 26, 30)
	return Rect2(mn.x * BoardGrid.TILE, mn.y * BoardGrid.TILE,
			(mx.x - mn.x + 1) * BoardGrid.TILE,
			(mx.y - mn.y + 1) * BoardGrid.TILE)

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

## Gera linhas ASCII de floresta determinística (mesma seed = mesmo mapa).
## Árvores 'P' (~7%) e pedras 'o' espalhadas, borda de parede; clareiras
## carimbadas nos spawns; flood-fill garante que o grupo alcança todos os
## inimigos (senão tenta a seed seguinte, até 30 vezes).
func _gen_proc_rows(p: Dictionary) -> Array:
	var w := int(p.get("w", 50))
	var h := int(p.get("h", 50))
	var base_seed := int(p.get("seed", 1))
	var rows: Array = []
	for attempt in range(30):
		rows = _forest_rows_try(w, h, base_seed + attempt)
		if not rows.is_empty():
			return rows
	push_error("[MAPA %s] Floresta procedural sem conectividade" % map_id)
	return rows

func _forest_rows_try(w: int, h: int, s: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = s
	var grid: Array = []
	for y in h:
		var row: Array = []
		for x in w:
			# Borda ABERTA e interior LIMPO: sem muros/colunas/pedras —
			# o jogador decora com arvores/pedras pelo editor. O rng sorteia
			# mesmo assim para nao deslocar o layout de spawns do seed.
			rng.randf()
			row.append(".")
		grid.append(row)
	# Spawns proporcionais ao tamanho da mesa (funciona de 20x20 a 70x50).
	var marks := {
		"K": Vector2i(w / 2, h - 9),
		"M": Vector2i(w / 2 - 2, h - 8),
		"W": Vector2i(w / 2 + 2, h - 8),
		"g": [Vector2i(roundi(w * 0.20), roundi(h * 0.33)),
				Vector2i(roundi(w * 0.76), roundi(h * 0.40)),
				Vector2i(roundi(w * 0.28), roundi(h * 0.56)),
				Vector2i(roundi(w * 0.66), roundi(h * 0.60))],
		"a": Vector2i(roundi(w * 0.48), roundi(h * 0.16)),
		"B": Vector2i(roundi(w * 0.48), roundi(h * 0.07)),
	}
	var stamps: Array = []
	for ch in marks:
		if marks[ch] is Array:
			for cc in marks[ch]:
				stamps.append([ch, cc])
		else:
			stamps.append([ch, marks[ch]])
	for stp in stamps:
		var cc: Vector2i = stp[1]
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var n := cc + Vector2i(dx, dy)
				if n.x > 0 and n.y > 0 and n.x < w - 1 and n.y < h - 1:
					grid[n.y][n.x] = "."
		grid[cc.y][cc.x] = stp[0]
	# Conectividade: flood-fill das casas livres a partir do K.
	var start: Vector2i = marks["K"]
	var seen := {start: true}
	var stack: Array = [start]
	while not stack.is_empty():
		var cur: Vector2i = stack.pop_back()
		for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1),
				Vector2i(0, -1)]:
			var n2: Vector2i = cur + off
			if n2.x < 0 or n2.y < 0 or n2.x >= w or n2.y >= h:
				continue
			if seen.has(n2) or grid[n2.y][n2.x] in ["#", "P", "o"]:
				continue
			seen[n2] = true
			stack.append(n2)
	for stp in stamps:
		if not seen.has(stp[1]):
			return []
	return grid.map(func(row): return "".join(row))

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
					"#..m.,.#...#",
					"#T.R.m.D..##",
					"#..m...#.S##",
					"############",
				],
			},
			{ # Segundo andar: corredor dos arqueiros
				"rows": [
					"############",
					"#a......P..#",
					"#..,....o..#",
					"#P.SD......#",
					"#.....,....#",  # entulho removido: ficava atrás da porta (6,5)
					"######D#####",
					"#g.......P.#",
					"#........S.#",
					"############",
				],
			},
			{ # Câmara do boss: ponte sobre o abismo
				"rows": [
					"##########",
					"#B.P....R#",
					"#~=~=..,.#",
					"#=~~=.P..#",
					"#..S=D...#",
					"##########",
				],
			},
		],
		"stairs": [
			[[9, 7, 0], [9, 7, 1]],
			[[3, 3, 1], [3, 4, 2]],
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
					"#..P.,..#",
					"#g.....g#",
					"#########",
				],
			},
			{
				"rows": [
					"#########",
					"#B..P...#",
					"#......,#",
					"#..,S,..#",
					"#....o..#",
					"#T......#",
					"#########",
				],
			},
		],
		"stairs": [
			[[4, 3, 0], [4, 3, 1]],
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
					"#..,..,#..#",
					"#L.D..,.S.#",
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
					"#..,.,..S.#",
					"###########",
				],
			},
		],
		"stairs": [
			[[8, 4, 0], [8, 3, 1]],
		],
	},

	# --------------------------------------------- Bosque das Sombras ------
	# Mapa procedural (30×30) com estética battle-grid: chão = folha
	# impressa do usuário com grade de 50×50 células (v2 da arte,
	# 5908²px ≈ 118px/célula); o mapa 30×30 cabe inteiro numa folha só
	# (sem costuras). Árvores/rochas são miniaturas EM CIMA da folha.
		"bosque_30": {
		"name": "Bosque das Sombras — 30×30",
		"outdoor": true,
		"proc": {"w": 30, "h": 30, "seed": 20260823},
		"floors": [],
		"sheet": {"tex": "res://src/assets/piso bosque/bosque.jpg",
			"cells_per_sheet": 50.0, "grid": true},
		# Battlemat: qualquer tile_*.glb / agua*.glb em src/assets/tilesets/.
		# Troque a hora que quiser pelo editor (Battlemat) ou por célula
		# (Tiles de rio). Enquanto não houver GLB, usa a folha texturizada.
		"tile_glb": "res://src/assets/tilesets",
	},
}
