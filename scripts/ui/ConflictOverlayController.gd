class_name ConflictOverlayController
extends PanelContainer

@onready var lbl_header: Label = get_node_or_null("VBox/LabelHeader")
@onready var lbl_details: Label = get_node_or_null("VBox/LabelDetails")
@onready var lbl_decision: Label = get_node_or_null("VBox/LabelDecision")

var display_timer: float = 0.0

func _ready() -> void:
	visible = false

func show_conflict_alert(robot_a_id: String, priority_a: float, robot_b_id: String, priority_b: float, winner_id: String, loser_id: String, reason: String = "") -> void:
	visible = true
	display_timer = 3.5

	if lbl_header:
		lbl_header.text = "CONFLICT DETECTED & RESOLVED"
		lbl_header.add_theme_color_override("font_color", Color(0.15, 0.39, 0.92)) # #2563EB
	if lbl_details:
		lbl_details.text = "%s (Priority %.0f)  ↔  %s (Priority %.0f)" % [robot_a_id, priority_a, robot_b_id, priority_b]
	if lbl_decision:
		lbl_decision.text = "RIGHT OF WAY: %s PROCEEDS  |  %s YIELDING" % [winner_id, loser_id]
		lbl_decision.add_theme_color_override("font_color", Color(0.02, 0.45, 0.3)) # #10B981

func show_deadlock_alert(cycle_str: String, resolution_str: String) -> void:
	visible = true
	display_timer = 4.0

	if lbl_header:
		lbl_header.text = "DEADLOCK DETECTED & RESOLVED"
		lbl_header.add_theme_color_override("font_color", Color(0.49, 0.23, 0.93)) # #7C3AED
	if lbl_details:
		lbl_details.text = cycle_str
	if lbl_decision:
		lbl_decision.text = "RESOLUTION: " + resolution_str
		lbl_decision.add_theme_color_override("font_color", Color(0.15, 0.39, 0.92))

func show_demo_stage(stage_title: String, description: String) -> void:
	visible = true
	display_timer = 4.0

	if lbl_header:
		lbl_header.text = stage_title
		lbl_header.add_theme_color_override("font_color", Color(0.15, 0.39, 0.92))
	if lbl_details:
		lbl_details.text = description
	if lbl_decision:
		lbl_decision.text = "P-DMAPF DECENTRALIZED MULTI-AGENT COORDINATION"
		lbl_decision.add_theme_color_override("font_color", Color(0.02, 0.45, 0.3))

func _process(delta: float) -> void:
	if visible:
		display_timer -= delta
		if display_timer <= 0:
			visible = false

