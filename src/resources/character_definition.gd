extends Resource
class_name CharacterDefinition

enum Faction { HERO, GOBLIN, BOSS }

@export var display_name: String = "Herói"
@export var faction: int = Faction.HERO
@export var hp_max: int = 20
@export var ca: int = 12
@export var str: int = 10
@export var dex: int = 10
@export var intel: int = 10
@export var move_fixed: int = 0
@export var attack_range: int = 1
@export var skill_name: String = ""
@export var skill_desc: String = ""
@export var capsule_color: Color = Color(0.20, 0.45, 0.85)
@export var capsule_height: float = 1.8
@export var capsule_radius: float = 0.35
@export var alternate_form: Resource = null
@export var model_scene: PackedScene = null

func faction_color() -> Color:
	match faction:
		Faction.HERO: return Color(0.20, 0.45, 0.85)
		Faction.GOBLIN: return Color(0.80, 0.25, 0.22)
		Faction.BOSS: return Color(0.55, 0.25, 0.78)
		_: return capsule_color

static func create_cavaleiro() -> Resource:
	var d: Resource = load("res://src/resources/character_definition.gd").new()
	d.set("display_name", "Cavaleiro")
	d.set("faction", Faction.HERO)
	d.set("hp_max", 40)
	d.set("ca", 16)
	d.set("str", 15)
	d.set("dex", 12)
	d.set("intel", 10)
	d.set("move_fixed", 0)
	d.set("attack_range", 1)
	d.set("skill_name", "Investida")
	d.set("capsule_color", Color(0.20, 0.45, 0.85))
	return d

static func create_maga() -> Resource:
	var d: Resource = load("res://src/resources/character_definition.gd").new()
	d.set("display_name", "Maga Elara")
	d.set("faction", Faction.HERO)
	d.set("hp_max", 28)
	d.set("ca", 12)
	d.set("str", 8)
	d.set("dex", 14)
	d.set("intel", 16)
	d.set("move_fixed", 0)
	d.set("attack_range", 6)
	d.set("skill_name", "Missil Ardente")
	d.set("capsule_color", Color(0.25, 0.60, 0.85))
	return d

static func create_druida() -> Resource:
	var d: Resource = load("res://src/resources/character_definition.gd").new()
	d.set("display_name", "Druida Rowan")
	d.set("faction", Faction.HERO)
	d.set("hp_max", 32)
	d.set("ca", 13)
	d.set("str", 12)
	d.set("dex", 13)
	d.set("intel", 14)
	d.set("move_fixed", 0)
	d.set("attack_range", 1)
	d.set("skill_name", "Fúria do Urso")
	d.set("skill_desc", "Transformação temporária (troca stats/visual)")
	d.set("capsule_color", Color(0.30, 0.65, 0.35))
	var bear: Resource = load("res://src/resources/character_definition.gd").new()
	bear.set("display_name", "Rowan (Urso)")
	bear.set("faction", Faction.HERO)
	bear.set("hp_max", 38)
	bear.set("ca", 14)
	bear.set("str", 17)
	bear.set("dex", 10)
	bear.set("intel", 10)
	bear.set("attack_range", 1)
	bear.set("skill_name", "Garra")
	bear.set("capsule_color", Color(0.55, 0.42, 0.20))
	bear.set("capsule_height", 2.1)
	bear.set("capsule_radius", 0.45)
	d.set("alternate_form", bear)
	return d

static func create_goblin_guerreiro() -> Resource:
	var d: Resource = load("res://src/resources/character_definition.gd").new()
	d.set("display_name", "Goblin Guerreiro")
	d.set("faction", Faction.GOBLIN)
	d.set("hp_max", 15)
	d.set("ca", 10)
	d.set("str", 12)
	d.set("dex", 10)
	d.set("intel", 8)
	d.set("move_fixed", 4)
	d.set("attack_range", 1)
	d.set("skill_name", "Corte")
	d.set("capsule_color", Color(0.80, 0.25, 0.22))
	return d

static func create_goblin_arqueiro() -> Resource:
	var d: Resource = load("res://src/resources/character_definition.gd").new()
	d.set("display_name", "Goblin Arqueiro")
	d.set("faction", Faction.GOBLIN)
	d.set("hp_max", 12)
	d.set("ca", 10)
	d.set("str", 9)
	d.set("dex", 14)
	d.set("intel", 8)
	d.set("move_fixed", 5)
	d.set("attack_range", 6)
	d.set("skill_name", "Tiro")
	d.set("capsule_color", Color(0.85, 0.35, 0.25))
	return d

static func create_boss() -> Resource:
	var d: Resource = load("res://src/resources/character_definition.gd").new()
	d.set("display_name", "Cavaleiro Ancestral")
	d.set("faction", Faction.BOSS)
	d.set("hp_max", 95)
	d.set("ca", 18)
	d.set("str", 18)
	d.set("dex", 10)
	d.set("intel", 12)
	d.set("move_fixed", 4)
	d.set("attack_range", 1)
	d.set("skill_name", "Esmagar / Golpe Especial")
	d.set("capsule_color", Color(0.55, 0.25, 0.78))
	d.set("capsule_height", 2.4)
	d.set("capsule_radius", 0.50)
	return d
