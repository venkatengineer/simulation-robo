class_name TaskManager
extends Node

signal task_reallocated(task_id: String, from_robot: String, to_robot: String)

var tasks: Array = []
var completed_tasks: Array = []
var task_counter: int = 1

func create_task(pickup_id: String, dropoff_id: String, priority: int = 5) -> Dictionary:
	var task = {
		"id": "TASK_%03d" % task_counter,
		"pickup_id": pickup_id,
		"dropoff_id": dropoff_id,
		"priority": priority,
		"assigned_robot_id": "",
		"status": "PENDING"
	}
	task_counter += 1
	tasks.append(task)
	return task

func assign_task(task_id: String, robot_id: String) -> bool:
	for task in tasks:
		if task.id == task_id and task.status == "PENDING":
			task.assigned_robot_id = robot_id
			task.status = "ASSIGNED"
			return true
	return false

func handle_robot_failure(failed_robot_id: String, robot_manager: RobotManager = null, sim_manager: SimulationManager = null) -> void:
	for task in tasks:
		if task.assigned_robot_id == failed_robot_id and task.status != "COMPLETED":
			var old_id = task.assigned_robot_id
			task.assigned_robot_id = ""
			task.status = "PENDING"

			# Reassign to an available fleet robot
			if robot_manager:
				for other in robot_manager.get_all_robots():
					if is_instance_valid(other) and other.config.robot_id != failed_robot_id and not other.failed:
						if other.state == RobotAgent.RobotState.READY or other.state == RobotAgent.RobotState.ARRIVED or other.state == RobotAgent.RobotState.IDLE:
							task.assigned_robot_id = other.config.robot_id
							task.status = "ASSIGNED"
							other.set_goal_node(task.dropoff_id)
							if sim_manager:
								sim_manager.plan_path_for_robot(other)
								if sim_manager.metrics_manager:
									sim_manager.metrics_manager.task_reallocations_count += 1
							task_reallocated.emit(task.id, old_id, other.config.robot_id)
							break

func clear() -> void:
	tasks.clear()
	completed_tasks.clear()
	task_counter = 1
