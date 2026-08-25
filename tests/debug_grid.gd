extends SceneTree

func _init() -> void:
	print("[DEBUG] iniciando teste de grid...")
	var main_scene: PackedScene = load("res://src/scenes/main.tscn") as PackedScene
	if main_scene == null:
		print("[DEBUG] ERRO: nao carregou main.tscn")
		quit(1)
		return
	var root_node: Node = main_scene.instantiate()
	# precisa adicionar ao root da SceneTree
	self.root.add_child(root_node)
	# aguarda physics_frame para bake
	await self.root.get_tree().physics_frame
	await self.root.get_tree().physics_frame
	await self.root.get_tree().physics_frame
	# pega Board
	var board: Node = root_node.find_child("Board", true, false)
	if board == null:
		print("[DEBUG] Board nao encontrado")
		quit(1)
		return
	print("[DEBUG] Board width=", board.get("width"), " height=", board.get("height"))
	var pieces: Array = board.call("get_pieces") as Array
	print("[DEBUG] pecas count=", pieces.size())
	for i: int in range(min(5, pieces.size())):
		var p: Node = pieces[i] as Node
		print("[DEBUG]  peca ", i, " cell=", p.get("cell"), " pos=", p.global_position, " mesh=", p.get_node_or_null("MeshInstance3D"))
		var mi: Node = p.get_node_or_null("MeshInstance3D") as Node
		if mi:
			var mesh: Resource = mi.get("mesh") as Resource
			print("[DEBUG]   mesh=", mesh, " mat=", mesh.get("material") if mesh else null)
	# BoardGrid
	var bg: Node = root.get_node_or_null("/root/BoardGrid")
	if bg:
		print("[DEBUG] BoardGrid bake_stats=", bg.call("bake_stats"))
		print("[DEBUG] cell(0,0,0)=", bg.call("cell_data", Vector3i(0,0,0)))
		print("[DEBUG] cell(5,5,0)=", bg.call("cell_data", Vector3i(5,5,0)))
		print("[DEBUG] grid_to_world(0,0,0)=", bg.call("grid_to_world", Vector3i(0,0,0)))
		print("[DEBUG] world_to_cell(1,0,1)=", bg.call("world_to_cell", Vector3(1,0,1), 0))
		print("[DEBUG] is_walkable(0,0,0)=", bg.call("is_walkable", Vector3i(0,0,0)))
	else:
		print("[DEBUG] BoardGrid autoload nao encontrado")
	# Camera
	var pivot: Node = root_node.find_child("CameraPivot", true, false)
	if pivot:
		print("[DEBUG] pivot pos=", pivot.global_position, " rot=", pivot.rotation_degrees)
		var arm: Node = pivot.get_node_or_null("SpringArm3D")
		if arm:
			print("[DEBUG] arm length=", arm.get("spring_length"))
		var cam: Node = root_node.find_child("Camera3D", true, false)
		if cam:
			print("[DEBUG] cam global pos=", (cam as Node3D).global_position)

	quit(0)
