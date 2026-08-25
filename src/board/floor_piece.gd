extends StaticBody3D
class_name FloorPiece

@export var theme: Resource
@export var cell: Vector3i = Vector3i(0, 0, 0)

@onready var _mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var _collision: CollisionShape3D = $CollisionShape3D

const TILE: float = 2.0

func _ready() -> void:
	_apply_theme()
	_apply_transform()
	set_meta("walkable", true)
	set_meta("blocks_los", false)
	collision_layer = 1
	collision_mask = 0

func _apply_theme() -> void:
	var t: Resource = theme
	if t == null:
		t = load("res://src/resources/floor_theme.gd").new()
	var thickness: float = float(t.get("thickness")) if t.get("thickness") != null else 0.15
	var col: Color = t.get("albedo_color") as Color if t.get("albedo_color") != null else Color(0.5, 0.5, 0.5)
	var rough: float = float(t.get("roughness")) if t.get("roughness") != null else 0.9
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(TILE, thickness, TILE)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = rough
	box.material = mat
	if _mesh_instance:
		_mesh_instance.mesh = box
		_mesh_instance.position = Vector3(0, -thickness * 0.5, 0)
	if _collision:
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = Vector3(TILE, thickness, TILE)
		_collision.shape = shape
		_collision.position = Vector3(0, -thickness * 0.5, 0)

func _apply_transform() -> void:
	var world_center: Vector3 = Vector3(
		float(cell.x) * TILE + TILE * 0.5,
		0.0,
		float(cell.y) * TILE + TILE * 0.5
	)
	if has_node("/root/BoardGrid"):
		var bg: Node = get_node("/root/BoardGrid")
		if bg.has_method("grid_to_world"):
			world_center = bg.call("grid_to_world", cell) as Vector3
	global_position = world_center

func configure(new_cell: Vector3i, new_theme: Resource, rotation_steps_90: int = 0) -> void:
	cell = new_cell
	if new_theme:
		theme = new_theme
	rotation.y = deg_to_rad(float(rotation_steps_90 * 90))
	_apply_theme()
	_apply_transform()

func get_cell() -> Vector3i:
	return cell
