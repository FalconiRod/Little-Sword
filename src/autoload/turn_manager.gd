extends Node
## Gerenciador de turnos: ordem fixa de iniciativa, rodadas e
## rolagem de movimento do herói (regra D6: 1-2 = movimento baixo).

var order: Array = []
var idx := -1
var round_num := 0
var active = null
var game_ended := false

var _ctl = null
var _ai = null

func setup(units: Array, controller, ai_node) -> void:
	order = units.duplicate()
	_ctl = controller
	_ai = ai_node
	EventBus.unit_died.connect(_on_unit_died)

func start_game() -> void:
	game_ended = false
	round_num = 1
	EventBus.log_msg.emit("Você entra na masmorra...", "#c9a227")
	_advance(true)

func reset() -> void:
	order = []
	idx = -1
	round_num = 0
	active = null
	game_ended = false

func _advance(first := false) -> void:
	if game_ended:
		return
	while true:
		if first:
			idx = 0
			first = false
		else:
			idx += 1
		if idx >= order.size():
			idx = 0
			round_num += 1
			EventBus.round_started.emit(round_num)
			EventBus.log_msg.emit("— Rodada %d —" % round_num, "#c9a227")
		var u = order[idx]
		if is_instance_valid(u) and u.alive:
			break
	active = order[idx]
	active.defending = false
	EventBus.turn_started.emit(active, round_num)
	if active.team == "hero":
		_hero_turn(active)
	else:
		_enemy_turn(active)

func _hero_turn(u) -> void:
	u.moves_left = 0
	var r := DiceManager.roll(6)
	# Regra da casa: D6 — 1-2 movimento baixo (metade), 3-6 movimento cheio.
	u.moves_left = 3 if r <= 2 else u.move_max
	u.mana = mini(u.max_mana, u.mana + 2)
	EventBus.dice_rolled.emit(6, r, u.moves_left, "Movimento do Cavaleiro")
	if r <= 2:
		EventBus.log_msg.emit("Movimento reduzido! (%d casas)" % u.moves_left, "#ffb84d")
	else:
		EventBus.log_msg.emit("Movimento completo: %d casas." % u.moves_left, "#9fd8ff")
	_ctl.on_turn_start(u)

func _enemy_turn(u) -> void:
	u.moves_left = u.move_max
	await get_tree().create_timer(0.55).timeout
	if game_ended:
		return
	await _ai.run_turn(u)
	if game_ended:
		return
	await get_tree().create_timer(0.35).timeout
	_advance()

## Chamado pelo controlador do jogador ao usar ação / passar a vez.
func end_hero_turn() -> void:
	if game_ended or active == null:
		return
	EventBus.turn_ended.emit(active)
	_ctl.on_turn_end()
	await get_tree().create_timer(0.3).timeout
	_advance()

func _on_unit_died(u) -> void:
	if game_ended or not started_game():
		return
	if u.team == "hero":
		_finish(false)
		return
	for x in order:
		if is_instance_valid(x) and x.alive and x.team == "enemy":
			return
	_finish(true)

func started_game() -> bool:
	return order.size() > 0

func _finish(victory: bool) -> void:
	if game_ended:
		return
	game_ended = true
	await get_tree().create_timer(0.9).timeout
	EventBus.game_over.emit(victory)
