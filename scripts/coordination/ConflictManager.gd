class_name ConflictManager
extends Node

enum ConflictType {
	NODE,
	EDGE,
	HEAD_ON,
	INTERSECTION
}

var active_conflicts: Array = []

func detect_conflict_between_robots(robot_a, robot_b) -> Dictionary:
	if robot_a == null or robot_b == null or robot_a.failed or robot_b.failed:
		return {}

	if robot_a.planned_path.size() == 0 or robot_b.planned_path.size() == 0:
		return {}

	var next_a = robot_a.get_next_path_node()
	var next_b = robot_b.get_next_path_node()

	if next_a == "" or next_b == "":
		return {}

	# 1. Target Node Conflict
	if next_a == next_b:
		return {
			"type": ConflictType.NODE,
			"node_id": next_a,
			"robots": [robot_a.config.robot_id, robot_b.config.robot_id]
		}

	# 2. Head-on Edge Swap Conflict
	if next_a == robot_b.current_node_id and next_b == robot_a.current_node_id:
		return {
			"type": ConflictType.HEAD_ON,
			"edge": "%s-%s" % [robot_a.current_node_id, robot_b.current_node_id],
			"robots": [robot_a.config.robot_id, robot_b.config.robot_id]
		}

	# 3. Proximity Safety Radius Overlap
	var dist = robot_a.global_position.distance_to(robot_b.global_position)
	if dist < (robot_a.config.radius + robot_b.config.radius + 10.0):
		return {
			"type": ConflictType.NODE,
			"node_id": next_a,
			"robots": [robot_a.config.robot_id, robot_b.config.robot_id]
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
