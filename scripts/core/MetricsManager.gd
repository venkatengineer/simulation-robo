class_name MetricsManager
extends Node

var a_star_searches: int = 0
var reroutes_count: int = 0
var active_conflicts: int = 0
var total_collisions: int = 0
var messages_count: int = 0
var deadlocks_detected_count: int = 0
var deadlocks_resolved_count: int = 0
var task_reallocations_count: int = 0
var completed_tasks_count: int = 0
var total_waiting_time: float = 0.0

func reset() -> void:
	a_star_searches = 0
	reroutes_count = 0
	active_conflicts = 0
	total_collisions = 0
	messages_count = 0
	deadlocks_detected_count = 0
	deadlocks_resolved_count = 0
	task_reallocations_count = 0
	completed_tasks_count = 0
	total_waiting_time = 0.0
