class_name SimulationManager
extends Node

signal simulation_ticked

var graph_manager: GraphManager
var robot_manager: RobotManager
var task_manager: TaskManager
var coordination_manager: CoordinationManager
var metrics_manager: MetricsManager

var comm_manager: CommunicationManager = CommunicationManager.new()
var collision_manager: CollisionAvoidanceManager = CollisionAvoidanceManager.new()
var movement_controller: RobotMovementController = RobotMovementController.new()

var is_running: bool = false

func _ready() -> void:
	add_child(comm_manager)
	add_child(collision_manager)
	add_child(movement_controller)

func initialize(
	graph: GraphManager,
	robots: RobotManager,
	tasks: TaskManager,
	coordination: CoordinationManager,
	metrics: MetricsManager
) -> void:
	graph_manager = graph
	robot_manager = robots
	task_manager = tasks
	coordination_manager = coordination
	metrics_manager = metrics

	if coordination_manager and graph_manager:
		var planner = AStarPlanner.new(graph_manager)
		coordination_manager.initialize(planner, graph_manager)

func start_all() -> void:
	is_running = true
	if robot_manager:
		robot_manager.start_all_robots()
		var robots = robot_manager.get_all_robots()
		for robot in robots:
			if is_instance_valid(robot) and (robot.state == RobotAgent.RobotState.PLANNING or robot.state == RobotAgent.RobotState.READY or robot.state == RobotAgent.RobotState.IDLE):
				plan_path_for_robot(robot)

func start_simulation() -> void:
	start_all()

func pause_simulation() -> void:
	is_running = false

func reset_simulation() -> void:
	is_running = false
	if robot_manager:
		var robots = robot_manager.get_all_robots()
		for robot in robots:
			robot.set_state(RobotAgent.RobotState.READY)
			robot.planned_path.clear()
			robot.path_index = 0
			if robot.config.start_node != "" and graph_manager:
				var node = graph_manager.get_graph_node(robot.config.start_node)
				if node:
					robot.set_start_node(node.id, node.position)

	if coordination_manager:
		coordination_manager.reservation_manager.clear()
		coordination_manager.deadlock_detector.clear_all()
	if metrics_manager:
		metrics_manager.reset()

func plan_path_for_robot(robot: RobotAgent) -> bool:
	if robot == null or robot.config.start_node == "" or robot.config.goal_node == "" or graph_manager == null:
		return false

	if metrics_manager:
		metrics_manager.a_star_searches += 1

	var path = graph_manager.find_path(robot.config.start_node, robot.config.goal_node)
	if path.size() > 0:
		robot.planned_path = path
		robot.path_index = 0
		robot.set_state(RobotAgent.RobotState.MOVING)
		return true
	return false

func _physics_process(delta: float) -> void:
	if not is_running or robot_manager == null or coordination_manager == null:
		return

	var robots = robot_manager.get_all_robots()
	
	# 1. Decentralized Communication & Local Knowledge Sync
	for robot in robots:
		comm_manager.broadcast(robot, robots, RobotMessage.MessageType.POSITION_UPDATE)

	# 2. Coordination & Deadlock Cycle Evaluation
	coordination_manager.update_coordination(robots, robot_manager, delta)

	var active_conflicts = coordination_manager.evaluate_conflicts(robots)
	if metrics_manager:
		metrics_manager.active_conflicts = active_conflicts.size()

	# 3. Handle Conflicts & Priority Negotiations
	for conflict in active_conflicts:
		var robot_a = robot_manager.get_robot(conflict.robots[0])
		var robot_b = robot_manager.get_robot(conflict.robots[1])
		if robot_a and robot_b:
			var res = coordination_manager.compare_priority(robot_a, robot_b)
			var winner: RobotAgent = res.winner
			var loser: RobotAgent = res.loser

			# HIGHER PRIORITY WINNER CONTINUES MOVING
			if winner.state == RobotAgent.RobotState.WAITING or winner.state == RobotAgent.RobotState.YIELDING:
				winner.set_state(RobotAgent.RobotState.MOVING)

			var is_head_on = (conflict.get("type", -1) == ConflictManager.ConflictType.HEAD_ON)
			var winner_next = winner.get_next_path_node()
			var loser_next = loser.get_next_path_node()

			# HEAD-ON / IN-PATH CONFLICT: Force lower-priority loser to REROUTE into adjacent aisle immediately
			if is_head_on or loser.current_node_id == winner_next or loser_next == winner.current_node_id:
				if loser.state != RobotAgent.RobotState.REROUTING:
					loser.set_state(RobotAgent.RobotState.REROUTING)
					var blocked_nodes = {}
					if winner.current_node_id != "": blocked_nodes[winner.current_node_id] = true
					if winner_next != "": blocked_nodes[winner_next] = true
					coordination_manager.request_reroute(loser, blocked_nodes)
			elif loser.state == RobotAgent.RobotState.MOVING:
				loser.set_state(RobotAgent.RobotState.WAITING)
				if loser.waiting_time > 1.0:
					var blocked_nodes = {}
					if winner_next != "": blocked_nodes[winner_next] = true
					coordination_manager.request_reroute(loser, blocked_nodes)

	# 3.5 Auto-Resume Waiting Robots when Path / Intersection Clears
	for robot in robots:
		if robot.failed or robot.planned_path.size() == 0:
			continue

		if robot.state == RobotAgent.RobotState.WAITING or robot.state == RobotAgent.RobotState.YIELDING:
			var in_conflict = false
			for c in active_conflicts:
				if c.robots.has(robot.config.robot_id):
					in_conflict = true
					break

			if not in_conflict:
				var next_node_id = robot.get_next_path_node()
				if next_node_id != "":
					if not coordination_manager.reservation_manager.is_node_reserved_by_other(next_node_id, robot.config.robot_id):
						robot.set_state(RobotAgent.RobotState.MOVING)

	# 4. Movement Execution Pipeline per Frame
	for robot in robots:
		if robot.failed:
			continue

		if robot.state == RobotAgent.RobotState.MOVING or robot.state == RobotAgent.RobotState.REROUTING:
			var next_node_id = robot.get_next_path_node()
			if next_node_id != "" and graph_manager:
				var next_node = graph_manager.get_graph_node(next_node_id)
				if next_node:
					# Pre-Intersection Locking: Priority-aware reservation check
					if next_node.type == GraphNodeData.NodeType.INTERSECTION:
						var eff_priority = robot.config.priority + (robot.waiting_time * 0.5)
						if not coordination_manager.request_reservation_with_priority(robot.config.robot_id, eff_priority, next_node_id):
							robot.set_state(RobotAgent.RobotState.WAITING)
							continue

					var dir = (next_node.position - robot.global_position)
					var dist = dir.length()

					if dist < 8.0:
						robot.current_node_id = next_node_id
						coordination_manager.release_reservation(robot.config.robot_id, next_node_id)
						robot.path_index += 1

						if robot.path_index >= robot.planned_path.size():
							robot.set_state(RobotAgent.RobotState.ARRIVED)
							robot.velocity = Vector2.ZERO
							continue

					var desired_vel = dir.normalized() * robot.config.speed
					var safe_vel = collision_manager.process_movement(robot, robots, desired_vel, delta)
					movement_controller.apply_movement(robot, safe_vel, delta)

	simulation_ticked.emit()
