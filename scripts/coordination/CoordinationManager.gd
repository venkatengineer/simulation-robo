class_name CoordinationManager
extends Node

signal deadlock_resolved_event(msg: String)
signal conflict_resolved_event(winner: RobotAgent, loser: RobotAgent, reason: String)

var priority_manager: PriorityManager = PriorityManager.new()
var conflict_manager: ConflictManager = ConflictManager.new()
var reservation_manager: ReservationManager = ReservationManager.new()
var deadlock_detector: DeadlockDetector = DeadlockDetector.new()
var rerouting_manager: ReroutingManager

func initialize(planner: AStarPlanner, graph_manager: GraphManager) -> void:
	rerouting_manager = ReroutingManager.new(planner, graph_manager)
	add_child(priority_manager)
	add_child(conflict_manager)
	add_child(reservation_manager)
	add_child(deadlock_detector)
	add_child(rerouting_manager)

	deadlock_detector.deadlock_detected.connect(_on_deadlock_detected)

func update_coordination(robots: Array, robot_manager: RobotManager, delta: float) -> void:
	# 1. Evaluate Conflicts
	var active_conflicts = evaluate_conflicts(robots)

	# 2. Update Wait-For Graph for any robot currently waiting on another
	for conflict in active_conflicts:
		var r_a = robot_manager.get_robot(conflict.robots[0])
		var r_b = robot_manager.get_robot(conflict.robots[1])
		if r_a and r_b:
			var p_res = compare_priority(r_a, r_b)
			var winner: RobotAgent = p_res.winner
			var loser: RobotAgent = p_res.loser

			deadlock_detector.update_wait_for(loser.config.robot_id, winner.config.robot_id, delta)

	# 3. Check for Deadlock Cycles
	deadlock_detector.evaluate_deadlocks(robot_manager)

func evaluate_conflicts(robots: Array) -> Array:
	return conflict_manager.evaluate_all_conflicts(robots)

func compare_priority(robot_a: RobotAgent, robot_b: RobotAgent) -> Dictionary:
	return priority_manager.compare_priority(robot_a, robot_b)

func request_reservation(robot_id: String, node_id: String, duration_sec: float = 2.5) -> bool:
	return reservation_manager.request_reservation(robot_id, node_id, duration_sec)

func request_reservation_with_priority(robot_id: String, priority: float, node_id: String, duration_sec: float = 2.5) -> bool:
	return reservation_manager.request_reservation_with_priority(robot_id, priority, node_id, duration_sec)

func release_reservation(robot_id: String, node_id: String) -> void:
	reservation_manager.release_reservation(robot_id, node_id)

func request_reroute(robot: RobotAgent, blocked_nodes: Dictionary = {}) -> bool:
	if rerouting_manager:
		return rerouting_manager.request_reroute(robot, blocked_nodes)
	return false

func _on_deadlock_detected(cycle: Array, winner: RobotAgent, losers: Array) -> void:
	var eff_p = float(winner.config.priority) + (winner.waiting_time * 0.2)
	var msg = "DEADLOCK DETECTED: %s -> WINNER: %s (Priority %.1f)" % [str(cycle), winner.config.robot_id, eff_p]
	deadlock_resolved_event.emit(msg)

	# Winner continues
	winner.set_state(RobotAgent.RobotState.MOVING)

	# Losers yield and reroute around blocked conflict nodes
	for loser in losers:
		if is_instance_valid(loser):
			loser.set_state(RobotAgent.RobotState.REROUTING)
			var blocked_nodes = {}
			var next_n = winner.get_next_path_node()
			if next_n != "":
				blocked_nodes[next_n] = true
			if winner.current_node_id != "":
				blocked_nodes[winner.current_node_id] = true
			request_reroute(loser, blocked_nodes)
