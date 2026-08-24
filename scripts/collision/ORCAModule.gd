class_name ORCAModule
extends RefCounted

var time_horizon: float = 2.0

func compute_safe_velocity(robot, neighbors: Array, pref_velocity: Vector2, delta: float = 0.016) -> Vector2:
	if robot == null or robot.failed:
		return Vector2.ZERO

	if pref_velocity == Vector2.ZERO:
		return Vector2.ZERO

	var safe_vel = pref_velocity

	for other in neighbors:
		if other.config.robot_id == robot.config.robot_id:
			continue

		var diff = other.global_position - robot.global_position
		var dist = diff.length()
		var combined_radius = robot.config.radius + other.config.radius + 6.0

		if dist == 0:
			continue

		if dist < combined_radius:
			# Overlapping - push away
			var overlap = combined_radius - dist
			var dir = diff.normalized()
			safe_vel -= dir * (overlap * 12.0)
		else:
			var dir = diff.normalized()
			var rel_vel = safe_vel - other.velocity
			var closing_speed = rel_vel.dot(dir)

			if closing_speed > 0:
				var time_to_collision = (dist - combined_radius) / closing_speed
				if time_to_collision < time_horizon:
					var avoid_factor = (time_horizon - time_to_collision) / time_horizon
					safe_vel -= dir * (closing_speed * avoid_factor * 0.5)

	if safe_vel.length() > robot.config.speed:
		safe_vel = safe_vel.normalized() * robot.config.speed

	return safe_vel
