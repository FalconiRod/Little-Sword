extends Resource
class_name FloorTheme
## FloorTheme — definição visual de um tema de chão (Resource).
## Nesta fase: cor sólida por tema. Futuro: aponta para model_scene (.glb).
## Arquitetura deixa troca trivial: todo visual referenciado por Resource.

@export var theme_name: String = "Grama"
@export var albedo_color: Color = Color(0.35, 0.65, 0.32) # verde grama
@export var roughness: float = 0.9
@export var thickness: float = 0.15  # espessura do BoxMesh achatado

## Futuro GLB (não usar agora, só deixar preparado):
@export var model_scene: PackedScene = null # quando GLB chegar, apontar aqui

## Cor identificadora para UI do editor
@export var editor_chip_color: Color = Color(0.35, 0.65, 0.32)
