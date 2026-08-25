extends Resource
class_name WallDefinition
## WallDefinition — parede na BORDA da célula (Seção 4)
## Fina 0.2 x 3.5 altura, compartilhada entre duas células, nunca duplicada.

@export var display_name: String = "Parede"
@export var thickness: float = 0.2
@export var height: float = 3.5
@export var albedo_color: Color = Color(0.68, 0.64, 0.58)
@export var roughness: float = 0.9
@export var model_scene: PackedScene = null # futuro GLB
