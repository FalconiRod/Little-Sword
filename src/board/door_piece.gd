extends StaticBody3D
class_name DoorPiece

enum State { CLOSED, OPEN, LOCKED }

@export var definition: Resource
@export var edge_cell: Vector3i = Vector3i(0,0,0)
@export var edge_dir: String = "north"
@export var state: int = State.CLOSED

@onready var _mesh: MeshInstance3D = $MeshInstance3D
@onready var _col: CollisionShape3D = $CollisionShape3D
@onready var _area: Area3D = $Area3D

const TILE: float = 2.0

func _ready() -> void:
	if definition == null:
		definition = load("res://src/resources/door_definition.gd").new()
	_apply_state()
	collision_layer = 2
	collision_mask = 0

func _apply_state() -> void:
	var def: Resource = definition
	var w: float = float(def.get("width")) if def.get("width") != null else 1.6
	var th: float = float(def.get("thickness")) if def.get("thickness") != null else 0.15
	var h: float = float(def.get("height")) if def.get("height") != null else 3.2
	var col: Color = Color(0.55,0.35,0.15)
	match state:
		State.CLOSED: col = def.get("color_closed") as Color if def.get("color_closed") != null else col
		State.OPEN: col = def.get("color_open") as Color if def.get("color_open") != null else Color(0.62,0.42,0.20)
		State.LOCKED: col = def.get("color_locked") as Color if def.get("color_locked") != null else Color(0.85,0.15,0.15)
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(w, h, th)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = col
	if state == State.OPEN:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color.a = 0.35
	box.material = mat
	if _mesh:
		_mesh.mesh = box
		_mesh.position = Vector3(0, h*0.5, 0)
		_mesh.visible = true
		if state == State.OPEN:
			# porta aberta fica encostada na parede (gira 90)
			_mesh.rotation.y = deg_to_rad(90)
		else:
			_mesh.rotation.y = 0
	if _col:
		if state == State.OPEN:
			_col.disabled = true
			set_meta("walkable", true)
			set_meta("blocks_los", false)
		else:
			_col.disabled = false
			var shape: BoxShape3D = BoxShape3D.new()
			shape.size = Vector3(w, h, th)
			_col.shape = shape
			_col.position = Vector3(0, h*0.5, 0)
			set_meta("walkable", false)
			set_meta("blocks_los", true)
	_place_at_edge()

func _place_at_edge() -> void:
	var base: Vector3 = Vector3(float(edge_cell.x)*TILE + TILE*0.5, float(edge_cell.z)*7.0, float(edge_cell.y)*TILE + TILE*0.5)
	var off: Vector3 = Vector3.ZERO
	match edge_dir:
		"north": off = Vector3(0,0,-TILE*0.5)
		"south": off = Vector3(0,0,TILE*0.5)
		"west": off = Vector3(-TILE*0.5,0,0)
		"east": off = Vector3(TILE*0.5,0,0)
	global_position = base + off
	if edge_dir in ["east","west"]:
		rotation.y = deg_to_rad(90)
	else:
		rotation.y = 0

func set_state(s: int) -> void:
	state = s
	_apply_state()

func is_blocking() -> bool:
	return state != State.OPEN

func cell_behind() -> Vector3i:
	match edge_dir:
		"north": return edge_cell + Vector3i(0,-1,0)
		"south": return edge_cell + Vector3i(0,1,0)
		"west": return edge_cell + Vector3i(-1,0,0)
		"east": return edge_cell + Vector3i(1,0,0)
		_: return edge_cell
