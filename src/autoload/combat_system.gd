extends Node
## Sistema de combate: D20 + modificador vs Classe de Armadura,
## críticos naturais, dano por notação de dados e ação Defender.

func attack(attacker, target, skill_label := "", skill_dmg := "", fx := "", transform_to := "") -> void:
	var is_skill := skill_dmg != ""
	# O atacante vira a peça para o alvo antes do golpe.
	attacker.face_towards(target.global_position)
	if transform_to != "":
		attacker.set_visual_id(transform_to)
		EventBus.log_msg.emit("%s invoca a forma selvagem!" % attacker.display_name, "#9dff6b")
		attacker.spawn_float_text("FORMA SELVAGEM!", "#9dff6b")
		EventBus.shake_requested.emit(0.2)
		await get_tree().create_timer(0.4).timeout
	EventBus.combat_message.emit("%s → %s" % [attacker.display_name, target.display_name])
	var chk: Dictionary = DiceManager.d20_check(attacker.atk_bonus, target.effective_ac())
	var label := skill_label if is_skill else "Ataque"
	EventBus.dice_rolled.emit(20, chk["roll"], chk["total"], "%s — %s" % [label, attacker.display_name])
	if fx == "projectile_red":
		EventBus.log_msg.emit("Um projétil flamejante cruza o ar!", "#ff6b6b")
		await get_tree().create_timer(0.55).timeout
		await _fire_projectile(attacker, target)
	else:
		await get_tree().create_timer(1.05).timeout
	if TurnManager.game_ended:
		return
	# A investida acompanha a resolucao (ataques corpo a corpo apenas).
	if fx != "projectile_red":
		attacker.animate_lunge(target.global_position)
	_alert_victims(target)
	var tgt_ac: int = target.effective_ac()
	if chk["hit"]:
		var nota: String = skill_dmg if is_skill else attacker.dmg
		if chk["crit"]:
			nota = DiceManager.double_dice(nota)
		var dmg := DiceManager.roll_notation(nota)
		dmg += attacker.dmg_bonus
		# Runas mágicas do chão amplificam golpes de quem está sobre elas.
		if BoardGrid.special.get(attacker.grid_pos, "") == "r":
			dmg += 2
			EventBus.log_msg.emit("As runas amplificam o golpe! (+2)", "#37e0ff")
		target.take_damage(dmg)
		# Impacto fisico: alvo recua e solta faiscas (mais fortes em critico).
		target.last_striker = attacker
		target.animate_recoil(attacker.global_position)
		_sparks(target.global_position + Vector3(0, 0.8, 0),
				"#ff9f43" if chk["crit"] else "#ffd166",
				26 if chk["crit"] else 14)
		if chk["crit"]:
			EventBus.log_msg.emit("ACERTO CRÍTICO! %s causa %d de dano (%d vs CA %d)." % [attacker.display_name, dmg, chk["total"], tgt_ac], "#ffd166")
			EventBus.shake_requested.emit(0.5)
		else:
			EventBus.log_msg.emit("%s acerta %d de dano (%d vs CA %d)." % [attacker.display_name, dmg, chk["total"], tgt_ac], "#e8e2d0")
			EventBus.shake_requested.emit(0.22)
	else:
		target.spawn_float_text("MISS", "#b8c0cc")
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

## Projétil mágico: esfera vermelha brilhante voa do conjurador ao alvo.
func _fire_projectile(from_unit, target) -> void:
	var p := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.16
	s.height = 0.32
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.html("ff3b30")
	m.emission_enabled = true
	m.emission = Color.html("ff5544")
	m.emission_energy_multiplier = 3.5
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p.mesh = s
	p.material_override = m
	add_child(p)
	p.position = from_unit.global_position + Vector3(0, 1.3, 0)
	var b: Vector3 = target.global_position + Vector3(0, 0.85, 0)
	var tw := create_tween()
	tw.tween_property(p, "position", b, 0.34) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	_sparks(b, "ff5544", 18)
	p.queue_free()

## Explosao curta de faiscas procedurais no ponto do impacto.
func _sparks(wp: Vector3, col_hex: String, amount: int) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.5
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 75.0
	p.initial_velocity_min = 2.2
	p.initial_velocity_max = 4.6
	p.gravity = Vector3(0, -10, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var mesh := SphereMesh.new()
	mesh.radius = 0.055
	mesh.height = 0.11
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.html(col_hex)
	m.emission_enabled = true
	m.emission = Color.html(col_hex)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = m
	p.mesh = mesh
	add_child(p)
	p.position = wp
	p.emitting = true
	p.finished.connect(p.queue_free)
