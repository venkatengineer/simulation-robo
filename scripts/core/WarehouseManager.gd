class_name WarehouseManager
extends Node2D

var graph_manager: GraphManager = GraphManager.new()
var warehouse_visuals_scene: PackedScene = preload("res://scenes/warehouse/WarehouseVisuals.tscn")

func _ready() -> void:
	add_child(graph_manager)
	
	if warehouse_visuals_scene:
		var visuals = warehouse_visuals_scene.instantiate()
		add_child(visuals)
	else:
		var visuals_script = preload("res://scenes/warehouse/WarehouseVisuals.gd")
		var visuals = Node2D.new()
		visuals.set_script(visuals_script)
		add_child(visuals)

func initialize_default_warehouse() -> void:
	graph_manager.load_acceptance_test_grid()
