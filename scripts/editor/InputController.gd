class_name InputController
extends Node2D

signal mode_changed(mode_name: String)
signal status_message_emitted(msg: String)

enum InteractionMode {
	NORMAL,
	SET_START,
	SET_GOAL,
	BLOCK_CELL,
	SELECT_ROBOT
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
	if robot_manager:
		return robot_manager.find_robot_at_position(world_pos, 28.0)
	return null

func _process(delta: float) -> void:
	# Handle manual keyboard control for any robot in MANUAL state
	if robot_manager:
		for r in robot_manager.get_all_robots():
			if is_instance_valid(r) and r.manual_control and r.state == RobotAgent.RobotState.MANUAL:
				var input_dir = Vector2.ZERO
				if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
					input_dir.y -= 1.0
				if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
					input_dir.y += 1.0
				if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
					input_dir.x -= 1.0
				if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
					input_dir.x += 1.0

				if input_dir.length() > 0:
					r.velocity = input_dir.normalized() * r.config.speed
					r.move_and_slide()
				else:
					r.velocity = Vector2.ZERO

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

	# Mouse Motion Preview & Hover Detection
	elif event is InputEventMouseMotion:
		var motion_event = event as InputEventMouseMotion
		_update_hover(motion_event.position)

func _handle_left_click(world_pos: Vector2) -> void:
	var sel_robot = robot_manager.get_selected_robot() if robot_manager else null

	match current_mode:
		InteractionMode.SET_START:
			if sel_robot:
				var node = graph_manager.find_nearest_node(world_pos, 45.0)
				if node and graph_manager.is_node_valid(node.id):
					# Collision check: verify node is not already occupied by another robot
					var is_occupied = false
					var occupying_id = ""
					if robot_manager:
						for other in robot_manager.get_all_robots():
							if is_instance_valid(other) and other != sel_robot and not other.failed:
								var d = other.global_position.distance_to(node.position)
								if other.current_node_id == node.id or d < (sel_robot.config.radius * 2.0 + 6.0):
									is_occupied = true
									occupying_id = other.config.robot_id
									break

					if is_occupied:
						emit_status("START OCCUPIED by %s - Select a free node" % occupying_id)
					else:
						var old_start = sel_robot.config.start_node
						sel_robot.set_start_node(node.id, node.position)
						print("[SET START] Robot: %s | Old Start: %s | New Start: %s | Goal: %s | Path Size: %d" % [
							sel_robot.config.robot_id, old_start, node.id, sel_robot.config.goal_node, sel_robot.planned_path.size()
						])
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
				if node and graph_manager.is_node_valid(node.id):
					var old_goal = sel_robot.config.goal_node
					sel_robot.set_goal_node(node.id)
					print("[SET GOAL] Robot: %s | Start: %s | Old Goal: %s | New Goal: %s | Path Size: %d" % [
						sel_robot.config.robot_id, sel_robot.config.start_node, old_goal, node.id, sel_robot.planned_path.size()
					])
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
			# Normal mode: Robot selection or Deselection
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

	var new_hovered_robot = query_robot_at_position(world_pos)
	if hovered_robot != new_hovered_robot:
		if hovered_robot and is_instance_valid(hovered_robot):
			hovered_robot.set_hovered(false)
		hovered_robot = new_hovered_robot
		if hovered_robot and is_instance_valid(hovered_robot):
			hovered_robot.set_hovered(true)

	queue_redraw()

func _draw() -> void:
	# Mouse Hover Preview when setting START or GOAL
	if (current_mode == InteractionMode.SET_START or current_mode == InteractionMode.SET_GOAL) and hovered_node:
		var preview_color = Color(0.06, 0.72, 0.5, 0.5) if current_mode == InteractionMode.SET_START else Color(0.96, 0.62, 0.04, 0.5)
		if not hovered_node.traversable:
			preview_color = Color(0.94, 0.27, 0.27, 0.5)

		draw_circle(hovered_node.position, 14.0, preview_color)
		draw_arc(hovered_node.position, 14.0, 0, TAU, 24, Color(1, 1, 1, 0.9), 2.0)
