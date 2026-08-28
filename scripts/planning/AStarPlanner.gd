class_name AStarPlanner
extends PathPlanner

const MAX_RETRIES: int = 3

func _init(p_graph_manager: Object):
	super(p_graph_manager)

func heuristic(node_a: GraphNodeData, node_b: GraphNodeData) -> float:
	return node_a.position.distance_to(node_b.position)

func find_path(start_id: String, goal_id: String, constraints: Dictionary = {}) -> Array[String]:
	return _find_path_internal(start_id, goal_id, constraints, 0)

func _find_path_internal(start_id: String, goal_id: String, constraints: Dictionary, retry_depth: int) -> Array[String]:
	if graph_manager == null:
		return []

	var start_node = graph_manager.get_graph_node(start_id)
	var goal_node = graph_manager.get_graph_node(goal_id)

	if start_node == null or goal_node == null:
		return []

	# Check start and goal node validity against obstacles
	if not graph_manager.is_node_valid(start_id) or not graph_manager.is_node_valid(goal_id):
		return []

	var open_set: Array[String] = [start_id]
	var came_from: Dictionary = {}

	var g_score: Dictionary = {}
	var f_score: Dictionary = {}

	for n_id in graph_manager.nodes:
		g_score[n_id] = INF
		f_score[n_id] = INF

	g_score[start_id] = 0.0
	f_score[start_id] = heuristic(start_node, goal_node)

	while open_set.size() > 0:
		var current_id = get_lowest_f_score_node(open_set, f_score)

		if current_id == goal_id:
			var candidate_path = reconstruct_path(came_from, current_id)
			var validation_result = validate_path(candidate_path)
			if validation_result.valid:
				return candidate_path
			else:
				# Path crossed invalid geometry -> Add dynamic constraints and retry
				if retry_depth < MAX_RETRIES:
					var new_constraints = constraints.duplicate(true)
					if not new_constraints.has("blocked_nodes"):
						new_constraints["blocked_nodes"] = {}
					if not new_constraints.has("blocked_edges"):
						new_constraints["blocked_edges"] = {}

					if validation_result.failed_node != "":
						new_constraints.blocked_nodes[validation_result.failed_node] = true
					if validation_result.failed_edge != "":
						new_constraints.blocked_edges[validation_result.failed_edge] = true

					return _find_path_internal(start_id, goal_id, new_constraints, retry_depth + 1)
				else:
					return []

		open_set.erase(current_id)
		var current_node = graph_manager.get_graph_node(current_id)

		if current_node == null:
			continue

		for neighbor_id in current_node.neighbors.keys():
			# 1. Check Node Validity & Obstacle Intersection
			if not graph_manager.is_node_valid(neighbor_id):
				continue

			if constraints.has("blocked_nodes") and constraints.blocked_nodes.has(neighbor_id):
				continue

			# 2. Check Edge Validity & Blocked Constraints
			if not graph_manager.is_edge_valid(current_id, neighbor_id, GraphManager.ROBOT_RADIUS):
				continue

			var edge_key_1 = "%s-%s" % [current_id, neighbor_id]
			var edge_key_2 = "%s-%s" % [neighbor_id, current_id]
			if constraints.has("blocked_edges") and (constraints.blocked_edges.has(edge_key_1) or constraints.blocked_edges.has(edge_key_2)):
				continue

			var neighbor_node = graph_manager.get_graph_node(neighbor_id)
			if neighbor_node == null:
				continue

			# 3. Geometric Obstacle Clearance Check Along Segment
			if graph_manager.is_segment_intersecting_obstacle(current_node.position, neighbor_node.position, GraphManager.DEFAULT_CLEARANCE):
				continue

			var edge = graph_manager.get_edge(current_id, neighbor_id)
			if edge == null or not edge.traversable:
				continue

			var tentative_g = g_score[current_id] + edge.weight

			if tentative_g < g_score[neighbor_id]:
				came_from[neighbor_id] = current_id
				g_score[neighbor_id] = tentative_g
				f_score[neighbor_id] = tentative_g + heuristic(neighbor_node, goal_node)

				if not open_set.has(neighbor_id):
					open_set.append(neighbor_id)

	return []

func validate_path(path: Array[String]) -> Dictionary:
	if path.size() <= 1:
		return { "valid": true, "failed_node": "", "failed_edge": "" }

	for i in range(path.size() - 1):
		var u = path[i]
		var v = path[i + 1]

		if not graph_manager.is_node_valid(u):
			return { "valid": false, "failed_node": u, "failed_edge": "" }
		if not graph_manager.is_node_valid(v):
			return { "valid": false, "failed_node": v, "failed_edge": "" }

		if not graph_manager.is_edge_valid(u, v, GraphManager.ROBOT_RADIUS):
			return { "valid": false, "failed_node": "", "failed_edge": "%s-%s" % [u, v] }

		var node_u = graph_manager.get_graph_node(u)
		var node_v = graph_manager.get_graph_node(v)
		if node_u and node_v:
			if graph_manager.is_segment_intersecting_obstacle(node_u.position, node_v.position, GraphManager.DEFAULT_CLEARANCE):
				return { "valid": false, "failed_node": "", "failed_edge": "%s-%s" % [u, v] }

	return { "valid": true, "failed_node": "", "failed_edge": "" }

func get_lowest_f_score_node(nodes_list: Array[String], f_score: Dictionary) -> String:
	var lowest_id = nodes_list[0]
	var lowest_val = f_score.get(lowest_id, INF)

	for i in range(1, nodes_list.size()):
		var id = nodes_list[i]
		var val = f_score.get(id, INF)
		if val < lowest_val:
			lowest_val = val
			lowest_id = id

	return lowest_id

func reconstruct_path(came_from: Dictionary, current_id: String) -> Array[String]:
	var total_path: Array[String] = [current_id]
	while came_from.has(current_id):
		current_id = came_from[current_id]
		total_path.push_front(current_id)
	return total_path
