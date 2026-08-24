class_name PriorityManager
extends Node

const WAITING_WEIGHT: float = 0.2

func calculate_effective_priority(robot) -> float:
	if robot == null:
		return 0.0
	var effective = robot.config.priority + (robot.waiting_time * WAITING_WEIGHT)
	return snappedf(effective, 0.01)

func compare_priority(robot_a, robot_b) -> Dictionary:
	var eff_a = calculate_effective_priority(robot_a)
	var eff_b = calculate_effective_priority(robot_b)

	if eff_a > eff_b:
		return { "winner": robot_a, "loser": robot_b, "reason": "Priority %.2f > %.2f" % [eff_a, eff_b] }
	elif eff_b > eff_a:
		return { "winner": robot_b, "loser": robot_a, "reason": "Priority %.2f > %.2f" % [eff_b, eff_a] }
	else:
		if robot_a.config.robot_id < robot_b.config.robot_id:
			return { "winner": robot_a, "loser": robot_b, "reason": "Tie-break ID %s < %s" % [robot_a.config.robot_id, robot_b.config.robot_id] }
		else:
			return { "winner": robot_b, "loser": robot_a, "reason": "Tie-break ID %s < %s" % [robot_b.config.robot_id, robot_a.config.robot_id] }
