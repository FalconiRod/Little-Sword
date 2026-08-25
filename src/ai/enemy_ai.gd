extends Node

var _alerted: Dictionary = {} # unit -> bool
var _board: Node = null

func _ready() -> void:
	add_to_group("enemy_ai")

func _get_board() -> Node:
	if _board:
		return _board
	_board = get_tree().get_first_node_in_group("board") as Node
	if _board == null and get_tree().current_scene:
		_board = get_tree().current_scene.find_child("Board", true, false) as Node
	return _board

func _is_alerted(unit: Node) -> bool:
	return bool(_alerted.get(unit, false))

func set_alerted(unit: Node, v: bool = true) -> void:
	_alerted[unit] = v
	if v:
		print("[EnemyAI] %s alertado!" % String(unit.get("definition").get("display_name")))

func alert_area(center: Vector3i, radius: int = 3) -> void:
	var bg: Node = get_node_or_null("/root/BoardGrid")
	if bg == null or _get_board() == null:
		return
	var board: Node = _get_board()
	var units: Array = board.call("get_units") as Array if board.has_method("get_units") else []
	for u: Node in units:
		var def: Resource = u.get("definition") as Resource
		if int(def.get("faction")) == 0:
			continue # herói não
		var pos: Vector3i = u.get("grid_pos") as Vector3i
		if maxi(abs(pos.x - center.x), abs(pos.y - center.y)) <= radius:
			set_alerted(u, true)

func can_see(unit: Node, target: Node) -> bool:
	var a: Vector3i = unit.get("grid_pos") as Vector3i
	var b: Vector3i = target.get("grid_pos") as Vector3i
	if a.z != b.z:
		return false
	var bg: Node = get_node_or_null("/root/BoardGrid")
	if bg == null:
		return false
	var dist: int = maxi(abs(a.x - b.x), abs(a.y - b.y))
	if dist > 6:
		return false
	return bool(bg.call("has_line_of_sight", a, b))

func take_turn(unit: Node) -> void:
	print("[EnemyAI] turno de ", String(unit.get("definition").get("display_name")), " pos ", unit.get("grid_pos"))
	# vigília: se não alertado, checa visão
	if not _is_alerted(unit):
		var heroes: Array = _get_heroes()
		for h: Node in heroes:
			if can_see(unit, h):
				set_alerted(unit, true)
				print("[EnemyAI] avistou ", String(h.get("definition").get("display_name")))
				break
		if not _is_alerted(unit):
			print("[EnemyAI] em vigília, passa vez")
			await get_tree().create_timer(0.6).timeout
			_next()
			return
	# alertado: tenta atacar se adjacente, senão persegue via BFS
	var target: Node = _closest_hero(unit)
	if target == null:
		await get_tree().create_timer(0.4).timeout
		_next()
		return
	if _can_attack(unit, target):
		print("[EnemyAI] ataca ", String(target.get("definition").get("display_name")))
		var combat: Node = get_node_or_null("/root/CombatSystem")
		if combat == null:
			combat = get_tree().get_first_node_in_group("combat") as Node
		if combat and combat.has_method("attack"):
			combat.call("attack", unit, target, {})
			# se matou, não prossegue
			if int(target.get("current_hp")) <= 0:
				print("[EnemyAI] %s morto!" % String(target.get("definition").get("display_name")))
		await get_tree().create_timer(0.5).timeout
		_next()
		return
	# persegue
	var steps: int = int(unit.get("definition").get("move_fixed")) if unit.get("definition").get("move_fixed") != null else 4
	var bg: Node = get_node_or_null("/root/BoardGrid")
	var reach: Dictionary = bg.call("compute_reachable", unit.get("grid_pos"), steps, false) as Dictionary
	var best: Vector3i = _best_step_toward(target, reach)
	if best != unit.get("grid_pos"):
		print("[EnemyAI] move para ", best)
		var path: Array = bg.call("path_from_reachable", reach, best) as Array
		var mover: Node = get_tree().get_first_node_in_group("movement") as Node
		if mover == null:
			mover = get_node_or_null("/root/MovementManager")
			if mover == null:
				mover = get_tree().current_scene.find_child("MovementManager", true, false) as Node
		if mover and mover.has_method("move_unit"):
			mover.call("move_unit", unit, path)
			await mover.movement_finished
		else:
			# fallback instantâneo
			unit.set("grid_pos", best)
			bg.call("place", unit, best)
	else:
		print("[EnemyAI] sem caminho")
	await get_tree().create_timer(0.3).timeout
	_next()

func _next() -> void:
	var tm: Node = get_node_or_null("/root/TurnManager")
	if tm == null:
		tm = get_tree().get_first_node_in_group("turn_manager") as Node
	if tm and tm.has_method("next_turn"):
		tm.call("next_turn")

func _get_heroes() -> Array:
	var board: Node = _get_board()
	if board == null:
		return []
	var units: Array = board.call("get_units") as Array if board.has_method("get_units") else []
	var out: Array = []
	for u: Node in units:
		var def: Resource = u.get("definition") as Resource
		if int(def.get("faction")) == 0 and int(u.get("current_hp")) > 0:
			out.append(u)
	return out

func _closest_hero(unit: Node) -> Node:
	var heroes: Array = _get_heroes()
	var best: Node = null
	var best_dist: int = 999
	var pos: Vector3i = unit.get("grid_pos") as Vector3i
	for h: Node in heroes:
		var hp: Vector3i = h.get("grid_pos") as Vector3i
		var d: int = maxi(abs(pos.x - hp.x), abs(pos.y - hp.y))
		if d < best_dist:
			best_dist = d
			best = h
	return best

func _can_attack(unit: Node, target: Node) -> bool:
	var combat: Node = get_node_or_null("/root/CombatSystem")
	if combat and combat.has_method("can_attack"):
		return bool(combat.call("can_attack", unit, target))
	var a: Vector3i = unit.get("grid_pos") as Vector3i
	var b: Vector3i = target.get("grid_pos") as Vector3i
	return maxi(abs(a.x - b.x), abs(a.y - b.y)) == 1

func _best_step_toward(target: Node, reach: Dictionary) -> Vector3i:
	var best: Vector3i = Vector3i(0,0,0)
	var best_dist: int = 999
	var tpos: Vector3i = target.get("grid_pos") as Vector3i
	var dist: Dictionary = reach["dist"] as Dictionary
	for cell_var: Variant in dist.keys():
		var cell: Vector3i = cell_var as Vector3i
		var d: int = maxi(abs(cell.x - tpos.x), abs(cell.y - tpos.y))
		if d < best_dist:
			# prefere mais perto e com LOS
			best_dist = d
			best = cell
	if best == Vector3i(0,0,0) and dist.size() > 0:
		best = (dist.keys()[0] as Vector3i)
	return best

func on_attacked(attacker: Node, victim: Node) -> void:
	if victim:
		set_alerted(victim, true)
		alert_area(victim.get("grid_pos") as Vector3i, 4)
