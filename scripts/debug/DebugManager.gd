class_name DebugManager
extends Node2D

var graph_manager: GraphManager
var robot_manager: RobotManager
var comm_manager: CommunicationManager
var reservation_manager: ReservationManager
var deadlock_detector: DeadlockDetector
var input_controller: InputController

enum PathDisplayMode {
	ALL = 0,
	SELECTED = 1,
	OFF = 2
}

# Debug & Display Toggles
var debug_mode_enabled: bool = false
var path_display_mode: PathDisplayMode = PathDisplayMode.ALL
var show_nodes: bool = false
var show_edges: bool = true
var show_comm: bool = false
var show_sensor_radius: bool = false
var show_reservations: bool = false
var show_wait_graph: bool = false

var active_pulses: Array = []
var packet_anim_time: float = 0.0

func setup(
	p_graph: GraphManager,
	p_robot_mgr: RobotManager,
	p_comm_mgr: CommunicationManager,
	p_res_mgr: ReservationManager,
	p_deadlock: DeadlockDetector = null,
	p_input: InputController = null
) -> void:
	graph_manager = p_graph
	robot_manager = p_robot_mgr
	comm_manager = p_comm_mgr
	reservation_manager = p_res_mgr
	deadlock_detector = p_deadlock
	input_controller = p_input

	if comm_manager:
		comm_manager.pulse_emitted.connect(_on_comm_pulse)

func set_path_display_mode(mode: int) -> void:
	path_display_mode = mode as PathDisplayMode
	queue_redraw()

func toggle_debug_mode(enabled: bool) -> void:
	debug_mode_enabled = enabled
	show_nodes = enabled
	show_sensor_radius = enabled
	show_comm = enabled
	show_reservations = enabled
	show_wait_graph = enabled
	queue_redraw()

func _on_comm_pulse(sender_id: String, pos: Vector2, radius: float) -> void:
	if show_comm:
		active_pulses.append({ "pos": pos, "radius": radius, "age": 0.0 })

func _process(delta: float) -> void:
	packet_anim_time += delta
	for i in range(active_pulses.size() - 1, -1, -1):
		active_pulses[i].age += delta
		if active_pulses[i].age >= 0.4:
			active_pulses.remove_at(i)
	queue_redraw()

func _draw() -> void:
	if graph_manager == null:
		return

	var default_font = ThemeDB.fallback_font

	# 1. Draw Static Storage Rack Obstacles & Safety Clearance Zones (Debug mode)
	if show_nodes or debug_mode_enabled:
		for rack in graph_manager.get_static_obstacles():
			draw_rect(rack, Color(0.94, 0.27, 0.27, 0.18), true)
			draw_rect(rack, Color(0.94, 0.27, 0.27, 0.8), false, 2.0)
			var clear_rect = rack.grow(GraphManager.DEFAULT_CLEARANCE)
			draw_rect(clear_rect, Color(0.96, 0.62, 0.04, 0.08), true)
			draw_rect(clear_rect, Color(0.96, 0.62, 0.04, 0.4), false, 1.0)
			draw_string(default_font, rack.position + Vector2(6, 20), "RACK OBSTACLE", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.94, 0.27, 0.27, 0.9))

	# 2. Draw Blocked Aisle Physical Barriers & Graph Edges (Debug Mode)
	for edge in graph_manager.edges:
		var node_a = graph_manager.get_graph_node(edge.start_id)
		var node_b = graph_manager.get_graph_node(edge.end_id)
		if node_a and node_b:
			var edge_valid = graph_manager.is_edge_valid(edge.start_id, edge.end_id, GraphManager.ROBOT_RADIUS)
			var is_blocked = (not edge.traversable or not edge_valid)

			if is_blocked:
				# PHYSICAL INDUSTRIAL HAZARD BARRIER ACROSS THE AISLE
				var mid_pos = (node_a.position + node_b.position) * 0.5
				var is_horizontal_aisle = abs(node_a.position.y - node_b.position.y) < 5.0

				# Barrier geometry spanning across the aisle
				if is_horizontal_aisle:
					# Vertical barrier blocking horizontal aisle
					var b_rect = Rect2(mid_pos.x - 7, mid_pos.y - 25, 14, 50)
					draw_rect(b_rect, Color(0.94, 0.27, 0.27), true)
					draw_rect(b_rect, Color(0.1, 0.1, 0.1), false, 1.5)
					# Barricade posts
					draw_circle(Vector2(mid_pos.x, mid_pos.y - 25), 4.0, Color(0.2, 0.2, 0.2))
					draw_circle(Vector2(mid_pos.x, mid_pos.y + 25), 4.0, Color(0.2, 0.2, 0.2))
					# Hazard diagonal stripes
					draw_line(Vector2(mid_pos.x - 7, mid_pos.y - 15), Vector2(mid_pos.x + 7, mid_pos.y - 5), Color(1, 1, 1), 2.0)
					draw_line(Vector2(mid_pos.x - 7, mid_pos.y + 5), Vector2(mid_pos.x + 7, mid_pos.y + 15), Color(1, 1, 1), 2.0)
				else:
					# Horizontal barrier blocking vertical aisle
					var b_rect = Rect2(mid_pos.x - 25, mid_pos.y - 7, 50, 14)
					draw_rect(b_rect, Color(0.94, 0.27, 0.27), true)
					draw_rect(b_rect, Color(0.1, 0.1, 0.1), false, 1.5)
					draw_circle(Vector2(mid_pos.x - 25, mid_pos.y), 4.0, Color(0.2, 0.2, 0.2))
					draw_circle(Vector2(mid_pos.x + 25, mid_pos.y), 4.0, Color(0.2, 0.2, 0.2))
					draw_line(Vector2(mid_pos.x - 15, mid_pos.y - 7), Vector2(mid_pos.x - 5, mid_pos.y + 7), Color(1, 1, 1), 2.0)
					draw_line(Vector2(mid_pos.x + 5, mid_pos.y - 7), Vector2(mid_pos.x + 15, mid_pos.y + 7), Color(1, 1, 1), 2.0)

				# High-contrast Blocked Tag Card
				var tag_text = "⛔ AISLE BLOCKED"
				var t_size = default_font.get_string_size(tag_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
				var tag_rect = Rect2(mid_pos.x - (t_size.x * 0.5) - 6, mid_pos.y - 32, t_size.x + 12, 16)
				draw_rect(tag_rect, Color(1, 1, 1, 0.98), true)
				draw_rect(tag_rect, Color(0.94, 0.27, 0.27), false, 1.5)
				draw_string(default_font, Vector2(tag_rect.position.x + 6, tag_rect.position.y + 12), tag_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.85, 0.15, 0.15))

			elif debug_mode_enabled:
				# Raw connectivity graph line ONLY in debug mode
				draw_line(node_a.position, node_b.position, Color(0.2, 0.6, 0.9, 0.3), 1.0)

	# 3. Draw Navigation Nodes & Reservation Overlays (ONLY in Debug Mode)
	if debug_mode_enabled or show_nodes or show_reservations:
		for n_id in graph_manager.nodes:
			var node = graph_manager.nodes[n_id]
			var is_valid = graph_manager.is_node_valid(node.id)

			if reservation_manager and reservation_manager.reservations.has(node.id):
				var res = reservation_manager.reservations[node.id]
				draw_circle(node.position, 16.0, Color(1.0, 0.6, 0.0, 0.25))
				draw_string(default_font, node.position + Vector2(-18, 22), "LOCK: " + res.robot_id, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1.0, 0.6, 0.0))

			if debug_mode_enabled or show_nodes:
				if not is_valid:
					var arm: float = 7.0
					draw_line(node.position + Vector2(-arm, -arm), node.position + Vector2(arm, arm), Color(0.94, 0.27, 0.27), 2.0)
					draw_line(node.position + Vector2(-arm, arm), node.position + Vector2(arm, -arm), Color(0.94, 0.27, 0.27), 2.0)
					draw_string(default_font, node.position + Vector2(-10, -10), node.id + " [✕]", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.94, 0.27, 0.27))
				else:
					var node_color = get_node_color(node.type)
					draw_circle(node.position, 5.0, node_color)
					draw_arc(node.position, 5.0, 0, TAU, 16, Color(1, 1, 1, 0.8), 1.0)
					draw_string(default_font, node.position + Vector2(-10, -10), node.id, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.4, 0.45, 0.55))

	if robot_manager == null:
		return

	var robots = robot_manager.get_all_robots()
	var selected_robot = robot_manager.get_selected_robot()
	var hovered_robot: RobotAgent = input_controller.hovered_robot if input_controller else null
	var inspection_robot: RobotAgent = hovered_robot if hovered_robot else selected_robot

	# 4. Draw Robot Routes (Clean Road Centerline Routes for Active Robots)
	if path_display_mode != PathDisplayMode.OFF:
		for robot in robots:
			if not is_instance_valid(robot) or robot.failed or robot.state == RobotAgent.RobotState.ARRIVED:
				continue

			var is_inspected = (robot == selected_robot) or (robot == hovered_robot)
			if path_display_mode == PathDisplayMode.SELECTED and not is_inspected:
				continue


			var robot_color = RobotAgent.get_robot_color_by_id(robot.config.robot_id)

			# 4.1 Rerouting Comparison: Old discarded route (fading red line with ✕)
			if robot.reroute_display_timer > 0.0 and robot.previous_path.size() > 0:
				var old_points: Array[Vector2] = [robot.global_position]
				for p_id in robot.previous_path:
					var n = graph_manager.get_graph_node(p_id)
					if n: old_points.append(n.position)
				if old_points.size() > 1:
					for k in range(old_points.size() - 1):
						draw_line(old_points[k], old_points[k+1], Color(0.94, 0.27, 0.27, 0.4), 1.5)
					draw_string(default_font, old_points[-1] + Vector2(-15, -8), "OLD ROUTE ✕", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.94, 0.27, 0.27, 0.8))

			# 4.2 Active Planned Route (Centerline Aisle Navigation)
			if robot.planned_path.size() > 0:
				# Defensive validation: Synchronize route with current physical/navigation state
				if not robot.is_path_valid():
					var start_id = robot.current_node_id if robot.current_node_id != "" else robot.config.start_node
					if start_id != "" and robot.config.goal_node != "" and graph_manager:
						var fresh_path = graph_manager.find_path(start_id, robot.config.goal_node)
						if fresh_path.size() > 0:
							robot.planned_path = fresh_path
							robot.path_index = 0
							if robot.planned_path[-1] != robot.config.goal_node:
								robot.planned_path.append(robot.config.goal_node)
						else:
							robot.planned_path.clear()

				if robot.planned_path.size() > 0:
					var path_nodes: Array[Vector2] = [robot.global_position]
					for i in range(robot.path_index, robot.planned_path.size()):
						var n = graph_manager.get_graph_node(robot.planned_path[i])
						if n: path_nodes.append(n.position)

					if path_nodes.size() > 1:
						if is_inspected:
							# Prominent 3.5px route for inspected robot
							for k in range(path_nodes.size() - 1):
								draw_line(path_nodes[k], path_nodes[k + 1], robot_color, 3.5)
								draw_circle(path_nodes[k + 1], 4.0, robot_color)
								draw_circle(path_nodes[k + 1], 2.0, Color(1, 1, 1))
						else:
							# Clean, subtle 2.0px route for other operating fleet robots
							var subtle_col = Color(robot_color.r, robot_color.g, robot_color.b, 0.5)
							for k in range(path_nodes.size() - 1):
								draw_line(path_nodes[k], path_nodes[k + 1], subtle_col, 2.0)
								draw_circle(path_nodes[k + 1], 2.5, subtle_col)


	# 5. Draw Goal / Destination Markers (◎) — 2.5x Larger & Prominent
	for robot in robots:
		if not is_instance_valid(robot) or robot.failed or robot.config.goal_node == "":
			continue

		var goal_node = graph_manager.get_graph_node(robot.config.goal_node)
		if goal_node == null:
			continue

		var goal_pos = goal_node.position
		var robot_color = RobotAgent.get_robot_color_by_id(robot.config.robot_id)
		var is_inspected = (robot == selected_robot) or (robot == hovered_robot)

		# 5.1 Large Target Symbol (◎)
		var ring_alpha = 1.0 if is_inspected else 0.85
		var target_col = Color(robot_color.r, robot_color.g, robot_color.b, ring_alpha)

		# Outer target ring (radius: 16px, 2.5px stroke)
		draw_arc(goal_pos, 16.0, 0, TAU, 36, target_col, 2.5)
		# Inner fill
		draw_circle(goal_pos, 16.0, Color(robot_color.r, robot_color.g, robot_color.b, 0.12))
		# Inner target ring (radius: 9px)
		draw_arc(goal_pos, 9.0, 0, TAU, 28, target_col, 1.5)
		# Center bullseye dot (radius: 4px)
		draw_circle(goal_pos, 4.0, target_col)

		if is_inspected:
			# Prominent pulsing/outer ring for inspected robot (radius: 22px)
			draw_arc(goal_pos, 22.0, 0, TAU, 36, target_col.lightened(0.25), 2.0)

		# 5.2 Destination Badge Tag (Clear High-Contrast Card)
		var badge_text = ""
		if robot.state == RobotAgent.RobotState.ARRIVED:
			badge_text = "◎ %s ✓ ARRIVED" % robot.config.robot_id
		elif robot.state == RobotAgent.RobotState.WAITING and robot.wait_reason == "GOAL_OCCUPIED":
			badge_text = "◎ %s ➔ %s [OCCUPIED]" % [robot.config.robot_id, get_station_label(goal_node.id)]
		else:
			var station_label = get_station_label(goal_node.id)
			badge_text = "◎ %s ➔ %s" % [robot.config.robot_id, station_label]

		var text_size = default_font.get_string_size(badge_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
		var badge_w = text_size.x + 14.0
		var badge_h = 18.0
		var badge_rect = Rect2(goal_pos.x - (badge_w * 0.5), goal_pos.y + 19.0, badge_w, badge_h)

		# Card background with robot accent border
		draw_rect(badge_rect, Color(1, 1, 1, 0.98), true)
		draw_rect(badge_rect, target_col, false, 1.5)

		# Label text
		var text_draw_pos = Vector2(badge_rect.position.x + 7.0, badge_rect.position.y + 13.0)
		var text_color = Color(0.06, 0.09, 0.16)
		if robot.state == RobotAgent.RobotState.ARRIVED:
			text_color = Color(0.02, 0.45, 0.3)
		elif robot.state == RobotAgent.RobotState.WAITING and robot.wait_reason == "GOAL_OCCUPIED":
			text_color = Color(0.85, 0.5, 0.02)
		draw_string(default_font, text_draw_pos, badge_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, text_color)


	# 6. SUBTLE COMMUNICATION VISUALIZATION (Selected / Hovered Robot Only)
	if inspection_robot and not inspection_robot.failed:
		var center = inspection_robot.global_position
		var comm_radius = inspection_robot.config.communication_range

		# 6.1 Thin Dotted Outline (Very Low Visual Weight)
		draw_arc(center, comm_radius, 0, TAU, 48, Color(0.15, 0.39, 0.92, 0.18), 1.0)

		# 6.2 Peers within Communication Range
		var peers = []
		for other in robots:
			if is_instance_valid(other) and other != inspection_robot and not other.failed:
				var d = center.distance_to(other.global_position)
				if d <= comm_radius:
					peers.append(other)

					# Thin connection line
					draw_line(center, other.global_position, Color(0.15, 0.39, 0.92, 0.35), 1.5)

					# Subtle peer highlight ring
					draw_arc(other.global_position, other.config.radius + 4.0, 0, TAU, 24, Color(0.06, 0.72, 0.5, 0.75), 1.5)

					# Animated knowledge packet
					var progress = fmod(packet_anim_time * 1.5 + (float(other.get_instance_id()) * 0.1), 1.0)
					var packet_pos = center.lerp(other.global_position, progress)
					draw_circle(packet_pos, 3.5, Color(0.15, 0.39, 0.92))
					draw_circle(packet_pos, 1.5, Color(1.0, 1.0, 1.0))

	# 7. Wait-For Graph (Deadlock Analysis Overlay in Debug Mode)
	if show_wait_graph and deadlock_detector:
		for waiting_id in deadlock_detector.wait_for_graph:
			var blocking_id = deadlock_detector.wait_for_graph[waiting_id]
			var r_wait = robot_manager.get_robot(waiting_id)
			var r_block = robot_manager.get_robot(blocking_id)
			if r_wait and r_block:
				draw_line(r_wait.global_position, r_block.global_position, Color(0.94, 0.27, 0.27, 0.8), 2.5)
				var mid = (r_wait.global_position + r_block.global_position) * 0.5
				draw_string(default_font, mid + Vector2(-20, -8), "WAITS FOR", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.94, 0.27, 0.27))

	# 8. Global Comm Pulses in Debug Mode
	if show_comm:
		for pulse in active_pulses:
			var alpha = 1.0 - (pulse.age / 0.4)
			var current_r = pulse.radius * (pulse.age / 0.4)
			draw_arc(pulse.pos, current_r, 0, TAU, 24, Color(0.2, 0.9, 1.0, alpha * 0.4), 1.5)


func get_station_label(node_id: String) -> String:
	match node_id:
		"N01", "N02": return "PICKUP A"
		"N09", "N10": return "DOCK A"
		"N51", "N52": return "CHARGING"
		"N59", "N60": return "DOCK B"
		_: return node_id

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

