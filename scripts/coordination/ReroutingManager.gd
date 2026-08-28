class_name ReroutingManager
extends Node

var planner: Object
var graph_manager: Object
var reroute_count: int = 0

func _init(p_planner: Object = null, p_graph_manager: Object = null):
	planner = p_planner
	graph_manager = p_graph_manager

func request_reroute(robot: RobotAgent, blocked_nodes: Dictionary = {}) -> bool:
	if robot == null or robot.config.goal_node == "" or robot.failed:
		return false

	var start_id = robot.current_node_id
	if start_id == "":
		start_id = robot.get_next_path_node()

	if start_id == "":
		return false

	if planner == null:
		return false

	# Save old path for visual rerouting demonstration
	robot.previous_path = robot.planned_path.duplicate()
	robot.reroute_display_timer = 3.5

	var new_path = planner.find_path(start_id, robot.config.goal_node, { "blocked_nodes": blocked_nodes })
	if new_path.size() > 0:
		robot.planned_path = new_path
		robot.path_index = 0
		robot.set_state(RobotAgent.RobotState.REROUTING)
		reroute_count += 1
		return true

	# Fallback: Try with unblocked search if target goal is reachable
	var fallback_path = planner.find_path(start_id, robot.config.goal_node, {})
	if fallback_path.size() > 0 and fallback_path != robot.previous_path:
		robot.planned_path = fallback_path
		robot.path_index = 0
		robot.set_state(RobotAgent.RobotState.REROUTING)
		reroute_count += 1
		return true

	robot.set_state(RobotAgent.RobotState.WAITING)
	return false
