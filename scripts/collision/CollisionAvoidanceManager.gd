class_name CollisionAvoidanceManager
extends Node

var orca: ORCAModule = ORCAModule.new()
var collision_count: int = 0

func process_movement(robot, all_robots: Array, desired_velocity: Vector2, delta: float = 0.016) -> Vector2:
	if robot == null or robot.failed:
		return Vector2.ZERO

	if robot.manual_control:
		return robot.velocity

	var neighbors: Array = []
	for other in all_robots:
		if other.config.robot_id != robot.config.robot_id:
			var d = robot.global_position.distance_to(other.global_position)
			if d <= robot.config.communication_range:
				neighbors.append(other)

	var safe_vel = orca.compute_safe_velocity(robot, neighbors, desired_velocity, delta)

	# Overlap safety assertion check
	for other in neighbors:
		var future_pos_self = robot.global_position + safe_vel * delta
		var future_pos_other = other.global_position + other.velocity * delta
		var d = future_pos_self.distance_to(future_pos_other)
		if d < (robot.config.radius + other.config.radius):
			collision_count += 1
			return Vector2.ZERO

	return safe_vel
