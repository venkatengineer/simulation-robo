class_name CollisionAvoidanceManager
extends Node

var orca: ORCAModule = ORCAModule.new()
var collision_count: int = 0

func process_movement(robot: RobotAgent, all_robots: Array, desired_velocity: Vector2, delta: float = 0.016) -> Vector2:
	if robot == null or robot.failed or robot.state == RobotAgent.RobotState.ARRIVED:
		return Vector2.ZERO

	if robot.manual_control:
		return robot.velocity

	if robot.state == RobotAgent.RobotState.WAITING or robot.state == RobotAgent.RobotState.YIELDING:
		return Vector2.ZERO

	var neighbors: Array = []
	var hard_stop_threshold = robot.config.radius * 2.0 + 6.0 # 42px minimum physical clearance
	var following_safe_distance = robot.config.radius * 2.0 + 18.0 # 54px following distance

	for other in all_robots:
		if is_instance_valid(other) and other.config.robot_id != robot.config.robot_id:
			var d = robot.global_position.distance_to(other.global_position)
			if d <= robot.config.communication_range:
				neighbors.append(other)

			# Real collision counter (only if actual physical body penetration occurs)
			if d < (robot.config.radius + other.config.radius - 2.0):
				collision_count += 1

	# Layer 4: Safe Following Distance & Static Obstacle Avoidance (Tailgating Prevention)
	var forward_dir = desired_velocity.normalized() if desired_velocity.length() > 0 else Vector2.RIGHT.rotated(robot.rotation)
	for other in neighbors:
		var offset = other.global_position - robot.global_position
		var d = offset.length()

		# Is other robot directly in front of this robot within following distance?
		if d < following_safe_distance and d > 0.0:
			var dot = forward_dir.dot(offset.normalized())
			if dot > 0.4: # In front cone
				var other_vel = other.velocity if (other.state == RobotAgent.RobotState.MOVING and not other.failed) else Vector2.ZERO
				var other_speed_in_dir = other_vel.dot(forward_dir)
				if other_speed_in_dir <= 10.0 or d < hard_stop_threshold:
					return Vector2.ZERO
				else:
					desired_velocity = forward_dir * min(desired_velocity.length(), other_speed_in_dir * 0.8)

	# Layer 4: ORCA velocity computation
	var safe_vel = orca.compute_safe_velocity(robot, neighbors, desired_velocity, delta)

	# Layer 5: Absolute Hard Physical Separation Guarantee
	for other in neighbors:
		var other_vel = other.velocity if (other.state == RobotAgent.RobotState.MOVING and not other.failed) else Vector2.ZERO
		var future_pos_self = robot.global_position + safe_vel * delta
		var future_pos_other = other.global_position + other_vel * delta
		var future_dist = future_pos_self.distance_to(future_pos_other)

		if future_dist < hard_stop_threshold:
			var to_other = (other.global_position - robot.global_position).normalized()
			if safe_vel.dot(to_other) > 0.0 or future_dist < (robot.config.radius + other.config.radius + 2.0):
				return Vector2.ZERO

	return safe_vel

