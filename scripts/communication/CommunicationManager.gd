class_name CommunicationManager
extends Node

signal pulse_emitted(sender_id: String, pos: Vector2, radius: float)

var message_count: int = 0

func broadcast(sender_robot, all_robots: Array, message_type: RobotMessage.MessageType, payload: Dictionary = {}) -> void:
	if sender_robot == null or sender_robot.failed:
		return

	message_count += 1
	pulse_emitted.emit(sender_robot.config.robot_id, sender_robot.global_position, sender_robot.config.communication_range)

	for receiver in all_robots:
		if receiver.config.robot_id == sender_robot.config.robot_id or receiver.failed:
			continue
		
		var dist = sender_robot.global_position.distance_to(receiver.global_position)
		if dist <= sender_robot.config.communication_range:
			deliver_message(sender_robot, receiver, message_type, payload)

func deliver_message(sender, receiver, type: RobotMessage.MessageType, payload: Dictionary) -> void:
	receiver.update_local_world_model(sender)
