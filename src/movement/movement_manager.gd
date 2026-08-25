extends Node
class_name MovementManager
## Movimento "pulando" por célula — camada de apresentação apenas.
## BFS já calculado, Tween por célula com arco + squash, sem afetar lógica.

signal movement_finished(unit: Node, dest: Vector3i)

func get_reachable(start: Vector3i, max_steps: int) -> Dictionary:
	var bg: Node = get_node_or_null("/root/BoardGrid") as Node
	if bg and bg.has_method("compute_reachable"):
		return bg.call("compute_reachable", start, max_steps) as Dictionary
	return {"dist":{}, "came":{}}

func get_movement_path(reach: Dictionary, dest: Vector3i) -> Array:
	var bg: Node = get_node_or_null("/root/BoardGrid") as Node
	if bg and bg.has_method("path_from_reachable"):
		return bg.call("path_from_reachable", reach, dest) as Array
	# fallback manual
	if not reach["dist"].has(dest):
		return []
	var path: Array = []
	var cur: Vector3i = dest
	while cur != reach["came"][cur]:
		path.push_front(cur)
		cur = reach["came"][cur] as Vector3i
	return path

func can_move_to(unit: Node, dest: Vector3i, max_steps: int) -> bool:
	var start: Vector3i = unit.get("grid_pos") as Vector3i
	var reach: Dictionary = get_reachable(start, max_steps)
	return reach["dist"].has(dest)

func move_unit(unit: Node, path: Array) -> void:
	if path.is_empty():
		movement_finished.emit(unit, unit.get("grid_pos") as Vector3i)
		return
	# bloqueia input durante movimento
	unit.set_meta("is_moving", true)
	var bg: Node = get_node_or_null("/root/BoardGrid") as Node
	var start: Vector3i = unit.get("grid_pos") as Vector3i
	# libera célula inicial
	if bg and bg.has_method("clear_cell"):
		bg.call("clear_cell", start)
	# anima sequencialmente
	_animate_path(unit, path, 0, bg)

func _animate_path(unit: Node, path: Array, idx: int, bg: Node) -> void:
	if idx >= path.size():
		var dest: Vector3i = path[path.size()-1] as Vector3i
		if bg and bg.has_method("place"):
			bg.call("place", unit, dest)
		unit.set_meta("is_moving", false)
		# se for druida transformado, reverte no início do turno seguinte — aqui simulamos revert após mover
		# não reverte automaticamente agora; deixa T manual
		movement_finished.emit(unit, dest)
		return
	var cell: Vector3i = path[idx] as Vector3i
	var target: Vector3 = bg.call("grid_to_world", cell) as Vector3 if bg else Vector3(float(cell.x)*2.0+1.0,0,float(cell.y)*2.0+1.0)
	var start_pos: Vector3 = (unit as Node3D).global_position
	var mid: Vector3 = (start_pos + target) * 0.5 + Vector3(0, 1.2, 0) # arco 1.2
	var duration: float = 0.22
	var tween: Tween = unit.create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	# sobe e arco + squash
	var mesh: Node = unit.get_node_or_null("MeshInstance3D") as Node
	# posição com arco (usando tween em global_position via método)
	tween.tween_property(unit, "global_position", mid, duration*0.5)
	tween.parallel().tween_property(mesh, "scale", Vector3(1.1, 0.85, 1.1), duration*0.5) if mesh else null
	tween.tween_property(unit, "global_position", target, duration*0.5)
	tween.parallel().tween_property(mesh, "scale", Vector3(0.95, 1.15, 0.95), duration*0.15) if mesh else null
	tween.tween_property(mesh, "scale", Vector3.ONE, 0.12) if mesh else null
	tween.tween_callback(func() -> void:
		# pequena pausa entre células 0.06s
		await unit.get_tree().create_timer(0.06).timeout
		_animate_path(unit, path, idx+1, bg)
	)
