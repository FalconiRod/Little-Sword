class_name UnitVisuals
## Construção procedural das miniaturas (placeholders estilizados).
## Frente da peça aponta para +Z.

static func _mat(hex: String, emis_hex := "", e_energy := 1.0, metal := 0.1, rough := 0.7) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.html(hex)
	if emis_hex != "":
		m.emission_enabled = true
		m.emission = Color.html(emis_hex)
		m.emission_energy_multiplier = e_energy
	m.metallic = metal
	m.roughness = rough
	return m

static func _add(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi

static func _box(parent: Node3D, size: Vector3, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _add(parent, b, mat, pos, rot)

static func _cyl(parent: Node3D, r_top: float, r_bottom: float, hgt: float, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bottom
	c.height = hgt
	return _add(parent, c, mat, pos, rot)

static func _sphere(parent: Node3D, radius: float, mat: Material, pos: Vector3) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	return _add(parent, s, mat, pos)

static func _cone(parent: Node3D, radius: float, hgt: float, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = radius
	c.height = hgt
	return _add(parent, c, mat, pos, rot)

static func _torus(parent: Node3D, inner: float, outer: float, mat: Material, pos: Vector3) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	return _add(parent, t, mat, pos)

## Base circular padrão de miniatura de mesa.
static func _base(root: Node3D, hex: String, radius := 0.42) -> void:
	_cyl(root, radius, radius * 1.05, 0.09, _mat(hex, "", 1.0, 0.8, 0.35), Vector3(0, 0.05, 0))
	_torus(root, radius - 0.03, radius + 0.02, _mat("c9a227", "c9a227", 0.5, 0.9, 0.3), Vector3(0, 0.08, 0))

## Espada grande com runas.
static func _great_sword(root: Node3D, blade_len: float, blade_hex: String, rune_hex: String, grip_hex := "2a2118") -> void:
	var g := Node3D.new()
	g.name = "Sword"
	root.add_child(g)
	g.position = Vector3(0.42, 0.78, 0.06)
	g.rotation_degrees = Vector3(0, 0, -18)
	_box(g, Vector3(0.09, blade_len, 0.03), _mat(blade_hex, rune_hex, 0.35, 0.95, 0.22), Vector3(0, blade_len * 0.5 + 0.12, 0))
	_box(g, Vector3(0.34, 0.07, 0.07), _mat("6b5a2a", "", 1.0, 0.8, 0.4), Vector3(0, 0.1, 0))
	_cyl(g, 0.035, 0.04, 0.2, _mat(grip_hex), Vector3(0, -0.02, 0))
	_sphere(g, 0.055, _mat("c9a227", "", 1.0, 0.9, 0.3), Vector3(0, -0.14, 0))

static func build(id: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Visual"
	match id:
		"knight":
			_build_knight(root)
		"mage":
			_build_mage(root)
		"druid":
			_build_druid(root)
		"druid_bear":
			_build_bear(root)
		"goblin_warrior":
			_build_goblin_warrior(root)
		"goblin_archer":
			_build_goblin_archer(root)
		"boss_knight":
			_build_boss(root)
	return root

static func _build_knight(root: Node3D) -> void:
	_base(root, "17171d")
	# Pernas / corpo / ombreiras
	_box(root, Vector3(0.36, 0.3, 0.26), _mat("20202a"), Vector3(0, 0.28, 0))
	_box(root, Vector3(0.54, 0.62, 0.38), _mat("262631", "", 1.0, 0.55, 0.45), Vector3(0, 0.76, 0))
	_sphere(root, 0.15, _mat("2e2e3b", "", 1.0, 0.55, 0.45), Vector3(0.32, 1.05, 0))
	_sphere(root, 0.15, _mat("2e2e3b", "", 1.0, 0.55, 0.45), Vector3(-0.32, 1.05, 0))
	# Elmo com olhos azuis brilhantes
	_box(root, Vector3(0.32, 0.32, 0.32), _mat("2c2c38", "", 1.0, 0.6, 0.4), Vector3(0, 1.28, 0))
	_box(root, Vector3(0.24, 0.055, 0.03), _mat("58c6ff", "58c6ff", 2.6, 0.0, 1.0), Vector3(0, 1.29, 0.17))
	# Capa vermelha esfarrapada (atrás, leve inclinação)
	_box(root, Vector3(0.46, 0.88, 0.05), _mat("7a1622", "", 1.0, 0.0, 0.95), Vector3(0, 0.72, -0.25), Vector3(10, 0, 0))
	_box(root, Vector3(0.16, 0.3, 0.04), _mat("5e101a"), Vector3(0.14, 0.28, -0.3), Vector3(14, 0, 8))
	_box(root, Vector3(0.14, 0.24, 0.04), _mat("5e101a"), Vector3(-0.13, 0.24, -0.31), Vector3(12, 0, -7))
	_great_sword(root, 0.98, "b9c2cf", "37e0ff")

static func _goblin_body(root: Node3D) -> void:
	_base(root, "14251a", 0.36)
	var body := CapsuleMesh.new()
	body.radius = 0.19
	body.height = 0.56
	_add(root, body, _mat("3e7d3a", "", 1.0, 0.0, 0.9), Vector3(0, 0.52, 0))
	_sphere(root, 0.17, _mat("4c8f43"), Vector3(0, 0.94, 0.02))
	_cone(root, 0.05, 0.18, _mat("3e7d3a"), Vector3(0.17, 1.04, 0), Vector3(0, 0, -70))
	_cone(root, 0.05, 0.18, _mat("3e7d3a"), Vector3(-0.17, 1.04, 0), Vector3(0, 0, 70))
	var eye := _mat("ffd23f", "ffd23f", 2.0, 0.0, 1.0)
	_sphere(root, 0.028, eye, Vector3(0.06, 0.96, 0.16))
	_sphere(root, 0.028, eye, Vector3(-0.06, 0.96, 0.16))
	_box(root, Vector3(0.3, 0.18, 0.24), _mat("5a4630"), Vector3(0, 0.32, 0))

static func _build_goblin_warrior(root: Node3D) -> void:
	_goblin_body(root)
	var arm := Node3D.new()
	root.add_child(arm)
	arm.position = Vector3(0.24, 0.6, 0.08)
	arm.rotation_degrees = Vector3(0, 0, -30)
	_box(arm, Vector3(0.05, 0.3, 0.02), _mat("aab2bd", "", 1.0, 0.9, 0.3), Vector3(0, 0.2, 0))
	_cyl(arm, 0.028, 0.03, 0.12, _mat("2a2118"), Vector3(0, 0.02, 0))

static func _build_goblin_archer(root: Node3D) -> void:
	_goblin_body(root)
	# Arco: arco simples de 3 segmentos
	_box(root, Vector3(0.03, 0.42, 0.03), _mat("6a4a26"), Vector3(0.26, 0.68, 0.12), Vector3(0, 0, 18))
	_box(root, Vector3(0.03, 0.42, 0.03), _mat("6a4a26"), Vector3(0.33, 0.68, 0.12), Vector3(0, 0, -18))
	_box(root, Vector3(0.006, 0.66, 0.006), _mat("d8d8d0"), Vector3(0.295, 0.68, 0.12))
	# Aljava nas costas
	_cyl(root, 0.05, 0.05, 0.26, _mat("4a3520"), Vector3(-0.12, 0.75, -0.14), Vector3(20, 0, 15))

static func _build_boss(root: Node3D) -> void:
	root.scale = Vector3(1.55, 1.55, 1.55)
	_base(root, "121216", 0.44)
	_box(root, Vector3(0.4, 0.34, 0.3), _mat("191921"), Vector3(0, 0.3, 0))
	_box(root, Vector3(0.6, 0.68, 0.42), _mat("1d1d27", "", 1.0, 0.6, 0.4), Vector3(0, 0.82, 0))
	_sphere(root, 0.17, _mat("23232f", "", 1.0, 0.6, 0.4), Vector3(0.36, 1.14, 0))
	_sphere(root, 0.17, _mat("23232f", "", 1.0, 0.6, 0.4), Vector3(-0.36, 1.14, 0))
	_cone(root, 0.07, 0.26, _mat("101014", "", 1.0, 0.5, 0.5), Vector3(0.16, 1.52, 0), Vector3(0, 0, -18))
	_cone(root, 0.07, 0.26, _mat("101014", "", 1.0, 0.5, 0.5), Vector3(-0.16, 1.52, 0), Vector3(0, 0, 18))
	_box(root, Vector3(0.34, 0.34, 0.34), _mat("20202c", "", 1.0, 0.65, 0.4), Vector3(0, 1.42, 0))
	_box(root, Vector3(0.26, 0.06, 0.03), _mat("ff3b30", "ff3b30", 3.2, 0.0, 1.0), Vector3(0, 1.43, 0.18))
	_box(root, Vector3(0.52, 1.0, 0.06), _mat("4a0d14", "", 1.0, 0.0, 0.95), Vector3(0, 0.78, -0.28), Vector3(10, 0, 0))
	# Runas no peito
	_box(root, Vector3(0.2, 0.06, 0.02), _mat("ff5544", "ff5544", 1.6, 0.0, 1.0), Vector3(0, 0.92, 0.22))
	var sword := Node3D.new()
	root.add_child(sword)
	sword.position = Vector3(0.48, 0.86, 0.08)
	sword.rotation_degrees = Vector3(0, 0, -16)
	_box(sword, Vector3(0.11, 1.35, 0.035), _mat("9aa2ad", "ff3b30", 0.5, 0.95, 0.22), Vector3(0, 0.79, 0))
	_box(sword, Vector3(0.4, 0.08, 0.08), _mat("4a3a1a", "", 1.0, 0.85, 0.35), Vector3(0, 0.08, 0))
	_cyl(sword, 0.04, 0.045, 0.22, _mat("1c1410"), Vector3(0, -0.05, 0))

## Maga Elara: robe arroxeado, chapéu pontudo e cajado com orbe vermelho.
static func _build_mage(root: Node3D) -> void:
	_base(root, "1a1226")
	# Robe (cone invertido) + torso
	_cone(root, 0.34, 0.9, _mat("2d1b47", "", 1.0, 0.05, 0.95), Vector3(0, 0.52, 0))
	_box(root, Vector3(0.4, 0.42, 0.3), _mat("35215a"), Vector3(0, 1.12, 0))
	# Cinto dourado
	_box(root, Vector3(0.42, 0.07, 0.32), _mat("c9a227", "c9a227", 0.5, 0.8, 0.35), Vector3(0, 0.94, 0))
	# Cabeca + olhos violetas
	_sphere(root, 0.14, _mat("e8c9a8"), Vector3(0, 1.44, 0.02))
	var eye := _mat("b06bff", "b06bff", 2.4, 0.0, 1.0)
	_sphere(root, 0.03, eye, Vector3(0.055, 1.46, 0.13))
	_sphere(root, 0.03, eye, Vector3(-0.055, 1.46, 0.13))
	# Chapeu pontudo com aba
	_cyl(root, 0.30, 0.30, 0.04, _mat("241238"), Vector3(0, 1.56, 0))
	_cone(root, 0.22, 0.55, _mat("2d1b47"), Vector3(0, 1.82, -0.02), Vector3(-8, 0, 0))
	# Cajado com orbe vermelho brilhante
	var staff := Node3D.new()
	root.add_child(staff)
	staff.position = Vector3(0.32, 0.9, 0.08)
	staff.rotation_degrees = Vector3(0, 0, -10)
	_cyl(staff, 0.03, 0.035, 1.25, _mat("4a3520"), Vector3(0, 0.1, 0))
	_sphere(staff, 0.11, _mat("ff3b30", "ff5544", 3.0, 0.0, 0.4), Vector3(0, 0.78, 0))
	_torus(staff, 0.13, 0.17, _mat("c9a227", "c9a227", 0.6, 0.85, 0.35), Vector3(0, 0.78, 0))

## Druida Rowan: manto verde-musgo, capuz e cajado de madeira com orbe verde.
static func _build_druid(root: Node3D) -> void:
	_base(root, "16211a")
	# Manto longo
	_cone(root, 0.33, 0.95, _mat("274a2c", "", 1.0, 0.0, 0.95), Vector3(0, 0.54, 0))
	_box(root, Vector3(0.38, 0.4, 0.28), _mat("2f5a34"), Vector3(0, 1.1, 0))
	# Capuz sobre a cabeca sombreada
	_sphere(root, 0.15, _mat("1c3520"), Vector3(0, 1.42, -0.02))
	_cone(root, 0.17, 0.3, _mat("274a2c"), Vector3(0, 1.56, -0.06), Vector3(-18, 0, 0))
	var eye := _mat("9dff6b", "9dff6b", 2.2, 0.0, 1.0)
	_sphere(root, 0.026, eye, Vector3(0.05, 1.41, 0.12))
	_sphere(root, 0.026, eye, Vector3(-0.05, 1.41, 0.12))
	# Ombreira de folhas
	_sphere(root, 0.09, _mat("3f7d3a", "69c94f", 0.7, 0.0, 0.9), Vector3(0.22, 1.26, 0))
	_sphere(root, 0.09, _mat("3f7d3a", "69c94f", 0.7, 0.0, 0.9), Vector3(-0.22, 1.26, 0))
	# Cajado druidico com orbe verde
	var staff := Node3D.new()
	root.add_child(staff)
	staff.position = Vector3(0.3, 0.88, 0.07)
	staff.rotation_degrees = Vector3(0, 0, -8)
	_cyl(staff, 0.032, 0.04, 1.2, _mat("5a4630"), Vector3(0, 0.1, 0))
	_sphere(staff, 0.1, _mat("69c94f", "9dff6b", 2.6, 0.0, 0.4), Vector3(0, 0.75, 0))

## Forma de urso da Rowan: quadrupede robusto com garras.
static func _build_bear(root: Node3D) -> void:
	root.scale = Vector3(1.25, 1.25, 1.25)
	_base(root, "16211a", 0.48)
	# Corpo macico
	_box(root, Vector3(0.62, 0.55, 0.95), _mat("5a4028", "", 1.0, 0.0, 0.95), Vector3(0, 0.62, -0.05))
	_box(root, Vector3(0.5, 0.3, 0.5), _mat("6b4c30"), Vector3(0, 0.92, -0.18), Vector3(12, 0, 0))
	# Cabeca + focinho + orelhas
	_sphere(root, 0.24, _mat("5a4028"), Vector3(0, 0.86, 0.52))
	_sphere(root, 0.12, _mat("7a5a38"), Vector3(0, 0.8, 0.72))
	_sphere(root, 0.045, _mat("201510"), Vector3(0, 0.84, 0.82))
	_cone(root, 0.07, 0.16, _mat("4a3422"), Vector3(0.13, 1.08, 0.48))
	_cone(root, 0.07, 0.16, _mat("4a3422"), Vector3(-0.13, 1.08, 0.48))
	var eye := _mat("ffd23f", "ffd23f", 2.4, 0.0, 1.0)
	_sphere(root, 0.032, eye, Vector3(0.09, 0.93, 0.68))
	_sphere(root, 0.032, eye, Vector3(-0.09, 0.93, 0.68))
	# Patas dianteiras com garras claras
	for sx in [-1.0, 1.0]:
		_box(root, Vector3(0.16, 0.5, 0.18), _mat("4a3422"), Vector3(sx * 0.24, 0.25, 0.38))
		_box(root, Vector3(0.14, 0.06, 0.2), _mat("d8cdb8"), Vector3(sx * 0.24, 0.06, 0.44))
	# Patas traseiras
	for sx in [-1.0, 1.0]:
		_box(root, Vector3(0.18, 0.42, 0.2), _mat("4a3422"), Vector3(sx * 0.22, 0.21, -0.36))
