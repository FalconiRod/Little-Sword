extends StaticBody3D
class_name WallPiece
## Parede na BORDA da célula (não no centro). Compartilhada entre 2 células.

@export var definition: Resource
@export var edge_cell: Vector3i = Vector3i(0, 0, 0)
@export var edge_dir: String = "north" # north/south/east/west

@onready var _mesh: MeshInstance3D = $MeshInstance3D
@onready var _col: CollisionShape3D = $CollisionShape3D

const TILE: float = 2.0

func _ready() -> void:
	if definition == null:
		definition = load("res://src/resources/wall_definition.gd").new()
	_apply()
	set_meta("walkable", false)
	set_meta("blocks_los", true)
	collision_layer = 2 # paredes layer 2 (SpringArm mask 2 colide aqui)
	collision_mask = 0

func _apply() -> void:
	var def: Resource = definition
	var thick: float = float(def.get("thickness")) if def.get("thickness") != null else 0.2
	var h: float = float(def.get("height")) if def.get("height") != null else 3.5
	var col: Color = def.get("albedo_color") as Color if def.get("albedo_color") != null else Color(0.68,0.64,0.58)
	# Box fina: largura TILE, espessura thick, altura h
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(TILE, h, thick)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.9
	box.material = mat
	if _mesh:
		_mesh.mesh = box
		_mesh.position = Vector3(0, h*0.5, 0)
	if _col:
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = Vector3(TILE, h, thick)
		_col.shape = shape
		_col.position = Vector3(0, h*0.5, 0)
	_place_at_edge()

func _place_at_edge() -> void:
	var base: Vector3 = Vector3(float(edge_cell.x)*TILE + TILE*0.5, float(edge_cell.z)*7.0, float(edge_cell.y)*TILE + TILE*0.5)
	var off: Vector3 = Vector3.ZERO
	match edge_dir:
		"north": off = Vector3(0, 0, -TILE*0.5)
		"south": off = Vector3(0, 0, TILE*0.5)
		"west": off = Vector3(-TILE*0.5, 0, 0)
		"east": off = Vector3(TILE*0.5, 0, 0)
	global_position = base + off
	# rotaciona para edge_dir east/west (parede fina no eixo Z vs X)
	if edge_dir in ["east", "west"]:
		rotation.y = deg_to_rad(90)
	else:
		rotation.y = 0

func configure(cell: Vector3i, dir: String, def: Resource = null) -> void:
	edge_cell = cell
	edge_dir = dir
	if def:
		definition = def
	_apply()
