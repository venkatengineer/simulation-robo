class_name TaskManager
extends Node

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

func handle_robot_failure(failed_robot_id: String) -> void:
	for task in tasks:
		if task.assigned_robot_id == failed_robot_id and task.status != "COMPLETED":
			task.assigned_robot_id = ""
			task.status = "PENDING"

func clear() -> void:
	tasks.clear()
	completed_tasks.clear()
	task_counter = 1
