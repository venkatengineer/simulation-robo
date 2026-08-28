class_name ReservationManager
extends Node

enum DestinationStatus {
	AVAILABLE,
	RESERVED,
	OCCUPIED,
	TEMPORARILY_BLOCKED
}

# Node reservations: node_id (String) -> { robot_id: String, priority: float, expiry: float }
var reservations: Dictionary = {}
# Edge reservations: "A-B" (String) -> { robot_id: String, priority: float, expiry: float }
var edge_reservations: Dictionary = {}
# Destination Occupancy: node_id (String) -> { occupant_id: String, status: DestinationStatus, timestamp: float }
var destination_occupancy: Dictionary = {}

func _process(delta: float) -> void:
	clean_expired()

func register_arrival(node_id: String, robot_id: String) -> void:
	destination_occupancy[node_id] = {
		"occupant_id": robot_id,
		"status": DestinationStatus.OCCUPIED,
		"timestamp": Time.get_ticks_msec() / 1000.0
	}

func release_arrival(node_id: String, robot_id: String) -> void:
	if destination_occupancy.has(node_id):
		if destination_occupancy[node_id].get("occupant_id", "") == robot_id:
			destination_occupancy.erase(node_id)

func is_destination_occupied(node_id: String, exclude_robot_id: String = "") -> bool:
	if destination_occupancy.has(node_id):
		var occupant = destination_occupancy[node_id].get("occupant_id", "")
		if occupant != "" and occupant != exclude_robot_id:
			return true
	return false

func get_destination_occupant(node_id: String) -> String:
	if destination_occupancy.has(node_id):
		return destination_occupancy[node_id].get("occupant_id", "")
	return ""

func find_nearest_waiting_node(goal_node_id: String, robot_id: String, graph_manager: GraphManager, robot_manager: RobotManager) -> String:
	if graph_manager == null:
		return ""

	var goal_node = graph_manager.get_graph_node(goal_node_id)
	if goal_node == null:
		return ""

	var best_node_id = ""
	var best_score = 999999.0

	for candidate_id in graph_manager.nodes:
		if candidate_id == goal_node_id:
			continue

		if not graph_manager.is_node_valid(candidate_id):
			continue

		var candidate_node = graph_manager.get_graph_node(candidate_id)
		if candidate_node == null:
			continue

		var dist_to_goal = candidate_node.position.distance_to(goal_node.position)
		# Must maintain robot safety distance from the goal (> 45px) and be within reasonable reach (< 350px)
		if dist_to_goal < 45.0 or dist_to_goal > 350.0:
			continue

		# Check if occupied by another robot
		var occupied = false
		if robot_manager:
			for other in robot_manager.get_all_robots():
				if is_instance_valid(other) and other.config.robot_id != robot_id and not other.failed:
					if other.global_position.distance_to(candidate_node.position) < 45.0:
						occupied = true
						break
					if other.state == RobotAgent.RobotState.ARRIVED and other.current_node_id == candidate_id:
						occupied = true
						break

		if occupied:
			continue

		# Penalize intersection nodes to avoid blocking crossroads if straightaway nodes exist
		var intersection_penalty = 80.0 if candidate_node.type == GraphNodeData.NodeType.INTERSECTION else 0.0
		var score = dist_to_goal + intersection_penalty

		if score < best_score:
			best_score = score
			best_node_id = candidate_id

	return best_node_id

func request_reservation(robot_id: String, node_id: String, duration_sec: float = 2.5) -> bool:
	return request_reservation_with_priority(robot_id, 5.0, node_id, duration_sec)

func request_reservation_with_priority(robot_id: String, priority: float, node_id: String, duration_sec: float = 2.5) -> bool:
	clean_expired()
	var now = Time.get_ticks_msec() / 1000.0

	if not reservations.has(node_id):
		reservations[node_id] = {
			"robot_id": robot_id,
			"priority": priority,
			"expiry": now + duration_sec
		}
		return true

	var existing = reservations[node_id]
	if existing.robot_id == robot_id:
		existing.expiry = now + duration_sec
		existing.priority = max(existing.priority, priority)
		return true

	# Priority Eviction: Higher priority robot preempts lower priority lock
	if priority > existing.priority:
		reservations[node_id] = {
			"robot_id": robot_id,
			"priority": priority,
			"expiry": now + duration_sec
		}
		return true

	return false

func is_node_reserved_by_other(node_id: String, robot_id: String) -> bool:
	var now = Time.get_ticks_msec() / 1000.0
	if reservations.has(node_id):
		if reservations[node_id].expiry <= now:
			reservations.erase(node_id)
			return false
		return reservations[node_id].robot_id != robot_id
	return false

func get_node_reservation_owner(node_id: String) -> String:
	var now = Time.get_ticks_msec() / 1000.0
	if reservations.has(node_id):
		if reservations[node_id].expiry > now:
			return reservations[node_id].robot_id
		else:
			reservations.erase(node_id)
	return ""

func request_edge_reservation(robot_id: String, from_node: String, to_node: String, priority: float, duration_sec: float = 3.0) -> bool:
	clean_expired()
	var now = Time.get_ticks_msec() / 1000.0
	var forward_key = "%s->%s" % [from_node, to_node]
	var reverse_key = "%s->%s" % [to_node, from_node]

	# If another robot owns the reverse edge, conflict!
	if edge_reservations.has(reverse_key):
		var rev = edge_reservations[reverse_key]
		if rev.robot_id != robot_id and rev.expiry > now:
			if priority > rev.priority:
				edge_reservations.erase(reverse_key)
			else:
				return false

	edge_reservations[forward_key] = {
		"robot_id": robot_id,
		"priority": priority,
		"expiry": now + duration_sec
	}
	return true

func release_reservation(robot_id: String, node_id: String) -> void:
	if reservations.has(node_id) and reservations[node_id].robot_id == robot_id:
		reservations.erase(node_id)

func release_all_for_robot(robot_id: String) -> void:
	var to_erase_nodes: Array[String] = []
	for n_id in reservations:
		if reservations[n_id].robot_id == robot_id:
			to_erase_nodes.append(n_id)
	for n_id in to_erase_nodes:
		reservations.erase(n_id)

	var to_erase_edges: Array[String] = []
	for e_key in edge_reservations:
		if edge_reservations[e_key].robot_id == robot_id:
			to_erase_edges.append(e_key)
	for e_key in to_erase_edges:
		edge_reservations.erase(e_key)

func clean_expired() -> void:
	var now = Time.get_ticks_msec() / 1000.0
	var to_erase_nodes: Array[String] = []
	for n_id in reservations:
		if reservations[n_id].expiry <= now:
			to_erase_nodes.append(n_id)
	for n_id in to_erase_nodes:
		reservations.erase(n_id)

	var to_erase_edges: Array[String] = []
	for e_key in edge_reservations:
		if edge_reservations[e_key].expiry <= now:
			to_erase_edges.append(e_key)
	for e_key in to_erase_edges:
		edge_reservations.erase(e_key)

func clear() -> void:
	reservations.clear()
	edge_reservations.clear()
	destination_occupancy.clear()

