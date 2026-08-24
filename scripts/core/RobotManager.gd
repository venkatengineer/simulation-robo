class_name RobotManager
extends Node

signal robot_selected(robot)

var graph_manager: GraphManager
var robot_scene: PackedScene = preload("res://scenes/robots/Robot.tscn")
var robots: Dictionary = {} # robot_id -> RobotAgent
var selected_robot_id: String = ""
var robot_counter: int = 1

func initialize(graph: GraphManager) -> void:
	graph_manager = graph

func generate_robot_id() -> String:
	var id_str = "R%02d" % robot_counter
	while robots.has(id_str):
		robot_counter += 1
		id_str = "R%02d" % robot_counter
	robot_counter += 1
	return id_str

func add_robot(start_node_id: String = "", priority: int = 5, custom_id: String = "") -> RobotAgent:
	return create_robot(start_node_id, priority, custom_id)

func create_robot(start_node_id: String = "", priority: int = 5, custom_id: String = "") -> RobotAgent:
	var robot_instance: RobotAgent = robot_scene.instantiate()
	var cfg = RobotConfig.new()
	cfg.robot_id = custom_id if custom_id != "" else generate_robot_id()
	cfg.priority = priority
	cfg.start_node = start_node_id

	robot_instance.setup(cfg)
	if graph_manager:
		robot_instance.configure_graph(graph_manager)

	add_child(robot_instance)
	robots[cfg.robot_id] = robot_instance
	return robot_instance

func remove_robot(robot: RobotAgent) -> void:
	if robot:
		delete_robot(robot.config.robot_id)

func delete_robot(robot_id: String) -> bool:
	if not robots.has(robot_id):
		return false

	var robot = robots[robot_id]
	if selected_robot_id == robot_id:
		selected_robot_id = ""
		robot_selected.emit(null)

	robots.erase(robot_id)
	robot.queue_free()
	return true

func select_robot(robot_id: String) -> RobotAgent:
	for r_id in robots:
		robots[r_id].set_selected(r_id == robot_id)

	if robots.has(robot_id):
		selected_robot_id = robot_id
		var sel = robots[robot_id]
		robot_selected.emit(sel)
		return sel

	selected_robot_id = ""
	robot_selected.emit(null)
	return null

func get_selected_robot() -> RobotAgent:
	return robots.get(selected_robot_id, null)

func get_robot(id: String) -> RobotAgent:
	return robots.get(id, null)

func get_robot_count() -> int:
	return robots.size()

func get_all_robots() -> Array:
	return robots.values()

func start_all_robots() -> void:
	var robot_list = get_all_robots()
	if robot_list.is_empty():
		print("No robots available to start.")
		return
	for robot in robot_list:
		if is_instance_valid(robot) and robot.has_method("start_robot"):
			robot.start_robot()

func find_robot_at_position(pos: Vector2, max_radius: float = 30.0) -> RobotAgent:
	for r_id in robots:
		var r = robots[r_id]
		if r.global_position.distance_to(pos) <= max_radius:
			return r
	return null

func clear() -> void:
	for r_id in robots:
		robots[r_id].queue_free()
	robots.clear()
	selected_robot_id = ""
	robot_counter = 1
