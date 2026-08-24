extends Node2D

@onready var warehouse_manager: WarehouseManager = %WarehouseManager if has_node("%WarehouseManager") else get_node_or_null("WarehouseManager")
@onready var graph_manager: GraphManager = %GraphManager if has_node("%GraphManager") else get_node_or_null("GraphManager")
@onready var robot_manager: RobotManager = %RobotManager if has_node("%RobotManager") else get_node_or_null("RobotManager")
@onready var task_manager: TaskManager = %TaskManager if has_node("%TaskManager") else get_node_or_null("TaskManager")
@onready var coordination_manager: CoordinationManager = %CoordinationManager if has_node("%CoordinationManager") else get_node_or_null("CoordinationManager")
@onready var metrics_manager: MetricsManager = %MetricsManager if has_node("%MetricsManager") else get_node_or_null("MetricsManager")
@onready var simulation_manager: SimulationManager = %SimulationManager if has_node("%SimulationManager") else get_node_or_null("SimulationManager")
@onready var scenario_manager: ScenarioManager = %ScenarioManager if has_node("%ScenarioManager") else get_node_or_null("ScenarioManager")
@onready var debug_manager: DebugManager = %DebugManager if has_node("%DebugManager") else get_node_or_null("DebugManager")
@onready var input_controller: InputController = %InputController if has_node("%InputController") else get_node_or_null("InputController")
@onready var ui: UIManager = %UI if has_node("%UI") else get_node_or_null("CanvasLayerUI/UI")

func _ready() -> void:
	if ui == null or simulation_manager == null or graph_manager == null or robot_manager == null:
		push_error("Critical UI or Manager nodes missing in Main scene.")
		return

	# 1. Initialize Graph & Managers
	graph_manager.load_industrial_warehouse_graph()
	robot_manager.initialize(graph_manager)
	
	simulation_manager.initialize(
		graph_manager,
		robot_manager,
		task_manager,
		coordination_manager,
		metrics_manager
	)

	if scenario_manager:
		scenario_manager.initialize(warehouse_manager, graph_manager, robot_manager, simulation_manager)
		scenario_manager.conflict_alert_triggered.connect(_on_conflict_alert_triggered)

	if debug_manager:
		var res_mgr = coordination_manager.reservation_manager if coordination_manager else null
		debug_manager.setup(
			graph_manager,
			robot_manager,
			simulation_manager.comm_manager,
			res_mgr
		)

	if input_controller:
		input_controller.setup(graph_manager, robot_manager)
		input_controller.mode_changed.connect(_on_input_mode_changed)

	# 2. Bind Top Bar UI Signals
	ui.demo_mode_pressed.connect(_on_demo_mode_pressed)
	ui.start_all_pressed.connect(_on_start_all)
	ui.pause_all_pressed.connect(_on_pause_all)
	ui.reset_pressed.connect(_on_reset)
	ui.add_robot_pressed.connect(_on_add_robot)
	ui.scenario_selected.connect(_on_scenario_selected)
	ui.mode_changed.connect(_on_mode_changed)
	ui.debug_mode_toggled.connect(_on_debug_mode_toggled)

	robot_manager.robot_selected.connect(_on_robot_selected)

	# 3. Bind Robot Panel Signals directly to InputController
	var rp = ui.robot_panel
	if rp:
		rp.set_start_requested.connect(func(r):
			if input_controller.current_mode == InputController.InteractionMode.SET_START:
				input_controller.cancel_mode()
			else:
				input_controller.set_mode(InputController.InteractionMode.SET_START)
		)
		rp.set_goal_requested.connect(func(r):
			if input_controller.current_mode == InputController.InteractionMode.SET_GOAL:
				input_controller.cancel_mode()
			else:
				input_controller.set_mode(InputController.InteractionMode.SET_GOAL)
		)
		rp.plan_requested.connect(func(r): simulation_manager.plan_path_for_robot(r))
		rp.start_robot_requested.connect(func(r):
			simulation_manager.plan_path_for_robot(r)
			simulation_manager.is_running = true
		)
		rp.manual_control_toggled.connect(func(r, en): r.set_manual_control(en))
		rp.fail_robot_requested.connect(func(r): r.fail())
		rp.delete_robot_requested.connect(func(r): robot_manager.delete_robot(r.config.robot_id))

	simulation_manager.simulation_ticked.connect(_on_simulation_ticked)

	# 4. Load Scenario 2 (Intersection Conflict) for immediate demo readiness
	if scenario_manager:
		scenario_manager.load_scenario(2)

func _on_demo_mode_pressed() -> void:
	if scenario_manager:
		scenario_manager.start_demo_mode()

func _on_start_all() -> void:
	if simulation_manager:
		simulation_manager.start_all()

func _on_pause_all() -> void:
	if simulation_manager:
		simulation_manager.pause_simulation()

func _on_reset() -> void:
	if simulation_manager:
		simulation_manager.reset_simulation()

func _on_add_robot() -> void:
	if graph_manager and robot_manager:
		var r = robot_manager.add_robot("N01", 5)
		var node = graph_manager.get_graph_node("N01")
		if node:
			r.set_start_node("N01", node.position)
			r.set_goal_node("N60")
		robot_manager.select_robot(r.config.robot_id)

func _on_scenario_selected(scenario_index: int) -> void:
	if scenario_manager:
		scenario_manager.load_scenario(scenario_index)

func _on_mode_changed(mode_name: String) -> void:
	if input_controller:
		match mode_name:
			"BLOCK_AISLE": input_controller.set_mode(InputController.InteractionMode.BLOCK_CELL)
			_: input_controller.set_mode(InputController.InteractionMode.NORMAL)

func _on_input_mode_changed(mode_str: String) -> void:
	var sel = robot_manager.get_selected_robot() if robot_manager else null
	if ui and ui.robot_panel and sel:
		ui.robot_panel.update_panel(sel, mode_str)

func _on_debug_mode_toggled(enabled: bool) -> void:
	if debug_manager:
		debug_manager.toggle_debug_mode(enabled)
	if input_controller:
		input_controller.show_input_debug = enabled

func _on_conflict_alert_triggered(robot_a_id: String, priority_a: float, robot_b_id: String, priority_b: float, winner_id: String, loser_id: String) -> void:
	if ui and ui.conflict_overlay:
		ui.conflict_overlay.show_conflict_alert(robot_a_id, priority_a, robot_b_id, priority_b, winner_id, loser_id)

func _on_robot_selected(robot: RobotAgent) -> void:
	if ui and ui.robot_panel:
		var mode_str = InputController.InteractionMode.keys()[input_controller.current_mode] if input_controller else "NORMAL"
		ui.robot_panel.update_panel(robot, mode_str)

func _on_simulation_ticked() -> void:
	if ui and ui.dashboard:
		ui.dashboard.update_dashboard(simulation_manager)
	if ui and ui.robot_panel and robot_manager:
		var sel = robot_manager.get_selected_robot()
		if sel:
			var mode_str = InputController.InteractionMode.keys()[input_controller.current_mode] if input_controller else "NORMAL"
			ui.robot_panel.update_panel(sel, mode_str)
