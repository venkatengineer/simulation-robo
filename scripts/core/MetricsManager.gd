class_name MetricsManager
extends Node

var a_star_searches: int = 0
var reroutes_count: int = 0
var active_conflicts: int = 0
var total_collisions: int = 0
var messages_count: int = 0

func reset() -> void:
	a_star_searches = 0
	reroutes_count = 0
	active_conflicts = 0
	total_collisions = 0
	messages_count = 0
