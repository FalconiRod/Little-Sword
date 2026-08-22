class_name TilePiece
## Catálogo de peças 3D modulares do "kit de mesa".
## Cada peça: propriedades de grid + builder procedural.
## >>> PONTO ÚNICO DE TROCA POR ASSETS (Meshy/GLB): basta substituir o
## builder da peça por um load("res://assets/pieces/<id>.glb") — as
## propriedades de grid continuam iguais.

const PROPS := {
	"floor_stone": {"w": true, "losb": false},
	"floor_carpet": {"w": true, "losb": false},
	"floor_moss": {"w": true, "losb": false},
	"wall_stone": {"w": false, "losb": true},
	"pillar": {"w": false, "losb": true},
	"rubble": {"w": false, "losb": false},
	"pit": {"w": false, "losb": false},
	"bridge_plank": {"w": true, "losb": false},
	"chest_prop": {"w": false, "losb": false},
	"runes": {"w": true, "losb": false, "special": "r"},
	"lever_base": {"w": false, "losb": false},
	# Portas e escadas são componentes próprios (Door.gd / stairs_prop).
}

static func build(id: String) -> Node3D:
	var root := Node3D.new()
	root.name = id
	match id:
		"floor_stone":
			_floor(root, Color.html("3a3a44"), 0.9)
		"floor_carpet":
			_floor(root, Color.html("5a1f2a"), 0.95)
			_carpet(root)
		"floor_moss":
			_floor(root, Color.html("33413a"), 0.92)
			_moss(root)
		"wall_stone":
			_wall(root)
		"pillar":
			_pillar(root)
		"rubble":
			_rubble(root)
		"pit":
			pass
		"bridge_plank":
			_bridge(root)
		"chest_prop":
			_chest(root)
		"runes":
			_floor(root, Color.html("2c3440"), 0.9)
			_runes(root)
		"lever_base":
			_lever(root)
		"torch":
			_torch(root)
		"stairs_prop":
			_stairs_column(root)
		"stairs_top":
			_stairs_marker(root)
	return root

## Escada-espiral: prop ÚNICO da célula base. Degraus em volta de um
## poste central subindo até logo abaixo do piso do andar de cima —
## puramente estético (a travessia é a transição de células ligadas).
static func _stairs_column(root: Node3D) -> void:
	var h: float = BoardGrid.FLOOR_H - 0.35
	var post := CylinderMesh.new()
	post.top_radius = 0.14
	post.bottom_radius = 0.2
	post.height = h
	_add(root, post, _mat(Color.html("4a3b2e")), Vector3(0, h * 0.5, 0))
	var steps := 10
	for i in steps:
		var ang := TAU * float(i) / float(steps)
		var y := (h - 0.22) * float(i) / float(steps)
		var st := BoxMesh.new()
		st.size = Vector3(0.54, 0.12, 0.36)
		var mi := _add(root, st, _mat(Color.html("6b5138"), Color(), 0.0, 0.05, 0.9),
				Vector3(cos(ang) * 0.6, y + 0.06, sin(ang) * 0.6))
		mi.rotation.y = -ang - PI / 2

## Marcador discreto da célula do TOPO da escada (chegada).
static func _stairs_marker(root: Node3D) -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = 0.62
	disc.bottom_radius = 0.62
	disc.height = 0.05
	_add(root, disc, _mat(Color.html("8a6d1f"), "ffd166", 0.7), Vector3(0, 0.03, 0))

# ------------------------------------------------------------- materiais ----

static func _mat(hex: Color, emis := Color(0, 0, 0), e_energy := 0.0,
		metal := 0.1, rough := 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = hex
	if e_energy > 0.0:
		m.emission_enabled = true
		m.emission = emis
		m.emission_energy_multiplier = e_energy
	m.metallic = metal
	m.roughness = rough
	return m

static func _add(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

# ---------------------------------------------------------------- peças -----

static func _floor(root: Node3D, col: Color, rough := 0.9) -> void:
	var b := BoxMesh.new()
	b.size = Vector3(1.98, 0.12, 1.98)
	_add(root, b, _mat(col, Color(), 0.0, 0.05, rough), Vector3(0, -0.06, 0))

static func _carpet(root: Node3D) -> void:
	var b := BoxMesh.new()
	b.size = Vector3(1.4, 0.03, 1.4)
	_add(root, b, _mat(Color.html("7a2536"), Color(), 0.0, 0.0, 1.0), Vector3(0, 0.005, 0))

static func _moss(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(root.name)
	for i in 5:
		var s := SphereMesh.new()
		s.radius = rng.randf_range(0.08, 0.2)
		s.height = s.radius * 0.8
		var x := rng.randf_range(-0.8, 0.8)
		var z := rng.randf_range(-0.8, 0.8)
		_add(root, s, _mat(Color.html("4a6b45"), Color(), 0.0, 0.0, 1.0),
				Vector3(x, -0.02, z))

static func _wall(root: Node3D) -> void:
	var b := BoxMesh.new()
	b.size = Vector3(2.0, 1.6, 2.0)
	_add(root, b, _mat(Color.html("4a4a56"), Color(), 0.0, 0.08, 0.85), Vector3(0, 0.68, 0))
	var cap := BoxMesh.new()
	cap.size = Vector3(2.06, 0.12, 2.06)
	_add(root, cap, _mat(Color.html("585866"), Color(), 0.0, 0.15, 0.75), Vector3(0, 1.52, 0))

static func _pillar(root: Node3D) -> void:
	var c := CylinderMesh.new()
	c.top_radius = 0.32
	c.bottom_radius = 0.38
	c.height = 1.7
	_add(root, c, _mat(Color.html("55555f"), Color(), 0.0, 0.2, 0.7), Vector3(0, 0.85, 0))
	var base := CylinderMesh.new()
	base.top_radius = 0.45
	base.bottom_radius = 0.45
	base.height = 0.16
	_add(root, base, _mat(Color.html("48484f"), Color(), 0.0, 0.15, 0.8), Vector3(0, 0.08, 0))
	var top := CylinderMesh.new()
	top.top_radius = 0.46
	top.bottom_radius = 0.42
	top.height = 0.14
	_add(root, top, _mat(Color.html("48484f"), Color(), 0.0, 0.15, 0.8), Vector3(0, 1.74, 0))

static func _rubble(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(root.name)
	for i in 4:
		var b := BoxMesh.new()
		b.size = Vector3(rng.randf_range(0.2, 0.5), rng.randf_range(0.12, 0.28),
				rng.randf_range(0.2, 0.45))
		var m := _mat(Color.html("50505c"), Color(), 0.0, 0.05, 0.95)
		var mi := _add(root, b, m, Vector3(rng.randf_range(-0.7, 0.7),
				0.08, rng.randf_range(-0.7, 0.7)))
		mi.rotation_degrees.y = rng.randf_range(0, 90)

static func _bridge(root: Node3D) -> void:
	for i in 4:
		var b := BoxMesh.new()
		b.size = Vector3(0.42, 0.08, 1.9)
		_add(root, b, _mat(Color.html("6a4a26"), Color(), 0.0, 0.0, 0.95),
				Vector3(-0.72 + i * 0.48, 0.02, 0))
	var rail := BoxMesh.new()
	rail.size = Vector3(1.9, 0.07, 0.07)
	_add(root, rail, _mat(Color.html("54381e")), Vector3(0, 0.36, 0.9))
	_add(root, rail.duplicate(), _mat(Color.html("54381e")), Vector3(0, 0.36, -0.9))

static func _chest(root: Node3D) -> void:
	var b := BoxMesh.new()
	b.size = Vector3(0.62, 0.38, 0.42)
	_add(root, b, _mat(Color.html("5a3a1e"), Color(), 0.0, 0.1, 0.85), Vector3(0, 0.19, 0))
	var lid := BoxMesh.new()
	lid.size = Vector3(0.66, 0.16, 0.46)
	_add(root, lid, _mat(Color.html("6b4626")), Vector3(0, 0.45, 0))
	var lock := BoxMesh.new()
	lock.size = Vector3(0.12, 0.14, 0.05)
	_add(root, lock, _mat(Color.html("c9a227"), Color.html("ffd166"), 0.8, 0.9, 0.3),
			Vector3(0, 0.3, 0.22))

static func _runes(root: Node3D) -> void:
	var t := TorusMesh.new()
	t.inner_radius = 0.5
	t.outer_radius = 0.66
	_add(root, t, _mat(Color.html("1d4f66"), Color.html("37e0ff"), 1.6, 0.2, 0.5),
			Vector3(0, 0.02, 0))
	var core := CylinderMesh.new()
	core.top_radius = 0.18
	core.bottom_radius = 0.18
	core.height = 0.04
	_add(root, core, _mat(Color.html("145a78"), Color.html("37e0ff"), 2.2, 0.1, 0.4),
			Vector3(0, 0.03, 0))

static func _lever(root: Node3D) -> void:
	var b := BoxMesh.new()
	b.size = Vector3(0.4, 0.24, 0.3)
	_add(root, b, _mat(Color.html("3c3c46")), Vector3(0, 0.12, 0))
	var arm := CylinderMesh.new()
	arm.top_radius = 0.03
	arm.bottom_radius = 0.04
	arm.height = 0.42
	var mi := _add(root, arm, _mat(Color.html("8a2f2f")), Vector3(0, 0.36, 0))
	mi.rotation_degrees.x = -24
	var knob := SphereMesh.new()
	knob.radius = 0.07
	knob.height = 0.14
	_add(root, knob, _mat(Color.html("ffd166"), Color.html("ffd166"), 1.2, 0.6, 0.4),
			Vector3(0, 0.54, -0.09))

static func _torch(root: Node3D) -> void:
	# Suporte na parede + chama emissiva (a luz Omni entra por parâmetro).
	var bracket := BoxMesh.new()
	bracket.size = Vector3(0.08, 0.08, 0.3)
	_add(root, bracket, _mat(Color.html("4a3626")), Vector3(0, 1.15, 0.18))
	var stick := CylinderMesh.new()
	stick.top_radius = 0.035
	stick.bottom_radius = 0.05
	stick.height = 0.5
	_add(root, stick, _mat(Color.html("54381e")), Vector3(0, 1.38, 0.28))
	var flame := SphereMesh.new()
	flame.radius = 0.11
	flame.height = 0.22
	_add(root, flame, _mat(Color.html("ffb454"), Color.html("ff9d2e"), 3.4, 0.1, 0.4),
			Vector3(0, 1.68, 0.28))
