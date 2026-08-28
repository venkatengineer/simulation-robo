class_name RobotAgent
extends CharacterBody2D

signal selected(robot_id: String)

enum RobotState {
	IDLE,
	READY,
	PLANNING,
	MOVING,
	WAITING,
	YIELDING,
	NEGOTIATING,
	REROUTING,
	DEADLOCK_RECOVERY,
	ARRIVED,
	FAILED,
	MANUAL
}

@export var config: RobotConfig = RobotConfig.new()

var graph_manager: GraphManager
var state: RobotState = RobotState.READY
var current_node_id: String = ""
var target_node_id: String = ""
var planned_path: Array[String] = []
var previous_path: Array[String] = []
var path_index: int = 0
var waiting_time: float = 0.0
var failed: bool = false
var manual_control: bool = false
var is_selected_flag: bool = false
var is_hovered_flag: bool = false
var reroute_display_timer: float = 0.0
var stuck_timer: float = 0.0
var yield_timer: float = 0.0
var last_progress_pos: Vector2 = Vector2.ZERO
var is_stuck: bool = false
var wait_reason: String = ""
var destination_wait_timer: float = 0.0
var waiting_target_goal: String = ""


# Local World Model (Decentralized Edge Intelligence)
var local_world_model: Dictionary = {
	"nearby_robots": {},
	"known_blocked_nodes": {},
	"congestion_nodes": {}
}

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var selection_indicator: Node2D = get_node_or_null("SelectionIndicator")
@onready var robot_label: Label = get_node_or_null("RobotLabel")

func configure_graph(graph: GraphManager) -> void:
	graph_manager = graph
	if config.start_node != "" and config.goal_node != "" and planned_path.is_empty():
		var path = graph_manager.find_path(config.start_node, config.goal_node)
		if path.size() > 0:
			planned_path = path
			if planned_path[-1] != config.goal_node:
				planned_path.append(config.goal_node)

func _ready() -> void:
	if selection_indicator:
		selection_indicator.visible = false
	update_ui_label()
	last_progress_pos = global_position

func setup(p_config: RobotConfig) -> void:
	config = p_config
	update_ui_label()
	last_progress_pos = global_position

func set_start_node(node_id: String, pos: Vector2 = Vector2.INF) -> void:
	config.start_node = node_id
	current_node_id = node_id
	if pos != Vector2.INF:
		global_position = pos
	elif graph_manager:
		var n = graph_manager.get_graph_node(node_id)
		if n:
			global_position = n.position
	last_progress_pos = global_position
	stuck_timer = 0.0
	yield_timer = 0.0
	is_stuck = false
	velocity = Vector2.ZERO
	path_index = 0
	previous_path.clear()
	reroute_display_timer = 0.0

	# 1. Invalidate stale planned path
	planned_path.clear()

	# 2. Recalculate A* path from NEW START to EXISTING GOAL
	if config.goal_node != "" and graph_manager:
		var new_path = graph_manager.find_path(node_id, config.goal_node)
		if new_path.size() > 0:
			planned_path = new_path
			if planned_path[-1] != config.goal_node:
				planned_path.append(config.goal_node)

	if state == RobotState.ARRIVED or state == RobotState.PLANNING or state == RobotState.MOVING:
		state = RobotState.READY
	queue_redraw()

func set_goal_node(node_id: String) -> void:
	config.goal_node = node_id
	path_index = 0
	previous_path.clear()
	reroute_display_timer = 0.0

	# 1. Invalidate stale planned path
	planned_path.clear()

	# 2. Recalculate A* path from CURRENT START to NEW GOAL
	var start_id = current_node_id if current_node_id != "" else config.start_node
	if start_id != "" and graph_manager:
		var new_path = graph_manager.find_path(start_id, node_id)
		if new_path.size() > 0:
			planned_path = new_path
			if planned_path[-1] != node_id:
				planned_path.append(node_id)

	if state == RobotState.ARRIVED:
		state = RobotState.READY
	queue_redraw()

func is_path_valid() -> bool:
	if planned_path.size() == 0 or graph_manager == null:
		return false

	var expected_start = current_node_id if current_node_id != "" else config.start_node
	if path_index == 0 and planned_path[0] != expected_start:
		return false

	if planned_path[-1] != config.goal_node:
		return false

	for i in range(path_index, planned_path.size()):
		var n_id = planned_path[i]
		if not graph_manager.is_node_valid(n_id):
			return false
		if i < planned_path.size() - 1:
			var next_id = planned_path[i + 1]
			if not graph_manager.is_edge_valid(n_id, next_id, GraphManager.ROBOT_RADIUS):
				return false

	return true

func start_robot() -> void:
	if failed or config.start_node == "" or config.goal_node == "":
		return
	if state == RobotState.READY or state == RobotState.ARRIVED or state == RobotState.IDLE:
		state = RobotState.PLANNING


func set_state(p_state: RobotState) -> void:
	state = p_state
	if p_state == RobotState.MOVING:
		stuck_timer = 0.0
		yield_timer = 0.0
		is_stuck = false
		last_progress_pos = global_position
	elif p_state == RobotState.WAITING or p_state == RobotState.YIELDING:
		yield_timer = 0.0
		stuck_timer = 0.0
		is_stuck = false
	queue_redraw()

func check_stuck(delta: float) -> bool:
	if failed or manual_control or state != RobotState.MOVING:
		stuck_timer = 0.0
		is_stuck = false
		return false

	var moved = global_position.distance_to(last_progress_pos)
	if velocity.length() < 5.0 or moved < (2.0 * delta):
		stuck_timer += delta
		if stuck_timer >= 1.0:
			is_stuck = true
			return true
	else:
		stuck_timer = max(0.0, stuck_timer - delta * 2.0)
		last_progress_pos = global_position
		is_stuck = false

	return false

func get_next_path_node() -> String:
	if planned_path.size() > 0 and path_index < planned_path.size():
		return planned_path[path_index]
	return ""


func fail() -> void:
	failed = true
	state = RobotState.FAILED
	velocity = Vector2.ZERO
	queue_redraw()

func revive() -> void:
	failed = false
	state = RobotState.READY
	queue_redraw()

func set_manual_control(enable: bool) -> void:
	manual_control = enable
	state = RobotState.MANUAL if enable else RobotState.READY
	if not enable:
		velocity = Vector2.ZERO
	queue_redraw()

func set_selected(is_sel: bool) -> void:
	is_selected_flag = is_sel
	if selection_indicator:
		selection_indicator.visible = is_sel
	queue_redraw()

func set_hovered(is_hov: bool) -> void:
	if is_hovered_flag != is_hov:
		is_hovered_flag = is_hov
		queue_redraw()

func update_local_world_model(sender_robot: RobotAgent, payload: Dictionary = {}) -> void:
	if sender_robot == null:
		return

	local_world_model.nearby_robots[sender_robot.config.robot_id] = {
		"position": sender_robot.global_position,
		"velocity": sender_robot.velocity,
		"priority": sender_robot.config.priority,
		"path": sender_robot.planned_path.duplicate(),
		"state": sender_robot.state,
		"last_seen": Time.get_ticks_msec() / 1000.0
	}

	# Ingest shared knowledge (blocked nodes, congestion)
	if payload.has("blocked_nodes"):
		for bn in payload.blocked_nodes:
			local_world_model.known_blocked_nodes[bn] = true

	if payload.has("congested_node"):
		local_world_model.congestion_nodes[payload.congested_node] = Time.get_ticks_msec() / 1000.0

const ROBOT_PALETTE: Array[Color] = [
	Color(0.15, 0.39, 0.92), # R01: Muted Blue (#2563EB)
	Color(0.06, 0.72, 0.50), # R02: Muted Emerald (#10B981)
	Color(0.92, 0.45, 0.15), # R03: Muted Warm Orange (#EA580C)
	Color(0.49, 0.23, 0.93), # R04: Muted Violet/Purple (#7C3AED)
	Color(0.05, 0.65, 0.75), # R05: Muted Teal/Cyan (#0891B2)
	Color(0.85, 0.25, 0.45), # R06: Muted Rose (#E11D48)
	Color(0.85, 0.60, 0.05), # R07: Muted Amber (#D97706)
	Color(0.25, 0.50, 0.75)  # R08: Muted Steel Blue
]

func get_accent_color() -> Color:
	return get_robot_color_by_id(config.robot_id)

static func get_robot_color_by_id(robot_id: String) -> Color:
	var num_str = ""
	for ch in robot_id:
		if ch.is_valid_int():
			num_str += ch
	var idx = int(num_str) - 1 if num_str != "" else 0
	if idx < 0: idx = 0
	return ROBOT_PALETTE[idx % ROBOT_PALETTE.size()]

func update_ui_label() -> void:
	if robot_label:
		robot_label.rotation = -rotation
		var eff_p = float(config.priority) + (waiting_time * 0.2)

		if state == RobotState.ARRIVED:
			robot_label.text = "%s ✓ ARRIVED" % config.robot_id
			robot_label.add_theme_color_override("font_color", Color(0.02, 0.45, 0.3))
		elif state == RobotState.WAITING or state == RobotState.YIELDING:
			if wait_reason == "GOAL_OCCUPIED":
				robot_label.text = "%s (WAIT: OCCUPIED)" % config.robot_id
			else:
				robot_label.text = "%s (WAIT)" % config.robot_id
			robot_label.add_theme_color_override("font_color", Color(0.85, 0.5, 0.02))
		elif state == RobotState.REROUTING:
			robot_label.text = "%s (REROUTE)" % config.robot_id
			robot_label.add_theme_color_override("font_color", Color(0.45, 0.18, 0.85))

		elif failed:
			robot_label.text = "%s (FAILED)" % config.robot_id
			robot_label.add_theme_color_override("font_color", Color(0.85, 0.15, 0.15))
		else:
			robot_label.text = "%s (P%d)" % [config.robot_id, int(round(eff_p))]
			robot_label.add_theme_color_override("font_color", Color(0.06, 0.09, 0.16))

func _process(delta: float) -> void:
	# Update waiting time
	if state == RobotState.WAITING or state == RobotState.YIELDING or state == RobotState.NEGOTIATING:
		waiting_time += delta
	elif state == RobotState.MOVING:
		waiting_time = max(0.0, waiting_time - delta * 0.5)

	if reroute_display_timer > 0.0:
		reroute_display_timer -= delta

	# Smooth rotation toward movement vector
	if velocity.length() > 5.0:
		var target_angle = velocity.angle()
		rotation = lerp_angle(rotation, target_angle, 10.0 * delta)

	update_ui_label()


func _draw() -> void:
	var accent = get_accent_color()

	# 1. Selection / Hover Outline (Clean Robot Accent Ring)
	if is_selected_flag:
		draw_arc(Vector2.ZERO, config.radius + 5.0, 0, TAU, 32, accent, 2.5)
	elif is_hovered_flag:
		draw_arc(Vector2.ZERO, config.radius + 3.5, 0, TAU, 32, accent.lightened(0.3), 1.5)

	# 2. Industrial AMR Base Chassis (Slate / Charcoal)
	var body_rect = Rect2(-17, -13, 34, 26)
	var base_color = Color(0.12, 0.16, 0.23) # #1E293B
	if state == RobotState.FAILED:
		base_color = Color(0.35, 0.12, 0.12)
	elif state == RobotState.MANUAL:
		base_color = Color(0.25, 0.28, 0.35)

	draw_rect(body_rect, base_color, true)
	draw_rect(body_rect, Color(0.4, 0.48, 0.58), false, 1.5)

	# 3. AMR Wheels / Bumpers (Industrial Black)
	draw_rect(Rect2(-15, -15, 7, 3), Color(0.08, 0.1, 0.14), true)
	draw_rect(Rect2(8, -15, 7, 3), Color(0.08, 0.1, 0.14), true)
	draw_rect(Rect2(-15, 12, 7, 3), Color(0.08, 0.1, 0.14), true)
	draw_rect(Rect2(8, 12, 7, 3), Color(0.08, 0.1, 0.14), true)

	# 4. Front Directional Indicator (Matching Robot Accent Forward Notch)
	var nose_points = PackedVector2Array([
		Vector2(17, 0),
		Vector2(11, -5),
		Vector2(11, 5)
	])
	draw_polygon(nose_points, [accent])

	# 5. Top LiDAR Sensor Hub
	draw_circle(Vector2(-4, 0), 5.0, Color(0.08, 0.1, 0.15))
	draw_circle(Vector2(-4, 0), 2.0, accent)

	# 6. Status LED Indicator
	var status_color = get_state_color(state)
	draw_circle(Vector2(5, 0), 3.5, status_color)
	draw_arc(Vector2(5, 0), 3.5, 0, TAU, 16, Color(1, 1, 1, 0.9), 1.0)

	# 7. Hardware Failure Cross Symbol
	if failed:
		draw_line(Vector2(-9, -9), Vector2(9, 9), Color(0.94, 0.27, 0.27), 2.5)
		draw_line(Vector2(9, -9), Vector2(-9, 9), Color(0.94, 0.27, 0.27), 2.5)


func get_state_color(p_state: RobotState) -> Color:
	match p_state:
		RobotState.IDLE, RobotState.READY, RobotState.ARRIVED:
			return Color(0.06, 0.72, 0.5) # #10B981 Muted Green
		RobotState.MOVING:
			return Color(0.15, 0.39, 0.92) # #2563EB Muted Blue
		RobotState.WAITING, RobotState.YIELDING:
			return Color(0.96, 0.62, 0.04) # #F59E0B Warm Amber
		RobotState.NEGOTIATING:
			return Color(0.92, 0.45, 0.15) # Warm Orange
		RobotState.REROUTING, RobotState.DEADLOCK_RECOVERY:
			return Color(0.49, 0.23, 0.93) # #7C3AED Muted Violet
		RobotState.FAILED:
			return Color(0.94, 0.27, 0.27) # #EF4444 Muted Red
		RobotState.MANUAL:
			return Color(0.95, 0.95, 0.95) # White
		_:
			return Color(0.5, 0.5, 0.5)
