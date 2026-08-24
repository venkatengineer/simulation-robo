class_name ConflictOverlayController
extends PanelContainer

@onready var lbl_header: Label = get_node_or_null("VBox/LabelHeader")
@onready var lbl_details: Label = get_node_or_null("VBox/LabelDetails")
@onready var lbl_decision: Label = get_node_or_null("VBox/LabelDecision")

var display_timer: float = 0.0

func _ready() -> void:
	visible = false

func show_conflict_alert(robot_a_id: String, priority_a: float, robot_b_id: String, priority_b: float, winner_id: String, loser_id: String) -> void:
	visible = true
	display_timer = 2.5 # Show for 2.5 seconds

	if lbl_header: lbl_header.text = "⚠️ INTERSECTION CONFLICT DETECTED"
	if lbl_details: lbl_details.text = "%s (Priority %.1f)  vs  %s (Priority %.1f)" % [robot_a_id, priority_a, robot_b_id, priority_b]
	if lbl_decision: lbl_decision.text = "DECISION:  %s PROCEEDS  |  %s YIELDS" % [winner_id, loser_id]

func _process(delta: float) -> void:
	if visible:
		display_timer -= delta
		if display_timer <= 0:
			visible = false
