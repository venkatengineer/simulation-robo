class_name GraphManager
extends Node

signal graph_changed

var nodes: Dictionary = {} # String -> GraphNodeData
var edges: Array = [] # Array of GraphEdgeData
var node_counter: int = 1

var planner = null

func _ready() -> void:
	planner = AStarPlanner.new(self)

func find_path(start_id: String, goal_id: String) -> Array[String]:
	if planner:
		return planner.find_path(start_id, goal_id)
	return []

func get_node_position(node_id: String) -> Vector2:
	var node = get_graph_node(node_id)
	return node.position if node else Vector2.ZERO

func is_node_blocked(node_id: String) -> bool:
	var node = get_graph_node(node_id)
	return not node.traversable if node else true

func is_edge_blocked(a: String, b: String) -> bool:
	var edge = get_edge(a, b)
	return not edge.traversable if edge else true

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
	var node = GraphNodeData.new(id, pos, type)
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
	
	var existing = get_edge(start_id, end_id)
	if existing != null:
		return existing

	var node_a = nodes[start_id]
	var node_b = nodes[end_id]
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

	var cols = [310, 410, 520, 630, 740, 850, 960, 1070, 1170, 1250]
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
