extends Resource
class_name PropObstacleDefinition
## Seção 4 — tabela de obstáculos

enum Type { DECOR_SMALL, LARGE, LOW_WALL, HIGH_WALL }

@export var display_name: String = "Obstáculo"
@export var type: int = Type.LARGE
@export var model_scene: PackedScene = null

func blocks_movement() -> bool:
	match type:
		Type.DECOR_SMALL: return false
		Type.LARGE: return true
		Type.LOW_WALL: return true
		Type.HIGH_WALL: return true
		_: return false

func blocks_line_of_sight() -> bool:
	match type:
		Type.DECOR_SMALL: return false
		Type.LARGE: return true
		Type.LOW_WALL: return false
		Type.HIGH_WALL: return true
		_: return false

func cover_bonus() -> int:
	match type:
		Type.DECOR_SMALL: return 0
		Type.LARGE: return 99 # total
		Type.LOW_WALL: return 2 # meia +2 CA
		Type.HIGH_WALL: return 99
		_: return 0

func primitive_color() -> Color:
	match type:
		Type.DECOR_SMALL: return Color(0.45, 0.75, 0.45) # verde claro
		Type.LARGE: return Color(0.45, 0.45, 0.48) # cinza pedra
		Type.LOW_WALL: return Color(0.78, 0.70, 0.55) # areia mureta
		Type.HIGH_WALL: return Color(0.35, 0.35, 0.40) # cinza escuro muro
		_: return Color(0.8, 0.8, 0.8)

func primitive_size() -> Vector3:
	match type:
		Type.DECOR_SMALL: return Vector3(0.6, 0.4, 0.6)
		Type.LARGE: return Vector3(1.4, 1.6, 1.4)
		Type.LOW_WALL: return Vector3(1.8, 0.9, 0.35)
		Type.HIGH_WALL: return Vector3(1.8, 2.2, 0.35)
		_: return Vector3(1, 1, 1)
