class_name ReroutingManager
extends Node

var planner: Object
var graph_manager: Object
var reroute_count: int = 0

func _init(p_planner: Object = null, p_graph_manager: Object = null):
	planner = p_planner
	graph_manager = p_graph_manager

func request_reroute(robot, blocked_nodes: Dictionary = {}) -> bool:
	if robot == null or robot.config.goal_node == "" or robot.failed:
		return false

	# Always start reroute from robot's CURRENT position so blocked next_node doesn't fail search
	var start_id = robot.current_node_id
	if start_id == "":
		start_id = robot.get_next_path_node()

	if start_id == "":
		return false

	if planner == null:
		return false

	var new_path = planner.find_path(start_id, robot.config.goal_node, { "blocked_nodes": blocked_nodes })
	if new_path.size() > 0:
		robot.planned_path = new_path
		robot.path_index = 0
		robot.set_state(robot.RobotState.MOVING)
		reroute_count += 1
		return true

	# Fallback: If no alternate path found with blocked_nodes, try clearing next node and rerouting
	var fallback_path = planner.find_path(start_id, robot.config.goal_node, {})
	if fallback_path.size() > 0:
		robot.planned_path = fallback_path
		robot.path_index = 0
		robot.set_state(robot.RobotState.MOVING)
		return true

	robot.set_state(robot.RobotState.WAITING)
	return false
