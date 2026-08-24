extends Node2D

const COLOR_FLOOR = Color(0.08, 0.1, 0.15)
const COLOR_GRID_LINE = Color(0.2, 0.35, 0.5, 0.18)
const COLOR_RACK_BODY = Color(0.14, 0.18, 0.28)
const COLOR_RACK_BORDER = Color(0.3, 0.45, 0.65)
const COLOR_AISLE_LINE = Color(0.96, 0.62, 0.04, 0.4)
const COLOR_ZONE_PICKUP = Color(0.06, 0.72, 0.5, 0.3)
const COLOR_ZONE_DROPOFF = Color(0.55, 0.36, 0.96, 0.3)
const COLOR_ZONE_CHARGING = Color(0.02, 0.71, 0.83, 0.3)

func _draw() -> void:
	var default_font = ThemeDB.fallback_font

	# 1. Dark Industrial Floor Background & Clear Grid Lines
	draw_rect(Rect2(0, 0, 1600, 950), COLOR_FLOOR, true)

	for x in range(0, 1600, 50):
		draw_line(Vector2(x, 0), Vector2(x, 950), COLOR_GRID_LINE, 1.0)
	for y in range(0, 950, 50):
		draw_line(Vector2(0, y), Vector2(1600, y), COLOR_GRID_LINE, 1.0)

	# 2. Storage Racks Array (Multi-Bay Storage Racks)
	var rack_rects = [
		Rect2(435, 160, 60, 70),
		Rect2(545, 160, 60, 70),
		Rect2(765, 160, 60, 70),
		Rect2(875, 160, 60, 70),
		Rect2(435, 290, 60, 70),
		Rect2(545, 290, 60, 70),
		Rect2(765, 290, 60, 70),
		Rect2(875, 290, 60, 70),
		Rect2(435, 420, 60, 70),
		Rect2(545, 420, 60, 70),
		Rect2(765, 420, 60, 70),
		Rect2(875, 420, 60, 70),
		Rect2(435, 550, 60, 70),
		Rect2(545, 550, 60, 70),
		Rect2(765, 550, 60, 70),
		Rect2(875, 550, 60, 70),
		Rect2(435, 680, 60, 70),
		Rect2(545, 680, 60, 70),
		Rect2(765, 680, 60, 70),
		Rect2(875, 680, 60, 70)
	]

	for r in rack_rects:
		draw_rect(r, COLOR_RACK_BODY, true)
		draw_rect(r, COLOR_RACK_BORDER, false, 2.0)
		draw_line(Vector2(r.position.x, r.position.y + 35), Vector2(r.position.x + r.size.x, r.position.y + 35), Color(0.3, 0.45, 0.6, 0.5), 1.0)
		draw_string(default_font, r.position + Vector2(6, 40), "STORAGE", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.5, 0.65, 0.8))

	# 3. Yellow Safety Aisle Boundary Lines
	var aisle_rows = [130, 260, 390, 520, 650, 780]
	for ay in aisle_rows:
		draw_line(Vector2(280, ay - 25), Vector2(1280, ay - 25), COLOR_AISLE_LINE, 1.5)
		draw_line(Vector2(280, ay + 25), Vector2(1280, ay + 25), COLOR_AISLE_LINE, 1.5)

	# 4. Facility Station Zones
	# Pickup Station A (Top Left)
	var pickup_rect = Rect2(270, 95, 90, 70)
	draw_rect(pickup_rect, COLOR_ZONE_PICKUP, true)
	draw_rect(pickup_rect, Color(0.06, 0.72, 0.5), false, 2.0)
	draw_string(default_font, Vector2(278, 135), "PICKUP A", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.06, 0.72, 0.5))

	# Dock A (Top Right)
	var dock_a_rect = Rect2(1210, 95, 90, 70)
	draw_rect(dock_a_rect, COLOR_ZONE_DROPOFF, true)
	draw_rect(dock_a_rect, Color(0.55, 0.36, 0.96), false, 2.0)
	draw_string(default_font, Vector2(1225, 135), "DOCK A", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.55, 0.36, 0.96))

	# Charging Station (Bottom Left)
	var charge_rect = Rect2(270, 745, 90, 70)
	draw_rect(charge_rect, COLOR_ZONE_CHARGING, true)
	draw_rect(charge_rect, Color(0.02, 0.71, 0.83), false, 2.0)
	draw_string(default_font, Vector2(276, 785), "CHARGING", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.02, 0.71, 0.83))

	# Dock B (Bottom Right)
	var dock_b_rect = Rect2(1210, 745, 90, 70)
	draw_rect(dock_b_rect, COLOR_ZONE_DROPOFF, true)
	draw_rect(dock_b_rect, Color(0.55, 0.36, 0.96), false, 2.0)
	draw_string(default_font, Vector2(1225, 785), "DOCK B", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.55, 0.36, 0.96))
