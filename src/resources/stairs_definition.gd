extends Resource
class_name StairsDefinition

@export var display_name: String = "Escada Casa"
@export var floors: int = 2 # 2 ou 3 andares
@export var footprint: Vector2i = Vector2i(2, 3) # casas ocupadas no chão
@export var albedo_color: Color = Color(0.58, 0.48, 0.35)
@export var model_scene: PackedScene = null # futuro asset casa 2-3 andares
