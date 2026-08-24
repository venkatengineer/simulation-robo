class_name RobotEditorController
extends Node

var robot_manager: RobotManager
var graph_manager: GraphManager

func setup(p_robot_mgr: RobotManager, p_graph: GraphManager) -> void:
	robot_manager = p_robot_mgr
	graph_manager = p_graph

func _physics_process(delta: float) -> void:
	if robot_manager == null:
		return

	# Handle WASD manual drive for robot in MANUAL state
	var robots = robot_manager.get_all_robots()
	for robot in robots:
		if robot.manual_control and robot.state == RobotAgent.RobotState.MANUAL:
			var move_dir = Vector2.ZERO
			if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): move_dir.y -= 1.0
			if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): move_dir.y += 1.0
			if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): move_dir.x -= 1.0
			if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): move_dir.x += 1.0

			if move_dir.length() > 0:
				robot.velocity = move_dir.normalized() * robot.config.speed
			else:
				robot.velocity = Vector2.ZERO
			robot.move_and_slide()
