class_name DebugManager
extends Node2D

var graph_manager: GraphManager
var robot_manager: RobotManager
var comm_manager: CommunicationManager
var reservation_manager: ReservationManager
var deadlock_detector: DeadlockDetector

# Debug Toggles
var debug_mode_enabled: bool = false
var show_nodes: bool = false
var show_edges: bool = true
var show_paths: bool = true
var show_comm: bool = false
var show_sensor_radius: bool = false
var show_reservations: bool = false
var show_wait_graph: bool = false

var active_pulses: Array = []

func setup(p_graph: GraphManager, p_robot_mgr: RobotManager, p_comm_mgr: CommunicationManager, p_res_mgr: ReservationManager) -> void:
	graph_manager = p_graph
	robot_manager = p_robot_mgr
	comm_manager = p_comm_mgr
	reservation_manager = p_res_mgr
	
	if comm_manager:
		comm_manager.pulse_emitted.connect(_on_comm_pulse)

func toggle_debug_mode(enabled: bool) -> void:
	debug_mode_enabled = enabled
	show_nodes = enabled
	show_sensor_radius = enabled
	show_comm = enabled
	show_reservations = enabled
	show_wait_graph = enabled

func _on_comm_pulse(sender_id: String, pos: Vector2, radius: float) -> void:
	if show_comm:
		active_pulses.append({ "pos": pos, "radius": radius, "age": 0.0 })

func _process(delta: float) -> void:
	for i in range(active_pulses.size() - 1, -1, -1):
		active_pulses[i].age += delta
		if active_pulses[i].age >= 0.4:
			active_pulses.remove_at(i)
	queue_redraw()

func _draw() -> void:
	if graph_manager == null:
		return

	var default_font = ThemeDB.fallback_font

	# 1. Draw Edges / Blocked Aisle Barriers
	if show_edges:
		for edge in graph_manager.edges:
			var node_a = graph_manager.get_graph_node(edge.start_id)
			var node_b = graph_manager.get_graph_node(edge.end_id)
			if node_a and node_b:
				if not edge.traversable:
					draw_line(node_a.position, node_b.position, Color(0.94, 0.27, 0.27, 0.9), 5.0)
					var mid_pos = (node_a.position + node_b.position) * 0.5
					draw_string(default_font, mid_pos + Vector2(-20, -6), "BLOCKED", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.94, 0.27, 0.27))
				elif debug_mode_enabled:
					draw_line(node_a.position, node_b.position, Color(0.2, 0.5, 0.8, 0.15), 1.5)

	# 2. Draw Navigation Nodes & Reservation Overlays
	if show_nodes or show_reservations:
		for n_id in graph_manager.nodes:
			var node = graph_manager.nodes[n_id]
			var node_color = get_node_color(node.type)

			if reservation_manager and reservation_manager.reservations.has(node.id):
				var res = reservation_manager.reservations[node.id]
				draw_circle(node.position, 14.0, Color(1.0, 0.6, 0.0, 0.4))
				draw_string(default_font, node.position + Vector2(-15, 20), "LOCK:" + res.robot_id, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1.0, 0.7, 0.2))

			if show_nodes:
				draw_circle(node.position, 6.0, node_color)
				draw_arc(node.position, 6.0, 0, TAU, 16, Color(1, 1, 1, 0.8), 1.0)
				draw_string(default_font, node.position + Vector2(-10, -10), node.id, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.8, 0.8, 0.8))

	# 3. Draw Robot Paths & Single Sensor Circle
	if robot_manager:
		var robots = robot_manager.get_all_robots()
		for robot in robots:
			if show_sensor_radius:
				draw_arc(robot.global_position, robot.config.communication_range, 0, TAU, 32, Color(0.2, 0.8, 0.4, 0.15), 1.0)

			# Conflict state text indicators near robot
			if robot.state == RobotAgent.RobotState.WAITING:
				draw_string(default_font, robot.global_position + Vector2(-22, -40), "⚠️ YIELDING", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.96, 0.62, 0.04))
			elif robot.state == RobotAgent.RobotState.REROUTING or robot.state == RobotAgent.RobotState.DEADLOCK_RECOVERY:
				draw_string(default_font, robot.global_position + Vector2(-22, -40), "↻ REROUTING", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.55, 0.36, 0.96))

			if show_paths and robot.planned_path.size() > 0:
				var path_nodes: Array[Vector2] = [robot.global_position]
				for i in range(robot.path_index, robot.planned_path.size()):
					var n = graph_manager.get_graph_node(robot.planned_path[i])
					if n:
						path_nodes.append(n.position)
				if path_nodes.size() > 1:
					var p_color = get_robot_color(robot.config.priority)
					for k in range(path_nodes.size() - 1):
						draw_line(path_nodes[k], path_nodes[k + 1], p_color, 2.5)

		# Draw START and GOAL visual markers for selected robot
		var selected_robot = robot_manager.get_selected_robot()
		if selected_robot:
			if selected_robot.config.start_node != "":
				var s_node = graph_manager.get_graph_node(selected_robot.config.start_node)
				if s_node:
					draw_circle(s_node.position, 10.0, Color(0.06, 0.72, 0.5, 0.4))
					draw_string(default_font, s_node.position + Vector2(-18, -16), "START", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.06, 0.72, 0.5))

			if selected_robot.config.goal_node != "":
				var g_node = graph_manager.get_graph_node(selected_robot.config.goal_node)
				if g_node:
					draw_circle(g_node.position, 12.0, Color(0.96, 0.62, 0.04, 0.4))
					draw_arc(g_node.position, 12.0, 0, TAU, 24, Color(0.96, 0.62, 0.04), 2.0)
					draw_string(default_font, g_node.position + Vector2(-15, -18), "GOAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.96, 0.62, 0.04))

	# 4. Peer-to-Peer Comm Pulses
	if show_comm:
		for pulse in active_pulses:
			var alpha = 1.0 - (pulse.age / 0.4)
			var current_r = pulse.radius * (pulse.age / 0.4)
			draw_arc(pulse.pos, current_r, 0, TAU, 24, Color(0.2, 0.9, 1.0, alpha * 0.4), 1.5)

func get_node_color(type: GraphNodeData.NodeType) -> Color:
	match type:
		GraphNodeData.NodeType.INTERSECTION:
			return Color(0.96, 0.62, 0.04)
		GraphNodeData.NodeType.PICKUP:
			return Color(0.06, 0.72, 0.5)
		GraphNodeData.NodeType.DROPOFF:
			return Color(0.55, 0.36, 0.96)
		GraphNodeData.NodeType.CHARGING:
			return Color(0.02, 0.71, 0.83)
		GraphNodeData.NodeType.WAITING:
			return Color(0.92, 0.7, 0.03)
		GraphNodeData.NodeType.BLOCKED:
			return Color(0.94, 0.27, 0.27)
		_:
			return Color(0.22, 0.74, 0.97)

func get_robot_color(priority: int) -> Color:
	if priority >= 10:
		return Color(0.94, 0.27, 0.27)
	elif priority >= 7:
		return Color(0.96, 0.62, 0.04)
	else:
		return Color(0.22, 0.74, 0.97)
