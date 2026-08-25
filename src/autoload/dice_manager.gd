extends Node

func roll(sides: int) -> int:
	return randi_range(1, sides)

func roll_d6() -> int:
	return roll(6)

func hero_steps_from_roll(roll: int) -> int:
	# 1-2 = 3 casas, 3-6 = 6 casas
	if roll <= 2:
		return 3
	return 6

func roll_hero_movement() -> Dictionary:
	var r: int = roll_d6()
	var steps: int = hero_steps_from_roll(r)
	return {"roll": r, "steps": steps}

func enemy_steps(definition: Resource) -> int:
	if definition and definition.get("move_fixed") != null:
		return int(definition.get("move_fixed"))
	return 4

func parse_ndm(expr: String) -> Dictionary:
	# "2d6+3" etc — simples
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
	for i: int in range(n):
		total += roll(m)
	return total
