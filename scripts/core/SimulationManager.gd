class_name SimulationManager
extends Node

signal simulation_ticked
signal conflict_occurred(robot_a_id: String, priority_a: float, robot_b_id: String, priority_b: float, winner_id: String, loser_id: String, reason: String)

var graph_manager: GraphManager
var robot_manager: RobotManager
var task_manager: TaskManager
var coordination_manager: CoordinationManager
var metrics_manager: MetricsManager

var comm_manager: CommunicationManager = CommunicationManager.new()
var collision_manager: CollisionAvoidanceManager = CollisionAvoidanceManager.new()
var movement_controller: RobotMovementController = RobotMovementController.new()

var is_running: bool = false
var comm_timer: float = 0.0

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
		var robots = robot_manager.get_all_robots()
		for robot in robots:
			if is_instance_valid(robot) and not robot.failed and not robot.manual_control:
				if robot.state != RobotAgent.RobotState.ARRIVED:
					if robot.planned_path.is_empty():
						plan_path_for_robot(robot)
					robot.set_state(RobotAgent.RobotState.MOVING)

func start_simulation() -> void:
	start_all()

func pause_simulation() -> void:
	is_running = false
	if robot_manager:
		for robot in robot_manager.get_all_robots():
			if is_instance_valid(robot) and robot.state == RobotAgent.RobotState.MOVING:
				robot.velocity = Vector2.ZERO

func reset_simulation() -> void:
	is_running = false
	if robot_manager:
		var robots = robot_manager.get_all_robots()
		for robot in robots:
			robot.set_state(RobotAgent.RobotState.READY)
			robot.planned_path.clear()
			robot.previous_path.clear()
			robot.path_index = 0
			robot.waiting_time = 0.0
			robot.reroute_display_timer = 0.0
			robot.is_stuck = false
			robot.velocity = Vector2.ZERO
			if robot.config.start_node != "" and graph_manager:
				var node = graph_manager.get_graph_node(robot.config.start_node)
				if node:
					robot.set_start_node(node.id, node.position)

		# Immediately re-plan paths so visualization and destination markers are ready
		plan_paths_for_all_robots()

	if coordination_manager:
		coordination_manager.reservation_manager.clear()
		coordination_manager.deadlock_detector.clear_all()
	if metrics_manager:
		metrics_manager.reset()

func plan_paths_for_all_robots() -> void:
	if robot_manager == null or graph_manager == null:
		return
	for robot in robot_manager.get_all_robots():
		if is_instance_valid(robot) and not robot.failed and robot.config.goal_node != "":
			plan_path_for_robot(robot)

func plan_path_for_robot(robot: RobotAgent) -> bool:
	if robot == null or robot.config.start_node == "" or robot.config.goal_node == "" or graph_manager == null:
		return false

	if metrics_manager:
		metrics_manager.a_star_searches += 1

	var start_id = robot.current_node_id if robot.current_node_id != "" else robot.config.start_node
	var goal_id = robot.config.goal_node

	# Check if destination is already occupied by an arrived robot
	var res_mgr = coordination_manager.reservation_manager if coordination_manager else null
	if res_mgr and res_mgr.is_destination_occupied(goal_id, robot.config.robot_id):
		var wait_node_id = res_mgr.find_nearest_waiting_node(goal_id, robot.config.robot_id, graph_manager, robot_manager)
		if wait_node_id != "" and wait_node_id != start_id:
			robot.waiting_target_goal = goal_id
			robot.wait_reason = "GOAL_OCCUPIED"
			var path_to_wait = graph_manager.find_path(start_id, wait_node_id)
			if path_to_wait.size() > 0:
				robot.planned_path = path_to_wait
				robot.path_index = 0
				if robot.planned_path[-1] != wait_node_id:
					robot.planned_path.append(wait_node_id)
				robot.set_state(RobotAgent.RobotState.MOVING if is_running else RobotAgent.RobotState.READY)
				return true
		elif wait_node_id == start_id:
			# Already at safe waiting node!
			robot.waiting_target_goal = goal_id
			robot.wait_reason = "GOAL_OCCUPIED"
			robot.planned_path.clear()
			robot.set_state(RobotAgent.RobotState.WAITING)
			robot.velocity = Vector2.ZERO
			return true

	var path = graph_manager.find_path(start_id, goal_id)
	if path.size() > 0:
		robot.planned_path = path
		robot.path_index = 0
		# Strict Path-Goal Consistency Check
		if robot.planned_path[-1] != goal_id:
			robot.planned_path.append(goal_id)
		robot.set_state(RobotAgent.RobotState.MOVING if is_running else RobotAgent.RobotState.READY)
		return true
	else:
		robot.planned_path.clear()
		return false

func find_alternative_station(current_goal: String, robot_id: String) -> String:
	var res_mgr = coordination_manager.reservation_manager if coordination_manager else null
	if res_mgr == null or graph_manager == null:
		return ""

	var candidates: Array[String] = []
	match current_goal:
		"N01", "N02": candidates = ["N51", "N52", "N09", "N10"] # Pickup A -> Charging or Dock A
		"N09", "N10": candidates = ["N59", "N60", "N01", "N02"] # Dock A -> Dock B or Pickup A
		"N51", "N52": candidates = ["N01", "N02", "N59", "N60"] # Charging -> Pickup A or Dock B
		"N59", "N60": candidates = ["N09", "N10", "N51", "N52"] # Dock B -> Dock A or Charging
		_:
			var node = graph_manager.get_graph_node(current_goal)
			if node:
				for n_id in graph_manager.nodes:
					if n_id != current_goal and graph_manager.is_node_valid(n_id):
						var other_n = graph_manager.get_graph_node(n_id)
						if other_n and other_n.position.distance_to(node.position) < 180.0:
							candidates.append(n_id)

	for c in candidates:
		if not res_mgr.is_destination_occupied(c, robot_id) and graph_manager.is_node_valid(c):
			return c

	return ""

func _physics_process(delta: float) -> void:
	if not is_running or robot_manager == null or coordination_manager == null:
		return

	var robots = robot_manager.get_all_robots()

	# 1. Decentralized Communication & Local Knowledge Sync (10Hz)
	comm_timer += delta
	if comm_timer >= 0.1:
		comm_timer = 0.0
		for robot in robots:
			if is_instance_valid(robot) and not robot.failed:
				comm_manager.broadcast(robot, robots, RobotMessage.MessageType.POSITION_UPDATE)

	# 2. Coordination & Deadlock Cycle Evaluation
	coordination_manager.update_coordination(robots, robot_manager, delta)

	var active_conflicts = coordination_manager.evaluate_conflicts(robots)
	if metrics_manager:
		metrics_manager.active_conflicts = active_conflicts.size()

	# 3. Handle Conflicts & Priority Negotiations (Excludes ARRIVED and FAILED robots)
	for conflict in active_conflicts:
		var robot_a = robot_manager.get_robot(conflict.robots[0])
		var robot_b = robot_manager.get_robot(conflict.robots[1])
		if robot_a and robot_b and not robot_a.failed and not robot_b.failed:
			if robot_a.state == RobotAgent.RobotState.ARRIVED or robot_b.state == RobotAgent.RobotState.ARRIVED:
				continue

			var res = coordination_manager.compare_priority(robot_a, robot_b)
			var winner: RobotAgent = res.winner
			var loser: RobotAgent = res.loser

			# Emit conflict event for visual overlay
			conflict_occurred.emit(
				robot_a.config.robot_id, res.priority_a,
				robot_b.config.robot_id, res.priority_b,
				winner.config.robot_id, loser.config.robot_id,
				res.reason
			)

			# Winner continues with priority
			if winner.state == RobotAgent.RobotState.WAITING or winner.state == RobotAgent.RobotState.YIELDING:
				winner.set_state(RobotAgent.RobotState.MOVING)

			var is_head_on = (conflict.get("type", -1) == ConflictManager.ConflictType.HEAD_ON)
			var winner_next = winner.get_next_path_node()
			var loser_next = loser.get_next_path_node()

			# Head-On or In-Path Conflict Resolution
			if is_head_on or loser.current_node_id == winner_next or loser_next == winner.current_node_id:
				if loser.state != RobotAgent.RobotState.REROUTING:
					loser.set_state(RobotAgent.RobotState.REROUTING)
					var blocked = {}
					if winner.current_node_id != "": blocked[winner.current_node_id] = true
					if winner_next != "": blocked[winner_next] = true
					var rerouted = coordination_manager.request_reroute(loser, blocked)
					if not rerouted:
						loser.set_state(RobotAgent.RobotState.YIELDING)
			elif loser.state == RobotAgent.RobotState.MOVING:
				loser.set_state(RobotAgent.RobotState.YIELDING)
				if loser.waiting_time > 1.2:
					var blocked = {}
					if winner_next != "": blocked[winner_next] = true
					coordination_manager.request_reroute(loser, blocked)

	# 4. Auto-Resume Waiting Robots & Yield Timeout Rerouting
	for robot in robots:
		if not is_instance_valid(robot) or robot.failed:
			continue

		if robot.state == RobotAgent.RobotState.WAITING and robot.wait_reason == "GOAL_OCCUPIED":
			# Destination Queue Monitor: check if original goal is free
			var orig_goal = robot.waiting_target_goal if robot.waiting_target_goal != "" else robot.config.goal_node
			var res_mgr = coordination_manager.reservation_manager if coordination_manager else null
			if res_mgr and orig_goal != "":
				if not res_mgr.is_destination_occupied(orig_goal, robot.config.robot_id):
					# Destination is free! Clear wait reason, plan direct path, and move into goal
					robot.waiting_target_goal = ""
					robot.wait_reason = ""
					robot.destination_wait_timer = 0.0
					robot.config.goal_node = orig_goal
					plan_path_for_robot(robot)
					robot.set_state(RobotAgent.RobotState.MOVING)
				else:
					robot.destination_wait_timer += delta
					if robot.destination_wait_timer >= 3.0:
						var alt_goal = find_alternative_station(orig_goal, robot.config.robot_id)
						if alt_goal != "" and alt_goal != orig_goal:
							robot.waiting_target_goal = ""
							robot.wait_reason = ""
							robot.destination_wait_timer = 0.0
							robot.config.goal_node = alt_goal
							plan_path_for_robot(robot)
							robot.set_state(RobotAgent.RobotState.MOVING)

		elif (robot.state == RobotAgent.RobotState.WAITING or robot.state == RobotAgent.RobotState.YIELDING) and robot.planned_path.size() > 0:
			robot.yield_timer += delta
			robot.waiting_time += delta

			var in_active_conflict = false
			for c in active_conflicts:
				if c.robots.has(robot.config.robot_id):
					in_active_conflict = true
					break

			if not in_active_conflict:
				var next_node_id = robot.get_next_path_node()
				if next_node_id != "":
					if not coordination_manager.reservation_manager.is_node_reserved_by_other(next_node_id, robot.config.robot_id):
						robot.set_state(RobotAgent.RobotState.MOVING)
			elif robot.yield_timer >= 2.0:
				# Yield timeout exceeded -> Trigger dynamic reroute to avoid infinite wait
				push_warning("YIELD TIMEOUT on Robot %s -> Rerouting around conflict" % robot.config.robot_id)
				robot.set_state(RobotAgent.RobotState.REROUTING)
				var blocked = {}
				for c in active_conflicts:
					if c.robots.has(robot.config.robot_id):
						for other_id in c.robots:
							if other_id != robot.config.robot_id:
								var other = robot_manager.get_robot(other_id)
								if other and other.current_node_id != "": blocked[other.current_node_id] = true
								if other and other.get_next_path_node() != "": blocked[other.get_next_path_node()] = true
				if blocked.is_empty():
					var next_n = robot.get_next_path_node()
					if next_n != "": blocked[next_n] = true
				coordination_manager.request_reroute(robot, blocked)
				robot.yield_timer = 0.0

	# 4.5. Stuck Detection & Autonomous Recovery (Only for active moving robots)
	for robot in robots:
		if not is_instance_valid(robot) or robot.failed or robot.state != RobotAgent.RobotState.MOVING:
			continue
		if robot.check_stuck(delta):
			push_warning("STUCK DETECTED on Robot %s -> Stopping, invalidating path, rerouting" % robot.config.robot_id)
			robot.set_state(RobotAgent.RobotState.REROUTING)
			robot.velocity = Vector2.ZERO
			var blocked = {}
			var next_n = robot.get_next_path_node()
			if next_n != "": blocked[next_n] = true
			coordination_manager.request_reroute(robot, blocked)

	# 5. Movement Execution Pipeline per Frame
	for robot in robots:
		if not is_instance_valid(robot) or robot.failed:
			continue

		if robot.state == RobotAgent.RobotState.ARRIVED:
			robot.velocity = Vector2.ZERO
			continue

		# If simulation is running and robot is READY with a planned path, set to MOVING
		if robot.state == RobotAgent.RobotState.READY and robot.planned_path.size() > 0:
			robot.set_state(RobotAgent.RobotState.MOVING)

		if robot.state == RobotAgent.RobotState.MOVING or robot.state == RobotAgent.RobotState.REROUTING:
			# Advance through waypoints if already within threshold of current target node
			while robot.path_index < robot.planned_path.size():
				var curr_target_id = robot.planned_path[robot.path_index]
				var curr_target_node = graph_manager.get_graph_node(curr_target_id)
				if curr_target_node and robot.global_position.distance_to(curr_target_node.position) < 14.0:
					robot.current_node_id = curr_target_id
					coordination_manager.release_reservation(robot.config.robot_id, curr_target_id)

					# Did we reach the waiting node for an occupied goal?
					if robot.waiting_target_goal != "" and curr_target_id != robot.waiting_target_goal:
						if robot.path_index >= robot.planned_path.size() - 1:
							robot.set_state(RobotAgent.RobotState.WAITING)
							robot.wait_reason = "GOAL_OCCUPIED"
							robot.velocity = Vector2.ZERO
							robot.destination_wait_timer = 0.0
							break
						else:
							robot.path_index += 1
							continue

					if curr_target_id == robot.config.goal_node or robot.path_index >= robot.planned_path.size() - 1:
						# Goal reached!
						robot.set_state(RobotAgent.RobotState.ARRIVED)
						robot.velocity = Vector2.ZERO
						coordination_manager.reservation_manager.register_arrival(curr_target_id, robot.config.robot_id)
						coordination_manager.reservation_manager.release_all_for_robot(robot.config.robot_id)
						if metrics_manager:
							metrics_manager.completed_tasks_count += 1
						break
					else:
						robot.path_index += 1
				else:
					break


			if robot.state == RobotAgent.RobotState.ARRIVED:
				continue

			var next_node_id = robot.get_next_path_node()
			if next_node_id != "" and graph_manager:
				var next_node = graph_manager.get_graph_node(next_node_id)
				if next_node:
					# Check node validity against static obstacles
					if not graph_manager.is_node_valid(next_node_id):
						robot.set_state(RobotAgent.RobotState.REROUTING)
						coordination_manager.request_reroute(robot, { next_node_id: true })
						continue

					# Pre-Intersection Reservation Check
					var eff_p = float(robot.config.priority) + (robot.waiting_time * 0.2)
					if next_node.type == GraphNodeData.NodeType.INTERSECTION:
						if not coordination_manager.request_reservation_with_priority(robot.config.robot_id, eff_p, next_node_id, 2.0):
							robot.set_state(RobotAgent.RobotState.WAITING)
							continue

					var dir = (next_node.position - robot.global_position)
					var desired_vel = dir.normalized() * robot.config.speed
					var safe_vel = collision_manager.process_movement(robot, robots, desired_vel, delta)
					movement_controller.apply_movement(robot, safe_vel, delta)

	simulation_ticked.emit()
