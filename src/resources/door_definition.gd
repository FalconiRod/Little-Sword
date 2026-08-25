extends Resource
class_name DoorDefinition

enum State { CLOSED, OPEN, LOCKED }

@export var display_name: String = "Porta"
@export var initial_state: int = State.CLOSED
@export var thickness: float = 0.15
@export var height: float = 3.2
@export var width: float = 1.6
@export var color_closed: Color = Color(0.55, 0.35, 0.15)
@export var color_open: Color = Color(0.62, 0.42, 0.20)
@export var color_locked: Color = Color(0.85, 0.15, 0.15)
@export var model_scene: PackedScene = null
