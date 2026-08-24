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
var path_index: int = 0
var waiting_time: float = 0.0
var failed: bool = false
var manual_control: bool = false
var is_selected_flag: bool = false

# Local World Model (Decentralized Information Sharing)
var local_world_model: Dictionary = {
	"nearby_robots": {},
	"known_blocked_nodes": []
}

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var selection_indicator: Node2D = get_node_or_null("SelectionIndicator")
@onready var robot_label: Label = get_node_or_null("RobotLabel")

func configure_graph(graph: GraphManager) -> void:
	graph_manager = graph

func _ready() -> void:
	if selection_indicator:
		selection_indicator.visible = false
	update_ui_label()

func setup(p_config: RobotConfig) -> void:
	config = p_config
	update_ui_label()

func set_start_node(node_id: String, pos: Vector2) -> void:
	config.start_node = node_id
	current_node_id = node_id
	global_position = pos
	if state == RobotState.ARRIVED or state == RobotState.PLANNING:
		state = RobotState.READY

func set_goal_node(node_id: String) -> void:
	config.goal_node = node_id
	if state == RobotState.ARRIVED:
		state = RobotState.READY

func start_robot() -> void:
	if failed or config.start_node == "" or config.goal_node == "":
		return
	if state == RobotState.READY or state == RobotState.ARRIVED:
		state = RobotState.PLANNING

func set_state(p_state: RobotState) -> void:
	state = p_state
	if p_state == RobotState.WAITING:
		waiting_time += 0.1
	elif p_state == RobotState.MOVING:
		waiting_time = max(0.0, waiting_time - 0.05)
	queue_redraw()

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
	queue_redraw()

func set_selected(is_sel: bool) -> void:
	is_selected_flag = is_sel
	if selection_indicator:
		selection_indicator.visible = is_sel
	queue_redraw()

func update_local_world_model(sender_robot) -> void:
	local_world_model.nearby_robots[sender_robot.config.robot_id] = {
		"position": sender_robot.global_position,
		"velocity": sender_robot.velocity,
		"priority": sender_robot.config.priority,
		"path": sender_robot.planned_path.duplicate(),
		"state": sender_robot.state,
		"last_seen": Time.get_ticks_msec() / 1000.0
	}

func update_ui_label() -> void:
	if robot_label:
		robot_label.text = "%s (P%d)" % [config.robot_id, config.priority]

func _process(delta: float) -> void:
	if velocity.length() > 5.0:
		var target_angle = velocity.angle()
		rotation = lerp_angle(rotation, target_angle, 10.0 * delta)

func _draw() -> void:
	if is_selected_flag:
		draw_arc(Vector2.ZERO, config.radius + 6.0, 0, TAU, 32, Color(0.2, 0.9, 1.0, 0.9), 2.5)

	var body_rect = Rect2(-18, -14, 36, 28)
	draw_rect(body_rect, Color(0.12, 0.16, 0.24), true)
	draw_rect(body_rect, Color(0.3, 0.4, 0.55), false, 2.0)

	var nose_points = PackedVector2Array([
		Vector2(18, 0),
		Vector2(12, -7),
		Vector2(12, 7)
	])
	draw_polygon(nose_points, [Color(0.96, 0.62, 0.04)])
	draw_circle(Vector2(-4, 0), 5.0, Color(0.05, 0.05, 0.05))

	var status_color = get_state_color(state)
	draw_circle(Vector2(6, 0), 4.0, status_color)
	draw_arc(Vector2(6, 0), 4.0, 0, TAU, 16, Color(1, 1, 1, 0.8), 1.0)

func get_state_color(p_state: RobotState) -> Color:
	match p_state:
		RobotState.IDLE, RobotState.READY, RobotState.ARRIVED:
			return Color(0.06, 0.72, 0.5)
		RobotState.MOVING:
			return Color(0.22, 0.74, 0.97)
		RobotState.WAITING, RobotState.YIELDING:
			return Color(0.96, 0.62, 0.04)
		RobotState.NEGOTIATING:
			return Color(0.97, 0.45, 0.09)
		RobotState.REROUTING, RobotState.DEADLOCK_RECOVERY:
			return Color(0.55, 0.36, 0.96)
		RobotState.FAILED:
			return Color(0.94, 0.27, 0.27)
		RobotState.MANUAL:
			return Color(1.0, 1.0, 1.0)
		_:
			return Color(0.5, 0.5, 0.5)
