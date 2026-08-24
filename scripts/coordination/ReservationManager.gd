class_name ReservationManager
extends Node

# Node reservations: nodeId (String) -> { robot_id: String, priority: float, expiry: float }
var reservations: Dictionary = {}

func _process(delta: float) -> void:
	clean_expired()

func request_reservation(robot_id: String, node_id: String, duration_sec: float = 2.5) -> bool:
	return request_reservation_with_priority(robot_id, 5.0, node_id, duration_sec)

func request_reservation_with_priority(robot_id: String, priority: float, node_id: String, duration_sec: float = 2.5) -> bool:
	clean_expired()
	var now = Time.get_ticks_msec() / 1000.0

	if not reservations.has(node_id):
		reservations[node_id] = {
			"robot_id": robot_id,
			"priority": priority,
			"expiry": now + duration_sec
		}
		return true

	var existing = reservations[node_id]
	if existing.robot_id == robot_id:
		existing.expiry = now + duration_sec
		existing.priority = max(existing.priority, priority)
		return true

	# Priority Eviction: Higher priority robot overrides lower priority lock
	if priority > existing.priority:
		reservations[node_id] = {
			"robot_id": robot_id,
			"priority": priority,
			"expiry": now + duration_sec
		}
		return true

	return false

func is_node_reserved_by_other(node_id: String, robot_id: String) -> bool:
	var now = Time.get_ticks_msec() / 1000.0
	if reservations.has(node_id):
		if reservations[node_id].expiry <= now:
			reservations.erase(node_id)
			return false
		return reservations[node_id].robot_id != robot_id
	return false

func release_reservation(robot_id: String, node_id: String) -> void:
	if reservations.has(node_id) and reservations[node_id].robot_id == robot_id:
		reservations.erase(node_id)

func release_all_for_robot(robot_id: String) -> void:
	var to_erase: Array[String] = []
	for n_id in reservations:
		if reservations[n_id].robot_id == robot_id:
			to_erase.append(n_id)
	for n_id in to_erase:
		reservations.erase(n_id)

func clean_expired() -> void:
	var now = Time.get_ticks_msec() / 1000.0
	var to_erase: Array[String] = []
	for n_id in reservations:
		if reservations[n_id].expiry <= now:
			to_erase.append(n_id)
	for n_id in to_erase:
		reservations.erase(n_id)

func clear() -> void:
	reservations.clear()
