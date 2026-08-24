class_name GraphEditorController
extends Node

var graph_manager: GraphManager
var robot_manager: RobotManager

func setup(p_graph: GraphManager, p_robot_mgr: RobotManager) -> void:
	graph_manager = p_graph
	robot_manager = p_robot_mgr
