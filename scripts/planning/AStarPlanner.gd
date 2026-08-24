class_name AStarPlanner
extends PathPlanner

func _init(p_graph_manager: Object):
	super(p_graph_manager)

func heuristic(node_a: GraphNodeData, node_b: GraphNodeData) -> float:
	return node_a.position.distance_to(node_b.position)

func find_path(start_id: String, goal_id: String, constraints: Dictionary = {}) -> Array[String]:
	if graph_manager == null:
		return []

	var start_node = graph_manager.get_graph_node(start_id)
	var goal_node = graph_manager.get_graph_node(goal_id)

	if start_node == null or goal_node == null:
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
			return reconstruct_path(came_from, current_id)

		open_set.erase(current_id)
		var current_node = graph_manager.get_graph_node(current_id)

		if current_node == null:
			continue

		for neighbor_id in current_node.neighbors.keys():
			var neighbor_node = graph_manager.get_graph_node(neighbor_id)
			if neighbor_node == null or not neighbor_node.traversable:
				continue

			if constraints.has("blocked_nodes") and constraints.blocked_nodes.has(neighbor_id):
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
