class_name ORCAModule
extends RefCounted

var time_horizon: float = 1.5

func compute_safe_velocity(robot: RobotAgent, neighbors: Array, pref_velocity: Vector2, delta: float = 0.016) -> Vector2:
	if robot == null or robot.failed:
		return Vector2.ZERO

	if pref_velocity == Vector2.ZERO:
		return Vector2.ZERO

	var safe_vel = pref_velocity
	var robot_radius = robot.config.radius

	for other in neighbors:
		if not is_instance_valid(other) or other.config.robot_id == robot.config.robot_id:
			continue

		var other_radius = other.config.radius
		var diff = other.global_position - robot.global_position
		var dist = diff.length()
		var combined_radius = robot_radius + other_radius + 8.0 # Safety buffer

		if dist == 0:
			continue

		var dir = diff / dist

		# 1. Critical safety zone - deceleration / separation
		if dist < combined_radius:
			var overlap = combined_radius - dist
			# Push back slightly along direction of separation
			safe_vel -= dir * (overlap * 8.0)
		else:
			# 2. Velocity obstacle lookahead
			var rel_vel = safe_vel - other.velocity
			var closing_speed = rel_vel.dot(dir)

			if closing_speed > 0.0:
				var time_to_collision = (dist - combined_radius) / closing_speed
				if time_to_collision < time_horizon:
					var avoid_factor = (time_horizon - time_to_collision) / time_horizon
					# Nudge velocity away from collision normal
					var side_dir = Vector2(-dir.y, dir.x)
					if rel_vel.dot(side_dir) < 0:
						side_dir = -side_dir

					# Moderate deceleration and lateral steer
					safe_vel -= dir * (closing_speed * avoid_factor * 0.7)
					safe_vel += side_dir * (robot.config.speed * avoid_factor * 0.3)

	# Cap velocity to robot max speed
	if safe_vel.length() > robot.config.speed:
		safe_vel = safe_vel.normalized() * robot.config.speed

	return safe_vel
