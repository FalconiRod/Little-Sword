extends Node
## Sistema de combate: D20 + modificador vs Classe de Armadura,
## críticos naturais, dano por notação de dados e ação Defender.

func attack(attacker, target, skill_label := "", skill_dmg := "") -> void:
	var is_skill := skill_dmg != ""
	# O atacante vira a peça para o alvo antes do golpe.
	attacker.face_towards(target.global_position)
	EventBus.combat_message.emit("%s → %s" % [attacker.display_name, target.display_name])
	var chk: Dictionary = DiceManager.d20_check(attacker.atk_bonus, target.effective_ac())
	var label := skill_label if is_skill else "Ataque"
	EventBus.dice_rolled.emit(20, chk["roll"], chk["total"], "%s — %s" % [label, attacker.display_name])
	await get_tree().create_timer(1.05).timeout
	if TurnManager.game_ended:
		return
	_alert_victims(target)
	var tgt_ac: int = target.effective_ac()
	if chk["hit"]:
		var nota: String = skill_dmg if is_skill else attacker.dmg
		if chk["crit"]:
			nota = DiceManager.double_dice(nota)
		var dmg := DiceManager.roll_notation(nota)
		# Runas mágicas do chão amplificam golpes de quem está sobre elas.
		if BoardGrid.special.get(attacker.grid_pos, "") == "r":
			dmg += 2
			EventBus.log_msg.emit("As runas amplificam o golpe! (+2)", "#37e0ff")
		target.take_damage(dmg)
		if chk["crit"]:
			EventBus.log_msg.emit("ACERTO CRÍTICO! %s causa %d de dano (%d vs CA %d)." % [attacker.display_name, dmg, chk["total"], tgt_ac], "#ffd166")
			EventBus.shake_requested.emit(0.5)
		else:
			EventBus.log_msg.emit("%s acerta %d de dano (%d vs CA %d)." % [attacker.display_name, dmg, chk["total"], tgt_ac], "#e8e2d0")
			EventBus.shake_requested.emit(0.22)
	else:
		if chk["fumble"]:
			EventBus.log_msg.emit("FALHA CRÍTICA! %s erra o golpe." % attacker.display_name, "#ff6b6b")
		else:
			EventBus.log_msg.emit("%s errou (%d vs CA %d)." % [attacker.display_name, chk["total"], tgt_ac], "#9aa0ad")

func defend(u) -> void:
	u.defending = true
	EventBus.log_msg.emit("%s ergue a guarda (+4 CA até seu próximo turno)." % u.display_name, "#7fd1ff")

## Atacar ou ser atacado desperta: o alvo e aliados próximos entram em combate.
func _alert_victims(target) -> void:
	if target == null or not is_instance_valid(target) or not target.alive:
		return
	if target.team != "enemy" or target.alerted:
		return
	target.alerted = true
	for c in BoardGrid.occupied.keys():
		var ally = BoardGrid.occupied[c]
		if is_instance_valid(ally) and ally.alive and ally.team == "enemy" and ally != target:
			if BoardGrid.chebyshev(c, target.grid_pos) <= 2:
				ally.alerted = true
	EventBus.log_msg.emit("%s entra em combate!" % target.display_name, "#ffb84d")
