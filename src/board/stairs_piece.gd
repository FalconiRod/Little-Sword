extends Node3D
class_name StairsPiece
## Asset casa 2-3 andares — visual primitivo + link lógico StairsLink

@export var bottom_cell: Vector3i = Vector3i(4,4,0)
@export var top_cell: Vector3i = Vector3i(4,4,1)
@export var definition: Resource

@onready var _house_mesh: MeshInstance3D = $HouseMesh
@onready var _stairs_mesh: MeshInstance3D = $StairsMesh

func _ready() -> void:
	if definition == null:
		definition = load("res://src/resources/stairs_definition.gd").new()
	_apply()
	_register()

func _apply() -> void:
	var def: Resource = definition
	var col: Color = def.get("albedo_color") as Color if def.get("albedo_color") != null else Color(0.58,0.48,0.35)
	var floors: int = int(def.get("floors")) if def.get("floors") != null else 2
	var tile: float = 2.0
	var fh: float = 7.0
	# Casa: footprint 2x3 tiles (4x6 unidades), altura floors*FH + 1
	var house_size: Vector3 = Vector3(float(2)*tile, float(floors)*fh + 0.5, float(3)*tile)
	var house: BoxMesh = BoxMesh.new()
	house.size = house_size
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.85
	house.material = mat
	if _house_mesh:
		_house_mesh.mesh = house
		_house_mesh.position = Vector3(tile*0.5, house_size.y*0.5, tile)
	# Escada interna: Box inclinada 2x0.2x 7
	var stair_size: Vector3 = Vector3(1.2, fh, 1.0)
	var stair: BoxMesh = BoxMesh.new()
	stair.size = stair_size
	var mat2: StandardMaterial3D = StandardMaterial3D.new()
	mat2.albedo_color = Color(0.65,0.55,0.40)
	stair.material = mat2
	if _stairs_mesh:
		_stairs_mesh.mesh = stair
		_stairs_mesh.position = Vector3(0, fh*0.5, 0)
	# posiciona no mundo na célula base
	var base_world: Vector3 = Vector3(float(bottom_cell.x)*tile+tile*0.5, float(bottom_cell.z)*fh, float(bottom_cell.y)*tile+tile*0.5)
	global_position = base_world

func _register() -> void:
	var bg: Node = get_node_or_null("/root/BoardGrid")
	if bg and bg.has_method("add_stair_link"):
		bg.call("add_stair_link", bottom_cell, top_cell)
		print("[StairsPiece] link ", bottom_cell, " -> ", top_cell)

func get_bottom() -> Vector3i:
	return bottom_cell
func get_top() -> Vector3i:
	return top_cell
