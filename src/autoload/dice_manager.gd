extends Node

signal roll_done(sides: int, result: int, is_crit: bool, is_fail: bool, label: String)

func roll(sides: int) -> int:
	return randi_range(1, sides)

func roll_d4() -> int: return roll(4)
func roll_d6() -> int: return roll(6)
func roll_d8() -> int: return roll(8)
func roll_d12() -> int: return roll(12)
func roll_d20() -> int: return roll(20)
func roll_d100() -> int: return roll(100)

func roll_with_label(sides: int, label: String = "") -> Dictionary:
	var r: int = roll(sides)
	var is_crit: bool = (sides == 20 and r == 20)
	var is_fail: bool = (sides == 20 and r == 1)
	roll_done.emit(sides, r, is_crit, is_fail, label)
	_show_popup(sides, r, is_crit, is_fail, label)
	return {"roll": r, "crit": is_crit, "fail": is_fail}

func _show_popup(sides: int, r: int, is_crit: bool, is_fail: bool, label: String) -> void:
	var hud: Node = get_tree().get_first_node_in_group("hud") as Node
	if hud and hud.has_method("show_dice"):
		hud.call("show_dice", sides, r, is_crit, is_fail, label)
	else:
		# fallback: print
		var txt: String = "D%d=%d %s" % [sides, r, label]
		if is_crit:
			txt += " CRIT!"
		if is_fail:
			txt += " FALHA!"
		print("[Dice] ", txt)

func hero_steps_from_roll(roll: int) -> int:
	if roll <= 2:
		return 3
	return 6

func roll_hero_movement() -> Dictionary:
	var r: int = roll_d6()
	var steps: int = hero_steps_from_roll(r)
	roll_with_label(6, "Movimento")
	return {"roll": r, "steps": steps}

func enemy_steps(definition: Resource) -> int:
	if definition and definition.get("move_fixed") != null:
		return int(definition.get("move_fixed"))
	return 4

func parse_ndm(expr: String) -> Dictionary:
	var s: String = expr.strip_edges().to_lower()
	var parts: PackedStringArray = s.split("d")
	if parts.size() != 2:
		return {"n":1, "m":6, "k":0}
	var n: int = int(parts[0]) if parts[0] != "" else 1
	var rest: String = parts[1]
	var k: int = 0
	var m: int = 6
	if rest.contains("+"):
		var p: PackedStringArray = rest.split("+")
		m = int(p[0])
		k = int(p[1])
	elif rest.contains("-"):
		var p: PackedStringArray = rest.split("-")
		m = int(p[0])
		k = -int(p[1])
	else:
		m = int(rest)
	return {"n":n, "m":m, "k":k}

func roll_expr(expr: String) -> int:
	var d: Dictionary = parse_ndm(expr)
	var n: int = d["n"] as int
	var m: int = d["m"] as int
	var k: int = d["k"] as int
	var total: int = k
	var rolls: Array = []
	for i: int in range(n):
		var r: int = roll(m)
		rolls.append(r)
		total += r
	roll_done.emit(m, total, false, false, expr)
	_show_popup(m, total, false, false, expr)
	return total
