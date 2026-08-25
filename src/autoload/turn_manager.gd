extends Node

signal turn_changed(unit: Node, team: String)
signal round_ended(round: int)

var order: Array = []
var current_idx: int = 0
var round_num: int = 1
var _board: Node = null

func setup(board: Node) -> void:
	_board = board
	_build_order()
	current_idx = 0
	round_num = 1
	if order.size() > 0:
		turn_changed.emit(order[current_idx], _team_of(order[current_idx]))

func _build_order() -> void:
	order.clear()
	if _board == null:
		_board = get_tree().get_first_node_in_group("board") as Node
		if _board == null and get_tree().current_scene:
			_board = get_tree().current_scene.find_child("Board", true, false) as Node
	if _board == null:
		return
	var units: Array = _board.call("get_units") as Array if _board.has_method("get_units") else []
	# separa heróis e inimigos, ordena por DEX desc dentro de cada time
	var heroes: Array = []
	var enemies: Array = []
	for u: Node in units:
		var def: Resource = u.get("definition") as Resource
		if def == null:
			continue
		if int(def.get("faction")) == 0: # HERO
			heroes.append(u)
		else:
			enemies.append(u)
	heroes.sort_custom(func(a: Node, b: Node) -> bool: return int(a.get("definition").get("dex")) > int(b.get("definition").get("dex")))
	enemies.sort_custom(func(a: Node, b: Node) -> bool: return int(a.get("definition").get("dex")) > int(b.get("definition").get("dex")))
	for h: Node in heroes:
		order.append(h)
	for e: Node in enemies:
		order.append(e)
	print("[TurnManager] ordem ", order.map(func(u: Node) -> String: return String(u.get("definition").get("display_name"))))

func _team_of(unit: Node) -> String:
	var def: Resource = unit.get("definition") as Resource
	if def == null:
		return "neutral"
	match int(def.get("faction")):
		0: return "heroes"
		1: return "goblins"
		2: return "boss"
		_: return "neutral"

func current_unit() -> Node:
	if order.is_empty():
		return null
	return order[current_idx] as Node

func current_team() -> String:
	var u: Node = current_unit()
	if u == null:
		return ""
	return _team_of(u)

func next_turn() -> void:
	if order.is_empty():
		return
	# reverte transformação druida no início do turno dele (se era urso, volta)
	var next_idx: int = (current_idx + 1) % order.size()
	if next_idx == 0:
		round_num += 1
		round_ended.emit(round_num)
	var next_unit: Node = order[next_idx] as Node
	if next_unit and next_unit.has_method("revert_if_transformed"):
		next_unit.call("revert_if_transformed")
	current_idx = next_idx
	var team: String = _team_of(next_unit)
	print("[TurnManager] turno %d/%d: %s (%s)" % [current_idx+1, order.size(), next_unit.get("definition").get("display_name"), team])
	turn_changed.emit(next_unit, team)
	# se for inimigo, dispara AI
	if team != "heroes":
		_trigger_enemy_ai(next_unit)

func _trigger_enemy_ai(unit: Node) -> void:
	var ai: Node = get_node_or_null("/root/EnemyAI")
	if ai == null:
		ai = get_tree().get_first_node_in_group("enemy_ai") as Node
	if ai and ai.has_method("take_turn"):
		ai.call("take_turn", unit)
	else:
		# fallback: passa vez após 0.5s
		await get_tree().create_timer(0.5).timeout
		next_turn()

func remove_dead(unit: Node) -> void:
	var idx: int = order.find(unit)
	if idx != -1:
		order.remove_at(idx)
		if current_idx >= order.size():
			current_idx = 0
		if order.size() == 0:
			print("[TurnManager] fim — todos mortos?")

func is_hero_turn() -> bool:
	return current_team() == "heroes"
