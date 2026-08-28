class_name ConflictManager
extends Node

enum ConflictType {
	NODE,
	EDGE,
	HEAD_ON,
	INTERSECTION,
	PROXIMITY
}

var active_conflicts: Array = []

func detect_conflict_between_robots(robot_a: RobotAgent, robot_b: RobotAgent) -> Dictionary:
	if robot_a == null or robot_b == null or robot_a.failed or robot_b.failed:
		return {}

	# ARRIVED and MANUAL robots do not participate in path priority negotiations
	if robot_a.state == RobotAgent.RobotState.ARRIVED or robot_b.state == RobotAgent.RobotState.ARRIVED:
		return {}
	if robot_a.manual_control or robot_b.manual_control:
		return {}


	var dist = robot_a.global_position.distance_to(robot_b.global_position)
	var next_a = robot_a.get_next_path_node()
	var next_b = robot_b.get_next_path_node()

	# 1. Head-on Edge Swap Conflict (Crucial for narrow aisles)
	if next_a != "" and next_b != "":
		if (next_a == robot_b.current_node_id and next_b == robot_a.current_node_id) or \
		   (next_a == robot_b.current_node_id and dist < 120.0) or \
		   (next_b == robot_a.current_node_id and dist < 120.0):
			return {
				"type": ConflictType.HEAD_ON,
				"node_id": next_a,
				"robots": [robot_a.config.robot_id, robot_b.config.robot_id],
				"distance": dist,
				"description": "HEAD-ON AISLE CONFLICT"
			}

	# 2. Target Node Conflict (Both heading into same immediate node)
	if next_a != "" and next_b != "" and next_a == next_b:
		return {
			"type": ConflictType.NODE,
			"node_id": next_a,
			"robots": [robot_a.config.robot_id, robot_b.config.robot_id],
			"distance": dist,
			"description": "SAME TARGET NODE: " + next_a
		}

	# 3. Path Intersection Conflict (Lookahead 2 nodes along path)
	if robot_a.planned_path.size() > 0 and robot_b.planned_path.size() > 0:
		var lookahead_a = robot_a.planned_path.slice(robot_a.path_index, min(robot_a.path_index + 3, robot_a.planned_path.size()))
		var lookahead_b = robot_b.planned_path.slice(robot_b.path_index, min(robot_b.path_index + 3, robot_b.planned_path.size()))

		for n_a in lookahead_a:
			if lookahead_b.has(n_a) and dist < 220.0:
				return {
					"type": ConflictType.INTERSECTION,
					"node_id": n_a,
					"robots": [robot_a.config.robot_id, robot_b.config.robot_id],
					"distance": dist,
					"description": "INTERSECTION CONVERGENCE: " + n_a
				}

	# 4. Proximity Safety Envelope (Close proximity safety alert)
	var safe_buffer = robot_a.config.radius + robot_b.config.radius + 24.0
	if dist < safe_buffer:
		return {
			"type": ConflictType.PROXIMITY,
			"node_id": next_a if next_a != "" else robot_a.current_node_id,
			"robots": [robot_a.config.robot_id, robot_b.config.robot_id],
			"distance": dist,
			"description": "PROXIMITY SAFETY BUFFER"
		}

	return {}

func evaluate_all_conflicts(robots: Array) -> Array:
	active_conflicts.clear()
	for i in range(robots.size()):
		for j in range(i + 1, robots.size()):
			var c = detect_conflict_between_robots(robots[i], robots[j])
			if not c.is_empty():
				active_conflicts.append(c)
	return active_conflicts
