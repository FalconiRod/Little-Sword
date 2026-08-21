class_name UnitDefs
## Definições de dados das miniaturas (estilo ficha de D&D).

const DEFS := {
	"knight": {
		"display_name": "Cavaleiro",
		"team": "hero",
		"max_hp": 40,
		"max_mana": 10,
		"ac": 16,
		"atk_bonus": 5,
		"dmg": "1d8+3",
		"move_max": 6,
		"attack_range": 1,
		"vision_range": 0,
		"strength": 15,
		"dexterity": 12,
		"intelligence": 10,
		"bar_h": 2.35,
	},
	"goblin_warrior": {
		"display_name": "Goblin Guerreiro",
		"team": "enemy",
		"max_hp": 15,
		"max_mana": 0,
		"ac": 10,
		"atk_bonus": 2,
		"dmg": "1d6+1",
		"move_max": 4,
		"attack_range": 1,
		"vision_range": 6,
		"strength": 10,
		"dexterity": 12,
		"intelligence": 6,
		"bar_h": 1.55,
	},
	"goblin_archer": {
		"display_name": "Goblin Arqueiro",
		"team": "enemy",
		"max_hp": 12,
		"max_mana": 0,
		"ac": 10,
		"atk_bonus": 3,
		"dmg": "1d6",
		"move_max": 3,
		"attack_range": 5,
		"vision_range": 7,
		"strength": 8,
		"dexterity": 14,
		"intelligence": 7,
		"bar_h": 1.55,
	},
	"boss_knight": {
		"display_name": "Cavaleiro Ancestral",
		"team": "enemy",
		"max_hp": 90,
		"max_mana": 0,
		"ac": 18,
		"atk_bonus": 5,
		"dmg": "1d12+4",
		"move_max": 3,
		"attack_range": 1,
		"vision_range": 9,
		"strength": 18,
		"dexterity": 10,
		"intelligence": 12,
		"bar_h": 3.15,
	},
}

static func def(id: String) -> Dictionary:
	return DEFS[id]

## Habilidade do cavaleiro (usa o sistema de dados normal).
const KNIGHT_SKILL_COST := 3
const KNIGHT_SKILL_DMG := "2d8+3"
const KNIGHT_SKILL_LABEL := "Golpe Poderoso"
