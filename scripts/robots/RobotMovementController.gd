class_name RobotMovementController
extends Node

func apply_movement(robot: RobotAgent, safe_velocity: Vector2, delta: float) -> void:
	if robot == null or robot.failed:
		return

	robot.velocity = safe_velocity
	robot.move_and_slide()
