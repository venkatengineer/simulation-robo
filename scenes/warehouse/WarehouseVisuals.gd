extends Node2D

const COLOR_BG = Color(0.95, 0.96, 0.98) # #F1F5F9 Concrete warehouse floor
const COLOR_ROAD = Color(1.0, 1.0, 1.0) # #FFFFFF Clean paved road surface
const COLOR_ROAD_BORDER = Color(0.82, 0.86, 0.90) # #CBD5E1 Road curb line
const COLOR_LANE_CENTER = Color(0.88, 0.91, 0.94, 0.7) # #E2E8F0 Subtle AGV guide centerline
const COLOR_INTERSECTION = Color(0.98, 0.99, 1.0) # #F8FAFC
const COLOR_INTERSECTION_BORDER = Color(0.75, 0.82, 0.90, 0.8)

const COLOR_RACK_BODY = Color(0.93, 0.95, 0.97) # #EEF2F6 Steel shelf base
const COLOR_RACK_FRAME = Color(0.65, 0.72, 0.80) # #94A3B8 Upright steel post frame
const COLOR_RACK_TIER = Color(0.80, 0.85, 0.90) # #CBD5E1 Internal shelf tier dividers
const COLOR_RACK_LABEL = Color(0.35, 0.42, 0.52) # #475569 Crisp rack typography

const COLOR_ZONE_PICKUP = Color(0.94, 0.99, 0.96) # #F0FDF4
const COLOR_ZONE_DROPOFF = Color(0.94, 0.97, 1.0) # #EFF6FF
const COLOR_ZONE_CHARGING = Color(0.93, 0.99, 1.0) # #ECFEFF

const ROAD_HALF_WIDTH: float = 30.0 # 60px wide roads (Robot diameter is 36px -> 12px clearance each side)

func _draw() -> void:
	var default_font = ThemeDB.fallback_font

	# 1. Warehouse Foundation Slab
	draw_rect(Rect2(0, 0, 1600, 950), COLOR_BG, true)

	# Facility Perimeter Wall Outline
	var facility_rect = Rect2(165, 75, 1055, 765)
	draw_rect(facility_rect, Color(0.98, 0.98, 0.99), true)
	draw_rect(facility_rect, Color(0.80, 0.84, 0.89), false, 2.0)

	# 2. PHYSICAL ROAD & AISLE NETWORK (Wide Paved Surfaces)
	var horizontal_aisle_y = [130, 260, 390, 520, 650, 780]
	var vertical_aisle_x = [220, 430, 650, 980, 1160]

	# 2.1 Draw Horizontal Main Aisles (Continuous Road Strips)
	for y in horizontal_aisle_y:
		var road_rect = Rect2(190, y - ROAD_HALF_WIDTH, 1000, ROAD_HALF_WIDTH * 2.0)
		draw_rect(road_rect, COLOR_ROAD, true)
		# Top & bottom road curb lines
		draw_line(Vector2(190, y - ROAD_HALF_WIDTH), Vector2(1190, y - ROAD_HALF_WIDTH), COLOR_ROAD_BORDER, 1.5)
		draw_line(Vector2(190, y + ROAD_HALF_WIDTH), Vector2(1190, y + ROAD_HALF_WIDTH), COLOR_ROAD_BORDER, 1.5)
		# Subtle AGV centerline guide
		draw_line(Vector2(190, y), Vector2(1190, y), COLOR_LANE_CENTER, 1.0)

	# 2.2 Draw Vertical Cross Aisles (Road Strips)
	for x in vertical_aisle_x:
		var road_rect = Rect2(x - ROAD_HALF_WIDTH, 100, ROAD_HALF_WIDTH * 2.0, 710)
		draw_rect(road_rect, COLOR_ROAD, true)
		# Left & right road curb lines
		draw_line(Vector2(x - ROAD_HALF_WIDTH, 100), Vector2(x - ROAD_HALF_WIDTH, 810), COLOR_ROAD_BORDER, 1.5)
		draw_line(Vector2(x + ROAD_HALF_WIDTH, 100), Vector2(x + ROAD_HALF_WIDTH, 810), COLOR_ROAD_BORDER, 1.5)
		# Subtle AGV centerline guide
		draw_line(Vector2(x, 100), Vector2(x, 810), COLOR_LANE_CENTER, 1.0)

	# 2.3 Draw Intersection Junction Pads with Corner Ticks
	for x in vertical_aisle_x:
		for y in horizontal_aisle_y:
			var junc_rect = Rect2(x - ROAD_HALF_WIDTH, y - ROAD_HALF_WIDTH, ROAD_HALF_WIDTH * 2.0, ROAD_HALF_WIDTH * 2.0)
			draw_rect(junc_rect, COLOR_INTERSECTION, true)
			
			# Subtle Corner Tick Marks ┌ ┐ └ ┘
			var tick_len: float = 6.0
			var tl = junc_rect.position
			var br = junc_rect.position + junc_rect.size
			var tr = Vector2(br.x, tl.y)
			var bl = Vector2(tl.x, br.y)

			draw_line(tl, tl + Vector2(tick_len, 0), COLOR_INTERSECTION_BORDER, 1.5)
			draw_line(tl, tl + Vector2(0, tick_len), COLOR_INTERSECTION_BORDER, 1.5)

			draw_line(tr, tr + Vector2(-tick_len, 0), COLOR_INTERSECTION_BORDER, 1.5)
			draw_line(tr, tr + Vector2(0, tick_len), COLOR_INTERSECTION_BORDER, 1.5)

			draw_line(bl, bl + Vector2(tick_len, 0), COLOR_INTERSECTION_BORDER, 1.5)
			draw_line(bl, bl + Vector2(0, -tick_len), COLOR_INTERSECTION_BORDER, 1.5)

			draw_line(br, br + Vector2(-tick_len, 0), COLOR_INTERSECTION_BORDER, 1.5)
			draw_line(br, br + Vector2(0, -tick_len), COLOR_INTERSECTION_BORDER, 1.5)

	# 3. STORAGE RACK BLOCKS (Single source of truth from GraphManager.DEFAULT_RACKS)
	var rack_rects = GraphManager.DEFAULT_RACKS
	var rack_idx = 1

	for r in rack_rects:
		# 3.1 Rack Solid Chassis Base
		draw_rect(r, COLOR_RACK_BODY, true)
		# 3.2 Heavy Upright Steel Frame
		draw_rect(r, COLOR_RACK_FRAME, false, 2.0)

		# 3.3 Multi-Tier Shelf Dividers (Realistic Warehouse Pallet Tiers)
		var tier_h = r.size.y / 3.0
		draw_line(Vector2(r.position.x, r.position.y + tier_h), Vector2(r.position.x + r.size.x, r.position.y + tier_h), COLOR_RACK_TIER, 1.0)
		draw_line(Vector2(r.position.x, r.position.y + (tier_h * 2.0)), Vector2(r.position.x + r.size.x, r.position.y + (tier_h * 2.0)), COLOR_RACK_TIER, 1.0)

		# 3.4 Vertical Steel Struts
		var mid_x = r.position.x + (r.size.x * 0.5)
		draw_line(Vector2(mid_x, r.position.y), Vector2(mid_x, r.position.y + r.size.y), Color(0.85, 0.89, 0.93), 1.0)

		# 3.5 Structural Corner Post Caps
		var cap_size: float = 3.5
		draw_rect(Rect2(r.position.x - 1, r.position.y - 1, cap_size, cap_size), COLOR_RACK_FRAME, true)
		draw_rect(Rect2(r.position.x + r.size.x - cap_size + 1, r.position.y - 1, cap_size, cap_size), COLOR_RACK_FRAME, true)
		draw_rect(Rect2(r.position.x - 1, r.position.y + r.size.y - cap_size + 1, cap_size, cap_size), COLOR_RACK_FRAME, true)
		draw_rect(Rect2(r.position.x + r.size.x - cap_size + 1, r.position.y + r.size.y - cap_size + 1, cap_size, cap_size), COLOR_RACK_FRAME, true)

		# 3.6 Clean Typography Label
		var label_str = "RACK %02d" % rack_idx
		rack_idx += 1
		draw_string(default_font, r.position + Vector2(8, 40), label_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, COLOR_RACK_LABEL)

	# 4. FACILITY TERMINAL STATIONS (Integrated with Road Endpoints)
	# Pickup Station A (Top Left: N01 / N02 Terminal)
	var pickup_rect = Rect2(185, 95, 80, 70)
	draw_rect(pickup_rect, COLOR_ZONE_PICKUP, true)
	draw_rect(pickup_rect, Color(0.06, 0.72, 0.5, 0.8), false, 2.0)
	draw_string(default_font, Vector2(192, 135), "PICKUP A", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.02, 0.45, 0.3))

	# Dock A (Top Right: N09 / N10 Terminal)
	var dock_a_rect = Rect2(1115, 95, 80, 70)
	draw_rect(dock_a_rect, COLOR_ZONE_DROPOFF, true)
	draw_rect(dock_a_rect, Color(0.15, 0.39, 0.92, 0.8), false, 2.0)
	draw_string(default_font, Vector2(1127, 135), "DOCK A", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.12, 0.32, 0.75))

	# Charging Station (Bottom Left: N51 / N52 Terminal)
	var charge_rect = Rect2(185, 745, 80, 70)
	draw_rect(charge_rect, COLOR_ZONE_CHARGING, true)
	draw_rect(charge_rect, Color(0.02, 0.71, 0.83, 0.8), false, 2.0)
	draw_string(default_font, Vector2(188, 785), "CHARGING", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.04, 0.48, 0.58))

	# Dock B (Bottom Right: N59 / N60 Terminal)
	var dock_b_rect = Rect2(1115, 745, 80, 70)
	draw_rect(dock_b_rect, COLOR_ZONE_DROPOFF, true)
	draw_rect(dock_b_rect, Color(0.15, 0.39, 0.92, 0.8), false, 2.0)
	draw_string(default_font, Vector2(1127, 785), "DOCK B", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.12, 0.32, 0.75))


