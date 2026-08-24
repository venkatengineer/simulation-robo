class_name GraphEdgeData
extends Resource

@export var id: String = ""
@export var start_id: String = ""
@export var end_id: String = ""
@export var distance: float = 0.0
@export var traversable: bool = true
@export var speed_limit: float = 100.0
@export var congestion_cost: float = 1.0

@export var weight: float:
	get:
		return distance * congestion_cost

func _init(p_start: String = "", p_end: String = "", p_dist: float = 0.0):
	start_id = p_start
	end_id = p_end
	id = "%s-%s" % [p_start, p_end]
	distance = p_dist

func to_dict() -> Dictionary:
	return {
		"id": id,
		"start_id": start_id,
		"end_id": end_id,
		"distance": distance,
		"weight": weight,
		"traversable": traversable,
		"speed_limit": speed_limit,
		"congestion_cost": congestion_cost
	}

static func from_dict(dict: Dictionary) -> GraphEdgeData:
	var edge = GraphEdgeData.new(dict.get("start_id", ""), dict.get("end_id", ""), dict.get("distance", 0.0))
	edge.traversable = dict.get("traversable", true)
	edge.speed_limit = dict.get("speed_limit", 100.0)
	edge.congestion_cost = dict.get("congestion_cost", 1.0)
	return edge
