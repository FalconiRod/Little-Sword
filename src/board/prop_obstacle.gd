extends StaticBody3D
class_name PropObstacle

@export var definition: Resource
@export var cell: Vector3i = Vector3i(0,0,0)

@onready var _mesh: MeshInstance3D = $MeshInstance3D
@onready var _col: CollisionShape3D = $CollisionShape3D

func _ready() -> void:
	if definition == null:
		var d: Resource = load("res://src/resources/prop_obstacle_definition.gd").new()
		d.set("type", 1)
		definition = d
	_apply()
	# metas independentes
	var blocks_mov: bool = bool(definition.call("blocks_movement")) if definition.has_method("blocks_movement") else false
	var blocks_los: bool = bool(definition.call("blocks_line_of_sight")) if definition.has_method("blocks_line_of_sight") else false
	set_meta("walkable", not blocks_mov)
	set_meta("blocks_los", blocks_los)
	set_meta("cover_bonus", int(definition.call("cover_bonus")) if definition.has_method("cover_bonus") else 0)
	collision_layer = 1 if not blocks_mov else 2
	# se decorativo pequeno, sem colisão; senão layer 2 para bake e LOS
	if not blocks_mov and not blocks_los:
		collision_layer = 0
		if _col:
			_col.disabled = true
	else:
		if _col:
			_col.disabled = false

func _apply() -> void:
	var def: Resource = definition
	var col: Color = def.call("primitive_color") as Color if def.has_method("primitive_color") else Color(0.5,0.5,0.5)
	var sz: Vector3 = def.call("primitive_size") as Vector3 if def.has_method("primitive_size") else Vector3(1,1,1)
	var blocked: bool = bool(def.call("blocks_movement")) if def.has_method("blocks_movement") else false
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = sz
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.9
	mesh.material = mat
	if _mesh:
		_mesh.mesh = mesh
		_mesh.position = Vector3(0, sz.y*0.5, 0)
	if _col:
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = sz
		_col.shape = shape
		_col.position = Vector3(0, sz.y*0.5, 0)
		_col.disabled = not blocked and not bool(def.call("blocks_line_of_sight"))
	var tile: float = 2.0
	var fh: float = 7.0
	if has_node("/root/BoardGrid"):
		var bg: Node = get_node("/root/BoardGrid")
		if bg.has_method("grid_to_world"):
			global_position = bg.call("grid_to_world", cell) as Vector3
			return
	global_position = Vector3(float(cell.x)*tile + tile*0.5, float(cell.z)*fh, float(cell.y)*tile + tile*0.5)
