extends Node
## Sistema de combate: D20 + modificador vs Classe de Armadura,
## críticos naturais, dano por notação de dados e ação Defender.

func attack(attacker, target, skill_label := "", skill_dmg := "") -> void:
	var is_skill := skill_dmg != ""
	EventBus.combat_message.emit("%s → %s" % [attacker.display_name, target.display_name])
	var chk: Dictionary = DiceManager.d20_check(attacker.atk_bonus, target.effective_ac())
	var label := skill_label if is_skill else "Ataque"
	EventBus.dice_rolled.emit(20, chk["roll"], chk["total"], "%s — %s" % [label, attacker.display_name])
	await get_tree().create_timer(1.05).timeout
	if TurnManager.game_ended:
		return
	var tgt_ac: int = target.effective_ac()
	if chk["hit"]:
		var nota: String = skill_dmg if is_skill else attacker.dmg
		if chk["crit"]:
			nota = DiceManager.double_dice(nota)
		var dmg := DiceManager.roll_notation(nota)
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
