extends Node
## EDITOR DE MAPA v2 â€” biblioteca de pecas por categoria + painel de
## transformacao da peca selecionada (rotacao 90graus, escala uniforme
## por padrao e por-eixo apenas em modo avancado), troca de piso por
## celula, colocacao de escadas (par) e persistencia em JSON aplicada
## POR CIMA da geracao do mapa (edicao de INSTANCIA, nunca da definicao
## compartilhada do catalogo TilePiece).
## F1 abre/fecha. Enquanto aberto: input do jogo bloqueado e turnos/IA
## ficam em espera (TurnManager consulta MapEditor.active).

const SAVE_NAME := "map_edits_%s.json"

## Biblioteca por categoria (nomes = ids do catalogo TilePiece).
const CAT_FLOORS := ["floor_water", "floor_dirt", "floor_stone",
	"floor_carpet", "floor_moss", "bridge_plank"]
const CAT_WALLS := ["wall_stone", "pillar"]
const CAT_OBSTACLES := ["rubble"]
const CAT_PROPS := ["chest_prop", "torch", "lever_base"]
const MODES := [["select", "Selecionar/Mover"], ["floor", "Trocar piso (tileset)"],
	["structure", "Paredes/Colunas"], ["obstacle", "Obstaculos"],
	["prop", "Props"], ["glb", "Modelos GLB"],
	["gtile", "Tiles de rio (GLB)"], ["stairs", "Escada"],
	["erase", "Apagar"]]
const SPAWN_KEYS := [["K", "Heroi"], ["M", "Maga"], ["W", "Druida"],
	["g", "Goblin"], ["a", "Arqueiro"], ["B", "Chefe"]]

var active := false
var env: Node = null
var mode := "select"
var cat_item := {}          # modo -> indice do item ativo na categoria
var spawn_key := "K"
var glb_list: Array = []
var selected_key = null     # Vector3i da peca selecionada (instancia)
var _pending_stair = null   # primeira celula do par de escada

var edits := {"props": [], "glbs": [], "floors": [], "stairs": [],
	"spawns": {}, "unit_removed": [], "unit_rot": {}}
var _placed := {}           # Vector3i -> {node, kind, data, fit}
var _floor_overrides := {}  # Vector3i -> {node, data} (troca de piso)
var _spawn_marks := {}
var _ui: CanvasLayer = null
var _cursor_quad: MeshInstance3D = null
var _hover_cell = null
var _icon_cache := {}       # id -> ImageTexture
var _icon_queue: Array = []

func _ready() -> void:
	_scan_glbs()
	load_edits()

func begin_session(environment: Node) -> void:
	env = environment
	apply_edits_to(environment)

# ------------------------------------------------------------ entrada ------

## Captura em fase ANTERIOR a GUI: se algum Control misterioso estiver
## engolindo cliques, aqui ainda chegamos. Ignora eventos sobre controles
## de UI (painel do proprio editor).
func _input(event: InputEvent) -> void:
	if not active or env == null:
		return
	if event is InputEventMouseMotion:
		var hov := get_viewport().gui_get_hovered_control()
		if hov != null:
			_dbg_gui(hov)
			return
		_update_hover(_pick_cell(event.position))
		_dbg_event(event)
	elif event is InputEventMouseButton and event.pressed \
			and (event.button_index == MOUSE_BUTTON_LEFT
					or event.button_index == MOUSE_BUTTON_RIGHT):
		var hov := get_viewport().gui_get_hovered_control()
		if hov != null:
			print("[EDITOR] clique sobre UI: ", hov.get_path())
			return
		var c: Variant = _pick_cell(event.position)
		_dbg_event(event)
		if event.button_index == MOUSE_BUTTON_LEFT:
			if mode == "select":
				# Modelo alto na frente do plano? Clique nele direto.
				var pc: Variant = _pick_piece(event.position)
				if pc != null:
					selected_unit = null
					_select(pc)
					_refresh_transform_ui()
					_set_status("Peca reselecionada em %s." % str(pc))
					return
			_apply_tool(c)
		else:
			if _dup_src != null:
				_dup_src = null
				_set_status("Modo carimbo encerrado.")
				_refresh_ui()
			else:
				_erase_at(c)

func _dbg_gui(hov: Control) -> void:
	var l: Control = _q("dbg")
	var path := str(hov.get_path())
	if l is Label:
		(l as Label).text = "DBG: mouse sobre UI: " + path
	if _last_gui_path != path:
		_last_gui_path = path
		print("[EDITOR] mouse sobre UI: ", path)

var _last_gui_path := ""

## Acao de 1 clique que NAO depende de picking: prova visivel de que a
## colocacao funciona (nasce ao lado do spawn do heroi).
func _place_test_piece() -> void:
	var base: Vector3i = env.spawns["K"][0] if env.spawns.has("K") \
			else Vector3i(5, 5, 0)
	var target := base
	for off in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, -1, 0),
			Vector3i(0, 1, 0)]:
		if BoardGrid.is_walkable(base + off) and not _placed.has(base + off):
			target = base + off
			break
	mode = "prop"
	cat_item["prop"] = CAT_PROPS.find("rubble")
	_place_piece("rubble", target, "prop")
	_refresh_ui()

## Status em destaque: o que o usuario acabou de causar / proximo passo.
func _set_status(t: String) -> void:
	var l: Control = _q("status")
	if l is Label:
		(l as Label).text = t
	print("[EDITOR][STATUS] ", t)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_F1:
		_toggle()
		get_viewport().set_input_as_handled()
		return
	if not active or env == null:
		return
	# Mouse e tratado em _input (fase anterior a GUI); aqui ficam so teclas.
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_Q:
				_rotate_selected(-90.0)
			KEY_E:
				_rotate_selected(90.0)
			KEY_G:
				_cycle_mode(1)
			KEY_DELETE, KEY_X:
				_delete_selected()
			KEY_Z:
				if event.ctrl_pressed:
					_undo_last()
			KEY_ESCAPE:
				if _dup_src != null:
					_dup_src = null
					_set_status("Modo carimbo encerrado.")
					_refresh_ui()
				elif selected_unit != null:
					selected_unit = null
					_set_status("Selecao de unidade limpa.")
				else:
					_select(null)

## Diagnostico ao vivo: mostra no painel o ultimo evento e a celula vista
## pelo picking (remover apos estabilizar o editor).
func _dbg_event(event: InputEvent) -> void:
	var l: Control = _q("dbg")
	if l == null or not (l is Label):
		return
	var txt := ""
	if event is InputEventMouseMotion:
		txt = "motion "
	elif event is InputEventMouseButton:
		txt = "btn%s p=%s" % [event.button_index, event.pressed]
	elif event is InputEventKey:
		txt = "key %s" % event.keycode
	var c = _pick_cell(event.position) if event is InputEventMouse else null
	var line := "DBG: %s celula=%s modo=%s pecas=%d" % [
			txt, str(c) if c != null else "null", mode, _placed.size()]
	(l as Label).text = line
	print("[EDITOR] ", line)

func _toggle() -> void:
	active = not active
	selected_key = null
	_pending_stair = null
	if active:
		_build_ui()
		selected_unit = null
		_set_hud_visible(false)
		_set_status("PAINEL ABERTO. 1) Escolha um item na lista. " +
				"2) CLIQUE NUMA CASA DO TABULEIRO (area central da tela).")
	else:
		_teardown_ui()
		_set_hud_visible(true)

## Esconde TODO o HUD do jogador (vida, status, bag) enquanto edita.
var _hud: CanvasLayer = null

func _set_hud_visible(v: bool) -> void:
	if _hud == null:
		for n in get_tree().root.get_children():
			if n is CanvasLayer and n != _ui and n != self \
					and n.get_script() != null \
					and str(n.get_script().resource_path).ends_with("hud.gd"):
				_hud = n
				break
	if _hud != null:
		_hud.visible = v
	EventBus.log_msg.emit("Editor de mapa %s." %
			["ABERTO (turnos em espera)" if active else "fechado"], "#7fd4ff")

func _pick_cell(screen_pos: Vector2):
	var cam := get_viewport().get_camera_3d()
	if cam == null or env == null:
		return null
	var origin := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.0005:
		return null
	var best = null
	var best_t := INF
	for f in maxi(1, env.floors_n):
		var plane_y: float = f * BoardGrid.FLOOR_H + 0.12
		var t := (plane_y - origin.y) / dir.y
		if t <= 0.01 or t >= best_t:
			continue
		var p := origin + dir * t
		var c := BoardGrid.world_to_cell(p, f)
		if BoardGrid.tiles.has(c):
			best = c
			best_t = t
	return best

func _cycle_mode(d: int) -> void:
	var names: Array = []
	for m in MODES:
		names.append(m[0])
	mode = names[(names.find(mode) + d + names.size()) % names.size()]
	_set_status("Modo: %s â€” clique numa casa do tabuleiro." % mode)
	_refresh_ui()

func _cat_items(mode_name: String) -> Array:
	match mode_name:
		"floor": return CAT_FLOORS
		"structure": return CAT_WALLS
		"obstacle": return CAT_OBSTACLES
		"prop": return CAT_PROPS
		"glb": return glb_list.filter(func(p) -> bool:
			return not _glb_tiles().has(p))
		"gtile": return _glb_tiles()
	return []

## GLBs que sao tiles de chao (substituem o gramado da casa):
## pasta terrenos/tileset ou arquivos começando com "agua".
func _glb_tiles() -> Array:
	var out: Array = []
	for p in glb_list:
		if p.find("terrenos/tileset") != -1 \
				or p.get_file().to_lower().begins_with("agua"):
			out.append(p)
	return out

func _active_item(mode_name: String) -> int:
	return cat_item.get(mode_name, 0)

# ------------------------------------------------------------- selecao -----

func _select(key) -> void:
	selected_key = key
	_refresh_transform_ui()

func _sel_entry() -> Variant:
	if selected_key != null and _placed.has(selected_key):
		return _placed[selected_key]
	return null

func _apply_transform(e, rot: float, su: float, adv: Vector3, fit: float) -> void:
	e["node"].rotation.y = deg_to_rad(rot)
	e["node"].scale = Vector3.ONE * su * adv * fit
	if e.get("kind") == "glb":
		_apply_bhv(e)

## ------------------------------------------------- COMPORTAMENTO DA Peca ---
## bhv: "block" (parede: nao passa), "top" (sobe: fica EM CIMA do modelo,
## mesma casa do grid), "decor" (atravessa). Auto por nome do arquivo.

const TOP_HINTS := ["eleva", "colina", "rampa", "ladeira", "subida"]

func _auto_bhv(path: String) -> String:
	var n := path.get_file().to_lower()
	for h in TOP_HINTS:
		if n.find(h) != -1:
			return "top"
	return "block"

## Corpo de colisao (trimesh) para raycast de altura das casas cobertas.
func _make_trimesh(e) -> void:
	for mi in _find_meshes(e["node"]):
		mi.create_trimesh_collision()
	for sb in _find_bodies(e["node"]):
		sb.collision_layer = 4
		sb.collision_mask = 0
		sb.set_meta("ed_data", e["data"])

## Clique em modelo ALTO: raycast fisico acha a peca certa (o plano do
## chao erraria para uma celula distante atras dela).
func _pick_piece(screen_pos: Vector2):
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return null
	var space: PhysicsDirectSpaceState3D = get_viewport().get_world_3d() \
			.direct_space_state
	var from := cam.project_ray_origin(screen_pos)
	var q := PhysicsRayQueryParameters3D.create(from,
			from + cam.project_ray_normal(screen_pos) * 300.0, 4)
	var hit = space.intersect_ray(q)
	if hit.is_empty():
		return null
	var col = hit.get("collider")
	if col is Node and (col as Node).has_meta("ed_data"):
		var d: Dictionary = (col as Node).get_meta("ed_data")
		return Vector3i(d["c"][0], d["c"][1], d["c"][2])
	return null

func _find_bodies(n: Node) -> Array:
	var out: Array = []
	if n is StaticBody3D:
		out.append(n)
	for ch in n.get_children():
		out.append_array(_find_bodies(ch))
	return out

## Todas as casas do tabuleiro sob o PE do modelo (AABB global XZ).
## NOTA: AABB() comeca como PONTO na origem — nunca usar como semente
## de merge (esticava a caixa ate (0,0,0) e cobria meio mapa!).
func _merge_seed() -> Array:
	return [AABB(), false]

func _mesh_aabb_world(e) -> AABB:
	var st := _merge_seed()
	for m in _find_meshes(e["node"]):
		if m is VisualInstance3D:
			var b: AABB = m.global_transform * m.get_aabb()
			st[0] = b if not st[1] else st[0].merge(b)
			st[1] = true
	return st[0] if st[1] else AABB()

func _covered_cells(e) -> Array:
	var st := _merge_seed()
	var any := false
	for m in _find_meshes(e["node"]):
		if m is VisualInstance3D:
			var b: AABB = m.global_transform * m.get_aabb()
			st[0] = b if not st[1] else st[0].merge(b)
			st[1] = true
	var out: Array = []
	if not st[1]:
		return out
	var box: AABB = st[0]
	var z: int = int(e["data"]["c"][2])
	var x0 := int(floor(box.position.x / BoardGrid.TILE))
	var x1 := int(floor((box.position.x + box.size.x) / BoardGrid.TILE))
	var y0 := int(floor(box.position.z / BoardGrid.TILE))
	var y1 := int(floor((box.position.z + box.size.z) / BoardGrid.TILE))
	for cy in range(y0, y1 + 1):
		for cx in range(x0, x1 + 1):
			out.append(Vector3i(cx, cy, z))
	return out

## Devolve as casas cobertas ao estado original (grid limpo p/ recalcular).
func _clear_cells(e) -> void:
	for d in e["data"].get("cells", []):
		var cc := Vector3i(d["c"][0], d["c"][1], d["c"][2])
		BoardGrid.set_tile(cc, bool(d["w"]), bool(d["l"]),
				int(d.get("e", 0)))
		BoardGrid.set_surface(cc, 0.0)
	e["data"]["cells"] = []

## Aplica comportamento em TODAS as casas cobertas pelo modelo.
func _apply_bhv(e) -> void:
	_clear_cells(e)
	var bhv := str(e["data"].get("bhv", "block"))
	if bhv == "decor":
		return
	var cells := _covered_cells(e)
	var recs: Array = []
	for c in cells:
		if not BoardGrid.tiles.has(c):
			continue
		recs.append({"c": [c.x, c.y, c.z],
				"w": BoardGrid.tiles[c]["w"],
				"l": BoardGrid.tiles[c]["losb"],
				"e": BoardGrid.tiles[c].get("elev", 0)})
	e["data"]["cells"] = recs
	if bhv == "block":
		for c in cells:
			if BoardGrid.tiles.has(c):
				BoardGrid.set_tile(c, false, true)
	else:
		_top_fill(e)

## SOBE: amostra a altura real do modelo em cada casa coberta (raycast
## contra o trimesh); se o raio falhar, usa fallback analitico do topo.
func _top_fill(e) -> void:
	for d in e["data"].get("cells", []):
		var c := Vector3i(d["c"][0], d["c"][1], d["c"][2])
		BoardGrid.set_tile(c, true, bool(d["l"]))
	if not is_inside_tree():
		return
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_instance_valid(e["node"]):
		return
	var space: PhysicsDirectSpaceState3D = get_viewport().get_world_3d() \
			.direct_space_state
	for d in e["data"].get("cells", []):
		var c := Vector3i(d["c"][0], d["c"][1], d["c"][2])
		var wp := BoardGrid.world_pos(c)
		var q := PhysicsRayQueryParameters3D.create(
				Vector3(wp.x, wp.y + 80, wp.z),
				Vector3(wp.x, wp.y - 30, wp.z), 4)
		var h := -1.0
		var hit = space.intersect_ray(q)
		if not hit.is_empty():
			h = float(hit["position"].y) - wp.y
		if h <= 0.02:
			# Fallback: topo analitico do AABB escalado.
			h = float(e["data"].get("hh", 0.0)) * float(e.get("fit", 1.0)) \
					* float(e["data"].get("s", 1.0))
		var steps := clampi(int(round(h / BoardGrid.ELEV_H)), 0, 8)
		d["e"] = steps
		BoardGrid.set_tile(c, true, bool(d["l"]), steps)
		BoardGrid.set_surface(c, h - steps * BoardGrid.ELEV_H)

func _cycle_bhv() -> void:
	var e = _sel_entry()
	if e == null or e["kind"] != "glb":
		_set_status("Selecione um MODELO GLB para mudar o comportamento.")
		return
	var order := ["block", "top", "decor"]
	var i := order.find(str(e["data"].get("bhv", "block")))
	e["data"]["bhv"] = order[(i + 1) % order.size()]
	_apply_bhv(e)
	_refresh_transform_ui()
	_set_status("Comportamento: %s" % _bhv_label(
			str(e["data"]["bhv"])))

func _bhv_label(bhv: String) -> String:
	return {"block": "BLOQUEIA (parede)", "top": "SOBE (fica em cima)",
			"decor": "ATRAVESSA (decoracao)"}.get(bhv, bhv)

func _rotate_selected(delta_deg: float) -> void:
	if selected_unit != null:
		var key: String = UNIT_KEY.get(selected_unit.id, "")
		selected_unit.rotation.y = wrapf(
				selected_unit.rotation.y + deg_to_rad(delta_deg),
				-PI, PI)
		if key != "":
			edits["unit_rot"][key] = rad_to_deg(selected_unit.rotation.y)
		_set_status("Unidade %s girada (%d graus)." % [selected_unit.id,
				int(rad_to_deg(selected_unit.rotation.y))])
		return
	var e = _sel_entry()
	if e == null:
		return
	e["data"]["rot"] = fposmod(float(e["data"].get("rot", 0.0)) + delta_deg, 360.0)
	_apply_transform(e, e["data"]["rot"], float(e["data"].get("s", 1.0)),
			_adv_v(e["data"]), float(e.get("fit", 1.0)))

func _set_uniform(v: float) -> void:
	if selected_unit != null:
		# Escala de personagem nativo (persistida por chave do heroi/inimigo).
		selected_unit.scale = Vector3.ONE * v
		var key: String = UNIT_KEY.get(selected_unit.id, "")
		if key != "":
			if not edits.has("unit_scl"):
				edits["unit_scl"] = {}
			edits["unit_scl"][key] = v
		_set_status("Escala de %s: %.2fx" % [selected_unit.id, v])
		return
	var e = _sel_entry()
	if e == null:
		return
	e["data"]["s"] = v
	_apply_transform(e, float(e["data"].get("rot", 0.0)), v,
			_adv_v(e["data"]), float(e.get("fit", 1.0)))

func _set_axis(axis: int, v: float) -> void:
	var e = _sel_entry()
	if e == null:
		return
	var adv: Array = e["data"].get("adv", [1, 1, 1])
	adv[axis] = v
	_apply_transform(e, float(e["data"].get("rot", 0.0)),
			float(e["data"].get("s", 1.0)),
			Vector3(float(adv[0]), float(adv[1]), float(adv[2])),
			float(e.get("fit", 1.0)))

# ------------------------------------------------------------- ferramentas --

func _apply_tool(c) -> void:
	if c == null:
		return
	if _dup_src != null:
		_stamp_duplicate(c)
		return
	match mode:
		"select":
			var u = BoardGrid.unit_at(c)
			if u != null:
				_select_unit(u, c)
			elif selected_unit != null and BoardGrid.is_free(c):
				_move_unit(selected_unit, c)
				selected_unit = null
			elif selected_key != null and _placed.has(selected_key) \
					and not _placed.has(c) and BoardGrid.is_free(c):
				_move_selected_piece(c)
			elif _placed.has(c):
				_select(c)
			elif BoardGrid.stair_links.has(c):
				EventBus.log_msg.emit("Escada: selecione os degraus colocados.", "#ffb84d")
			else:
				_select(null)
		"floor":
			_place_floor(_cat_items("floor")[_active_item("floor")], c)
		"structure":
			_place_piece(_cat_items("structure")[_active_item("structure")], c,
					"struct")
		"obstacle":
			_place_piece("rubble", c, "struct")
		"prop":
			_place_piece(_cat_items("prop")[_active_item("prop")], c, "prop")
		"glb":
			if not glb_list.is_empty():
				_place_glb(glb_list[_active_item("glb")], c)
		"gtile":
			if not _glb_tiles().is_empty():
				_place_gtile(_cat_items("gtile")[_active_item("gtile")], c)
		"stairs":
			_stairs_click(c)
		"erase":
			if _placed.has(c):
				_erase_at(c)
			else:
				_erase_unit_at(c)

## ------------------------------------------------------- UNITS DO MAPA ---
## Unidades nativas do mapa (herois/goblins) tambem sao editaveis:
## selecionar, mover para casa livre e excluir (so inimigos).

const UNIT_KEY := {"knight": "K", "mage": "M", "druid": "W",
		"goblin_warrior": "g", "goblin_archer": "a", "boss_knight": "B"}
var selected_unit = null

func _select_unit(u, c: Vector3i) -> void:
	selected_unit = u
	_select(null)
	var uid: String = str(u.id) if "id" in u else "?"
	_set_status(("Unidade selecionada: %s em %s. Clique noutra casa livre "
			+ "para move-la.") % [uid, str(c)])
	EventBus.log_msg.emit("Unidade %s selecionada" % uid, "#ffd166")

func _move_unit(u, nc: Vector3i) -> void:
	var oc: Vector3i = u.grid_pos
	BoardGrid.move_unit(u, nc)
	u.floor_index = nc.z
	u.position = BoardGrid.world_pos(nc)
	var key: String = UNIT_KEY.get(u.id, "")
	if key != "":
		edits["spawns"][key] = [nc.x, nc.y, nc.z]
	_push_undo({"op": "moveu", "u": u, "from": oc})
	_set_status("Unidade %s movida para %s (salva ao sair do editor)." %
			[u.id, nc])
	EventBus.log_msg.emit("%s -> %s" % [u.id, nc], "#ffd166")

func _erase_unit_at(c) -> void:
	var u = BoardGrid.unit_at(c)
	if u == null:
		return
	var key: String = UNIT_KEY.get(u.id, "")
	if key in ["K", "M", "W"]:
		_set_status("Herois nao podem ser excluidos â€” so reposicionar.")
		return
	edits["unit_removed"].append(key)
	u.die()
	selected_unit = null
	_set_status("Inimigo %s removido do mapa." % u.id)
	EventBus.log_msg.emit("Inimigo removido: %s" % u.id, "#ffb84d")

## Exclui o que estiver selecionado (peca do editor OU unidade inimiga).
func _delete_selected() -> void:
	if selected_unit != null:
		var u = selected_unit
		var key: String = UNIT_KEY.get(u.id, "")
		if key in ["K", "M", "W"]:
			_set_status("Herois nao podem ser excluidos â€” so reposicionar.")
			return
		edits["unit_removed"].append(key)
		u.die()
		selected_unit = null
		_set_status("Inimigo removido.")
		return
	if selected_key != null and _placed.has(selected_key):
		_erase_at(selected_key)

## ------------------------------------------------- DESFAZER / DUPLICAR ---
## Undo v1 cobre: colocar, apagar (exceto escada), mover peca, mover
## unidade e troca de piso (restaurando o estado anterior da casa).

var _undo: Array[Dictionary] = []
var _dup_src = null   # {kind,data,fit} para carimbar copias

func _push_undo(d: Dictionary) -> void:
	_undo.append(d)
	if _undo.size() > 60:
		_undo.pop_front()

func _undo_last() -> void:
	if _undo.is_empty():
		_set_status("Nada para desfazer.")
		return
	var a: Dictionary = _undo.pop_back()
	match a["op"]:
		"place":
			_erase_at(a["c"], false)
			_set_status("Desfeito: colocacao em %s." % str(a["c"]))
		"erase":
			_restore_entry(a["c"], a)
			_set_status("Desfeito: remocao em %s." % str(a["c"]))
		"floor":
			_restore_floor(a["c"], a.get("prev"))
			_set_status("Desfeito: troca de piso em %s." % str(a["c"]))
		"movep":
			_move_selected_piece_impl(a["to"], a["from"], false)
			selected_key = a["from"]
			_set_status("Desfeito: movimento de peca.")
		"moveu":
			var u = a["u"]
			if is_instance_valid(u):
				BoardGrid.move_unit(u, a["from"])
				u.floor_index = a["from"].z
				u.position = BoardGrid.world_pos(a["from"])
			_set_status("Desfeito: movimento de unidade.")

func _restore_entry(c: Vector3i, a: Dictionary) -> void:
	var kind: String = a["kind"]
	var data: Dictionary = a["data"].duplicate()
	if kind == "glb":
		_silent_glb(data.get("p", ""), c, data)
	elif kind == "gtile":
		_silent_gtile(data.get("p", ""), c, data)
	else:
		_silent_place(data.get("id", "rubble"), c, data)
		if kind == "struct":
			var meta: Dictionary = TilePiece.PROPS.get(data.get("id", ""), {})
			BoardGrid.set_tile(c, meta.get("w", true),
					BoardGrid.tiles[c]["losb"] if BoardGrid.tiles.has(c)
					else false)
	var e = _placed.get(c)
	if e != null and a.has("fit"):
		e["fit"] = a["fit"]

func _restore_floor(c: Vector3i, prev) -> void:
	if _floor_overrides.has(c):
		_floor_overrides[c]["node"].queue_free()
		_floor_overrides.erase(c)
	env.set_sheet_cell_hidden(c, false)
	if prev != null:
		_silent_floor(prev["id"], c)
		# _silent_floor ja esconde o base; registrar override manualmente.
		var node := Node3D.new()
		_floor_overrides[c] = {"node": _floor_overrides.get(
				c, {"node": null})["node"] if _floor_overrides.has(c)
				else node, "data": prev.duplicate()}

func _arm_duplicate() -> void:
	var e = _sel_entry()
	if e == null:
		_set_status("Selecione uma peca primeiro para duplicar.")
		return
	_dup_src = {"kind": e["kind"], "data": e["data"].duplicate(),
			"fit": float(e.get("fit", 1.0))}
	_refresh_ui()
	_set_status("MODO CARIMBO: clique nas casas para colocar copias. " +
			"Botao direito/ESC sai.")

func _stamp_duplicate(c: Vector3i) -> void:
	if c == null or not BoardGrid.is_walkable(c) or _placed.has(c):
		EventBus.log_msg.emit("Casa invalida para copia.", "#ff6b6b")
		return
	match _dup_src["kind"]:
		"glb":
			_silent_glb(_dup_src["data"].get("p", ""), c,
					_dup_src["data"].duplicate())
		"gtile":
			_silent_gtile(_dup_src["data"].get("p", ""), c,
					_dup_src["data"].duplicate())
		_:
			_silent_place(_dup_src["data"].get("id", "rubble"), c,
					_dup_src["data"].duplicate())
			var e = _placed.get(c)
			if e != null:
				e["fit"] = _dup_src["fit"]
				_apply_transform(e, float(e["data"].get("rot", 0.0)),
						float(e["data"].get("s", 1.0)), _adv_v(e["data"]),
						_dup_src["fit"])
	if _placed.has(c):
		_push_undo({"op": "place", "c": c})
		_select(c)
		_set_status("Copia em %s (%d carimbos ativos)." % [str(c), 1])

## Move a peca do editor selecionada para outra casa livre.
func _move_selected_piece(nc: Vector3i) -> void:
	_move_selected_piece_impl(nc, selected_key, true)

func _move_selected_piece_impl(nc: Vector3i, oc: Vector3i, record: bool) -> void:
	if not _placed.has(oc):
		return
	var e = _placed[oc]
	if e["kind"] == "gtile":
		env.set_sheet_cell_hidden(oc, false)
		env.set_sheet_cell_hidden(nc, true)
	if e["kind"] == "glb" or e["kind"] == "gtile":
		BoardGrid.set_tile(oc, bool(e["data"].get("pw", true)),
				bool(e["data"].get("pl", false)))
	if e["kind"] == "glb":
		_clear_cells(e)
	e["node"].position = BoardGrid.world_pos(nc) \
			+ (Vector3(0, 0.02, 0) if e["kind"] == "floor" else Vector3.ZERO)
	if e["kind"] == "struct":
		var meta: Dictionary = TilePiece.PROPS.get(e["data"]["id"], {})
		BoardGrid.set_tile(oc, true, BoardGrid.tiles[oc]["losb"]
				if BoardGrid.tiles.has(oc) else false)
		BoardGrid.set_tile(nc, meta.get("w", true), false)
	e["data"]["c"] = [nc.x, nc.y, nc.z]
	_placed.erase(oc)
	_placed[nc] = e
	if e["kind"] == "glb":
		_apply_bhv(e)
	elif e["kind"] == "gtile":
		# Agua rasa: bloqueia andar, NAO bloqueia visao.
		BoardGrid.set_tile(nc, false, false)
	selected_key = nc
	_refresh_transform_ui()
	if record:
		_push_undo({"op": "movep", "from": oc, "to": nc})
	_set_status("%s movido para %s. Q/E gira; DEL apaga." %
			[e["data"].get("id", "peca"), nc])

func _floor_node(c: Vector3i) -> Node3D:
	return env.get_node_or_null("Floor%d" % c.z)

func _register(kind: String, node: Node3D, c: Vector3i, data: Dictionary,
		fit := 1.0) -> void:
	node.position = BoardGrid.world_pos(c)
	node.rotation.y = deg_to_rad(float(data.get("rot", 0.0)))
	node.scale = Vector3.ONE * float(data.get("s", 1.0)) \
			* _adv_v(data) * fit
	_placed[c] = {"node": node, "kind": kind, "data": data, "fit": fit}

func _place_piece(id: String, c: Vector3i, kind: String) -> void:
	if _placed.has(c):
		EventBus.log_msg.emit("Celula ja ocupada pelo editor.", "#ff6b6b")
		return
	if not BoardGrid.is_walkable(c):
		EventBus.log_msg.emit("So sobre casas andaveis.", "#ff6b6b")
		return
	var piece := TilePiece.build(id)
	if piece == null:
		return
	var fl := _floor_node(c)
	if fl == null:
		piece.free()
		return
	fl.add_child(piece)
	_register(kind, piece, c, {"id": id, "c": [c.x, c.y, c.z],
			"rot": 0.0, "s": 1.0, "adv": [1, 1, 1]})
	# Pecas estruturais alteram o grid (bloqueio) pela tabela do catalogo;
	# props decorativos nao mexem no pathing.
	if kind == "struct":
		var meta: Dictionary = TilePiece.PROPS.get(id, {})
		BoardGrid.set_tile(c, meta.get("w", true), BoardGrid.tiles[c]["losb"])
	_select(c)
	_push_undo({"op": "place", "c": c})
	_set_status("OK: %s colocado em %s. Q/E gira, roda muda escala." % [id, c])
	EventBus.log_msg.emit("%s em %s" % [id, c], "#7fd4ff")

func _place_floor(id: String, c: Vector3i) -> void:
	if not BoardGrid.is_walkable(c):
		EventBus.log_msg.emit("So sobre casas andaveis.", "#ff6b6b")
		return
	# Troca SOMENTE o piso da celula: overrides de piso vivem em registro
	# proprio, preservando prop/obstaculo ja colocado ali.
	var prev = _floor_overrides[c]["data"].duplicate() \
			if _floor_overrides.has(c) else null
	if _floor_overrides.has(c):
		_floor_overrides[c]["node"].queue_free()
	var piece := TilePiece.build(id)
	if piece == null:
		return
	var fl := _floor_node(c)
	if fl == null:
		piece.free()
		return
	fl.add_child(piece)
	piece.position = BoardGrid.world_pos(c) + Vector3(0, 0.02, 0)
	_floor_overrides[c] = {"node": piece,
			"data": {"id": id, "c": [c.x, c.y, c.z]}}
	# Some com o tile base GLB da casa para o novo piso aparecer limpo.
	env.set_sheet_cell_hidden(c, true)
	_push_undo({"op": "floor", "c": c, "prev": prev})
	EventBus.log_msg.emit("Piso -> %s em %s" % [id, c], "#7fd4ff")

func _place_glb(path: String, c: Vector3i) -> void:
	if _placed.has(c):
		EventBus.log_msg.emit("Celula ja ocupada pelo editor.", "#ff6b6b")
		return
	if not BoardGrid.is_walkable(c):
		EventBus.log_msg.emit("So sobre casas andaveis.", "#ff6b6b")
		return
	var ps: PackedScene = load(path)
	if ps == null:
		return
	var inst: Node3D = ps.instantiate()
	var box := _model_aabb(inst)
	var holder := Node3D.new()
	holder.add_child(inst)
	var fl := _floor_node(c)
	if fl == null:
		holder.free()
		return
	fl.add_child(holder)
	var fit := 1.0
	if box.size.y > 0.001:
		fit = 1.4 / box.size.y
	# Pes no nivel do topo do tile (nao afundado): base do AABB em y=0,
	# centrado em XZ. holder escala depois; offset fica em unidades do GLB.
	inst.position = Vector3(-(box.position.x + box.size.x * 0.5),
			-box.position.y, -(box.position.z + box.size.z * 0.5))
	# Comportamento da peca: sobe/bloqueia/atravessa + estado antigo p/
	# restaurar ao apagar/mover.
	var pw: bool = BoardGrid.tiles[c]["w"] if BoardGrid.tiles.has(c) else true
	var pl: bool = BoardGrid.tiles[c]["losb"] if BoardGrid.tiles.has(c) else false
	_register("glb", holder, c, {"p": path, "c": [c.x, c.y, c.z],
			"rot": 0.0, "s": 1.0, "adv": [1, 1, 1], "pw": pw,
			"pl": pl, "bhv": _auto_bhv(path), "hh": box.size.y}, fit)
	_make_trimesh(_placed[c])
	_apply_bhv(_placed[c])
	_select(c)
	_push_undo({"op": "place", "c": c})
	_set_status("OK: %s em %s (%s)." % [path.get_file(), c,
			_bhv_label(str(_placed[c]["data"]["bhv"]))])
	EventBus.log_msg.emit("GLB em %s" % c, "#7fd4ff")

func _find_meshes(n: Node) -> Array:
	var out: Array = []
	if n is MeshInstance3D:
		out.append(n)
	for ch in n.get_children():
		out.append_array(_find_meshes(ch))
	return out

## AABB do modelo INTEIRO no espaco da raiz (cada malha transformada pelo
## proprio transform relativo — GLBs exportados com geometria deslocada
## da origem quebravam cobertura/colisao/altura).
func _aabb_rel(root: Node, n: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != root:
		if cur is Node3D:
			t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t

func _model_aabb(inst: Node3D) -> AABB:
	var st := _merge_seed()
	for m in _find_meshes(inst):
		if m is VisualInstance3D:
			var b: AABB = _aabb_rel(inst, m) \
					* (m as VisualInstance3D).get_aabb()
			st[0] = b if not st[1] else st[0].merge(b)
			st[1] = true
	return st[0] if st[1] else AABB(Vector3.ZERO, Vector3.ONE)

## Tile GLB (agua/rio): cobre a casa INTEIRA e esconde o gramado por baixo.
func _place_gtile(path: String, c: Vector3i) -> void:
	if _placed.has(c):
		EventBus.log_msg.emit("Celula ja ocupada pelo editor.", "#ff6b6b")
		return
	if not BoardGrid.is_walkable(c):
		EventBus.log_msg.emit("So sobre casas andaveis.", "#ff6b6b")
		return
	var ps: PackedScene = load(path)
	if ps == null:
		return
	var inst: Node3D = ps.instantiate()
	var box := _model_aabb(inst)
	var holder := Node3D.new()
	holder.add_child(inst)
	var fl := _floor_node(c)
	if fl == null:
		holder.free()
		return
	fl.add_child(holder)
	var span: float = maxf(box.size.x, box.size.z)
	var fit := 1.0
	if span > 0.001:
		fit = BoardGrid.TILE / span
	inst.position = Vector3(-(box.position.x + box.size.x * 0.5),
			-box.position.y, -(box.position.z + box.size.z * 0.5))
	var pw: bool = BoardGrid.tiles[c]["w"] if BoardGrid.tiles.has(c) else true
	var pl: bool = BoardGrid.tiles[c]["losb"] if BoardGrid.tiles.has(c) else false
	env.set_sheet_cell_hidden(c, true)
	# Agua rasa: bloqueia andar, mas NAO bloqueia visao.
	BoardGrid.set_tile(c, false, false)
	_register("gtile", holder, c, {"p": path, "c": [c.x, c.y, c.z],
			"rot": 0.0, "s": 1.0, "adv": [1, 1, 1], "pw": pw, "pl": pl}, fit)
	_select(c)
	_push_undo({"op": "place", "c": c})
	_set_status("OK: tile %s em %s (grama escondida, casa bloqueada)." %
			[path.get_file(), c])
	EventBus.log_msg.emit("Tile GLB em %s" % c, "#7fd4ff")

func _silent_gtile(path: String, c: Vector3i, data: Dictionary) -> void:
	if path == "" or _placed.has(c) or not BoardGrid.is_walkable(c):
		return
	var ps: PackedScene = load(path)
	if ps == null:
		return
	var inst: Node3D = ps.instantiate()
	var box := _model_aabb(inst)
	var holder := Node3D.new()
	holder.add_child(inst)
	var fl := _floor_node(c)
	if fl == null:
		holder.free()
		return
	fl.add_child(holder)
	var span: float = maxf(box.size.x, box.size.z)
	var fit := 1.0
	if span > 0.001:
		fit = BoardGrid.TILE / span
	inst.position = Vector3(-(box.position.x + box.size.x * 0.5),
			-box.position.y, -(box.position.z + box.size.z * 0.5))
	data["pw"] = BoardGrid.tiles[c]["w"] if BoardGrid.tiles.has(c) else true
	data["pl"] = BoardGrid.tiles[c]["losb"] if BoardGrid.tiles.has(c) else false
	env.set_sheet_cell_hidden(c, true)
	BoardGrid.set_tile(c, false, false)
	data["c"] = [c.x, c.y, c.z]
	_register("gtile", holder, c, data, fit)

func _stairs_click(c: Vector3i) -> void:
	if _pending_stair == null:
		_pending_stair = c
		EventBus.log_msg.emit("Escada: base em %s. Clique no topo (outro andar)." % c,
				"#ffd166")
		return
	var a: Vector3i = _pending_stair
	_pending_stair = null
	if a == c or a.z == c.z:
		EventBus.log_msg.emit("Par invalido: precisa de andares diferentes.", "#ff6b6b")
		return
	if BoardGrid.stair_links.has(a) or BoardGrid.stair_links.has(c):
		EventBus.log_msg.emit("Uma das celulas ja tem escada.", "#ff6b6b")
		return
	BoardGrid.add_stair_link(a, c)
	for pair in [[a, "stairs_prop"], [c, "stairs_top"]]:
		var pc: Vector3i = pair[0]
		var piece := TilePiece.build(pair[1])
		var fl := _floor_node(pc)
		if fl != null:
			fl.add_child(piece)
			_register("stair", piece, pc, {"pair": [a, c],
					"c": [pc.x, pc.y, pc.z]})
	edits["stairs"].append([[a.x, a.y, a.z], [c.x, c.y, c.z]])
	EventBus.log_msg.emit("Escada criada: %s <-> %s" % [a, c], "#8fdc7f")

func _set_spawn(key: String, c: Vector3i) -> void:
	edits["spawns"][key] = [c.x, c.y, c.z]
	_draw_spawn_mark(key, c)
	EventBus.log_msg.emit("Spawn %s = %s (aplica ao reiniciar)" % [key, c], "#ffd166")

func _draw_spawn_mark(key: String, c: Vector3i) -> void:
	if _spawn_marks.has(c):
		_spawn_marks[c].queue_free()
		_spawn_marks.erase(c)
	var m := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.32
	cyl.bottom_radius = 0.32
	cyl.height = 0.06
	m.mesh = cyl
	var col := Color(0.3, 0.85, 0.4) if key in ["K", "M", "W"] \
			else Color(0.9, 0.25, 0.25)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(col.r, col.g, col.b, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.material_override = mat
	var fl := _floor_node(c)
	if fl == null:
		return
	fl.add_child(m)
	m.position = BoardGrid.world_pos(c) + Vector3(0, 0.16, 0)
	var lab := Label3D.new()
	lab.text = key
	lab.font_size = 220
	lab.pixel_size = 0.004
	lab.modulate = col
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.position = Vector3(0, 0.35, 0)
	m.add_child(lab)
	_spawn_marks[c] = m

func _erase_at(c, record := true) -> void:
	if c == null:
		return
	if _placed.has(c):
		var e = _placed[c]
		var can_undo: bool = record and e["kind"] != "stair"
		e["node"].queue_free()
		if e["kind"] == "struct":
			BoardGrid.set_tile(c, true,
					BoardGrid.tiles[c]["losb"] if BoardGrid.tiles.has(c) else false)
		if e["kind"] == "gtile":
			env.set_sheet_cell_hidden(c, false)
		if e["kind"] == "glb" or e["kind"] == "gtile":
			BoardGrid.set_tile(c, bool(e["data"].get("pw", true)),
					bool(e["data"].get("pl", false)))
		if e["kind"] == "glb":
			_clear_cells(e)
		if e["kind"] == "stair":
			var other = BoardGrid.stair_pair(c)
			BoardGrid.stair_links.erase(c)
			for kk in _placed.keys().duplicate():
				if _placed[kk]["kind"] == "stair" and kk != c:
					_placed[kk]["node"].queue_free()
					_placed.erase(kk)
			BoardGrid.stair_links.erase(other) if other != c else null
			_remove_stair_from_edits(c)
		if selected_key != null and selected_key == c:
			_select(null)
		_placed.erase(c)
		if can_undo:
			_push_undo({"op": "erase", "c": c, "kind": e["kind"],
					"data": e["data"].duplicate(),
					"fit": float(e.get("fit", 1.0))})
		_set_status("Removido: %s em %s." %
				[e["kind"], c])
		EventBus.log_msg.emit("Item removido em %s" % c, "#ffb84d")
	elif _floor_overrides.has(c):
		_floor_overrides[c]["node"].queue_free()
		_floor_overrides.erase(c)
		env.set_sheet_cell_hidden(c, false)
		_set_status("Piso base restaurado em %s." % c)
		EventBus.log_msg.emit("Piso restaurado em %s" % c, "#ffb84d")
	elif _spawn_marks.has(c):
		_spawn_marks[c].queue_free()
		_spawn_marks.erase(c)
		for k in edits["spawns"].keys():
			var v: Array = edits["spawns"][k]
			if Vector3i(v[0], v[1], v[2]) == c:
				edits["spawns"].erase(k)

func _remove_stair_from_edits(c: Vector3i) -> void:
	for i in range(edits["stairs"].size() - 1, -1, -1):
		var pr: Array = edits["stairs"][i]
		var a := Vector3i(pr[0][0], pr[0][1], pr[0][2])
		var b := Vector3i(pr[1][0], pr[1][1], pr[1][2])
		if a == c or b == c:
			edits["stairs"].remove_at(i)

# ---------------------------------------------------------------- cursor ---

func _update_hover(c) -> void:
	_hover_cell = c
	if c == null:
		if _cursor_quad != null:
			_cursor_quad.visible = false
		if _ghost != null:
			_ghost.visible = false
		return
	if _cursor_quad == null:
		_cursor_quad = MeshInstance3D.new()
		var q := PlaneMesh.new()
		q.size = Vector2(BoardGrid.TILE * 0.96, BoardGrid.TILE * 0.96)
		_cursor_quad.mesh = q
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.83, 0.2, 0.35)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_cursor_quad.material_override = mat
		add_child(_cursor_quad)
	var sel: bool = _hover_cell == selected_key
	var mat: StandardMaterial3D = _cursor_quad.material_override
	var armed: bool = mode in ["floor", "structure", "obstacle", "prop",
			"glb", "gtile", "stairs"] or _dup_src != null
	if armed:
		# Verde = pode colocar aqui; vermelho = ocupada/invalida.
		var ok: bool = BoardGrid.is_walkable(c) and not _placed.has(c) \
				and not BoardGrid.occupied.has(c)
		mat.albedo_color = Color(0.3, 1.0, 0.5, 0.45) if ok \
				else Color(1.0, 0.25, 0.25, 0.4)
	else:
		mat.albedo_color = Color(0.3, 1.0, 0.5, 0.45) if sel \
				else Color(1.0, 0.83, 0.2, 0.35)
	_cursor_quad.visible = true
	_cursor_quad.position = BoardGrid.world_pos(c) + Vector3(0, 0.14, 0)
	_update_ghost(c)

## Miniatura fantasma do asset armado: caixa translucida + nome flutuante
## sobre a casa sob o cursor (some quando o modo nao coloca nada).
var _ghost: Node3D = null
var _ghost_label: Label3D = null

func _armed_item_name() -> String:
	match mode:
		"floor", "structure", "obstacle", "prop":
			return str(_cat_items(mode)[_active_item(mode)])
		"glb":
			return glb_list[_active_item("glb")].get_file() \
					if not glb_list.is_empty() else ""
		"gtile":
			return _cat_items("gtile")[_active_item("gtile")].get_file() \
					if not _glb_tiles().is_empty() else ""
	return ""

func _update_ghost(c: Vector3i) -> void:
	var name := _armed_item_name()
	if name == "" or not BoardGrid.is_walkable(c):
		if _ghost != null:
			_ghost.visible = false
		return
	if _ghost == null:
		_ghost = MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(BoardGrid.TILE * 0.9, 1.4, BoardGrid.TILE * 0.9)
		_ghost.mesh = bm
		var gm := StandardMaterial3D.new()
		gm.albedo_color = Color(0.4, 0.8, 1.0, 0.28)
		gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ghost.material_override = gm
		add_child(_ghost)
		_ghost_label = Label3D.new()
		_ghost_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_ghost_label.no_depth_test = true
		_ghost_label.font_size = 40
		_ghost_label.pixel_size = 0.004
		_ghost_label.modulate = Color(0.55, 0.9, 1.0)
		_ghost.add_child(_ghost_label)
		_ghost_label.position = Vector3(0, 1.05, 0)
	_ghost.visible = true
	_ghost.position = BoardGrid.world_pos(c) + Vector3(0, 0.7, 0)
	_ghost_label.text = name

# ------------------------------------------------------- persistencia ------

func _save_path() -> String:
	return SAVE_NAME % (env.map_id if env != null else "default")

func save_edits() -> void:
	var out := {"props": [], "glbs": [], "gtiles": [], "floors": [],
			"stairs": [], "spawns": edits["spawns"]}
	for c in _placed:
		var e = _placed[c]
		match e["kind"]:
			"struct":
				out["props"].append(_merge({"id": e["data"]["id"],
						"struct": true}, e["data"]))
			"prop":
				out["props"].append(e["data"])
			"glb":
				out["glbs"].append(e["data"])
			"gtile":
				out["gtiles"].append(e["data"])
	for c in _floor_overrides:
		out["floors"].append(_floor_overrides[c]["data"])
	out["stairs"] = edits["stairs"]
	out["unit_removed"] = edits["unit_removed"]
	out["unit_rot"] = edits["unit_rot"]
	out["unit_scl"] = edits.get("unit_scl", {})
	out["mat_glb"] = edits.get("mat_glb", "")
	var f := FileAccess.open("user://" + _save_path(), FileAccess.WRITE)
	if f == null:
		EventBus.log_msg.emit("Editor: falha ao salvar!", "#ff6b6b")
		return
	f.store_string(JSON.stringify(out, "\t"))
	f.close()
	# Validacao D14 (portas desobstruidas): avisa, nao trava.
	env._validate_doors()
	EventBus.log_msg.emit("Mapa salvo: %s (validacao de portas executada)" %
			OS.get_user_data_dir().path_join(_save_path()), "#8fdc7f")

func _merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := b.duplicate()
	for k in a:
		out[k] = a[k]
	return out

func load_edits() -> void:
	var p := "user://" + _save_path()
	if not FileAccess.file_exists(p):
		return
	var f := FileAccess.open(p, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		edits = parsed
	if not edits.has("unit_removed"):
		edits["unit_removed"] = []
	if not edits.has("unit_rot"):
		edits["unit_rot"] = {}
	if not edits.has("unit_scl"):
		edits["unit_scl"] = {}
	if not edits.has("mat_glb"):
		edits["mat_glb"] = ""

## Reaplica edicoes salvas por cima do mapa recem-gerado (instancias).
func apply_edits_to(environment: Node) -> void:
	env = environment
	for d in edits.get("props", []):
		var c := Vector3i(d["c"][0], d["c"][1], d["c"][2])
		_silent_place(_item_id(d), c, _norm_item(d))
	for d in edits.get("glbs", []):
		var c := Vector3i(d["c"][0], d["c"][1], d["c"][2])
		_silent_glb(d.get("p", ""), c, _norm_item(d))
	for d in edits.get("gtiles", []):
		var c := Vector3i(d["c"][0], d["c"][1], d["c"][2])
		_silent_gtile(d.get("p", ""), c, _norm_item(d))
	for d in edits.get("floors", []):
		_silent_floor(_item_id(d), Vector3i(d["c"][0], d["c"][1], d["c"][2]))
	for pr in edits.get("stairs", []):
		var a := Vector3i(pr[0][0], pr[0][1], pr[0][2])
		var b := Vector3i(pr[1][0], pr[1][1], pr[1][2])
		if not BoardGrid.stair_links.has(a) and not BoardGrid.stair_links.has(b):
			BoardGrid.add_stair_link(a, b)
			for pair in [[a, "stairs_prop"], [b, "stairs_top"]]:
				var pc: Vector3i = pair[0]
				var piece := TilePiece.build(pair[1])
				var fl := _floor_node(pc)
				if fl != null:
					fl.add_child(piece)
					_register("stair", piece, pc, {"pair": [a, b],
							"c": [pc.x, pc.y, pc.z]})
	for k in edits["spawns"].keys():
		var v: Array = edits["spawns"][k]
		environment.spawns[k] = [Vector3i(v[0], v[1], v[2])]
		_draw_spawn_mark(k, Vector3i(v[0], v[1], v[2]))
	# Inimigos removidos pelo editor nao nascem (herois nunca sao removidos).
	for k in edits.get("unit_removed", []):
		if not edits["spawns"].has(k):
			environment.spawns.erase(k)
	# Battlemat alternativo salvo pelo editor (troca do GLB do chao base).
	var mat: String = str(edits.get("mat_glb", ""))
	if mat != "" and ResourceLoader.exists(mat) \
			and environment.has_method("set_battle_mat"):
		environment.set_battle_mat.call_deferred(mat)
	var total: int = int(edits.get("props", []).size()) \
			+ int(edits.get("glbs", []).size()) \
			+ int(edits.get("gtiles", []).size()) \
			+ int(edits.get("floors", []).size()) \
			+ int(edits.get("stairs", []).size()) \
			+ int(edits["spawns"].size())
	if total > 0:
		EventBus.log_msg.emit("Edicoes de mapa carregadas (%d)." % total, "#7fd4ff")

## Compat v1->v2: "t" antigo virou "id", "yaw" virou "rot".
func _item_id(d: Dictionary) -> String:
	return str(d.get("id", d.get("t", "rubble")))

func _norm_item(d: Dictionary) -> Dictionary:
	var out := d.duplicate()
	out["id"] = _item_id(out)
	if out.has("t"):
		out.erase("t")
	if out.has("yaw") and not out.has("rot"):
		out["rot"] = out["yaw"]
		out.erase("yaw")
	if not out.has("rot"):
		out["rot"] = 0.0
	if not out.has("s"):
		out["s"] = 1.0
	if not out.has("adv"):
		out["adv"] = [1, 1, 1]
	return out

func _silent_place(id: String, c: Vector3i, data: Dictionary) -> void:
	if _placed.has(c) or not BoardGrid.is_walkable(c):
		return
	var piece := TilePiece.build(id)
	if piece == null:
		return
	var fl := _floor_node(c)
	if fl == null:
		piece.free()
		return
	fl.add_child(piece)
	data["c"] = [c.x, c.y, c.z]
	_register("struct" if data.get("struct", false) else "prop", piece, c, data)
	if data.get("struct", false):
		var meta: Dictionary = TilePiece.PROPS.get(id, {})
		BoardGrid.set_tile(c, meta.get("w", true), BoardGrid.tiles[c]["losb"])

func _silent_glb(path: String, c: Vector3i, data: Dictionary) -> void:
	if path == "" or _placed.has(c) or not BoardGrid.is_walkable(c):
		return
	var ps: PackedScene = load(path)
	if ps == null:
		return
	var inst: Node3D = ps.instantiate()
	var box := _model_aabb(inst)
	var holder := Node3D.new()
	holder.add_child(inst)
	var fl := _floor_node(c)
	if fl == null:
		holder.free()
		return
	fl.add_child(holder)
	var fit := 1.0
	if box.size.y > 0.001:
		fit = 1.4 / box.size.y
	inst.position = Vector3(-(box.position.x + box.size.x * 0.5),
			-box.position.y, -(box.position.z + box.size.z * 0.5))
	if not data.has("pw"):
		data["pw"] = BoardGrid.tiles[c]["w"] if BoardGrid.tiles.has(c) else true
		data["pl"] = BoardGrid.tiles[c]["losb"] \
				if BoardGrid.tiles.has(c) else false
	if not data.has("bhv"):
		data["bhv"] = _auto_bhv(path)
	if not data.has("hh"):
		data["hh"] = box.size.y
	data["c"] = [c.x, c.y, c.z]
	_register("glb", holder, c, data, fit)
	_make_trimesh(_placed[c])
	_apply_bhv(_placed[c])

func _silent_floor(id: String, c: Vector3i) -> void:
	var piece := TilePiece.build(id)
	if piece == null:
		return
	var fl := _floor_node(c)
	if fl == null:
		piece.free()
		return
	fl.add_child(piece)
	piece.position = BoardGrid.world_pos(c) + Vector3(0, 0.02, 0)
	env.set_sheet_cell_hidden(c, true)

# -------------------------------------------------------------------- UI ---

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 95
	add_child(_ui)
	var sc := ScrollContainer.new()
	sc.anchor_left = 1.0
	sc.anchor_right = 1.0
	sc.anchor_top = 0.0
	sc.anchor_bottom = 1.0
	sc.offset_left = -320
	sc.offset_top = 16
	sc.offset_right = -14
	sc.offset_bottom = -16
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_ui.add_child(sc)
	var vb := VBoxContainer.new()
	vb.name = "VB"
	vb.custom_minimum_size = Vector2(295, 0)
	sc.add_child(vb)
	_add_label(vb, "title", "EDITOR DE MAPA (F1 fecha)")
	var armed := Label.new()
	armed.name = "armed_name"
	armed.text = "VAI COLOCAR: (nada)"
	armed.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	armed.add_theme_font_size_override("font_size", 16)
	armed.add_theme_color_override("font_color", Color.html("7fd4ff"))
	vb.add_child(armed)
	var dbg := Label.new()
	dbg.name = "dbg"
	dbg.text = "DBG: aguardando eventos..."
	dbg.add_theme_font_size_override("font_size", 12)
	vb.add_child(dbg)
	var status := Label.new()
	status.name = "status"
	status.text = ""
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size", 15)
	status.add_theme_color_override("font_color", Color.html("ffd166"))
	vb.add_child(status)
	var tb := Button.new()
	tb.text = "TESTE: colocar pedra ao lado do heroi"
	tb.pressed.connect(_place_test_piece)
	vb.add_child(tb)
	var du := Button.new()
	du.name = "del_unit"
	du.text = "EXCLUIR inimigo sob o cursor (modo Apagar)"
	du.pressed.connect(func() -> void:
		mode = "erase"
		_set_status("Modo APAGAR: clique num item OU num INIMIGO para remover.")
		_refresh_ui())
	vb.add_child(du)
	var ds := Button.new()
	ds.name = "del_sel"
	ds.text = "EXCLUIR o que esta selecionado (DEL)"
	ds.pressed.connect(_delete_selected)
	vb.add_child(ds)
	var un := Button.new()
	un.name = "undo_btn"
	un.text = "DESFAZER (Ctrl+Z)"
	un.pressed.connect(_undo_last)
	vb.add_child(un)
	var dp := Button.new()
	dp.name = "dup_btn"
	dp.text = "DUPLICAR selecao (modo carimbo)"
	dp.pressed.connect(_arm_duplicate)
	vb.add_child(dp)
	for m in MODES:
		var b := Button.new()
		b.name = "mode_" + m[0]
		b.pressed.connect(func() -> void: mode = m[0]; _refresh_ui())
		vb.add_child(b)
	_add_label(vb, "lib_title", "--- Biblioteca ---")
	for cat in [["floor", CAT_FLOORS], ["structure", CAT_WALLS],
			["obstacle", CAT_OBSTACLES], ["prop", CAT_PROPS]]:
		_add_label(vb, "cat_" + cat[0], cat[0])
		for i in cat[1].size():
			var id: String = cat[1][i]
			var b := Button.new()
			b.name = "item_%s_%d" % [cat[0], i]
			b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.pressed.connect(func() -> void:
				mode = cat[0]; cat_item[cat[0]] = i; _refresh_ui())
			vb.add_child(b)
	_add_label(vb, "cat_glb", "modelos GLB")
	var hint := Label.new()
	hint.name = "glb_hint"
	hint.text = "Coloque .glb em src/assets/editor e clique RECARREGAR"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color.html("8a8f9c"))
	vb.add_child(hint)
	var rl := Button.new()
	rl.name = "reload_assets"
	rl.text = "RECARREGAR ASSETS (.glb)"
	rl.pressed.connect(_reload_assets)
	vb.add_child(rl)
	for i in glb_list.size():
		var b := Button.new()
		b.name = "item_glb_%d" % i
		b.pressed.connect(func() -> void:
			mode = "glb"; cat_item["glb"] = i; _refresh_ui())
		vb.add_child(b)
	_add_label(vb, "cat_spawns", "spawns (clique = marca)")
	for sk in SPAWN_KEYS:
		var b := Button.new()
		b.name = "spawn_" + sk[0]
		b.pressed.connect(func() -> void:
			spawn_key = sk[0]
			if _hover_cell != null:
				_set_spawn(sk[0], _hover_cell)
			_refresh_ui())
		vb.add_child(b)
	_add_label(vb, "cat_mat", "--- Battlemat (TROCA O MAPA INTEIRO) ---")
	var rb := Button.new()
	rb.name = "mat_reset"
	rb.text = "RESTAURAR chao padrao do mapa"
	rb.pressed.connect(func() -> void: _reset_battle_mat())
	vb.add_child(rb)
	var mats: Array = _mat_candidates()
	for i in mats.size():
		var mb := Button.new()
		mb.name = "mat_%d" % i
		mb.pressed.connect(func() -> void: _apply_battle_mat(mats[i]))
		vb.add_child(mb)
	_add_label(vb, "cat_units", "--- Personagens no mapa ---")
	var ub := VBoxContainer.new()
	ub.name = "units_box"
	vb.add_child(ub)
	_add_label(vb, "cat_placed", "--- Pecas colocadas (clique p/ editar) ---")
	var pb2 := VBoxContainer.new()
	pb2.name = "placed_box"
	vb.add_child(pb2)
	_add_label(vb, "tf_title", "--- Transformacao ---")
	_add_label(vb, "tf_sel", "nenhuma peca selecionada")
	_add_label(vb, "tf_h", "")
	var rot_row := HBoxContainer.new()
	rot_row.name = "tf_rot"
	vb.add_child(rot_row)
	var bm := Button.new(); bm.text = "-90 (Q)"
	bm.pressed.connect(func() -> void: _rotate_selected(-90.0))
	rot_row.add_child(bm)
	var bp := Button.new(); bp.text = "+90 (E)"
	bp.pressed.connect(func() -> void: _rotate_selected(90.0))
	rot_row.add_child(bp)
	_add_label(vb, "tf_s_label", "Escala uniforme")
	var sl := HSlider.new()
	sl.name = "tf_s"
	sl.min_value = 0.3
	sl.max_value = 3.0
	sl.step = 0.05
	sl.value = 1.0
	sl.custom_minimum_size = Vector2(280, 20)
	sl.value_changed.connect(func(v: float) -> void: _set_uniform(v))
	vb.add_child(sl)
	var adv_cb := CheckBox.new()
	adv_cb.name = "tf_adv"
	adv_cb.text = "Eixos independentes (avancado - distorce!)"
	adv_cb.pressed.connect(func() -> void: _refresh_transform_ui())
	vb.add_child(adv_cb)
	for ax in [["X", 0], ["Y", 1], ["Z", 2]]:
		_add_label(vb, "tf_ax%d_l" % ax[1], "")
		var sa := HSlider.new()
		sa.name = "tf_ax%d" % ax[1]
		sa.min_value = 0.3
		sa.max_value = 3.0
		sa.step = 0.05
		sa.custom_minimum_size = Vector2(280, 20)
		var axis: int = ax[1]
		sa.value_changed.connect(func(v: float) -> void: _set_axis(axis, v))
		vb.add_child(sa)
	var del := Button.new()
	del.name = "tf_del"
	del.text = "EXCLUIR peca selecionada"
	del.pressed.connect(func() -> void: _erase_at(selected_key))
	vb.add_child(del)
	var bb := Button.new()
	bb.name = "tf_bhv"
	bb.text = "Andar: (selecione uma peca)"
	bb.pressed.connect(func() -> void: _cycle_bhv())
	vb.add_child(bb)
	_add_label(vb, "hint", "Clique: usar ferramenta | Direito: apagar\n" +
			"Q/E gira | G troca modo | Esc: desselecionar")
	var gen_b := Button.new()
	gen_b.text = "GERAR GRID (raycast — bake)"
	gen_b.pressed.connect(func() -> void:
		if env != null and env.has_method("bake_grid"):
			env.bake_grid()
			_set_status("Grid gerado por raycast (%d células)." % BoardGrid.tiles.size()))
	vb.add_child(gen_b)
	var save_b := Button.new()
	save_b.text = "SALVAR MAPA"
	save_b.pressed.connect(save_edits)
	vb.add_child(save_b)
	_refresh_ui()
	_refresh_transform_ui()
	_queue_icons()

func _add_label(vb: VBoxContainer, name_: String, txt: String) -> void:
	var l := Label.new()
	l.name = name_
	l.text = txt
	vb.add_child(l)

func _q(n: String) -> Control:
	if _ui == null:
		return null
	return _ui.get_node_or_null(NodePath("ScrollContainer/VB/" + n))

## ------------------------------------------------------- BATTLEMAT GLB ---
## Candidatos = qualquer .glb na pasta de assets cujo arquivo comece com
## "tile_" (ex.: tile_bosque.glb). Solte novos tiles_*.glb em
## src/assets/editor e clique RECARREGAR ASSETS para lista-los aqui.

func _mat_candidates() -> Array:
	# APENAS mats de mapa inteiro (convencao tile_*.glb). Tiles por casa
	# (agua/rio) ficam no modo "Tiles de rio (GLB)", nao aqui!
	var out: Array = []
	for p in glb_list:
		if p.get_file().begins_with("tile_"):
			out.append(p)
	return out

func _reset_battle_mat() -> void:
	if env == null or not env.has_method("set_battle_mat"):
		return
	var dflt: String = env.get_default_mat()
	if dflt == "" or not env.set_battle_mat(dflt):
		_set_status("Falha ao restaurar o battlemat padrao.")
		return
	edits["mat_glb"] = ""
	for c in _floor_overrides:
		env.set_sheet_cell_hidden(c, true)
	_refresh_ui()
	_set_status("Battlemat padrao restaurado (%s). Salve para manter."
			% dflt.get_file())

func _apply_battle_mat(path: String) -> void:
	if env == null or not env.has_method("set_battle_mat"):
		return
	if env.set_battle_mat(path):
		edits["mat_glb"] = path
		# Reconstrucao da folha zera escondimentos: re-aplica os overrides.
		for c in _floor_overrides:
			env.set_sheet_cell_hidden(c, true)
		_refresh_ui()
		_set_status("Battlemat trocado para %s. Salve para manter."
				% path.get_file())
		EventBus.log_msg.emit("Battlemat: %s" % path.get_file(), "#8fdc7f")
	else:
		_set_status("Falha ao trocar battlemat para %s." % path.get_file())

func _refresh_ui() -> void:
	if _ui == null:
		return
	# Linha "VAI COLOCAR": nome escrito do asset armado no momento.
	var armed: Control = _q("armed_name")
	if armed is Label:
		var t := ""
		if _dup_src != null:
			t = "VAI COLOCAR: COPIA de %s (carimbo)" % [
					str(_dup_src["data"].get("id",
					_dup_src["data"].get("p", "?")).get_file())]
		elif mode in ["floor", "structure", "obstacle", "prop"]:
			var items: Array = _cat_items(mode)
			t = "VAI COLOCAR: %s (%s)" % [str(items[_active_item(mode)]), mode]
		elif mode == "glb" and not glb_list.is_empty():
			t = "VAI COLOCAR: %s (modelo GLB)" \
					% glb_list[_active_item("glb")].get_file()
		elif mode == "gtile":
			var gt: Array = _glb_tiles()
			t = "VAI COLOCAR: %s (tile de rio — grama some)" % (
					gt[_active_item("gtile")].get_file()
					if not gt.is_empty() else "nenhum tile encontrado")
		elif mode == "stairs":
			t = "MODO ESCADA: clique casa baixa e depois a alta"
		elif mode == "erase":
			t = "MODO APAGAR: clique no que quer remover"
		else:
			t = "MODO SELECIONAR/MOVER"
		(armed as Label).text = t
	_rebuild_units_box()
	_rebuild_placed_box()

## Lista clicavel de TODAS as unidades nativas do mapa (herois e inimigos).
func _rebuild_units_box() -> void:
	var box: Control = _q("units_box")
	if box == null:
		return
	for ch in box.get_children():
		ch.free()
	if BoardGrid.occupied.is_empty():
		var l := Label.new()
		l.text = "(nenhuma)"
		box.add_child(l)
		return
	for c in BoardGrid.occupied.keys():
		var u = BoardGrid.occupied[c]
		var b := Button.new()
		b.text = "[%s] %s @ %s" % [UNIT_KEY.get(u.id, "?"), u.id, str(c)]
		b.pressed.connect(func() -> void:
			selected_unit = u
			selected_key = null
			_select(null)
			_refresh_transform_ui()
			_set_status("Personagem %s selecionado. Q/E gira; " +
					"escala no slider." % u.id))
		box.add_child(b)

## Lista clicavel de todas as pecas colocadas — reselecao garantida.
func _rebuild_placed_box() -> void:
	var box: Control = _q("placed_box")
	if box == null:
		return
	for ch in box.get_children():
		ch.free()
	if _placed.is_empty():
		var l := Label.new()
		l.text = "(nenhuma ainda)"
		box.add_child(l)
		return
	for k in _placed.keys():
		var e = _placed[k]
		var nm: String = str(e["data"].get("id",
				e["data"].get("p", "?"))).get_file()
		var b := Button.new()
		b.text = "%s @ %s" % [nm, str(k)]
		b.pressed.connect(func() -> void:
			selected_unit = null
			selected_key = k
			_select(k)
			_refresh_transform_ui()
			_set_status("Peca %s reselecionada." % nm))
		box.add_child(b)
	for m in MODES:
		var b: Control = _q("mode_" + m[0])
		if b is Button:
			b.text = ("[x] " if mode == m[0] else "[  ] ") + m[1]
	for cat in [["structure", CAT_WALLS], ["obstacle", CAT_OBSTACLES],
			["prop", CAT_PROPS], ["floor", CAT_FLOORS], ["glb", glb_list]]:
		for i in cat[1].size():
			var b: Control = _q("item_%s_%d" % [cat[0], i])
			if b is Button:
				var id = cat[1][i]
				var label: String = id.get_file() if cat[0] == "glb" else str(id)
				var mark: bool = mode == cat[0] and _active_item(cat[0]) == i
				b.text = ("[x] " if mark else "[  ] ") + label
				if _icon_cache.has(label):
					b.icon = _icon_cache[label]
	for sk in SPAWN_KEYS:
		var b: Control = _q("spawn_" + sk[0])
		if b is Button:
			var extra := ""
			if edits["spawns"].has(sk[0]):
				var v: Array = edits["spawns"][sk[0]]
				extra = " @%s,%s,%s" % [v[0], v[1], v[2]]
			b.text = ("[x] " if spawn_key == sk[0] else "[  ] ") \
					+ "Spawn " + sk[1] + extra
	var mats: Array = _mat_candidates()
	for i in mats.size():
		var mb: Control = _q("mat_%d" % i)
		if mb is Button:
			var active: bool = edits.get("mat_glb", "") == mats[i]
			mb.text = ("[x] Battlemat: " if active else "[  ] Battlemat: ") \
					+ mats[i].get_file()

func _refresh_transform_ui() -> void:
	var l: Control = _q("tf_sel")
	var e = _sel_entry()
	var has := e != null or selected_unit != null
	var hl: Control = _q("tf_h")
	if l is Label:
		if selected_unit != null:
			l.text = "personagem: %s @ %s" % [selected_unit.id,
					str(selected_unit.grid_pos)]
		else:
			l.text = "selecionado: %s em %s" % [
					e["data"].get("id", e["data"].get("p", "?")).get_file()
					if has else "-", str(selected_key) if has else "-"]
	if hl is Label:
		var t2 := ""
		if has and e != null and e["kind"] == "glb" \
				and str(e["data"].get("bhv", "")) == "top":
			var mx := 0
			for d in e["data"].get("cells", []):
				mx = maxi(mx, int(d.get("e", 0)))
			t2 = ("Altura no grid: %d degrau(s) — ate 1 degrau as " +
					"unidades sobem sozinhas") % mx
		(hl as Label).text = t2
	var bb: Control = _q("tf_bhv")
	if bb is Button:
		(bb as Button).text = "Andar: %s" % (_bhv_label(
				str(e["data"].get("bhv", "block"))) if e != null
				and e["kind"] == "glb" else "(selecione um MODELO GLB)")
	var adv: Control = _q("tf_adv")
	var show_ax: bool = adv != null and adv is CheckBox \
			and adv.button_pressed and has
	for ax in [0, 1, 2]:
		var lab: Control = _q("tf_ax%d_l" % ax)
		var sld: Control = _q("tf_ax%d" % ax)
		if lab is Label:
			lab.visible = show_ax
			lab.text = ["Eixo X", "Eixo Y (altura)", "Eixo Z"][ax]
		if sld != null:
			sld.visible = show_ax
			if has and sld is HSlider:
				sld.set_value_no_signal(e["data"].get("adv", [1, 1, 1])[ax])
	if has:
		var sld: Control = _q("tf_s")
		if sld is HSlider:
			sld.set_value_no_signal(e["data"].get("s", 1.0))
	_update_hover(_hover_cell)

# Thumbnails: mesmo principio do retrato de personagem - um SubViewport
# rende a peca uma vez; resultado vira icone do botao (sem arte 2D).
func _queue_icons() -> void:
	for cat in [CAT_WALLS, CAT_OBSTACLES, CAT_PROPS, CAT_FLOORS]:
		for id in cat:
			if not _icon_cache.has(id):
				_icon_queue.append(id)

func _process(_delta: float) -> void:
	if _icon_queue.is_empty() or not active:
		return
	var id: String = _icon_queue.pop_front()
	if not _icon_cache.has(id):
		var tex = await _render_icon_scene(id)
		if tex != null:
			_icon_cache[id] = tex
			_refresh_ui()

func _render_icon_scene(id: String) -> Texture2D:
	var piece := TilePiece.build(id)
	if piece == null:
		return null
	var vp := SubViewport.new()
	vp.size = Vector2i(72, 72)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)
	var root := Node3D.new()
	vp.add_child(root)
	root.add_child(piece)
	var st := _merge_seed()
	for m in _find_meshes(piece):
		if m is VisualInstance3D:
			var b: AABB = m.get_aabb()
			st[0] = b if not st[1] else st[0].merge(b)
			st[1] = true
	var aabb: AABB = st[0] if st[1] \
			else AABB(Vector3(-0.5, 0, -0.5), Vector3.ONE)
	if aabb.size.length() < 0.001:
		aabb = AABB(Vector3(-0.5, 0, -0.5), Vector3.ONE)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.position = aabb.get_center() + Vector3(0.9, 0.9, 1.1) \
			* aabb.size.length()
	cam.look_at(aabb.get_center())
	cam.near = 0.01
	cam.far = aabb.size.length() * 6.0
	var sun := DirectionalLight3D.new()
	root.add_child(sun)
	sun.rotation_degrees = Vector3(-45, 30, 0)
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	piece.queue_free()
	return ImageTexture.create_from_image(img)

# ------------------------------------------------------- scan de modelos ---

func _scan_glbs() -> void:
	glb_list.clear()
	var stack: Array = ["res://src/assets", "res://assets/models"]
	while not stack.is_empty():
		var dir_path: String = stack.pop_back()
		var d := DirAccess.open(dir_path)
		if d == null:
			continue
		d.list_dir_begin()
		var fn := d.get_next()
		while fn != "":
			var full := dir_path.path_join(fn)
			if d.current_is_dir():
				stack.append(full)
			elif fn.get_extension() == "glb":
				glb_list.append(full)
			fn = d.get_next()
	glb_list.sort()

## Reescaneia os .glb sem reiniciar o jogo (fluxo do game designer:
## solta arquivos novos em src/assets/editor e clica aqui).
func _reload_assets() -> void:
	var before: int = glb_list.size()
	_scan_glbs()
	if _ui != null:
		_teardown_ui()
		_build_ui()
		_refresh_ui()
		_set_status("Assets recarregados: %d modelos (%d novos). Clique num " +
				"modelo e depois numa casa do tabuleiro." %
				[glb_list.size(), glb_list.size() - before])
	else:
		EventBus.log_msg.emit("Assets: %d modelos GLB." % glb_list.size(),
				"#7fd4ff")

## adv chega como Array (JSON); Vector3 nao tem construtor de Array.
func _adv_v(d: Dictionary) -> Vector3:
	var a: Array = d.get("adv", [1, 1, 1])
	return Vector3(float(a[0]), float(a[1]), float(a[2]))

func _teardown_ui() -> void:
	if _ui != null:
		_ui.queue_free()
		_ui = null
