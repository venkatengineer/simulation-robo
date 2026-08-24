class_name InputController
extends Node2D

signal mode_changed(mode_name: String)
signal status_message_emitted(msg: String)

enum InteractionMode {
	NORMAL,
	SET_START,
	SET_GOAL,
	BLOCK_CELL,
	SELECT_ROBOT,
	PAN_CAMERA
}

var current_mode: InteractionMode = InteractionMode.NORMAL
var graph_manager: GraphManager
var robot_manager: RobotManager

var show_input_debug: bool = false
var hovered_node: GraphNodeData = null
var hovered_robot: RobotAgent = null
var last_status_msg: String = "READY"

func setup(p_graph: GraphManager, p_robot_mgr: RobotManager) -> void:
	graph_manager = p_graph
	robot_manager = p_robot_mgr

func set_mode(new_mode: InteractionMode) -> void:
	if new_mode == InteractionMode.SET_START or new_mode == InteractionMode.SET_GOAL:
		var sel = robot_manager.get_selected_robot() if robot_manager else null
		if sel == null:
			emit_status("SELECT A ROBOT FIRST")
			current_mode = InteractionMode.NORMAL
			mode_changed.emit("NORMAL")
			return

	current_mode = new_mode
	var mode_name = InteractionMode.keys()[current_mode]
	mode_changed.emit(mode_name)
	emit_status("MODE: " + mode_name)
	queue_redraw()

func cancel_mode() -> void:
	set_mode(InteractionMode.NORMAL)

func emit_status(msg: String) -> void:
	last_status_msg = msg
	status_message_emitted.emit(msg)

func query_robot_at_position(world_pos: Vector2) -> RobotAgent:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = world_pos
	query.collision_mask = 2 # Layer 2: ROBOT_COLLISION_LAYER
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var results = space_state.intersect_point(query)
	if results.size() > 0:
		for res in results:
			var collider = res.get("collider", null)
			if collider is RobotAgent:
				return collider as RobotAgent

	# Fallback distance check if physics collider not active
	if robot_manager:
		return robot_manager.find_robot_at_position(world_pos, 25.0)

	return null

func _unhandled_input(event: InputEvent) -> void:
	if graph_manager == null:
		return

	# ESC Key -> Cancel active mode
	if event is InputEventKey:
		var key_event = event as InputEventKey
		if key_event.pressed and key_event.keycode == KEY_ESCAPE:
			cancel_mode()
			get_viewport().set_input_as_handled()
			return

	# Mouse Button Events
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		var mouse_pos = mouse_event.position

		# Right Click -> Cancel current mode
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
			cancel_mode()
			get_viewport().set_input_as_handled()
			return

		# Left Click Processing
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_handle_left_click(mouse_pos)
			get_viewport().set_input_as_handled()

	# Mouse Motion Preview
	elif event is InputEventMouseMotion:
		var motion_event = event as InputEventMouseMotion
		_update_hover(motion_event.position)

func _handle_left_click(world_pos: Vector2) -> void:
	var sel_robot = robot_manager.get_selected_robot() if robot_manager else null

	match current_mode:
		InteractionMode.SET_START:
			if sel_robot:
				var node = graph_manager.find_nearest_node(world_pos, 45.0)
				if node and node.traversable:
					sel_robot.set_start_node(node.id, node.position)
					emit_status("%s START -> %s" % [sel_robot.config.robot_id, node.id])
					if robot_manager: robot_manager.robot_selected.emit(sel_robot)
					set_mode(InteractionMode.NORMAL)
				else:
					emit_status("INVALID LOCATION - Select a valid aisle node")
			else:
				emit_status("NO ROBOT SELECTED")
				set_mode(InteractionMode.NORMAL)

		InteractionMode.SET_GOAL:
			if sel_robot:
				var node = graph_manager.find_nearest_node(world_pos, 45.0)
				if node and node.traversable:
					sel_robot.set_goal_node(node.id)
					emit_status("%s GOAL -> %s" % [sel_robot.config.robot_id, node.id])
					if robot_manager: robot_manager.robot_selected.emit(sel_robot)
					set_mode(InteractionMode.NORMAL)
				else:
					emit_status("INVALID LOCATION - Select a valid aisle node")
			else:
				emit_status("NO ROBOT SELECTED")
				set_mode(InteractionMode.NORMAL)

		InteractionMode.BLOCK_CELL:
			var edge = graph_manager.find_nearest_edge(world_pos, 25.0)
			if edge:
				graph_manager.toggle_edge_blocked(edge.start_id, edge.end_id)
				emit_status("TOGGLED AISLE BLOCK")
			else:
				var node = graph_manager.find_nearest_node(world_pos, 25.0)
				if node:
					node.traversable = not node.traversable
					graph_manager.graph_changed.emit()
					emit_status("TOGGLED NODE BLOCK")

		InteractionMode.NORMAL, _:
			# Normal mode: Physics query robot selection
			var clicked_robot = query_robot_at_position(world_pos)
			if clicked_robot:
				robot_manager.select_robot(clicked_robot.config.robot_id)
				emit_status("SELECTED: %s" % clicked_robot.config.robot_id)
			else:
				robot_manager.select_robot("")
				emit_status("DESELECTED")

func _update_hover(world_pos: Vector2) -> void:
	if graph_manager:
		hovered_node = graph_manager.find_nearest_node(world_pos, 45.0)
	hovered_robot = query_robot_at_position(world_pos)
	queue_redraw()

func _draw() -> void:
	var default_font = ThemeDB.fallback_font

	# 1. Mouse Hover Preview when setting START or GOAL
	if (current_mode == InteractionMode.SET_START or current_mode == InteractionMode.SET_GOAL) and hovered_node:
		var preview_color = Color(0.06, 0.72, 0.5, 0.5) if current_mode == InteractionMode.SET_START else Color(0.96, 0.62, 0.04, 0.5)
		if not hovered_node.traversable:
			preview_color = Color(0.94, 0.27, 0.27, 0.5)

		draw_circle(hovered_node.position, 14.0, preview_color)
		draw_arc(hovered_node.position, 14.0, 0, TAU, 24, Color(1, 1, 1, 0.9), 2.0)

	# 2. Input Debug Developer Overlay
	if show_input_debug:
		var mouse_pos = get_local_mouse_position()
		var sel_id = robot_manager.get_selected_robot().config.robot_id if (robot_manager and robot_manager.get_selected_robot()) else "None"
		var hov_r_id = hovered_robot.config.robot_id if hovered_robot else "None"
		var hov_n_id = hovered_node.id if hovered_node else "None"

		var lines = [
			"=== INPUT DEBUG OVERLAY ===",
			"Mode: %s" % InteractionMode.keys()[current_mode],
			"Mouse Pos: (%.0f, %.0f)" % [mouse_pos.x, mouse_pos.y],
			"Selected Robot: %s" % sel_id,
			"Hovered Robot: %s" % hov_r_id,
			"Hovered Node: %s" % hov_n_id,
			"Last Event: %s" % last_status_msg
		]

		var overlay_rect = Rect2(15, 60, 240, 140)
		draw_rect(overlay_rect, Color(0.05, 0.08, 0.12, 0.85), true)
		draw_rect(overlay_rect, Color(0.2, 0.6, 0.9, 0.8), false, 1.5)

		var y_offset = 78
		for line in lines:
			draw_string(default_font, Vector2(25, y_offset), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.9, 0.9, 0.9))
			y_offset += 18
