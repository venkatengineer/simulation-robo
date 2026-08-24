class_name DeadlockDetector
extends Node

signal deadlock_detected(cycle: Array, winner: RobotAgent, losers: Array)

var wait_for_graph: Dictionary = {} # waiting_robot_id -> blocking_robot_id
var wait_timers: Dictionary = {} # waiting_robot_id -> float
const WAIT_TIMEOUT: float = 1.5

func update_wait_for(waiting_id: String, blocking_id: String, delta: float) -> void:
	if waiting_id == "" or blocking_id == "" or waiting_id == blocking_id:
		return

	wait_for_graph[waiting_id] = blocking_id
	wait_timers[waiting_id] = wait_timers.get(waiting_id, 0.0) + delta

func clear_wait_for(waiting_id: String) -> void:
	wait_for_graph.erase(waiting_id)
	wait_timers.erase(waiting_id)

func clear_all() -> void:
	wait_for_graph.clear()
	wait_timers.clear()

func evaluate_deadlocks(robot_manager: RobotManager) -> void:
	if robot_manager == null:
		return

	var cycles = find_all_cycles()
	for cycle in cycles:
		var timed_out = true
		for r_id in cycle:
			if wait_timers.get(r_id, 0.0) < WAIT_TIMEOUT:
				timed_out = false
				break

		if timed_out and cycle.size() > 0:
			resolve_cycle(cycle, robot_manager)

func find_all_cycles() -> Array:
	var detected_cycles = []
	var visited = {}

	for start_node in wait_for_graph.keys():
		var path = []
		var current = start_node

		while current != "" and wait_for_graph.has(current):
			if path.has(current):
				# Cycle detected
				var cycle_start_index = path.find(current)
				var cycle = path.slice(cycle_start_index)
				if not contains_cycle(detected_cycles, cycle):
					detected_cycles.append(cycle)
				break
			path.append(current)
			current = wait_for_graph.get(current, "")

	return detected_cycles

func contains_cycle(all_cycles: Array, target_cycle: Array) -> bool:
	for c in all_cycles:
		if c.size() == target_cycle.size():
			var match_count = 0
			for node in target_cycle:
				if c.has(node):
					match_count += 1
			if match_count == c.size():
				return true
	return false

func resolve_cycle(cycle: Array, robot_manager: RobotManager) -> void:
	var cycle_robots: Array[RobotAgent] = []
	var highest_eff_priority: float = -1.0
	var winner: RobotAgent = null

	for r_id in cycle:
		var r = robot_manager.get_robot(r_id)
		if r and is_instance_valid(r):
			cycle_robots.append(r)
			# Effective Priority = Base Priority + 0.5 * Waiting Time
			var eff_p = r.config.priority + (r.waiting_time * 0.5)
			if eff_p > highest_eff_priority:
				highest_eff_priority = eff_p
				winner = r

	if winner == null and cycle_robots.size() > 0:
		winner = cycle_robots[0]

	var losers: Array = []
	for r in cycle_robots:
		if r != winner:
			losers.append(r)

	if winner and losers.size() > 0:
		deadlock_detected.emit(cycle, winner, losers)
		# Clear wait entries for resolved cycle
		for r_id in cycle:
			clear_wait_for(r_id)
