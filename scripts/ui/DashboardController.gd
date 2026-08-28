class_name DashboardController
extends Control

@onready var lbl_total_robots: Label = get_node_or_null("%ValTotalRobots")
@onready var lbl_moving_robots: Label = get_node_or_null("%ValMovingRobots")
@onready var lbl_waiting_robots: Label = get_node_or_null("%ValWaitingRobots")
@onready var lbl_failed_robots: Label = get_node_or_null("%ValFailedRobots")
@onready var lbl_active_conflicts: Label = get_node_or_null("%ValActiveConflicts")
@onready var lbl_collisions: Label = get_node_or_null("%ValCollisions")
@onready var lbl_searches: Label = get_node_or_null("%ValSearches")
@onready var lbl_reroutes: Label = get_node_or_null("%ValReroutes")
@onready var lbl_deadlocks: Label = get_node_or_null("%ValDeadlocks")
@onready var lbl_tasks: Label = get_node_or_null("%ValTasks")
@onready var lbl_messages: Label = get_node_or_null("%ValMessages")



func update_dashboard(sim_manager: SimulationManager) -> void:
	if sim_manager == null:
		return

	var robots = sim_manager.robot_manager.get_all_robots()
	var total = robots.size()
	var moving = 0
	var waiting = 0
	var failed = 0

	for r in robots:
		if is_instance_valid(r):
			if r.failed: failed += 1
			elif r.state == RobotAgent.RobotState.MOVING or r.state == RobotAgent.RobotState.REROUTING: moving += 1
			elif r.state == RobotAgent.RobotState.WAITING or r.state == RobotAgent.RobotState.YIELDING or r.state == RobotAgent.RobotState.NEGOTIATING: waiting += 1

	if lbl_total_robots: lbl_total_robots.text = str(total)
	if lbl_moving_robots: lbl_moving_robots.text = str(moving)
	if lbl_waiting_robots: lbl_waiting_robots.text = str(waiting)
	if lbl_failed_robots: lbl_failed_robots.text = str(failed)

	if sim_manager.metrics_manager:
		if lbl_active_conflicts: lbl_active_conflicts.text = str(sim_manager.metrics_manager.active_conflicts)
		if lbl_searches: lbl_searches.text = str(sim_manager.metrics_manager.a_star_searches)
		if lbl_tasks: lbl_tasks.text = str(sim_manager.metrics_manager.completed_tasks_count)

	if sim_manager.collision_manager:
		if lbl_collisions:
			lbl_collisions.text = str(sim_manager.collision_manager.collision_count)
			if sim_manager.collision_manager.collision_count == 0:
				lbl_collisions.add_theme_color_override("font_color", Color(0.06, 0.72, 0.5))
			else:
				lbl_collisions.add_theme_color_override("font_color", Color(0.94, 0.27, 0.27))

	if sim_manager.coordination_manager:
		if lbl_reroutes and sim_manager.coordination_manager.rerouting_manager:
			lbl_reroutes.text = str(sim_manager.coordination_manager.rerouting_manager.reroute_count)
		if lbl_deadlocks and sim_manager.coordination_manager.deadlock_detector:
			lbl_deadlocks.text = str(sim_manager.coordination_manager.deadlock_detector.deadlocks_resolved_count)

	if sim_manager.comm_manager:
		if lbl_messages: lbl_messages.text = str(sim_manager.comm_manager.message_count)
