extends StaticBody3D
class_name ColumnPiece

@export var definition: Resource
@export var cell: Vector3i = Vector3i(0,0,0)

@onready var _mesh: MeshInstance3D = $MeshInstance3D
@onready var _col: CollisionShape3D = $CollisionShape3D

func _ready() -> void:
	if definition == null:
		definition = load("res://src/resources/column_definition.gd").new()
	_apply()
	set_meta("walkable", false)
	set_meta("blocks_los", true)
	collision_layer = 2
	collision_mask = 0

func _apply() -> void:
	var def: Resource = definition
	var r: float = float(def.get("radius")) if def.get("radius") != null else 0.22
	var h: float = float(def.get("height")) if def.get("height") != null else 3.5
	var col: Color = def.get("albedo_color") as Color if def.get("albedo_color") != null else Color(0.72,0.72,0.70)
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = r
	cyl.bottom_radius = r
	cyl.height = h
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = col
	cyl.material = mat
	if _mesh:
		_mesh.mesh = cyl
		_mesh.position = Vector3(0, h*0.5, 0)
	if _col:
		var shape: CylinderShape3D = CylinderShape3D.new()
		shape.radius = r
		shape.height = h
		_col.shape = shape
		_col.position = Vector3(0, h*0.5, 0)
	var tile: float = 2.0
	var fh: float = 7.0
	if has_node("/root/BoardGrid"):
		var bg: Node = get_node("/root/BoardGrid")
		if bg.has_method("grid_to_world"):
			global_position = bg.call("grid_to_world", cell) as Vector3
			return
	global_position = Vector3(float(cell.x)*tile + tile*0.5, float(cell.z)*fh, float(cell.y)*tile + tile*0.5)
