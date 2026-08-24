class_name RobotConfig
extends Resource

@export var robot_id: String = "R01"
@export var priority: int = 5
@export var speed: float = 100.0
@export var radius: float = 18.0
@export var battery: float = 100.0
@export var communication_range: float = 180.0
@export var start_node: String = ""
@export var goal_node: String = ""

func duplicate_config() -> RobotConfig:
	var cfg = RobotConfig.new()
	cfg.robot_id = robot_id
	cfg.priority = priority
	cfg.speed = speed
	cfg.radius = radius
	cfg.battery = battery
	cfg.communication_range = communication_range
	cfg.start_node = start_node
	cfg.goal_node = goal_node
	return cfg
