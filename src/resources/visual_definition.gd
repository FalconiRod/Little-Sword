extends Resource
class_name VisualDefinition
## VisualDefinition — base para qualquer visual trocável.
## Primitiva agora, GLB no futuro via model_scene.

@export var display_name: String = "Peça"
@export var primitive_color: Color = Color(0.8, 0.8, 0.8)
@export var primitive_shape: String = "box" # box | capsule | cylinder | plane
@export var model_scene: PackedScene = null # futuro GLB
@export var blocks_movement: bool = false
@export var blocks_line_of_sight: bool = false
@export var cover_bonus: int = 0 # 0=nenhuma, 2=meia, 99=total
