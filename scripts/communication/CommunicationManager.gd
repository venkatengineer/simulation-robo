class_name CommunicationManager
extends Node

signal pulse_emitted(sender_id: String, pos: Vector2, radius: float)
signal message_delivered(sender_id: String, receiver_id: String, type: int)

var message_count: int = 0
var active_pulses: Array = [] # { pos: Vector2, radius: float, age: float, max_age: float }
var active_packets: Array = [] # { from_pos: Vector2, to_pos: Vector2, progress: float, color: Color }

func _process(delta: float) -> void:
	# Update pulse rings
	for i in range(active_pulses.size() - 1, -1, -1):
		active_pulses[i].age += delta
		if active_pulses[i].age >= active_pulses[i].max_age:
			active_pulses.remove_at(i)

	# Update flying knowledge packets
	for i in range(active_packets.size() - 1, -1, -1):
		active_packets[i].progress += delta * 2.5 # ~0.4s travel time
		if active_packets[i].progress >= 1.0:
			active_packets.remove_at(i)

func broadcast(sender_robot: RobotAgent, all_robots: Array, message_type: RobotMessage.MessageType, payload: Dictionary = {}) -> void:
	if sender_robot == null or sender_robot.failed:
		return

	message_count += 1
	var comm_r = sender_robot.config.communication_range
	pulse_emitted.emit(sender_robot.config.robot_id, sender_robot.global_position, comm_r)

	for receiver in all_robots:
		if not is_instance_valid(receiver) or receiver.config.robot_id == sender_robot.config.robot_id or receiver.failed:
			continue

		var dist = sender_robot.global_position.distance_to(receiver.global_position)
		if dist <= comm_r:
			deliver_message(sender_robot, receiver, message_type, payload)

func deliver_message(sender: RobotAgent, receiver: RobotAgent, type: RobotMessage.MessageType, payload: Dictionary) -> void:
	receiver.update_local_world_model(sender, payload)
	message_delivered.emit(sender.config.robot_id, receiver.config.robot_id, type)

	# Spawn visual packet for hover / debug communication animation
	if sender.is_hovered_flag or sender.is_selected_flag or receiver.is_hovered_flag or receiver.is_selected_flag:
		if active_packets.size() < 12:
			active_packets.append({
				"from_pos": sender.global_position,
				"to_pos": receiver.global_position,
				"progress": 0.0,
				"color": Color(0.26, 0.48, 0.36) if type == RobotMessage.MessageType.PATH_UPDATE else Color(0.22, 0.74, 0.97)
			})

func get_communicating_peers(robot: RobotAgent, all_robots: Array) -> Array:
	var peers = []
	if robot == null:
		return peers

	var comm_r = robot.config.communication_range
	for other in all_robots:
		if is_instance_valid(other) and other.config.robot_id != robot.config.robot_id and not other.failed:
			if robot.global_position.distance_to(other.global_position) <= comm_r:
				peers.append(other)
	return peers
