class_name PriorityManager
extends Node

const WAITING_WEIGHT: float = 0.2

# Calculate Effective Priority = Base Priority + (Waiting Time * 0.2)
func calculate_effective_priority(robot: RobotAgent) -> float:
	if robot == null:
		return 0.0
	var effective = float(robot.config.priority) + (robot.waiting_time * WAITING_WEIGHT)
	return snappedf(effective, 0.01)

func compare_priority(robot_a: RobotAgent, robot_b: RobotAgent) -> Dictionary:
	if robot_a == null or robot_b == null:
		return { "winner": robot_a, "loser": robot_b, "reason": "Invalid robot" }

	var eff_a = calculate_effective_priority(robot_a)
	var eff_b = calculate_effective_priority(robot_b)

	if eff_a > eff_b:
		return {
			"winner": robot_a,
			"loser": robot_b,
			"priority_a": eff_a,
			"priority_b": eff_b,
			"reason": "%s (Priority %.2f) > %s (Priority %.2f)" % [robot_a.config.robot_id, eff_a, robot_b.config.robot_id, eff_b]
		}
	elif eff_b > eff_a:
		return {
			"winner": robot_b,
			"loser": robot_a,
			"priority_a": eff_a,
			"priority_b": eff_b,
			"reason": "%s (Priority %.2f) > %s (Priority %.2f)" % [robot_b.config.robot_id, eff_b, robot_a.config.robot_id, eff_a]
		}
	else:
		# Tie-breaker: Deterministic lexicographical comparison of Robot ID
		if robot_a.config.robot_id < robot_b.config.robot_id:
			return {
				"winner": robot_a,
				"loser": robot_b,
				"priority_a": eff_a,
				"priority_b": eff_b,
				"reason": "Tie-break ID %s < %s" % [robot_a.config.robot_id, robot_b.config.robot_id]
			}
		else:
			return {
				"winner": robot_b,
				"loser": robot_a,
				"priority_a": eff_a,
				"priority_b": eff_b,
				"reason": "Tie-break ID %s < %s" % [robot_b.config.robot_id, robot_a.config.robot_id]
			}
