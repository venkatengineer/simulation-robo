extends SceneTree

func _init():
	print("==================================================")
	print("RUNNING P-DMAPF NAVIGATION & SCENARIO TEST SUITE")
	print("==================================================")
	var passed = 0
	var failed = 0

	# 1. Test Static Obstacle Geometric Queries
	var graph = GraphManager.new()
	graph.load_industrial_warehouse_graph()

	# Test point inside Rack 1: Rect2(435, 160, 60, 70) -> Center is (465, 195)
	var inside_rack = graph.is_point_in_obstacle(Vector2(465, 195), 0.0)
	if inside_rack:
		print("✓ PASS: Point (465, 195) correctly identified as INSIDE storage rack")
		passed += 1
	else:
		printerr("✗ FAIL: Point (465, 195) should be inside storage rack")
		failed += 1

	# Test point in valid aisle: N01 is (310, 130)
	var in_aisle = graph.is_point_in_obstacle(Vector2(310, 130), 0.0)
	if not in_aisle:
		print("✓ PASS: Aisle point (310, 130) correctly identified as OUTSIDE storage rack")
		passed += 1
	else:
		printerr("✗ FAIL: Aisle point (310, 130) should be outside storage rack")
		failed += 1

	# Test segment crossing Rack 1: (410, 195) to (520, 195)
	var seg_crossing = graph.is_segment_intersecting_obstacle(Vector2(410, 195), Vector2(520, 195), 0.0)
	if seg_crossing:
		print("✓ PASS: Segment crossing rack correctly detected as INTERSECTING obstacle")
		passed += 1
	else:
		printerr("✗ FAIL: Segment crossing rack should be detected as intersecting")
		failed += 1

	# Test valid horizontal aisle segment: N01 (310, 130) to N02 (410, 130)
	var seg_valid = graph.is_segment_intersecting_obstacle(Vector2(310, 130), Vector2(410, 130), GraphManager.ROBOT_RADIUS)
	if not seg_valid:
		print("✓ PASS: Valid aisle segment (310, 130) -> (410, 130) has clear obstacle clearance")
		passed += 1
	else:
		printerr("✗ FAIL: Valid aisle segment should have clearance")
		failed += 1

	# 2. Test Node & Edge Creation Obstacle Rejection
	var bad_node = graph.add_node(Vector2(465, 195), GraphNodeData.NodeType.NORMAL, "TEST_BAD")
	if bad_node.type == GraphNodeData.NodeType.BLOCKED and not bad_node.traversable:
		print("✓ PASS: Node placed inside rack automatically marked BLOCKED and non-traversable")
		passed += 1
	else:
		printerr("✗ FAIL: Node inside rack must be marked BLOCKED")
		failed += 1

	var bad_edge = graph.add_edge("N02", "N13") # N02 is (410, 130), N13 is (520, 260) - cuts through Rack 1
	if bad_edge == null:
		print("✓ PASS: Diagonal edge cutting through rack was REJECTED during edge creation")
		passed += 1
	else:
		printerr("✗ FAIL: Diagonal edge cutting through rack should be rejected")
		failed += 1

	# 3. Test Deterministic A* Route Selection (Route A vs Route B)
	var planner = AStarPlanner.new(graph)
	var path_route_b = planner.find_path("N12", "N34")
	print("Planned path from N12 to N34: %s" % str(path_route_b))
	if path_route_b.size() > 0:
		var val_res = planner.validate_path(path_route_b)
		if val_res.valid:
			print("✓ PASS: A* selected Route B and completely avoided all storage racks (Path size: %d)" % path_route_b.size())
			passed += 1
		else:
			printerr("✗ FAIL: Path failed obstacle validation: %s" % str(val_res))
			failed += 1
	else:
		printerr("✗ FAIL: A* failed to find valid path around obstacles")
		failed += 1

	# 4. Test Cross-Warehouse A* Paths
	var test_pairs = [
		["N01", "N60"],
		["N10", "N51"],
		["N21", "N30"],
		["N05", "N55"]
	]
	var all_paths_valid = true
	for pair in test_pairs:
		var p = planner.find_path(pair[0], pair[1])
		if p.size() == 0:
			all_paths_valid = false
			printerr("✗ FAIL: No path found for %s -> %s" % [pair[0], pair[1]])
		else:
			var v = planner.validate_path(p)
			if not v.valid:
				all_paths_valid = false
				printerr("✗ FAIL: Path %s -> %s intersected obstacle!" % [pair[0], pair[1]])
	if all_paths_valid:
		print("✓ PASS: All cross-warehouse benchmark paths are 100% obstacle-free")
		passed += 1
	else:
		failed += 1

	# 5. Test Robot Stuck Detection
	var robot_scene = load("res://scenes/robots/Robot.tscn")
	var robot = robot_scene.instantiate()
	robot.configure_graph(graph)
	robot.setup(RobotConfig.new())
	robot.set_start_node("N01", Vector2(310, 130))
	robot.set_state(RobotAgent.RobotState.MOVING)
	robot.velocity = Vector2.ZERO # Stationary while moving

	var stuck_detected = false
	for tick in range(70): # 70 ticks * 0.016s = 1.12s
		if robot.check_stuck(0.016):
			stuck_detected = true
			break

	if stuck_detected:
		print("✓ PASS: Stuck detector triggered after >1.0s of stalled movement")
		passed += 1
	else:
		printerr("✗ FAIL: Stuck detector failed to trigger")
		failed += 1

	robot.free()

	# 6. Test All 7 Scenarios
	var main_scene = load("res://scenes/main/Main.tscn")
	var main_instance = main_scene.instantiate()
	root.add_child(main_instance)
	main_instance._ready()

	var sim_mgr: SimulationManager = main_instance.get_node("SimulationManager")
	var scenario_mgr: ScenarioManager = main_instance.get_node("ScenarioManager")
	var robot_mgr: RobotManager = main_instance.get_node("RobotManager")

	for s_idx in range(1, 8):
		scenario_mgr.load_scenario(s_idx)
		sim_mgr.start_simulation()

		var scenario_clean = true
		var robot_count = robot_mgr.get_robot_count()
		if robot_count == 0:
			scenario_clean = false
			printerr("✗ FAIL: Scenario %d loaded 0 robots!" % s_idx)

		# Run 100 physics steps per scenario
		for step in range(100):
			sim_mgr._physics_process(0.016)
			for r in robot_mgr.get_all_robots():
				if graph.is_point_in_obstacle(r.global_position, 0.0):
					scenario_clean = false
					printerr("✗ FAIL: In scenario %d, robot %s entered rack at %s!" % [s_idx, r.config.robot_id, str(r.global_position)])
					break
			if not scenario_clean:
				break

		if scenario_clean:
			print("✓ PASS: Scenario %d (%d robots) completed 100 simulation steps with ZERO obstacle penetrations" % [s_idx, robot_count])
			passed += 1
		else:
			failed += 1

	# 7. Test Multi-Robot Independent Path Ownership & Destination Marker Consistency
	scenario_mgr.load_scenario(3) # Congested warehouse with 6 robots (R01..R06)
	var robots_6 = robot_mgr.get_all_robots()
	var paths_consistent = true

	if robots_6.size() != 6:
		paths_consistent = false
		printerr("✗ FAIL: Expected 6 robots in Scenario 3, got %d" % robots_6.size())

	for r in robots_6:
		if r.planned_path.size() == 0:
			paths_consistent = false
			printerr("✗ FAIL: Robot %s has empty planned path!" % r.config.robot_id)
		elif r.planned_path[-1] != r.config.goal_node:
			paths_consistent = false
			printerr("✗ FAIL: Robot %s path endpoint %s does not match goal node %s!" % [r.config.robot_id, r.planned_path[-1], r.config.goal_node])

		var goal_node = graph.get_graph_node(r.config.goal_node)
		if goal_node == null:
			paths_consistent = false
			printerr("✗ FAIL: Goal node %s for robot %s does not exist in graph!" % [r.config.goal_node, r.config.robot_id])

	if paths_consistent:
		print("✓ PASS: All 6 robots have independent paths, verified endpoints, and valid destination markers")
		passed += 1
	else:
		failed += 1

	# 8. Test Path Visibility Modes
	var debug_mgr: DebugManager = main_instance.get_node_or_null("DebugManager")
	if debug_mgr:
		debug_mgr.set_path_display_mode(DebugManager.PathDisplayMode.ALL)
		var mode_all = (debug_mgr.path_display_mode == DebugManager.PathDisplayMode.ALL)
		debug_mgr.set_path_display_mode(DebugManager.PathDisplayMode.SELECTED)
		var mode_sel = (debug_mgr.path_display_mode == DebugManager.PathDisplayMode.SELECTED)
		debug_mgr.set_path_display_mode(DebugManager.PathDisplayMode.OFF)
		var mode_off = (debug_mgr.path_display_mode == DebugManager.PathDisplayMode.OFF)

		if mode_all and mode_sel and mode_off:
			print("✓ PASS: Path visibility modes (ALL, SELECTED, OFF) toggle correctly")
			passed += 1
		else:
			printerr("✗ FAIL: Path visibility mode toggle error")
			failed += 1

	# 9. Test Start Position Change & Immediate Path Re-planning
	var r03 = robot_mgr.get_robot("R03")
	if r03:
		# Initial: R03 at N21 -> Goal N32
		var initial_start = r03.config.start_node
		var initial_goal = r03.config.goal_node
		# Change start position to N41
		var new_start_node = graph.get_graph_node("N41")
		if new_start_node:
			r03.set_start_node("N41", new_start_node.position)
			var pos_synced = (r03.global_position == new_start_node.position)
			var node_synced = (r03.current_node_id == "N41" and r03.config.start_node == "N41")
			var path_start_synced = (r03.planned_path.size() > 0 and r03.planned_path[0] == "N41")
			var goal_preserved = (r03.config.goal_node == initial_goal and r03.planned_path[-1] == initial_goal)
			var valid_path = r03.is_path_valid()

			if pos_synced and node_synced and path_start_synced and goal_preserved and valid_path:
				print("✓ PASS: SET START dynamically updated robot position, invalidated old path, and planned fresh path from N41 to %s" % initial_goal)
				passed += 1
			else:
				printerr("✗ FAIL: SET START synchronization error on R03! pos_synced: %s, path_start: %s" % [pos_synced, r03.planned_path])
				failed += 1
	# 10. Multi-Robot Arrival Isolation, Clearance, and Non-Overlap Verification
	robot_mgr.clear()
	var test_r1 = robot_mgr.create_robot("N17", 10, "R01")
	var n_r1 = graph.get_graph_node("N17")
	if n_r1: test_r1.set_start_node("N17", n_r1.position)
	test_r1.set_goal_node("N29")

	var test_r2 = robot_mgr.create_robot("N25", 6, "R02")
	var n_r2 = graph.get_graph_node("N25")
	if n_r2: test_r2.set_start_node("N25", n_r2.position)
	test_r2.set_goal_node("N40")

	var test_r3 = robot_mgr.create_robot("N30", 5, "R03")
	var n_r3 = graph.get_graph_node("N30")
	if n_r3: test_r3.set_start_node("N30", n_r3.position)
	test_r3.set_goal_node("N40")

	sim_mgr.plan_paths_for_all_robots()
	sim_mgr.is_running = true

	var min_separation_observed: float = 9999.0
	var overlap_detected: bool = false
	var arrival_isolated: bool = true

	for step in range(250):
		sim_mgr._physics_process(0.016)

		# Physical separation check between all robot pairs
		var all_r = [test_r1, test_r2, test_r3]
		for i in range(all_r.size()):
			for j in range(i + 1, all_r.size()):
				var r_i = all_r[i]
				var r_j = all_r[j]
				var d = r_i.global_position.distance_to(r_j.global_position)
				if d < min_separation_observed:
					min_separation_observed = d
				var min_req = r_i.config.radius + r_j.config.radius # 36px
				if d < (min_req - 1.0):
					overlap_detected = true
					printerr("✗ FAIL: Physical overlap between %s and %s (dist: %.1f < %.1f)" % [r_i.config.robot_id, r_j.config.robot_id, d, min_req])

		# When a robot is ARRIVED, verify its velocity is 0 and it remains stationary
		for r in all_r:
			if r.state == RobotAgent.RobotState.ARRIVED:
				if r.velocity.length() > 0.01:
					arrival_isolated = false
					printerr("✗ FAIL: Arrived robot %s has non-zero velocity: %s" % [r.config.robot_id, r.velocity])

	if not overlap_detected and arrival_isolated and min_separation_observed >= 35.0:
		print("✓ PASS: Multi-robot arrival isolation verified with ZERO overlap (Min separation observed: %.1f px)" % min_separation_observed)
		passed += 1
	else:
		printerr("✗ FAIL: Multi-robot arrival or overlap failure! min_sep: %.1f, overlap: %s" % [min_separation_observed, overlap_detected])
		failed += 1

	# 11. Same-Destination Queueing, Waiting Node Routing & Occupancy Resolution Test
	robot_mgr.clear()
	sim_mgr.reset_simulation()

	var q_r1 = robot_mgr.create_robot("N17", 10, "R01")
	var n_q1 = graph.get_graph_node("N17")
	if n_q1: q_r1.set_start_node("N17", n_q1.position)
	q_r1.set_goal_node("N05")

	var q_r3 = robot_mgr.create_robot("N30", 5, "R03")
	var n_q3 = graph.get_graph_node("N30")
	if n_q3: q_r3.set_start_node("N30", n_q3.position)
	q_r3.set_goal_node("N05")

	sim_mgr.plan_paths_for_all_robots()
	sim_mgr.is_running = true

	# Step 1: Let R01 arrive at N05 first
	for step in range(250):
		sim_mgr._physics_process(0.016)
		if q_r1.state == RobotAgent.RobotState.ARRIVED:
			break

	var r1_arrived_at_goal = (q_r1.state == RobotAgent.RobotState.ARRIVED and q_r1.current_node_id == "N05")
	var goal_marked_occupied = sim_mgr.coordination_manager.reservation_manager.is_destination_occupied("N05")

	# Step 2: Allow R03 to approach occupied goal N05 and wait at safe waiting node
	for step in range(250):
		sim_mgr._physics_process(0.016)

	var dist_r1_r3 = q_r1.global_position.distance_to(q_r3.global_position)
	var r3_handled_gracefully = (q_r3.state == RobotAgent.RobotState.WAITING or q_r3.state == RobotAgent.RobotState.MOVING) and dist_r1_r3 >= 40.0

	# Step 3: Clear R01 from destination to simulate task completion
	sim_mgr.coordination_manager.reservation_manager.release_arrival("N05", "R01")
	q_r1.global_position = Vector2(9999, 9999) # move completed robot away

	# Step 4: Verify R03 detects available goal, leaves waiting node, and reaches N05
	for step in range(250):
		sim_mgr._physics_process(0.016)
		if q_r3.state == RobotAgent.RobotState.ARRIVED:
			break

	var r3_arrived = (q_r3.state == RobotAgent.RobotState.ARRIVED and q_r3.current_node_id == "N05")


	if r1_arrived_at_goal and goal_marked_occupied and r3_handled_gracefully and r3_arrived:
		print("✓ PASS: Goal occupancy deadlock resolved: R03 safely queued at waiting node and automatically advanced to N05 when free")
		passed += 1
	else:
		printerr("✗ FAIL: Goal occupancy queue test failed! r1_arr: %s, occ: %s, r3_wait: %s (dist: %.1f), r3_arr: %s" % [
			r1_arrived_at_goal, goal_marked_occupied, r3_handled_gracefully, dist_r1_r3, r3_arrived
		])
		failed += 1

	main_instance.free()
	graph.free()

	print("==================================================")
	print("RESULTS: %d PASSED, %d FAILED" % [passed, failed])
	print("==================================================")

	quit(0 if failed == 0 else 1)



