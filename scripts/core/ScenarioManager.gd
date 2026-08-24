class_name ScenarioManager
extends Node

signal conflict_alert_triggered(robot_a, priority_a, robot_b, priority_b, winner, loser)

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
	if sim_manager: sim_manager.reset_simulation()
	if graph_manager: graph_manager.load_industrial_warehouse_graph()
	if robot_manager: robot_manager.clear()

	match scenario_index:
		1: setup_basic_fleet()
		2: setup_intersection_conflict()
		3: setup_congested_warehouse()
		4: setup_blocked_aisle()
		5: setup_manual_intrusion()
		6: setup_robot_failure()
		_: setup_intersection_conflict()

func setup_basic_fleet() -> void:
	var r1 = robot_manager.create_robot("N01", 10, "R01")
	r1.set_start_node("N01", Vector2(350, 180))
	r1.set_goal_node("N06")

	var r2 = robot_manager.create_robot("N19", 7, "R02")
	r2.set_start_node("N19", Vector2(350, 720))
	r2.set_goal_node("N24")

	var r3 = robot_manager.create_robot("N07", 5, "R03")
	r3.set_start_node("N07", Vector2(350, 360))
	r3.set_goal_node("N12")

func setup_intersection_conflict() -> void:
	var r1 = robot_manager.create_robot("N01", 10, "R01")
	r1.set_start_node("N01", Vector2(350, 180))
	r1.set_goal_node("N24")

	var r2 = robot_manager.create_robot("N19", 7, "R02")
	r2.set_start_node("N19", Vector2(350, 720))
	r2.set_goal_node("N06")

	var r3 = robot_manager.create_robot("N13", 5, "R03")
	r3.set_start_node("N13", Vector2(690, 540))
	r3.set_goal_node("N18")

func setup_congested_warehouse() -> void:
	for i in range(1, 7):
		var id = "R0%d" % i
		var start_id = "N%02d" % (i * 3)
		var goal_id = "N%02d" % (25 - i * 3)
		var r = robot_manager.create_robot(start_id, 11 - i, id)
		if graph_manager:
			var node = graph_manager.get_graph_node(start_id)
			if node: r.set_start_node(start_id, node.position)
		r.set_goal_node(goal_id)

func setup_blocked_aisle() -> void:
	setup_intersection_conflict()
	if graph_manager:
		graph_manager.toggle_edge_blocked("N14", "N15")

func setup_manual_intrusion() -> void:
	setup_basic_fleet()
	var r1 = robot_manager.get_all_robots()[0]
	if r1: r1.set_manual_control(true)

func setup_robot_failure() -> void:
	setup_intersection_conflict()
	var r3 = robot_manager.get_all_robots()[2]
	if r3: r3.fail()

func start_demo_mode() -> void:
	load_scenario(2)
	is_demo_mode_active = true
	demo_step = 0
	demo_timer = 0.0

func _process(delta: float) -> void:
	if not is_demo_mode_active:
		return

	demo_timer += delta

	if demo_step == 0 and demo_timer >= 1.0:
		demo_step = 1
		if sim_manager: sim_manager.start_simulation()
	elif demo_step == 1 and demo_timer >= 4.0:
		demo_step = 2
		var r1 = robot_manager.get_robot("R01")
		var r2 = robot_manager.get_robot("R02")
		if r1 and r2:
			conflict_alert_triggered.emit(r1.config.robot_id, r1.config.priority, r2.config.robot_id, r2.config.priority, r1.config.robot_id, r2.config.robot_id)
	elif demo_step == 2 and demo_timer >= 10.0:
		is_demo_mode_active = false
