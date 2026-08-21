extends Node
## Inventário e equipamento do herói.

const ITEMS := {
	"health_potion": {"name": "Poção de Vida", "type": "consumable", "desc": "Recupera 15 PV", "heal": 15},
	"ancient_sword": {"name": "Espada Ancestral", "type": "weapon", "desc": "+1 Ataque", "atk": 1},
	"dark_armor": {"name": "Armadura do Cavaleiro Sombrio", "type": "armor", "desc": "Proteção pesada", "ac": 0},
	"defense_ring": {"name": "Anel de Defesa", "type": "accessory", "desc": "+2 CA", "ac": 2},
}

const SLOT_NAMES := {"weapon": "Arma", "armor": "Armadura", "accessory": "Acessório"}

var potions := 2
var equipped := {"weapon": "ancient_sword", "armor": "dark_armor", "accessory": ""}
var storage: Array = ["defense_ring"]

func reset() -> void:
	potions = 2
	equipped = {"weapon": "ancient_sword", "armor": "dark_armor", "accessory": ""}
	storage = ["defense_ring"]

func ac_bonus() -> int:
	var total := 0
	for slot in equipped:
		var id: String = equipped[slot]
		if id != "" and ITEMS.has(id) and ITEMS[id].has("ac"):
			total += ITEMS[id]["ac"]
	return total

func atk_bonus() -> int:
	var total := 0
	for slot in equipped:
		var id: String = equipped[slot]
		if id != "" and ITEMS.has(id) and ITEMS[id].has("atk"):
			total += ITEMS[id]["atk"]
	return total

func apply_to_unit(u) -> void:
	u.ac = u.base_ac + ac_bonus()
	u.atk_bonus += 0

func equip(item_id: String) -> void:
	if not ITEMS.has(item_id):
		return
	var item: Dictionary = ITEMS[item_id]
	var t: String = item["type"]
	if t == "consumable":
		return
	# Devolve o item atual da vaga para a mochila.
	var current: String = equipped.get(t, "")
	if current != "":
		storage.append(current)
	equipped[t] = item_id
	storage.erase(item_id)
	EventBus.inventory_changed.emit()
	EventBus.log_msg.emit("Equipado: %s." % item["name"], "#ffd166")

func unequip(slot: String) -> void:
	var id: String = equipped.get(slot, "")
	if id == "" or not ITEMS.has(id):
		return
	equipped[slot] = ""
	storage.append(id)
	EventBus.inventory_changed.emit()
	EventBus.log_msg.emit("Guardado: %s." % ITEMS[id]["name"], "#c9b26a")

func use_potion(u) -> bool:
	if potions <= 0:
		return false
	potions -= 1
	u.heal(ITEMS["health_potion"]["heal"])
	EventBus.log_msg.emit("%s bebe uma Poção de Vida." % u.display_name, "#6bff8f")
	EventBus.inventory_changed.emit()
	return true

func add_potions(n: int) -> void:
	potions += n
	EventBus.inventory_changed.emit()
