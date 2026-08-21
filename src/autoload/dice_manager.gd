extends Node
## Sistema de dados completo: D4 D6 D8 D10 D12 D20 + notação estilo D&D.

func roll(sides: int, count: int = 1) -> int:
	var total := 0
	for i in count:
		total += randi_range(1, sides)
	return total

## Rola uma notação tipo "1d8+3", "2d6", "1d12-2".
func roll_notation(notation: String) -> int:
	var s := notation.replace(" ", "").to_lower()
	if s.is_empty():
		return 0
	var bonus := 0
	var dice_part := s
	if "+" in s:
		var parts := s.split("+")
		dice_part = parts[0]
		bonus = int(parts[1])
	elif s.find("-", 1) > 0:
		var idx := s.find("-", 1)
		dice_part = s.substr(0, idx)
		bonus = -int(s.substr(idx + 1))
	var cd := dice_part.split("d")
	var count := 1
	if cd[0] != "":
		count = int(cd[0])
	var sides := int(cd[1])
	return roll(sides, count) + bonus

## "1d8+3" vira "2d8+3" (crítico dobra os dados, não o modificador).
func double_dice(notation: String) -> String:
	var s := notation.replace(" ", "")
	var bonus_txt := ""
	var dice_part := s
	if "+" in s:
		var parts := s.split("+")
		dice_part = parts[0]
		bonus_txt = "+" + parts[1]
	elif s.find("-", 1) > 0:
		var idx := s.find("-", 1)
		dice_part = s.substr(0, idx)
		bonus_txt = "-" + s.substr(idx + 1)
	var cd := dice_part.split("d")
	var count := int(cd[0]) * 2
	return "%dd%s%s" % [count, cd[1], bonus_txt]

## Teste de ataque D20: natural 20 acerta sempre e é crítico;
## natural 1 falha sempre.
func d20_check(bonus: int, target_ac: int) -> Dictionary:
	var r := randi_range(1, 20)
	var total := r + bonus
	var crit := r == 20
	var fumble := r == 1
	var hit := crit or (not fumble and total >= target_ac)
	return {"roll": r, "total": total, "crit": crit, "fumble": fumble, "hit": hit}
