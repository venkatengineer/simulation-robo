class_name DashboardController
extends Control

@onready var lbl_total_robots: Label = $VBoxContainer/Grid/ValTotalRobots
@onready var lbl_moving_robots: Label = $VBoxContainer/Grid/ValMovingRobots
@onready var lbl_waiting_robots: Label = $VBoxContainer/Grid/ValWaitingRobots
@onready var lbl_failed_robots: Label = $VBoxContainer/Grid/ValFailedRobots
@onready var lbl_active_conflicts: Label = $VBoxContainer/Grid/ValActiveConflicts
@onready var lbl_collisions: Label = $VBoxContainer/Grid/ValCollisions
@onready var lbl_searches: Label = $VBoxContainer/Grid/ValSearches
@onready var lbl_messages: Label = $VBoxContainer/Grid/ValMessages

func update_dashboard(sim_manager: SimulationManager) -> void:
	if sim_manager == null:
		return

	var robots = sim_manager.robot_manager.get_all_robots()
	var total = robots.size()
	var moving = 0
	var waiting = 0
	var failed = 0

	for r in robots:
		if r.failed: failed += 1
		elif r.state == RobotAgent.RobotState.MOVING: moving += 1
		elif r.state == RobotAgent.RobotState.WAITING or r.state == RobotAgent.RobotState.NEGOTIATING: waiting += 1

	if lbl_total_robots: lbl_total_robots.text = str(total)
	if lbl_moving_robots: lbl_moving_robots.text = str(moving)
	if lbl_waiting_robots: lbl_waiting_robots.text = str(waiting)
	if lbl_failed_robots: lbl_failed_robots.text = str(failed)
	if lbl_active_conflicts: lbl_active_conflicts.text = str(sim_manager.metrics_manager.active_conflicts)
	if lbl_collisions: lbl_collisions.text = str(sim_manager.collision_manager.collision_count)
	if lbl_searches: lbl_searches.text = str(sim_manager.metrics_manager.a_star_searches)
	if lbl_messages: lbl_messages.text = str(sim_manager.comm_manager.message_count)
