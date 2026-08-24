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

@onready var lbl_id: Label = get_node_or_null("VBoxContainer/Header/LabelID")
@onready var lbl_status: Label = get_node_or_null("VBoxContainer/Grid/LabelStatusValue")
@onready var spin_priority: SpinBox = get_node_or_null("VBoxContainer/Grid/SpinPriority")
@onready var lbl_start: Label = get_node_or_null("VBoxContainer/Grid/LabelStartValue")
@onready var lbl_goal: Label = get_node_or_null("VBoxContainer/Grid/LabelGoalValue")
@onready var lbl_path: Label = get_node_or_null("VBoxContainer/Grid/LabelPathValue")
@onready var spin_speed: SpinBox = get_node_or_null("VBoxContainer/Grid/SpinSpeed")

@onready var btn_set_start: Button = get_node_or_null("VBoxContainer/BtnSetStart")
@onready var btn_set_goal: Button = get_node_or_null("VBoxContainer/BtnSetGoal")
@onready var btn_plan: Button = get_node_or_null("VBoxContainer/BtnPlan")
@onready var btn_start: Button = get_node_or_null("VBoxContainer/BtnStart")

var current_robot: RobotAgent = null

func _ready() -> void:
	visible = false

func update_panel(robot: RobotAgent, interaction_mode_str: String = "NORMAL") -> void:
	current_robot = robot
	if robot == null:
		visible = false
		return

	visible = true
	if lbl_id: lbl_id.text = "ROBOT %s" % robot.config.robot_id
	if lbl_status: lbl_status.text = RobotAgent.RobotState.keys()[robot.state]
	if spin_priority: spin_priority.value = robot.config.priority
	if lbl_start: lbl_start.text = robot.config.start_node if robot.config.start_node != "" else "None"
	if lbl_goal: lbl_goal.text = robot.config.goal_node if robot.config.goal_node != "" else "None"
	if spin_speed: spin_speed.value = robot.config.speed

	if btn_set_start:
		btn_set_start.text = "CANCEL START" if (interaction_mode_str == "SET_START" or interaction_mode_str == "SETTING_START") else "SET START"
	if btn_set_goal:
		btn_set_goal.text = "CANCEL DESTINATION" if (interaction_mode_str == "SET_GOAL" or interaction_mode_str == "SETTING_GOAL") else "SET GOAL"

	if lbl_path:
		if robot.planned_path.size() > 0:
			lbl_path.text = "%d nodes (%s...%s)" % [robot.planned_path.size(), robot.planned_path[0], robot.planned_path[-1]]
		else:
			lbl_path.text = "No Path"

func _on_spin_priority_value_changed(val: float) -> void:
	if current_robot:
		current_robot.config.priority = int(val)

func _on_btn_set_start_pressed() -> void:
	if current_robot: set_start_requested.emit(current_robot)

func _on_btn_set_goal_pressed() -> void:
	if current_robot: set_goal_requested.emit(current_robot)

func _on_btn_plan_pressed() -> void:
	if current_robot:
		if current_robot.config.start_node == "":
			print("Set a start location first.")
			return
		if current_robot.config.goal_node == "":
			print("Set a destination first.")
			return
		if current_robot.config.start_node == current_robot.config.goal_node:
			print("Start and destination cannot be identical.")
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
