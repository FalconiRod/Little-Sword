extends Node3D
class_name BoardUnit

@export var definition: Resource
@export var grid_pos: Vector3i = Vector3i(0,0,0)
@export var current_hp: int = 20

var _base_def: Resource = null
var _is_transformed: bool = false

@onready var _mesh: MeshInstance3D = $MeshInstance3D
@onready var _col: CollisionShape3D = $CollisionShape3D
@onready var _label: Label3D = $Label3D

func _ready() -> void:
	if definition == null:
		var CD: GDScript = load("res://src/resources/character_definition.gd") as GDScript
		definition = CD.call("create_cavaleiro") as Resource
	_base_def = definition
	current_hp = int(definition.get("hp_max"))
	_apply_visual()
	_update_position()
	if _col:
		_col.disabled = false

func _apply_visual() -> void:
	var def: Resource = definition
	var col: Color = def.get("capsule_color") as Color if def.get("capsule_color") != null else Color(0.2,0.45,0.85)
	var h: float = float(def.get("capsule_height")) if def.get("capsule_height") != null else 1.8
	var r: float = float(def.get("capsule_radius")) if def.get("capsule_radius") != null else 0.35
	var cap: CapsuleMesh = CapsuleMesh.new()
	cap.radius = r
	cap.height = h
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.7
	cap.material = mat
	if _mesh:
		_mesh.mesh = cap
		_mesh.position = Vector3(0, h*0.5, 0)
	if _col:
		var shape: CapsuleShape3D = CapsuleShape3D.new()
		shape.radius = r
		shape.height = h
		_col.shape = shape
		_col.position = Vector3(0, h*0.5, 0)
	if _label:
		_label.text = "%s\nHP %d/%d CA %d" % [def.get("display_name"), current_hp, int(def.get("hp_max")), int(def.get("ca"))]
		_label.modulate = Color(1,1,1)
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED

func _update_position() -> void:
	if has_node("/root/BoardGrid"):
		var bg: Node = get_node("/root/BoardGrid")
		if bg.has_method("grid_to_world"):
			global_position = bg.call("grid_to_world", grid_pos) as Vector3
			return
	global_position = Vector3(float(grid_pos.x)*2.0+1.0, float(grid_pos.z)*7.0, float(grid_pos.y)*2.0+1.0)

func place_at(cell: Vector3i) -> void:
	grid_pos = cell
	_update_position()
	var bg: Node = get_node_or_null("/root/BoardGrid")
	if bg and bg.has_method("place"):
		bg.call("place", self, cell)

func take_damage(amt: int) -> void:
	current_hp = maxi(0, current_hp - amt)
	_apply_visual()

func transform_toggle() -> void:
	var def: Resource = definition
	var alt: Resource = def.get("alternate_form") as Resource
	if alt == null:
		print("[BoardUnit] ", def.get("display_name"), " sem alternate_form")
		return
	if not _is_transformed:
		definition = alt
		_is_transformed = true
		print("[BoardUnit] Transformou -> ", alt.get("display_name"))
	else:
		definition = _base_def
		_is_transformed = false
		print("[BoardUnit] Reverteu -> ", _base_def.get("display_name"))
	_apply_visual()

func revert_if_transformed() -> void:
	if _is_transformed:
		definition = _base_def
		_is_transformed = false
		_apply_visual()
		print("[BoardUnit] Reversão automática turno seguinte: ", definition.get("display_name"))

func is_hero() -> bool:
	return int(definition.get("faction")) == 0

func is_goblin() -> bool:
	return int(definition.get("faction")) == 1

func is_boss() -> bool:
	return int(definition.get("faction")) == 2
