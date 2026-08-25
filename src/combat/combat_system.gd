extends Node

signal attack_resolved(attacker: Node, defender: Node, result: Dictionary)

func _get_bonus(attacker: Node) -> int:
	var def: Resource = attacker.get("definition") as Resource
	if def == null:
		return 0
	var rng: Variant = def.get("attack_range")
	var is_ranged: bool = int(rng) > 1 if rng != null else false
	var stat: int = int(def.get("dex")) if is_ranged else int(def.get("str"))
	return int((stat - 10) / 2)

func _get_cover(defender: Node) -> int:
	var cell: Vector3i = defender.get("grid_pos") as Vector3i
	var bg: Node = get_node_or_null("/root/BoardGrid")
	if bg == null:
		return 0
	# mureta adjacente dá +2 CA se atacante não estiver do mesmo lado
	# verifica vizinhos do defensor que são mureta (cover 2)
	var cover: int = 0
	for off: Vector3i in [Vector3i(1,0,0), Vector3i(-1,0,0), Vector3i(0,1,0), Vector3i(0,-1,0)]:
		var n: Vector3i = cell + off
		var d: Dictionary = bg.call("cell_data", n) as Dictionary
		if d.has("cover") and int(d.get("cover", 0)) == 2:
			cover = 2
			break
	# também verifica se há parede entre atacante e defensor (já bloqueia LOS, mas se não, dá cover?)
	return cover

func _is_flanking(attacker: Node, defender: Node) -> bool:
	var a: Vector3i = attacker.get("grid_pos") as Vector3i
	var d: Vector3i = defender.get("grid_pos") as Vector3i
	var bg: Node = get_node_or_null("/root/BoardGrid")
	if bg == null:
		return false
	# célula oposta ao atacante em relação ao defensor
	var dx: int = d.x - a.x
	var dy: int = d.y - a.y
	# normaliza para direção cardinal/diagonal
	var ox: int = d.x + sign(dx)
	var oy: int = d.y + sign(dy)
	# se dx,dy é diagonal, oposta também diagonal
	if abs(dx) <= 1 and abs(dy) <= 1 and (dx != 0 or dy != 0):
		var opposite: Vector3i = Vector3i(ox, oy, d.z)
		var ally: Node = bg.call("unit_at", opposite) as Node
		if ally and ally != attacker and ally != defender:
			var def_a: Resource = attacker.get("definition") as Resource
			var def_ally: Resource = ally.get("definition") as Resource
			if def_a and def_ally and int(def_a.get("faction")) == int(def_ally.get("faction")):
				return true
	return false

func attack(attacker: Node, defender: Node, opts: Dictionary = {}) -> Dictionary:
	var def_att: Resource = attacker.get("definition") as Resource
	var def_def: Resource = defender.get("definition") as Resource
	var ca_base: int = int(def_def.get("ca")) if def_def else 10
	var defending: bool = bool(opts.get("defending", false))
	var cover: int = _get_cover(defender)
	var extra_ca: int = cover
	if defending:
		extra_ca += 4
	if _is_flanking(attacker, defender):
		extra_ca -= 2 # flanqueio +2 para atacante = -2 CA efetivo
	var ca_eff: int = ca_base + extra_ca
	var bonus: int = _get_bonus(attacker)
	var roll: int = DiceManager.roll(20) as int
	var total: int = roll + bonus
	var is_crit: bool = (roll == 20)
	var is_fail: bool = (roll == 1)
	var hit: bool = false
	if is_crit:
		hit = true
	elif is_fail:
		hit = false
	else:
		hit = total >= ca_eff
	var dmg: int = 0
	if hit:
		# dano base 1d8 + bonus (ou 1d6 para mago)
		var is_mage: bool = String(def_att.get("display_name")).contains("Elara")
		var dice: int = 8
		if is_mage:
			dice = 6
		var base_dmg: int = DiceManager.roll(dice) as int + maxi(0, bonus)
		if is_crit:
			base_dmg *= 2
		dmg = base_dmg
		# aplica
		if defender.has_method("take_damage"):
			defender.call("take_damage", dmg)
	var result: Dictionary = {
		"roll": roll,
		"bonus": bonus,
		"total": total,
		"ca_base": ca_base,
		"ca_eff": ca_eff,
		"cover": cover,
		"flanking": _is_flanking(attacker, defender),
		"defending": defending,
		"hit": hit,
		"crit": is_crit,
		"fail": is_fail,
		"dmg": dmg,
		"defender_hp": int(defender.get("current_hp")) if defender.get("current_hp") != null else 0,
	}
	attack_resolved.emit(attacker, defender, result)
	print("[Combat] %s -> %s D20=%d+%d=%d vs CA %d (%d+%d) %s %s dmg %d HP %d" % [
		def_att.get("display_name"), def_def.get("display_name"), roll, bonus, total, ca_eff, ca_base, extra_ca,
		"CRIT! " if is_crit else "", "FALHA! " if is_fail else ("ACERTO" if hit else "ERRO"),
		dmg, result["defender_hp"]
	])
	return result

func can_attack(attacker: Node, defender: Node) -> bool:
	var a: Vector3i = attacker.get("grid_pos") as Vector3i
	var d: Vector3i = defender.get("grid_pos") as Vector3i
	if a.z != d.z:
		return false
	var def: Resource = attacker.get("definition") as Resource
	var rng: int = 1
	if def:
		var v: Variant = def.get("attack_range")
		rng = int(v) if v != null else 1
	var dist: int = maxi(abs(a.x - d.x), abs(a.y - d.y))
	if dist > rng:
		return false
	if rng == 1 and dist != 1:
		return false
	var bg: Node = get_node_or_null("/root/BoardGrid")
	if bg and rng > 1 and not bg.call("has_line_of_sight", a, d):
		return false
	return true

func check_opportunity(mover: Node, from: Vector3i, to: Vector3i, opts: Dictionary = {}) -> Array:
	if bool(opts.get("dispersar", false)):
		return []
	var bg: Node = get_node_or_null("/root/BoardGrid")
	if bg == null:
		return []
	var attackers: Array = []
	for cell_var: Variant in bg.get("occupied").keys():
		var cell: Vector3i = cell_var as Vector3i
		var unit: Node = bg.call("unit_at", cell) as Node
		if unit == null or unit == mover:
			continue
		var def_m: Resource = mover.get("definition") as Resource
		var def_u: Resource = unit.get("definition") as Resource
		if def_m and def_u and int(def_m.get("faction")) == int(def_u.get("faction")):
			continue
		# se mover estava adjacente e vai sair
		var was_adj: bool = maxi(abs(from.x - cell.x), abs(from.y - cell.y)) == 1
		var will_adj: bool = maxi(abs(to.x - cell.x), abs(to.y - cell.y)) == 1
		if was_adj and not will_adj:
			if can_attack(unit, mover):
				attackers.append(unit)
	return attackers
