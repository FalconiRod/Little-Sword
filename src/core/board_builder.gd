class_name BoardBuilder
extends Node3D
## Constrói a dungeon física sobre o grid lógico: piso, paredes quebradas,
## tochas, baú, runas, névoa de exploração e ambiente.

const MAP := [
	"#############",
	"#..T.....T..#",
	"#....K......#",
	"#...........#",
	"#...........#",
	"######.######",
	"#...g...g...#",
	"#...........#",
	"#.....T...C.#",
	"#...........#",
	"######.######",
	"#...........#",
	"#..a.....B..#",
	"#..T....rr..#",
	"#############",
]

const ROOMS := [
	{"name": "Sala Inicial", "rect": Rect2i(1, 1, 11, 4), "fog": false},
	{"name": "Salão de Combate", "rect": Rect2i(1, 6, 11, 4), "fog": true},
	{"name": "Câmara do Boss", "rect": Rect2i(1, 11, 11, 3), "fog": true},
]

var _rng := RandomNumberGenerator.new()
var _torch_lights: Array[OmniLight3D] = []
var _rune_mats: Array[StandardMaterial3D] = []
var _flame_mats: Array[StandardMaterial3D] = []
var _fog_mats: Array[StandardMaterial3D] = []
var _fog_planes: Array[MeshInstance3D] = []
var _rooms_revealed: Array[bool] = []
var chest_cell := Vector2i(-1, -1)
var chest_group: Node3D
var chest_looted := false
var boss_cell := Vector2i(-1, -1)
var boss_unit = null
var _t := 0.0

func is_revealed(index: int) -> bool:
	return _rooms_revealed[index]

func get_boss_unit():
	return boss_unit

func build() -> void:
	_rng.seed = 1337
	_rooms_revealed = []
	for r in ROOMS:
		_rooms_revealed.append(not r["fog"])
	_build_environment()
	var floor_mat_a := _mat("2b2b33", "", 1.0, 0.05, 0.85)
	var floor_mat_b := _mat("26262e", "", 1.0, 0.05, 0.9)
	var wall_mat := _mat("1d1d25", "", 1.0, 0.08, 0.8)
	for z in BoardGrid.h:
		var row: String = MAP[z]
		for x in row.length():
			var ch := row[x]
			var c := Vector2i(x, z)
			if ch == "#":
				if _near_playable(c):
					_build_wall(c, wall_mat)
				continue
			_build_floor(c, floor_mat_a if (x + z) % 2 == 0 else floor_mat_b)
			match ch:
				"T":
					_build_torch(c)
				"C":
					chest_cell = c
					_build_chest(c)
				"r":
					_build_rune(c)
				"B":
					boss_cell = c
	_build_boss_circle()
	_build_fog()

func _mat(hex: String, emis_hex := "", e_energy := 1.0, metal := 0.05, rough := 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.html(hex)
	if emis_hex != "":
		m.emission_enabled = true
		m.emission = Color.html(emis_hex)
		m.emission_energy_multiplier = e_energy
	m.metallic = metal
	m.roughness = rough
	return m

func _near_playable(c: Vector2i) -> bool:
	for n in BoardGrid.neighbors4(c):
		if BoardGrid.is_walkable(n):
			return true
	return false

func _build_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.html("07070d")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.html("34344a")
	env.ambient_light_energy = 0.5
	env.fog_enabled = true
	env.fog_light_color = Color.html("0b0b16")
	env.fog_density = 0.014
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_color = Color.html("aab4ff")
	sun.light_energy = 0.45
	sun.shadow_enabled = true
	add_child(sun)

func _build_floor(c: Vector2i, base_mat: StandardMaterial3D) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = base_mat.albedo_color.darkened(_rng.randf_range(-0.06, 0.12))
	m.metallic = 0.05
	m.roughness = 0.85
	var b := BoxMesh.new()
	b.size = Vector3(1.92, 0.12, 1.92)
	var mi := MeshInstance3D.new()
	mi.mesh = b
	mi.material_override = m
	mi.position = Vector3(c.x * BoardGrid.TILE, -0.06, c.y * BoardGrid.TILE)
	add_child(mi)

func _build_wall(c: Vector2i, wall_mat: StandardMaterial3D) -> void:
	var hgt := _rng.randf_range(1.45, 1.8)
	var broken := _rng.randf() < 0.22
	if broken:
		hgt *= 0.55
	var m := StandardMaterial3D.new()
	m.albedo_color = wall_mat.albedo_color.darkened(_rng.randf_range(-0.08, 0.15))
	m.metallic = 0.05
	m.roughness = 0.85
	var b := BoxMesh.new()
	b.size = Vector3(2.0, hgt, 2.0)
	var mi := MeshInstance3D.new()
	mi.mesh = b
	mi.material_override = m
	mi.position = Vector3(c.x * BoardGrid.TILE, hgt / 2.0, c.y * BoardGrid.TILE)
	if broken:
		mi.rotation_degrees.y = _rng.randf_range(-7, 7)
		var debris := BoxMesh.new()
		debris.size = Vector3(0.5, 0.24, 0.4)
		var d := MeshInstance3D.new()
		d.mesh = debris
		d.material_override = wall_mat
		d.position = Vector3(c.x * BoardGrid.TILE + _rng.randf_range(-0.6, 0.6), hgt + 0.12, c.y * BoardGrid.TILE + _rng.randf_range(-0.6, 0.6))
		d.rotation_degrees.z = _rng.randf_range(0, 40)
		add_child(d)
	add_child(mi)

func _build_torch(c: Vector2i) -> void:
	var wp := BoardGrid.world_pos(c)
	var g := Node3D.new()
	g.position = wp
	add_child(g)
	var pole := _cyl_local(g, 0.045, 0.055, 0.95, _mat("2a2119"), Vector3(0, 0.47, 0))
	pole.name = "Pole"
	_cyl_local(g, 0.13, 0.09, 0.13, _mat("3a3a46", "", 1.0, 0.6, 0.5), Vector3(0, 0.98, 0))
	var flame_m := _mat("ff9a3c", "ff9a3c", 2.8, 0.0, 1.0)
	_flame_mats.append(flame_m)
	_cone_local(g, 0.11, 0.32, flame_m, Vector3(0, 1.2, 0))
	var light := OmniLight3D.new()
	light.position = Vector3(0, 1.55, 0)
	light.light_color = Color.html("ff9a45")
	light.light_energy = 1.5
	light.omni_range = 5.5
	light.shadow_enabled = false
	g.add_child(light)
	_torch_lights.append(light)

func _build_chest(c: Vector2i) -> void:
	var wp := BoardGrid.world_pos(c)
	chest_group = Node3D.new()
	chest_group.position = wp
	add_child(chest_group)
	var wood := _mat("4a2f1d")
	var gold := _mat("c9a227", "c9a227", 0.35, 0.9, 0.35)
	_box_local(chest_group, Vector3(0.82, 0.5, 0.56), wood, Vector3(0, 0.27, 0))
	_box_local(chest_group, Vector3(0.86, 0.07, 0.6), gold, Vector3(0, 0.42, 0))
	_box_local(chest_group, Vector3(0.86, 0.06, 0.1), gold, Vector3(0, 0.18, 0))
	var lid := Node3D.new()
	lid.name = "Lid"
	lid.position = Vector3(0, 0.53, -0.26)
	lid.rotation_degrees.x = -38
	chest_group.add_child(lid)
	var lid_mesh := MeshInstance3D.new()
	var lb := BoxMesh.new()
	lb.size = Vector3(0.84, 0.16, 0.58)
	lid_mesh.mesh = lb
	lid_mesh.material_override = wood
	lid.add_child(lid_mesh)
	lid_mesh.position = Vector3(0, 0, 0.29)
	_sphere_local(chest_group, 0.06, gold, Vector3(0, 0.36, 0.3))
	var glow := OmniLight3D.new()
	glow.position = Vector3(0, 0.7, 0)
	glow.light_color = Color.html("ffc76b")
	glow.light_energy = 0.7
	glow.omni_range = 3.0
	chest_group.add_child(glow)

func _build_rune(c: Vector2i) -> void:
	var wp := BoardGrid.world_pos(c)
	var m := _mat("37e0ff", "37e0ff", 1.4, 0.0, 1.0)
	_rune_mats.append(m)
	var disc := CylinderMesh.new()
	disc.top_radius = 0.62
	disc.bottom_radius = 0.66
	disc.height = 0.03
	var mi := MeshInstance3D.new()
	mi.mesh = disc
	mi.material_override = m
	mi.position = wp + Vector3(0, 0.03, 0)
	add_child(mi)

func _build_boss_circle() -> void:
	if boss_cell.x < 0:
		return
	var wp := BoardGrid.world_pos(boss_cell)
	var m := _mat("ff5544", "ff5544", 1.2, 0.0, 1.0)
	_rune_mats.append(m)
	var t := TorusMesh.new()
	t.inner_radius = 0.78
	t.outer_radius = 0.92
	var mi := MeshInstance3D.new()
	mi.mesh = t
	mi.material_override = m
	mi.position = wp + Vector3(0, 0.04, 0)
	add_child(mi)

func _build_fog() -> void:
	for i in ROOMS.size():
		var room: Dictionary = ROOMS[i]
		if not room["fog"]:
			continue
		var rect: Rect2i = room["rect"]
		var size := Vector2(rect.size.x * BoardGrid.TILE, rect.size.y * BoardGrid.TILE)
		var center := BoardGrid.world_pos(rect.position) \
			+ Vector3((rect.size.x - 1) * BoardGrid.TILE * 0.5, 0, (rect.size.y - 1) * BoardGrid.TILE * 0.5)
		for layer in 2:
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.62, 0.66, 0.78, 0.52 if layer == 0 else 0.3)
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			_fog_mats.append(m)
			var pm := PlaneMesh.new()
			pm.size = size * (0.98 if layer == 0 else 0.92)
			var mi := MeshInstance3D.new()
			mi.mesh = pm
			mi.material_override = m
			mi.position = center + Vector3(0, 0.75 if layer == 0 else 1.35, 0)
			add_child(mi)
			_fog_planes.append(mi)

func reveal_room(index: int) -> void:
	if index < 0 or index >= ROOMS.size() or _rooms_revealed[index]:
		return
	_rooms_revealed[index] = true
	EventBus.log_msg.emit("Área revelada: %s" % ROOMS[index]["name"], "#9fd8ff")
	EventBus.reveal_room.emit(ROOMS[index]["name"])
	var start_idx := _fog_start_index(index)
	for layer in 2:
		var plane := _fog_planes[start_idx + layer]
		var mat := _fog_mats[start_idx + layer]
		var tw := create_tween()
		tw.tween_property(mat, "albedo_color:a", 0.0, 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_callback(plane.hide)

func _fog_start_index(room_index: int) -> int:
	var idx := 0
	for i in room_index:
		if ROOMS[i]["fog"]:
			idx += 2
	return idx

func room_index_at(cell: Vector2i) -> int:
	for i in ROOMS.size():
		var rect: Rect2i = ROOMS[i]["rect"]
		if rect.has_point(cell):
			return i
	return -1

func loot_chest() -> void:
	if chest_looted or chest_group == null:
		return
	chest_looted = true
	var lid := chest_group.get_node_or_null("Lid")
	if lid != null:
		var tw := create_tween()
		tw.tween_property(lid, "rotation_degrees:x", -85.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	_t += delta
	for i in _torch_lights.size():
		var flicker := 0.82 + 0.28 * sin(_t * 11.0 + i * 2.7) + 0.12 * sin(_t * 23.0 + i)
		_torch_lights[i].light_energy = 1.5 * clampf(flicker, 0.55, 1.25)
	for i in _flame_mats.size():
		_flame_mats[i].emission_energy_multiplier = 2.8 + 0.7 * sin(_t * 13.0 + i * 1.9)
	for i in _rune_mats.size():
		_rune_mats[i].emission_energy_multiplier = 1.2 + 0.5 * sin(_t * 2.2 + i * 1.3)

# Helpers locais (posições relativas ao grupo pai).
func _box_local(parent: Node3D, size: Vector3, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi

func _cyl_local(parent: Node3D, r_top: float, r_bottom: float, hgt: float, mat: Material, pos: Vector3) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bottom
	c.height = hgt
	var mi := MeshInstance3D.new()
	mi.mesh = c
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

func _cone_local(parent: Node3D, radius: float, hgt: float, mat: Material, pos: Vector3) -> void:
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = radius
	c.height = hgt
	var mi := MeshInstance3D.new()
	mi.mesh = c
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)

func _sphere_local(parent: Node3D, radius: float, mat: Material, pos: Vector3) -> void:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	var mi := MeshInstance3D.new()
	mi.mesh = s
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
