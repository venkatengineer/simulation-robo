class_name UIManager
extends Control

signal demo_mode_pressed
signal start_all_pressed
signal pause_all_pressed
signal reset_pressed
signal add_robot_pressed
signal scenario_selected(index: int)
signal mode_changed(mode: String)
signal debug_mode_toggled(enabled: bool)
signal path_visibility_changed(mode: int)

@onready var btn_demo_mode: Button = get_node_or_null("%BtnDemoMode")
@onready var btn_start_all: Button = get_node_or_null("%BtnStartAll")
@onready var btn_pause: Button = get_node_or_null("%BtnPause")
@onready var btn_reset: Button = get_node_or_null("%BtnReset")
@onready var btn_mode_select: Button = get_node_or_null("%BtnModeSelect")
@onready var btn_block_aisle: Button = get_node_or_null("%BtnBlockAisle")
@onready var btn_add_robot: Button = get_node_or_null("%BtnAddRobot")
@onready var opt_scenarios: OptionButton = get_node_or_null("%OptScenarios")
@onready var opt_path_visibility: OptionButton = get_node_or_null("%OptPathVisibility")
@onready var chk_debug_mode: CheckButton = get_node_or_null("%ChkDebugMode")
@onready var status_badge: Label = get_node_or_null("%StatusBadge")


@onready var robot_panel: RobotPanelController = get_node_or_null("%RobotPanel")
@onready var dashboard: DashboardController = get_node_or_null("%Dashboard")
@onready var conflict_overlay: ConflictOverlayController = get_node_or_null("%ConflictOverlay")

func _ready() -> void:
	if btn_demo_mode: btn_demo_mode.pressed.connect(func(): demo_mode_pressed.emit())
	if btn_start_all: btn_start_all.pressed.connect(func():
		set_simulation_running(true)
		start_all_pressed.emit()
	)
	if btn_pause: btn_pause.pressed.connect(func():
		set_simulation_running(false)
		pause_all_pressed.emit()
	)
	if btn_reset: btn_reset.pressed.connect(func():
		set_simulation_running(false)
		reset_pressed.emit()
	)
	if btn_add_robot: btn_add_robot.pressed.connect(func(): add_robot_pressed.emit())
	if btn_mode_select: btn_mode_select.pressed.connect(func(): mode_changed.emit("SELECT"))
	if btn_block_aisle: btn_block_aisle.pressed.connect(func(): mode_changed.emit("BLOCK_AISLE"))
	if chk_debug_mode: chk_debug_mode.toggled.connect(func(en): debug_mode_toggled.emit(en))

	# Populate Scenario Dropdown
	if opt_scenarios:
		opt_scenarios.clear()
		opt_scenarios.add_item("Scenario 1: Basic Fleet", 1)
		opt_scenarios.add_item("Scenario 2: Intersection Conflict", 2)
		opt_scenarios.add_item("Scenario 3: Congested Warehouse", 3)
		opt_scenarios.add_item("Scenario 4: Blocked Aisle", 4)
		opt_scenarios.add_item("Scenario 5: Manual Intrusion", 5)
		opt_scenarios.add_item("Scenario 6: Robot Failure", 6)
		opt_scenarios.add_item("Scenario 7: Obstacle Clearance Benchmark", 7)
		opt_scenarios.item_selected.connect(func(idx): scenario_selected.emit(opt_scenarios.get_item_id(idx)))

	# Populate Path Visibility Dropdown
	if opt_path_visibility:
		opt_path_visibility.clear()
		opt_path_visibility.add_item("PATHS: ALL", 0)
		opt_path_visibility.add_item("PATHS: SELECTED", 1)
		opt_path_visibility.add_item("PATHS: OFF", 2)
		opt_path_visibility.item_selected.connect(func(idx): path_visibility_changed.emit(opt_path_visibility.get_item_id(idx)))


func set_simulation_running(running: bool) -> void:
	if status_badge:
		if running:
			status_badge.text = "RUNNING ●"
			status_badge.add_theme_color_override("font_color", Color(0.06, 0.72, 0.5))
		else:
			status_badge.text = "PAUSED ○"
			status_badge.add_theme_color_override("font_color", Color(0.85, 0.5, 0.02))


