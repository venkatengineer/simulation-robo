class_name PathPlanner
extends RefCounted

var graph_manager: Object

func _init(p_graph_manager: Object):
	graph_manager = p_graph_manager

func find_path(start_id: String, goal_id: String, constraints: Dictionary = {}) -> Array[String]:
	push_error("PathPlanner.find_path must be overridden.")
	return []
