class_name GraphManager
extends Node

signal graph_changed

const ROBOT_RADIUS: float = 18.0
const SAFETY_MARGIN: float = 4.0
const DEFAULT_CLEARANCE: float = 22.0

const DEFAULT_RACKS: Array[Rect2] = [
	Rect2(345, 160, 60, 70),
	Rect2(455, 160, 60, 70),
	Rect2(675, 160, 60, 70),
	Rect2(785, 160, 60, 70),
	Rect2(345, 290, 60, 70),
	Rect2(455, 290, 60, 70),
	Rect2(675, 290, 60, 70),
	Rect2(785, 290, 60, 70),
	Rect2(345, 420, 60, 70),
	Rect2(455, 420, 60, 70),
	Rect2(675, 420, 60, 70),
	Rect2(785, 420, 60, 70),
	Rect2(345, 550, 60, 70),
	Rect2(455, 550, 60, 70),
	Rect2(675, 550, 60, 70),
	Rect2(785, 550, 60, 70),
	Rect2(345, 680, 60, 70),
	Rect2(455, 680, 60, 70),
	Rect2(675, 680, 60, 70),
	Rect2(785, 680, 60, 70)
]


var obstacles: Array[Rect2] = []
var nodes: Dictionary = {} # String -> GraphNodeData
var edges: Array = [] # Array of GraphEdgeData
var node_counter: int = 1

var planner: AStarPlanner = null

func _init() -> void:
	obstacles = DEFAULT_RACKS.duplicate()
	planner = AStarPlanner.new(self)

func _ready() -> void:
	if planner == null:
		planner = AStarPlanner.new(self)


func get_static_obstacles() -> Array[Rect2]:
	return obstacles

func set_static_obstacles(p_obstacles: Array[Rect2]) -> void:
	obstacles = p_obstacles.duplicate()
	graph_changed.emit()

# ---------------------------------------------------------
# Geometric Obstacle & Collision Checks
# ---------------------------------------------------------

static func segment_intersects_segment(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	var denom = (b.x - a.x) * (d.y - c.y) - (b.y - a.y) * (d.x - c.x)
	if is_zero_approx(denom):
		return false # Parallel or collinear
	var r = ((a.y - c.y) * (d.x - c.x) - (a.x - c.x) * (d.y - c.y)) / denom
	var s = ((a.y - c.y) * (b.x - a.x) - (a.x - c.x) * (b.y - a.y)) / denom
	return (r >= 0.0 and r <= 1.0 and s >= 0.0 and s <= 1.0)

func is_segment_intersecting_rect(p1: Vector2, p2: Vector2, rect: Rect2, clearance: float = 0.0) -> bool:
	var exp_rect = rect.grow(clearance)

	# If either endpoint lies within the expanded obstacle rectangle
	if exp_rect.has_point(p1) or exp_rect.has_point(p2):
		return true

	# Fast 2D Bounding Box Rejection
	var seg_min_x = min(p1.x, p2.x)
	var seg_max_x = max(p1.x, p2.x)
	var seg_min_y = min(p1.y, p2.y)
	var seg_max_y = max(p1.y, p2.y)

	if seg_max_x < exp_rect.position.x or seg_min_x > (exp_rect.position.x + exp_rect.size.x):
		return false
	if seg_max_y < exp_rect.position.y or seg_min_y > (exp_rect.position.y + exp_rect.size.y):
		return false

	var tl = exp_rect.position
	var tr = Vector2(exp_rect.position.x + exp_rect.size.x, exp_rect.position.y)
	var bl = Vector2(exp_rect.position.x, exp_rect.position.y + exp_rect.size.y)
	var br = exp_rect.position + exp_rect.size

	# Check against all 4 bounding edges of the rectangle
	if segment_intersects_segment(p1, p2, tl, tr): return true
	if segment_intersects_segment(p1, p2, tr, br): return true
	if segment_intersects_segment(p1, p2, br, bl): return true
	if segment_intersects_segment(p1, p2, bl, tl): return true

	return false

func is_point_in_obstacle(pos: Vector2, clearance: float = 0.0) -> bool:
	for rack in obstacles:
		if rack.grow(clearance).has_point(pos):
			return true
	return false

func is_segment_intersecting_obstacle(p1: Vector2, p2: Vector2, clearance: float = ROBOT_RADIUS) -> bool:
	for rack in obstacles:
		if is_segment_intersecting_rect(p1, p2, rack, clearance):
			return true
	return false

func is_node_valid(node_id: String) -> bool:
	if not nodes.has(node_id):
		return false
	var node = nodes[node_id]
	if not node.traversable or node.type == GraphNodeData.NodeType.BLOCKED:
		return false
	if is_point_in_obstacle(node.position, 0.0):
		return false
	return true

func is_edge_valid(start_id: String, end_id: String, clearance: float = ROBOT_RADIUS) -> bool:
	if not is_node_valid(start_id) or not is_node_valid(end_id):
		return false
	var edge = get_edge(start_id, end_id)
	if edge == null or not edge.traversable:
		return false
	var node_a = nodes[start_id]
	var node_b = nodes[end_id]
	if is_segment_intersecting_obstacle(node_a.position, node_b.position, clearance):
		return false
	return true

# ---------------------------------------------------------
# Path Planning API
# ---------------------------------------------------------

func find_path(start_id: String, goal_id: String, constraints: Dictionary = {}) -> Array[String]:
	if planner == null:
		planner = AStarPlanner.new(self)
	return planner.find_path(start_id, goal_id, constraints)


func get_node_position(node_id: String) -> Vector2:
	var node = get_graph_node(node_id)
	return node.position if node else Vector2.ZERO

func is_node_blocked(node_id: String) -> bool:
	var node = get_graph_node(node_id)
	return not is_node_valid(node_id) if node else true

func is_edge_blocked(a: String, b: String) -> bool:
	return not is_edge_valid(a, b)

func get_neighbors(node_id: String) -> Array[String]:
	var node = get_graph_node(node_id)
	if node:
		var result: Array[String] = []
		for n_id in node.neighbors.keys():
			result.append(String(n_id))
		return result
	return []

func generate_node_id() -> String:
	var id_str = "N%02d" % node_counter
	while nodes.has(id_str):
		node_counter += 1
		id_str = "N%02d" % node_counter
	node_counter += 1
	return id_str

func add_node(pos: Vector2, type: GraphNodeData.NodeType = GraphNodeData.NodeType.NORMAL, custom_id: String = "") -> GraphNodeData:
	var id = custom_id if custom_id != "" else generate_node_id()
	
	# Geometric check: Mark BLOCKED if placed inside obstacle
	if is_point_in_obstacle(pos, 0.0):
		type = GraphNodeData.NodeType.BLOCKED

	var node = GraphNodeData.new(id, pos, type)
	if type == GraphNodeData.NodeType.BLOCKED:
		node.traversable = false

	nodes[id] = node
	graph_changed.emit()
	return node

func get_graph_node(id: String) -> GraphNodeData:
	return nodes.get(id, null)

func remove_node(id: String) -> bool:
	if not nodes.has(id):
		return false
	
	var new_edges: Array = []
	for edge in edges:
		if edge.start_id != id and edge.end_id != id:
			new_edges.append(edge)
	edges = new_edges

	for n_id in nodes:
		nodes[n_id].remove_neighbor(id)

	nodes.erase(id)
	graph_changed.emit()
	return true

func add_edge(start_id: String, end_id: String, speed_limit: float = 100.0) -> GraphEdgeData:
	if start_id == end_id or not nodes.has(start_id) or not nodes.has(end_id):
		return null
	
	var node_a = nodes[start_id]
	var node_b = nodes[end_id]

	# Geometric check: Reject edge creation if crossing obstacle footprint
	if is_segment_intersecting_obstacle(node_a.position, node_b.position, ROBOT_RADIUS):
		push_warning("Rejected edge %s-%s: Intersects storage rack obstacle" % [start_id, end_id])
		return null

	var existing = get_edge(start_id, end_id)
	if existing != null:
		return existing

	var dist = node_a.position.distance_to(node_b.position)
	var edge = GraphEdgeData.new(start_id, end_id, dist)
	edge.speed_limit = speed_limit
	edges.append(edge)

	node_a.add_neighbor(end_id, dist)
	node_b.add_neighbor(start_id, dist)

	graph_changed.emit()
	return edge

func get_edge(start_id: String, end_id: String) -> GraphEdgeData:
	for edge in edges:
		if (edge.start_id == start_id and edge.end_id == end_id) or (edge.start_id == end_id and edge.end_id == start_id):
			return edge
	return null

func remove_edge(start_id: String, end_id: String) -> bool:
	var edge = get_edge(start_id, end_id)
	if edge == null:
		return false
	
	edges.erase(edge)
	if nodes.has(start_id):
		nodes[start_id].remove_neighbor(end_id)
	if nodes.has(end_id):
		nodes[end_id].remove_neighbor(start_id)

	graph_changed.emit()
	return true

func toggle_edge_blocked(start_id: String, end_id: String) -> bool:
	var edge = get_edge(start_id, end_id)
	if edge:
		edge.traversable = not edge.traversable
		graph_changed.emit()
		return true
	return false

func find_nearest_node(pos: Vector2, max_dist: float = 45.0) -> GraphNodeData:
	var closest: GraphNodeData = null
	var min_sq_dist: float = max_dist * max_dist

	for n_id in nodes:
		var node = nodes[n_id]
		var sq_dist = node.position.distance_squared_to(pos)
		if sq_dist < min_sq_dist:
			min_sq_dist = sq_dist
			closest = node

	return closest

func find_nearest_edge(pos: Vector2, max_dist: float = 25.0) -> GraphEdgeData:
	var closest: GraphEdgeData = null
	var min_dist = max_dist

	for edge in edges:
		var node_a = nodes.get(edge.start_id, null)
		var node_b = nodes.get(edge.end_id, null)
		if node_a and node_b:
			var d = point_to_segment_dist(pos, node_a.position, node_b.position)
			if d < min_dist:
				min_dist = d
				closest = edge
	return closest

func point_to_segment_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var l2 = a.distance_squared_to(b)
	if l2 == 0: return p.distance_to(a)
	var t = max(0.0, min(1.0, (p - a).dot(b - a) / l2))
	var projection = a + t * (b - a)
	return p.distance_to(projection)

func clear() -> void:
	nodes.clear()
	edges.clear()
	node_counter = 1
	graph_changed.emit()

# Load Large 60-Node Industrial Warehouse Navigation Graph (10 Cols x 6 Rows)
# Spans x: [310 to 1250], y: [130 to 780]
func load_industrial_warehouse_graph() -> void:
	clear()
	obstacles = DEFAULT_RACKS.duplicate()

	var cols = [220, 320, 430, 540, 650, 760, 870, 980, 1080, 1160]
	var rows = [130, 260, 390, 520, 650, 780]


	var grid = []
	var count = 1

	for r in range(6):
		var row_nodes = []
		for c in range(10):
			var id = "N%02d" % count
			count += 1

			var pos = Vector2(cols[c], rows[r])
			var type = GraphNodeData.NodeType.NORMAL

			# Special Station Classifications
			if r == 0 and c == 0: type = GraphNodeData.NodeType.PICKUP # Pickup A
			elif r == 0 and c == 9: type = GraphNodeData.NodeType.DROPOFF # Dock A
			elif r == 5 and c == 0: type = GraphNodeData.NodeType.CHARGING # Charge Bay
			elif r == 5 and c == 9: type = GraphNodeData.NodeType.DROPOFF # Dock B
			elif (c == 2 or c == 4 or c == 7) and (r >= 1 and r <= 4):
				type = GraphNodeData.NodeType.INTERSECTION # Cross intersections

			add_node(pos, type, id)
			row_nodes.append(id)
		grid.append(row_nodes)

	# Horizontal Aisle Edges
	for r in range(6):
		for c in range(9):
			add_edge(grid[r][c], grid[r][c + 1])

	# Vertical Aisle Cross-Junctions
	for r in range(5):
		for c in range(10):
			# Vertical connections at main cross-junction aisles (Cols 0, 2, 4, 7, 9)
			if c == 0 or c == 2 or c == 4 or c == 7 or c == 9:
				add_edge(grid[r][c], grid[r + 1][c])

func load_acceptance_test_grid() -> void:
	load_industrial_warehouse_graph()
