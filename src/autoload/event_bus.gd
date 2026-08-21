extends Node
## Barramento global de sinais — desacopla sistemas (HUD, combate, turnos, IA).

signal log_msg(text: String, color: String)
signal dice_rolled(sides: int, result: int, total: int, label: String)
signal combat_message(text: String)
signal banner(text: String)
signal turn_started(unit, round_num: int)
signal turn_ended(unit)
signal round_started(round_num: int)
signal unit_damaged(unit, amount: int)
signal unit_healed(unit, amount: int)
signal unit_died(unit)
signal unit_moved(unit)
signal inventory_changed()
signal reveal_room(room_name: String)
signal shake_requested(strength: float)
signal game_over(victory: bool)
