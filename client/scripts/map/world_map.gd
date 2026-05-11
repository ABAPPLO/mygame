extends Node2D

const TILE_SIZE = 32
const MAP_SIZE = 32
const VIEW_RADIUS = 4
const AI_DECISION_INTERVAL = 3.0

var tile_map: Node2D
var fog_map: Node2D
var hero_markers: Dictionary = {}
var monster_data: Dictionary = {}  # key: "x,y" -> monster dict
var monster_visuals: Dictionary = {}
var resource_data: Dictionary = {}
var resource_visuals: Dictionary = {}
var map_data: Dictionary = {}
var revealed: Dictionary = {}
var tile_types: Dictionary = {}
var map_seed: int = 0
var ai_timer: float = 0.0
var ai_busy: bool = false
var info_label: Label
var log_label: RichTextLabel
var camera: Camera2D
var event_log: Array = []


func _ready():
	_create_layers()
	_build_ui()
	if GameManager.has_map_cache():
		_restore_map()
	else:
		_generate_map()
		_place_map_entities()
	_place_heroes()
	_process_battle_result()


func _create_layers():
	tile_map = Node2D.new()
	tile_map.name = "TileMap"
	add_child(tile_map)

	fog_map = Node2D.new()
	fog_map.name = "Fog"
	add_child(fog_map)

	camera = Camera2D.new()
	camera.zoom = Vector2(2, 2)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.0
	add_child(camera)


func _build_ui():
	var ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)

	var ui_root = Control.new()
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(ui_root)

	# Top bar
	var top_panel = Panel.new()
	top_panel.position = Vector2(0, 0)
	top_panel.size = Vector2(1280, 40)
	top_panel.modulate = Color(0, 0, 0, 0.5)
	ui_root.add_child(top_panel)

	var back_btn = Button.new()
	back_btn.text = "<< 返回城镇"
	back_btn.position = Vector2(10, 5)
	back_btn.size = Vector2(120, 30)
	back_btn.pressed.connect(_on_back_button_pressed)
	ui_root.add_child(back_btn)

	info_label = Label.new()
	info_label.position = Vector2(140, 8)
	info_label.size = Vector2(600, 28)
	info_label.add_theme_font_size_override("font_size", 15)
	ui_root.add_child(info_label)

	# Event log panel at bottom
	var log_panel = Panel.new()
	log_panel.position = Vector2(0, 520)
	log_panel.size = Vector2(500, 200)
	log_panel.modulate = Color(0, 0, 0, 0.6)
	ui_root.add_child(log_panel)

	var log_title = Label.new()
	log_title.text = "事件日志"
	log_title.position = Vector2(10, 525)
	log_title.add_theme_font_size_override("font_size", 14)
	log_title.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	ui_root.add_child(log_title)

	log_label = RichTextLabel.new()
	log_label.position = Vector2(10, 545)
	log_label.size = Vector2(480, 170)
	log_label.bbcode_enabled = true
	ui_root.add_child(log_label)


func _generate_map():
	map_data = await NetworkManager.generate_map()
	if map_data.has("error"):
		_log_event("[color=red]地图生成失败[/color]")
		return

	map_seed = map_data.get("seed", 0)
	info_label.text = "地图种子: %d" % map_seed

	var tiles = map_data.get("tiles", [])
	for y in range(MAP_SIZE):
		for x in range(MAP_SIZE):
			if y < tiles.size() and x < tiles[y].size():
				var tile_type = tiles[y][x].get("type", "grass")
				tile_types["%d,%d" % [x, y]] = tile_type
				var cell = ColorRect.new()
				cell.position = Vector2(x * TILE_SIZE, y * TILE_SIZE)
				cell.size = Vector2(TILE_SIZE, TILE_SIZE)
				cell.color = _tile_color(tile_type)
				tile_map.add_child(cell)

				var fog_cell = ColorRect.new()
				fog_cell.position = Vector2(x * TILE_SIZE, y * TILE_SIZE)
				fog_cell.size = Vector2(TILE_SIZE, TILE_SIZE)
				fog_cell.color = Color(0, 0, 0, 1)
				fog_cell.name = "fog_%d_%d" % [x, y]
				fog_map.add_child(fog_cell)

	# Town marker
	var town_pos = map_data.get("town_position", {"x": 1, "y": 1})
	var town_marker = ColorRect.new()
	town_marker.position = Vector2(town_pos.x * TILE_SIZE, town_pos.y * TILE_SIZE)
	town_marker.size = Vector2(TILE_SIZE, TILE_SIZE)
	town_marker.color = Color(0.2, 0.7, 0.9)
	tile_map.add_child(town_marker)
	var town_lbl = Label.new()
	town_lbl.text = "城"
	town_lbl.position = Vector2(town_pos.x * TILE_SIZE + 8, town_pos.y * TILE_SIZE + 6)
	town_lbl.add_theme_font_size_override("font_size", 14)
	town_lbl.add_theme_color_override("font_color", Color.WHITE)
	tile_map.add_child(town_lbl)


func _place_map_entities():
	for m in map_data.get("monsters", []):
		var key = "%d,%d" % [m.x, m.y]
		monster_data[key] = m
		var marker = ColorRect.new()
		marker.position = Vector2(m.x * TILE_SIZE + 8, m.y * TILE_SIZE + 8)
		marker.size = Vector2(16, 16)
		marker.color = Color(1, 0.2, 0.2, 0.9)
		marker.name = "monster_%s" % key
		tile_map.add_child(marker)
		monster_visuals[key] = marker

	for r in map_data.get("resources", []):
		var key = "%d,%d" % [r.x, r.y]
		resource_data[key] = r
		var marker = ColorRect.new()
		marker.position = Vector2(r.x * TILE_SIZE + 10, r.y * TILE_SIZE + 10)
		marker.size = Vector2(12, 12)
		marker.color = Color(1, 0.85, 0.15, 0.9)
		marker.name = "resource_%s" % key
		tile_map.add_child(marker)
		resource_visuals[key] = marker


func _place_heroes():
	for hero in GameManager.heroes:
		if not hero.in_town:
			_create_hero_marker(hero)
			_reveal_around(hero.pos_x, hero.pos_y)


func _process_battle_result():
	if GameManager.last_battle_result.is_empty():
		return
	var result = GameManager.last_battle_result
	GameManager.last_battle_result = {}

	var hero_id = result.get("hero_id", "")
	var hero = GameManager.get_hero(hero_id)
	if hero.is_empty():
		return

	if result.get("victory", false):
		var loot = result.get("loot", {})
		_log_event("[color=green]%s 战斗胜利！[/color] +%d金 +%d经验" % [
			hero.name, loot.get("gold", 0), loot.get("exp", 0)
		])
		# Re-create hero marker since we're back on map
		if not hero.in_town:
			_create_hero_marker(hero)
	else:
		_log_event("[color=red]%s 战败，返回城镇[/color]" % hero.name)
		hero.in_town = true
		hero.pos_x = 1
		hero.pos_y = 1


func _create_hero_marker(hero: Dictionary):
	if hero_markers.has(hero.id):
		var old = hero_markers[hero.id]
		old.queue_free()
		hero_markers.erase(hero.id)

	var marker = ColorRect.new()
	marker.size = Vector2(20, 20)
	marker.color = _class_color(hero.hero_class)
	marker.name = "hero_%s" % hero.id
	tile_map.add_child(marker)
	hero_markers[hero.id] = marker

	var lbl = Label.new()
	lbl.text = hero.name
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.position = Vector2(-10, -15)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	marker.add_child(lbl)


func _tile_color(type: String) -> Color:
	match type:
		"grass": return Color(0.35, 0.55, 0.25)
		"forest": return Color(0.18, 0.40, 0.15)
		"mountain": return Color(0.50, 0.45, 0.40)
		"water": return Color(0.20, 0.35, 0.65)
		_: return Color(0.35, 0.55, 0.25)


func _class_color(hero_class: String) -> Color:
	match hero_class:
		"战士": return Color(0.9, 0.2, 0.2)
		"法师": return Color(0.3, 0.4, 0.9)
		"游侠": return Color(0.2, 0.8, 0.3)
		_: return Color(1, 1, 1)


func _reveal_around(cx: int, cy: int):
	for dx in range(-VIEW_RADIUS, VIEW_RADIUS + 1):
		for dy in range(-VIEW_RADIUS, VIEW_RADIUS + 1):
			var x = cx + dx
			var y = cy + dy
			if x >= 0 and x < MAP_SIZE and y >= 0 and y < MAP_SIZE:
				var key = "%d_%d" % [x, y]
				if not revealed.has(key):
					revealed[key] = true
					var fog_cell = fog_map.get_node_or_null("fog_%s" % key)
					if fog_cell:
						fog_cell.visible = false


func _process(delta):
	# Update hero marker positions
	for hero in GameManager.heroes:
		if not hero.in_town and hero_markers.has(hero.id):
			var marker = hero_markers[hero.id]
			marker.position = Vector2(hero.pos_x * TILE_SIZE + 6, hero.pos_y * TILE_SIZE + 6)
			_reveal_around(hero.pos_x, hero.pos_y)

	# Camera follows first active hero
	var active = GameManager.get_active_heroes()
	if active.size() > 0:
		camera.position = Vector2(active[0].pos_x * TILE_SIZE, active[0].pos_y * TILE_SIZE)

	# AI decision loop
	if not ai_busy and active.size() > 0:
		ai_timer += delta
		if ai_timer >= AI_DECISION_INTERVAL:
			ai_timer = 0.0
			_run_ai_decisions()


func _run_ai_decisions():
	ai_busy = true
	var active = GameManager.get_active_heroes()
	for hero in active:
		await _make_hero_decision(hero)
		await get_tree().create_timer(0.3).timeout
	ai_busy = false


func _make_hero_decision(hero: Dictionary):
	# Build context for LLM
	var nearby_enemies = _scan_nearby(hero.pos_x, hero.pos_y, monster_data, 5)
	var nearby_resources = _scan_nearby(hero.pos_x, hero.pos_y, resource_data, 5)
	var visible_summary = _get_visible_summary(hero.pos_x, hero.pos_y)
	var town_dist = abs(hero.pos_x - 1) + abs(hero.pos_y - 1)
	var def_key = "def" if hero.stats.has("def") else "defense"

	var request_data = {
		"hero_id": hero.id,
		"hero_name": hero.name,
		"hero_class": hero.hero_class,
		"personality": hero.personality,
		"level": hero.level,
		"hp": hero.stats.get("hp", 0),
		"max_hp": hero.max_hp,
		"troops": hero.troops,
		"talent_name": hero.talent.get("name", ""),
		"talent_desc": hero.talent.get("description", ""),
		"x": hero.pos_x,
		"y": hero.pos_y,
		"visible_info": visible_summary,
		"nearby_enemies": nearby_enemies,
		"nearby_resources": nearby_resources,
		"town_distance": town_dist,
	}

	var result = await NetworkManager.ai_explore(request_data)

	if result.has("error"):
		# Fallback: random move on API failure
		_log_event("[color=gray]%s 思考中...(fallback)[/color]" % hero.name)
		_fallback_move(hero)
		return

	_execute_hero_action(hero, result)


func _scan_nearby(cx: int, cy: int, data: Dictionary, radius: int) -> String:
	var found = []
	for key in data:
		var parts = key.split(",")
		var x = int(parts[0])
		var y = int(parts[1])
		var dist = abs(x - cx) + abs(y - cy)
		if dist <= radius:
			var entry = data[key]
			found.append("%s(距离%d)" % [entry.get("name", entry.get("type", "?")), dist])
	if found.is_empty():
		return "无"
	return ", ".join(found)


func _get_visible_summary(cx: int, cy: int) -> String:
	var grass = 0
	var forest = 0
	var mountain = 0
	var water = 0
	for dx in range(-VIEW_RADIUS, VIEW_RADIUS + 1):
		for dy in range(-VIEW_RADIUS, VIEW_RADIUS + 1):
			var key = "%d,%d" % [cx + dx, cy + dy]
			match tile_types.get(key, "grass"):
				"grass": grass += 1
				"forest": forest += 1
				"mountain": mountain += 1
				"water": water += 1
	return "草地%d 森林%d 山地%d 水域%d" % [grass, forest, mountain, water]


func _execute_hero_action(hero: Dictionary, decision: Dictionary):
	var action = decision.get("action", "rest")
	var reason = decision.get("reason", "")

	match action:
		"move":
			var direction = decision.get("direction", "north")
			var dx = 0
			var dy = 0
			match direction:
				"north": dy = -1
				"south": dy = 1
				"east": dx = 1
				"west": dx = -1
				_: dy = -1
			var new_x = clampi(hero.pos_x + dx, 0, MAP_SIZE - 1)
			var new_y = clampi(hero.pos_y + dy, 0, MAP_SIZE - 1)

			# Check if tile is water (impassable)
			var tile_key = "%d,%d" % [new_x, new_y]
			if tile_types.get(tile_key, "grass") == "water":
				_log_event("[color=gray]%s: 前方是水，绕路[/color]" % hero.name)
				_fallback_move(hero)
				return

			hero.pos_x = new_x
			hero.pos_y = new_y
			_log_event("[color=cyan]%s[/color] 向%s移动 (%d,%d)" % [hero.name, direction, new_x, new_y])

			# Check for monster encounter
			var m_key = "%d,%d" % [new_x, new_y]
			if monster_data.has(m_key):
				_trigger_battle(hero, m_key)
				return

			# Check for resource gathering
			if resource_data.has(m_key):
				_gather_resource(hero, m_key)

		"attack":
			var target_pos = decision.get("target", "")
			if target_pos and monster_data.has(target_pos):
				_trigger_battle(hero, target_pos)
			else:
				# No valid target, move instead
				_fallback_move(hero)

		"gather":
			var pos_key = "%d,%d" % [hero.pos_x, hero.pos_y]
			if resource_data.has(pos_key):
				_gather_resource(hero, pos_key)
			else:
				_log_event("[color=gray]%s: 这里没有资源[/color]" % hero.name)

		"rest":
			var heal = 5
			hero.stats.hp = mini(hero.stats.get("hp", 0) + heal, hero.max_hp)
			_log_event("[color=green]%s 休息，恢复 %d HP[/color]" % [hero.name, heal])

		"return_town":
			hero.in_town = true
			hero.pos_x = 1
			hero.pos_y = 1
			if hero_markers.has(hero.id):
				hero_markers[hero.id].queue_free()
				hero_markers.erase(hero.id)
			_log_event("[color=yellow]%s 返回了城镇[/color]" % hero.name)

		_:
			_fallback_move(hero)


func _fallback_move(hero: Dictionary):
	var directions = [[0, -1], [0, 1], [-1, 0], [1, 0]]
	directions.shuffle()
	for d in directions:
		var nx = clampi(hero.pos_x + d[0], 0, MAP_SIZE - 1)
		var ny = clampi(hero.pos_y + d[1], 0, MAP_SIZE - 1)
		var key = "%d,%d" % [nx, ny]
		if tile_types.get(key, "grass") != "water":
			hero.pos_x = nx
			hero.pos_y = ny
			return


func _trigger_battle(hero: Dictionary, monster_key: String):
	var monster = monster_data[monster_key]
	_log_event("[color=red]!! %s 遭遇了 %s！进入战斗！[/color]" % [hero.name, monster.get("name", "怪物")])

	# Remove monster from map
	monster_data.erase(monster_key)
	if monster_visuals.has(monster_key):
		monster_visuals[monster_key].queue_free()
		monster_visuals.erase(monster_key)

	# Save map state before leaving
	_save_map_state()

	# Store battle context and switch scene
	GameManager.start_battle(hero.id, [monster])


func _gather_resource(hero: Dictionary, res_key: String):
	var resource = resource_data[res_key]
	var res_type = resource.get("type", "gold")
	var amount = resource.get("amount", 5)
	ResourceManager.add_resource(res_type, amount)
	_log_event("[color=yellow]%s 采集了 %s x%d[/color]" % [hero.name, res_type, amount])

	# Remove resource from map
	resource_data.erase(res_key)
	if resource_visuals.has(res_key):
		resource_visuals[res_key].queue_free()
		resource_visuals.erase(res_key)


func _log_event(msg: String):
	if not log_label:
		return
	event_log.append(msg)
	if event_log.size() > 50:
		event_log.pop_front()
	var full_text = ""
	for line in event_log:
		full_text += line + "\n"
	log_label.text = full_text
	# Auto-scroll to bottom
	log_label.scroll_to_line(event_log.size())


func _on_back_button_pressed():
	_save_map_state()
	for hero in GameManager.heroes:
		if not hero.in_town:
			hero.in_town = true
			hero.pos_x = 1
			hero.pos_y = 1
	GameManager.change_state(GameManager.GameState.TOWN)


func _save_map_state():
	GameManager.save_map_state({
		"seed": map_seed,
		"map_data": map_data,
		"tile_types": tile_types,
		"monster_data": monster_data,
		"resource_data": resource_data,
		"revealed": revealed,
		"event_log": event_log,
	})


func _restore_map():
	var cache = GameManager.get_map_cache()
	map_seed = cache.get("seed", 0)
	map_data = cache.get("map_data", {})
	tile_types = cache.get("tile_types", {})
	monster_data = cache.get("monster_data", {})
	resource_data = cache.get("resource_data", {})
	revealed = cache.get("revealed", {})
	event_log = cache.get("event_log", [])

	info_label.text = "地图种子: %d | 继续探索..." % map_seed

	# Rebuild visual tiles from cached tile_types
	for key in tile_types:
		var parts = key.split(",")
		var x = int(parts[0])
		var y = int(parts[1])
		var cell = ColorRect.new()
		cell.position = Vector2(x * TILE_SIZE, y * TILE_SIZE)
		cell.size = Vector2(TILE_SIZE, TILE_SIZE)
		cell.color = _tile_color(tile_types[key])
		tile_map.add_child(cell)

	# Restore fog (only reveal previously revealed tiles)
	for key in tile_types:
		var parts = key.split(",")
		var x = int(parts[0])
		var y = int(parts[1])
		var fog_cell = ColorRect.new()
		fog_cell.position = Vector2(x * TILE_SIZE, y * TILE_SIZE)
		fog_cell.size = Vector2(TILE_SIZE, TILE_SIZE)
		fog_cell.color = Color(0, 0, 0, 1)
		fog_cell.name = "fog_%d_%d" % [x, y]
		fog_map.add_child(fog_cell)
		var revealed_key = "%d_%d" % [x, y]
		if revealed.has(revealed_key):
			fog_cell.visible = false

	# Town marker
	var town_pos = map_data.get("town_position", {"x": 1, "y": 1})
	var town_marker = ColorRect.new()
	town_marker.position = Vector2(town_pos.x * TILE_SIZE, town_pos.y * TILE_SIZE)
	town_marker.size = Vector2(TILE_SIZE, TILE_SIZE)
	town_marker.color = Color(0.2, 0.7, 0.9)
	tile_map.add_child(town_marker)

	# Restore monsters
	for key in monster_data:
		var m = monster_data[key]
		var parts = key.split(",")
		var marker = ColorRect.new()
		marker.position = Vector2(int(parts[0]) * TILE_SIZE + 8, int(parts[1]) * TILE_SIZE + 8)
		marker.size = Vector2(16, 16)
		marker.color = Color(1, 0.2, 0.2, 0.9)
		tile_map.add_child(marker)
		monster_visuals[key] = marker

	# Restore resources
	for key in resource_data:
		var r = resource_data[key]
		var parts = key.split(",")
		var marker = ColorRect.new()
		marker.position = Vector2(int(parts[0]) * TILE_SIZE + 10, int(parts[1]) * TILE_SIZE + 10)
		marker.size = Vector2(12, 12)
		marker.color = Color(1, 0.85, 0.15, 0.9)
		tile_map.add_child(marker)
		resource_visuals[key] = marker

	# Restore event log
	if log_label:
		var full_text = ""
		for line in event_log:
			full_text += line + "\n"
		log_label.text = full_text
