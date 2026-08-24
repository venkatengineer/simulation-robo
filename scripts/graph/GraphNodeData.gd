class_name GraphNodeData
extends Resource

enum NodeType {
	NORMAL,
	INTERSECTION,
	PICKUP,
	DROPOFF,
	CHARGING,
	WAITING,
	BLOCKED
}

@export var id: String = ""
@export var position: Vector2 = Vector2.ZERO
@export var type: NodeType = NodeType.NORMAL
@export var traversable: bool = true
@export var occupied: bool = false
@export var occupied_by_robot_id: String = ""
@export var reserved_by_robot_id: String = ""
@export var neighbors: Dictionary = {} # neighbor_id (String) -> edge_cost (float)

func _init(p_id: String = "", p_pos: Vector2 = Vector2.ZERO, p_type: NodeType = NodeType.NORMAL):
	id = p_id
	position = p_pos
	type = p_type
	traversable = (type != NodeType.BLOCKED)

func set_type(p_type: NodeType) -> void:
	type = p_type
	traversable = (type != NodeType.BLOCKED)

func add_neighbor(neighbor_id: String, cost: float = 1.0) -> void:
	if neighbor_id != id:
		neighbors[neighbor_id] = cost

func remove_neighbor(neighbor_id: String) -> void:
	neighbors.erase(neighbor_id)

func to_dict() -> Dictionary:
	return {
		"id": id,
		"position_x": position.x,
		"position_y": position.y,
		"type": type,
		"traversable": traversable,
		"neighbors": neighbors
	}

static func from_dict(dict: Dictionary) -> GraphNodeData:
	var node = GraphNodeData.new(dict.get("id", ""), Vector2(dict.get("position_x", 0), dict.get("position_y", 0)), dict.get("type", NodeType.NORMAL))
	node.neighbors = dict.get("neighbors", {})
	return node
