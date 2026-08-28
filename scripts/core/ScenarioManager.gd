class_name ScenarioManager
extends Node

signal conflict_alert_triggered(robot_a: String, priority_a: float, robot_b: String, priority_b: float, winner: String, loser: String, reason: String)
signal demo_stage_announced(stage_number: int, stage_title: String, description: String)

var warehouse_manager: WarehouseManager
var graph_manager: GraphManager
var robot_manager: RobotManager
var sim_manager: SimulationManager

var is_demo_mode_active: bool = false
var demo_step: int = 0
var demo_timer: float = 0.0

func initialize(p_warehouse: WarehouseManager, p_graph: GraphManager, p_robot_mgr: RobotManager, p_sim: SimulationManager) -> void:
	warehouse_manager = p_warehouse
	graph_manager = p_graph
	robot_manager = p_robot_mgr
	sim_manager = p_sim

func setup(p_warehouse: WarehouseManager, p_robot_mgr: RobotManager, p_sim: SimulationManager) -> void:
	var g_mgr = p_warehouse.graph_manager if p_warehouse else null
	initialize(p_warehouse, g_mgr, p_robot_mgr, p_sim)

func load_scenario(scenario_index: int) -> void:
	is_demo_mode_active = false
	if sim_manager:
		sim_manager.reset_simulation()
	if graph_manager:
		graph_manager.load_industrial_warehouse_graph()
	if robot_manager:
		robot_manager.clear()
	if sim_manager and sim_manager.task_manager:
		sim_manager.task_manager.clear()

	match scenario_index:
		1: setup_basic_fleet()
		2: setup_intersection_conflict()
		3: setup_congested_warehouse()
		4: setup_blocked_aisle()
		5: setup_manual_intrusion()
		6: setup_robot_failure()
		7: setup_obstacle_clearance_benchmark()
		_: setup_intersection_conflict()

	# Immediately plan paths for all robots so routes and destination markers are displayed
	if sim_manager:
		sim_manager.plan_paths_for_all_robots()

	# Auto-select primary robot for inspector detail
	if robot_manager:
		var robots = robot_manager.get_all_robots()
		if robots.size() > 0:
			robot_manager.select_robot(robots[0].config.robot_id)

# SCENARIO 1: BASIC MULTI-ROBOT FLEET
func setup_basic_fleet() -> void:
	var r1 = robot_manager.create_robot("N01", 10, "R01")
	var n1 = graph_manager.get_graph_node("N01")
	if n1: r1.set_start_node("N01", n1.position)
	r1.set_goal_node("N10")

	var r2 = robot_manager.create_robot("N51", 7, "R02")
	var n2 = graph_manager.get_graph_node("N51")
	if n2: r2.set_start_node("N51", n2.position)
	r2.set_goal_node("N60")

	var r3 = robot_manager.create_robot("N21", 5, "R03")
	var n3 = graph_manager.get_graph_node("N21")
	if n3: r3.set_start_node("N21", n3.position)
	r3.set_goal_node("N30")

# SCENARIO 2: INTERSECTION CONFLICT & PRIORITY RESOLUTION
func setup_intersection_conflict() -> void:
	# R01 travels North-to-South through intersection N25
	var r1 = robot_manager.create_robot("N05", 10, "R01")
	var n1 = graph_manager.get_graph_node("N05")
	if n1: r1.set_start_node("N05", n1.position)
	r1.set_goal_node("N55")

	# R02 travels West-to-East across intersection N25 (Lower priority)
	var r2 = robot_manager.create_robot("N21", 6, "R02")
	var n2 = graph_manager.get_graph_node("N21")
	if n2: r2.set_start_node("N21", n2.position)
	r2.set_goal_node("N29")

	# R03 on side aisle
	var r3 = robot_manager.create_robot("N31", 5, "R03")
	var n3 = graph_manager.get_graph_node("N31")
	if n3: r3.set_start_node("N31", n3.position)
	r3.set_goal_node("N40")

# SCENARIO 3: CONGESTED WAREHOUSE (6-8 ROBOTS DETERMINISTIC BENCHMARK)
func setup_congested_warehouse() -> void:
	var start_goal_pairs = [
		["N01", "N27", 10],
		["N51", "N14", 8],
		["N21", "N32", 7],
		["N30", "N08", 6],
		["N60", "N41", 5],
		["N50", "N19", 4]
	]

	for i in range(start_goal_pairs.size()):
		var id = "R%02d" % (i + 1)
		var pair = start_goal_pairs[i]
		var r = robot_manager.create_robot(pair[0], pair[2], id)
		var node = graph_manager.get_graph_node(pair[0])
		if node: r.set_start_node(pair[0], node.position)
		r.set_goal_node(pair[1])


# SCENARIO 4: BLOCKED AISLE & DYNAMIC REROUTING
func setup_blocked_aisle() -> void:
	var r1 = robot_manager.create_robot("N11", 10, "R01")
	var n1 = graph_manager.get_graph_node("N11")
	if n1: r1.set_start_node("N11", n1.position)
	r1.set_goal_node("N20")

	# Block the main central aisle edge (N14 - N15)
	if graph_manager:
		graph_manager.toggle_edge_blocked("N14", "N15")

# SCENARIO 5: MANUAL INTRUSION & ADAPTIVE FLEET
func setup_manual_intrusion() -> void:
	setup_basic_fleet()
	var r1 = robot_manager.get_robot("R01")
	if r1:
		r1.set_manual_control(true)

# SCENARIO 6: ROBOT FAILURE & TASK REALLOCATION
func setup_robot_failure() -> void:
	setup_basic_fleet()
	# Create a delivery task assigned to R03
	if sim_manager and sim_manager.task_manager:
		var task = sim_manager.task_manager.create_task("N21", "N30", 8)
		sim_manager.task_manager.assign_task(task.id, "R03")

	# Trigger simulated failure on R03 after short delay or immediately
	var r3 = robot_manager.get_robot("R03")
	if r3:
		r3.fail()
# SCENARIO 7: OBSTACLE CLEARANCE BENCHMARK (ROUTE A vs ROUTE B)
func setup_obstacle_clearance_benchmark() -> void:
	# Robot R01 is tasked with travelling from N12 (410, 260) to N34 (630, 520)
	# Direct Euclidean diagonal (Route A) would cut across Rack 2 (x: 435..495, y: 290..360) and Rack 3 (x: 545..605, y: 420..490)
	# Valid Aisle route (Route B) navigates around the storage racks through valid cross-junction aisles.
	var r1 = robot_manager.create_robot("N12", 10, "R01")
	var n1 = graph_manager.get_graph_node("N12")
	if n1: r1.set_start_node("N12", n1.position)
	r1.set_goal_node("N34")

	var r2 = robot_manager.create_robot("N03", 8, "R02")
	var n2 = graph_manager.get_graph_node("N03")
	if n2: r2.set_start_node("N03", n2.position)
	r2.set_goal_node("N45")

# 10-STAGE GUIDED HACKATHON DEMO MODE
func start_demo_mode() -> void:

	load_scenario(2) # Start with intersection scenario
	is_demo_mode_active = true
	demo_step = 1
	demo_timer = 0.0
	demo_stage_announced.emit(1, "1. NORMAL MULTI-ROBOT FLEET", "Autonomous AMRs calculating local paths with A*")
	if sim_manager:
		sim_manager.start_simulation()

func _process(delta: float) -> void:
	if not is_demo_mode_active:
		return

	demo_timer += delta

	match demo_step:
		1: # Normal navigation
			if demo_timer >= 2.5:
				demo_step = 2
				demo_timer = 0.0
				demo_stage_announced.emit(2, "2. CONFLICT PREDICTION", "Predicting path intersection at Node N25")
		2: # Conflict resolution
			if demo_timer >= 3.0:
				demo_step = 3
				demo_timer = 0.0
				demo_stage_announced.emit(3, "3. PRIORITY NEGOTIATION", "R01 (Priority 10) takes Right-of-Way. R02 (Priority 6) yields.")
				var r1 = robot_manager.get_robot("R01")
				var r2 = robot_manager.get_robot("R02")
				if r1 and r2:
					conflict_alert_triggered.emit(
						r1.config.robot_id, float(r1.config.priority),
						r2.config.robot_id, float(r2.config.priority),
						r1.config.robot_id, r2.config.robot_id,
						"R01 Priority 10 > R02 Priority 6"
					)
		3: # Communication demonstration
			if demo_timer >= 3.5:
				demo_step = 4
				demo_timer = 0.0
				demo_stage_announced.emit(4, "4. PEER-TO-PEER COMMUNICATION", "Exchanging local world models and node reservations")
				var r1 = robot_manager.get_robot("R01")
				if r1:
					robot_manager.select_robot(r1.config.robot_id)
		4: # Dynamic Rerouting
			if demo_timer >= 4.0:
				demo_step = 5
				demo_timer = 0.0
				demo_stage_announced.emit(5, "5. DYNAMIC REROUTING", "Blocking aisle N24-N25. R02 recalculates optimal route.")
				if graph_manager:
					graph_manager.toggle_edge_blocked("N24", "N25")
				var r2 = robot_manager.get_robot("R02")
				if r2 and sim_manager and sim_manager.coordination_manager:
					sim_manager.coordination_manager.request_reroute(r2, { "N25": true })
		5: # Deadlock Formation & Detection
			if demo_timer >= 4.5:
				demo_step = 6
				demo_timer = 0.0
				demo_stage_announced.emit(6, "6. DEADLOCK DETECTION & RECOVERY", "Wait-For graph cycle evaluated. Highest priority robot proceeds.")
		6: # Robot Failure & Task Reallocation
			if demo_timer >= 4.5:
				demo_step = 7
				demo_timer = 0.0
				demo_stage_announced.emit(7, "7. HARDWARE FAILURE ADAPTATION", "R03 encounters hardware failure. Fleet adapts.")
				var r3 = robot_manager.get_robot("R03")
				if r3:
					r3.fail()
					if sim_manager and sim_manager.task_manager:
						sim_manager.task_manager.handle_robot_failure("R03", robot_manager, sim_manager)
		7: # Fleet Completes Operation
			if demo_timer >= 5.0:
				demo_step = 8
				demo_timer = 0.0
				demo_stage_announced.emit(8, "8. FLEET COORDINATION COMPLETE", "Zero collisions. All autonomous tasks fulfilled successfully.")
		8:
			if demo_timer >= 4.0:
				is_demo_mode_active = false
