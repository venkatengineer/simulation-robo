class_name RobotMessage
extends RefCounted

enum MessageType {
	POSITION_UPDATE,
	VELOCITY_UPDATE,
	PATH_UPDATE,
	INTENT_UPDATE,
	CONFLICT_WARNING,
	PRIORITY_REQUEST,
	YIELD_REQUEST,
	YIELD_RESPONSE,
	RESERVATION_REQUEST,
	RESERVATION_GRANTED,
	RESERVATION_DENIED,
	ROBOT_FAILED,
	HEARTBEAT
}

var sender_id: String = ""
var type: MessageType = MessageType.POSITION_UPDATE
var payload: Dictionary = {}
var timestamp: float = 0.0

func _init(p_sender: String = "", p_type: MessageType = MessageType.POSITION_UPDATE, p_payload: Dictionary = {}):
	sender_id = p_sender
	type = p_type
	payload = p_payload
	timestamp = Time.get_ticks_msec() / 1000.0
