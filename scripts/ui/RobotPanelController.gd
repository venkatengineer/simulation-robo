class_name RobotPanelController
extends Control

signal set_start_requested(robot)
signal set_goal_requested(robot)
signal plan_requested(robot)
signal start_robot_requested(robot)
signal pause_robot_requested(robot)
signal manual_control_toggled(robot, enable)
signal fail_robot_requested(robot)
signal delete_robot_requested(robot)

@onready var lbl_id: Label = get_node_or_null("%LabelID")
@onready var lbl_status_badge: Label = get_node_or_null("%LabelStatusBadge")
@onready var lbl_status: Label = get_node_or_null("%LabelStatusValue")
@onready var spin_priority: SpinBox = get_node_or_null("%SpinPriority")
@onready var spin_speed: SpinBox = get_node_or_null("%SpinSpeed")
@onready var lbl_start: Label = get_node_or_null("%LabelStartValue")
@onready var lbl_goal: Label = get_node_or_null("%LabelGoalValue")
@onready var lbl_battery: Label = get_node_or_null("%LabelBatteryValue")
@onready var lbl_path: Label = get_node_or_null("%LabelPathValue")
@onready var lbl_peers: Label = get_node_or_null("%LabelPeersValue")

@onready var btn_set_start: Button = get_node_or_null("%BtnSetStart")
@onready var btn_set_goal: Button = get_node_or_null("%BtnSetGoal")
@onready var btn_plan: Button = get_node_or_null("%BtnPlan")
@onready var btn_start: Button = get_node_or_null("%BtnStart")
@onready var btn_manual: Button = get_node_or_null("%BtnManual")
@onready var btn_fail: Button = get_node_or_null("%BtnFail")
@onready var btn_delete: Button = get_node_or_null("%BtnDelete")

var current_robot: RobotAgent = null

func _ready() -> void:
	visible = false

func update_panel(robot: RobotAgent, interaction_mode_str: String = "NORMAL") -> void:
	current_robot = robot
	if robot == null or not is_instance_valid(robot):
		visible = false
		return

	visible = true
	var state_name = RobotAgent.RobotState.keys()[robot.state]

	if lbl_id: lbl_id.text = "ROBOT %s" % robot.config.robot_id
	if lbl_status: lbl_status.text = state_name

	if lbl_status_badge:
		lbl_status_badge.text = "● " + state_name
		match robot.state:
			RobotAgent.RobotState.MOVING, RobotAgent.RobotState.READY, RobotAgent.RobotState.ARRIVED:
				lbl_status_badge.add_theme_color_override("font_color", Color(0.02, 0.45, 0.3))
			RobotAgent.RobotState.WAITING, RobotAgent.RobotState.YIELDING:
				lbl_status_badge.add_theme_color_override("font_color", Color(0.85, 0.5, 0.02))
			RobotAgent.RobotState.FAILED:
				lbl_status_badge.add_theme_color_override("font_color", Color(0.85, 0.15, 0.15))
			RobotAgent.RobotState.REROUTING:
				lbl_status_badge.add_theme_color_override("font_color", Color(0.45, 0.18, 0.85))
			_:
				lbl_status_badge.add_theme_color_override("font_color", Color(0.35, 0.4, 0.5))

	if spin_priority and not spin_priority.has_focus():
		spin_priority.value = robot.config.priority
	if spin_speed and not spin_speed.has_focus():
		spin_speed.value = robot.config.speed

	if lbl_start: lbl_start.text = robot.config.start_node if robot.config.start_node != "" else "Unassigned"
	if lbl_goal: lbl_goal.text = robot.config.goal_node if robot.config.goal_node != "" else "Unassigned"
	if lbl_battery: lbl_battery.text = "%d%%" % int(robot.config.battery)

	if btn_set_start:
		btn_set_start.text = "CANCEL START" if (interaction_mode_str == "SET_START" or interaction_mode_str == "SETTING_START") else "SET START"
	if btn_set_goal:
		btn_set_goal.text = "CANCEL GOAL" if (interaction_mode_str == "SET_GOAL" or interaction_mode_str == "SETTING_GOAL") else "SET GOAL"

	if lbl_path:
		if robot.planned_path.size() > 0:
			lbl_path.text = "%d waypoints (%s...%s)" % [robot.planned_path.size(), robot.planned_path[0], robot.planned_path[-1]]
		else:
			lbl_path.text = "No Active Route"

	if lbl_peers and robot.local_world_model:
		var peers_list = robot.local_world_model.get("nearby_robots", {}).keys()
		if peers_list.size() > 0:
			lbl_peers.text = ", ".join(peers_list)
		else:
			lbl_peers.text = "Searching within 180px..."

	if btn_manual:
		btn_manual.set_pressed_no_signal(robot.manual_control)

func _on_spin_priority_value_changed(val: float) -> void:
	if current_robot and is_instance_valid(current_robot):
		current_robot.config.priority = int(val)
		current_robot.update_ui_label()

func _on_spin_speed_value_changed(val: float) -> void:
	if current_robot and is_instance_valid(current_robot):
		current_robot.config.speed = val

func _on_btn_set_start_pressed() -> void:
	if current_robot: set_start_requested.emit(current_robot)

func _on_btn_set_goal_pressed() -> void:
	if current_robot: set_goal_requested.emit(current_robot)

func _on_btn_plan_pressed() -> void:
	if current_robot:
		if current_robot.config.start_node == "" or current_robot.config.goal_node == "":
			return
		plan_requested.emit(current_robot)

func _on_btn_start_pressed() -> void:
	if current_robot:
		if current_robot.planned_path.size() == 0:
			plan_requested.emit(current_robot)
		start_robot_requested.emit(current_robot)

func _on_btn_manual_toggled(toggled_on: bool) -> void:
	if current_robot: manual_control_toggled.emit(current_robot, toggled_on)

func _on_btn_fail_pressed() -> void:
	if current_robot: fail_robot_requested.emit(current_robot)

func _on_btn_delete_pressed() -> void:
	if current_robot: delete_robot_requested.emit(current_robot)

