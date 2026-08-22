class_name DungeonStairs
extends Node3D
## Escada do kit de mesa: conecta duas células (podem ser de andares
## diferentes ou níveis de elevação) e registra o link no grid.

var a := Vector3i.ZERO
var b := Vector3i.ZERO

func setup(pa: Vector3i, pb: Vector3i) -> void:
	a = pa
	b = pb
	BoardGrid.add_link(a, b)
	_build()

func _build() -> void:
	var wa := BoardGrid.world_pos(a)
	var wb := BoardGrid.world_pos(b)
	position = wa
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.html("565664")
	m.roughness = 0.85
	if Vector2(a.x, a.y) != Vector2(b.x, b.y):
		# Rampa reta entre os centros das duas casas.
		var to_b := wb - wa
		var len_xz := Vector2(to_b.x, to_b.z).length()
		var steps := maxi(4, int(len_xz / 0.5))
		for i in steps:
			var t := (float(i) + 0.5) / float(steps)
			var bm := BoxMesh.new()
			bm.size = Vector3(1.5, 0.16, len_xz / steps + 0.12)
			var mi := MeshInstance3D.new()
			mi.mesh = bm
			mi.material_override = m
			mi.position = Vector3(
				lerpf(0.0, to_b.x, t),
				lerpf(0.0, to_b.y, t) + 0.08,
				lerpf(0.0, to_b.z, t))
			add_child(mi)
	else:
		# Vertical (mesmo x,y): espiral de degraus ao redor da casa.
		var dh := wb.y - wa.y
		for i in 8:
			var ang := TAU * i / 8.0
			var bm := BoxMesh.new()
			bm.size = Vector3(0.72, 0.14, 0.52)
			var mi := MeshInstance3D.new()
			mi.mesh = bm
			mi.material_override = m
			mi.position = Vector3(cos(ang) * 0.64,
				dh * (float(i) + 1.0) / 8.0 + 0.07, sin(ang) * 0.64)
			mi.rotation_degrees.y = rad_to_deg(-ang)
			add_child(mi)
