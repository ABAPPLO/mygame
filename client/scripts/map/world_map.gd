extends Node2D

const TILE_SIZE = 32
const MAP_SIZE = 32
const VIEW_RADIUS = 4
const AI_DECISION_INTERVAL = 3.0

var tile_map: Node2D
var fog_map: Node2D
var hero_markers: Dictionary = {}
var monster_data: Dictionary = {}
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
var status_label: Label
var camera: Camera2D
var event_log: Array = []
var map_loaded: bool = false


func _ready():
	_create_layers()
	_build_ui()
	_log_event("正在加载地图...")
	info_label.text = "正在连接服务器生成地图..."
	if GameManager.has_map_cache():
		_restore_map()
		map_loaded = true
	else:
		await _generate_map()
		_place_map_entities()
		map_loaded = true
	_place_heroes()
	_process_battle_result()
	_snap_camera_to_hero()


func _create_layers():
	tile_map = Node2D.new()
	tile_map.name = "TileMap"
	add_child(tile_map)

	fog_map = Node2D.new()
	fog_map.name = "Fog"
	fog_map.z_index = 1
	add_child(fog_map)

	camera = Camera2D.new()
	camera.zoom = Vector2(2, 2)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	add_child(camera)


func _build_ui():
	var ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)

	var ui_root = Control.new()
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(ui_root)

	# Top bar
	var top_bar = Panel.new()
	top_bar.position = Vector2(0, 0)
	top_bar.size = Vector2(1280, 40)
	top_bar.modulate = Color(0, 0, 0, 0.7)
	ui_root.add_child(top_bar)

	var back_btn = Button.new()
	back_btn.text = "<< 返回城镇"
	back_btn.position = Vector2(10, 5)
	back_btn.size = Vector2(120, 30)
	back_btn.pressed.connect(_on_back_button_pressed)
	ui_root.add_child(back_btn)

	info_label = Label.new()
	info_label.position = Vector2(140, 8)
	info_label.size = Vector2(800, 28)
	info_label.add_theme_font_size_override("font_size", 15)
	info_label.add_theme_color_override("font_color", Color(1, 0.9, 0.7))
	ui_root.add_child(info_label)

	# Status bar (hero position, etc)
	status_label = Label.new()
	status_label.position = Vector2(140, 25)
	status_label.size = Vector2(800, 20)
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
	ui_root.add_child(status_label)

	# Event log panel
	var log_panel = Panel.new()
	log_panel.position = Vector2(0, 520)
	log_panel.size = Vector2(550, 200)
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
	log_label.size = Vector2(530, 170)
	log_label.bbcode_enabled = true
	ui_root.add_child(log_label)


func _generate_map():
	map_data = await NetworkManager.generate_map()
	if map_data.has("error"):
		_log_event("[color=red]地图生成失败: %s[/color]" % str(map_data.error))
		_log_event("[color=gray]使用本地空地图[/color]")
		return

	map_seed = map_data.get("seed", 0)

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

	var m_count = map_data.get("monsters", []).size()
	var r_count = map_data.get("resources", []).size()
	_log_event("[color=green]地图已加载！种子:%d 怪物:%d 资源:%d[/color]" % [map_seed, m_count, r_count])


func _place_map_entities():
	for m in map_data.get("monsters", []):
		var key = "%d,%d" % [m.x, m.y]
		monster_data[key] = m
		var marker = _create_monster_visual(m)
		marker.name = "monster_%s" % key
		tile_map.add_child(marker)
		monster_visuals[key] = marker

	for r in map_data.get("resources", []):
		var key = "%d,%d" % [r.x, r.y]
		resource_data[key] = r
		var marker = _create_resource_visual(r)
		marker.name = "resource_%s" % key
		tile_map.add_child(marker)
		resource_visuals[key] = marker


func _create_monster_visual(m: Dictionary) -> Node2D:
	var container = Node2D.new()
	container.position = Vector2(m.x * TILE_SIZE, m.y * TILE_SIZE)

	# Red square with black border
	var border = ColorRect.new()
	border.position = Vector2(2, 2)
	border.size = Vector2(TILE_SIZE - 4, TILE_SIZE - 4)
	border.color = Color(0, 0, 0)
	container.add_child(border)

	var body = ColorRect.new()
	body.position = Vector2(4, 4)
	body.size = Vector2(TILE_SIZE - 8, TILE_SIZE - 8)
	body.color = Color(1, 0.15, 0.15)
	container.add_child(body)

	# Monster initial
	var lbl = Label.new()
	var name = m.get("name", "?")
	lbl.text = name.left(1)
	lbl.position = Vector2(8, 4)
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	container.add_child(lbl)

	return container


func _create_resource_visual(r: Dictionary) -> Node2D:
	var container = Node2D.new()
	container.position = Vector2(r.x * TILE_SIZE, r.y * TILE_SIZE)

	var diamond = ColorRect.new()
	diamond.position = Vector2(8, 4)
	diamond.size = Vector2(16, 16)
	diamond.color = Color(1, 0.85, 0.1)
	container.add_child(diamond)

	var diamond2 = ColorRect.new()
	diamond2.position = Vector2(10, 6)
	diamond2.size = Vector2(12, 12)
	diamond2.color = Color(1, 0.95, 0.4)
	container.add_child(diamond2)

	return container


func _place_heroes():
	for hero in GameManager.heroes:
		if not hero.in_town:
			_create_hero_marker(hero)
			_reveal_around(hero.pos_x, hero.pos_y)
			_log_event("[color=cyan]%s 出现在地图上 (%d,%d)[/color]" % [hero.name, hero.pos_x, hero.pos_y])


func _snap_camera_to_hero():
	var active = GameManager.get_active_heroes()
	if active.size() > 0:
		camera.position = Vector2(active[0].pos_x * TILE_SIZE + TILE_SIZE / 2, active[0].pos_y * TILE_SIZE + TILE_SIZE / 2)
		camera.position_smoothing_enabled = true


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

	var container = Node2D.new()
	container.name = "hero_%s" % hero.id

	# White border (makes hero easy to spot)
	var border = ColorRect.new()
	border.position = Vector2(-2, -2)
	border.size = Vector2(TILE_SIZE + 4, TILE_SIZE + 4)
	border.color = Color.WHITE
	container.add_child(border)

	# Hero body (class color fills most of tile)
	var body = ColorRect.new()
	body.position = Vector2(0, 0)
	body.size = Vector2(TILE_SIZE, TILE_SIZE)
	body.color = _class_color(hero.hero_class)
	container.add_child(body)

	# Hero name above
	var lbl = Label.new()
	lbl.text = hero.name
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.position = Vector2(-5, -16)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	container.add_child(lbl)

	# HP bar underneath
	var hp_bg = ColorRect.new()
	hp_bg.position = Vector2(0, TILE_SIZE + 2)
	hp_bg.size = Vector2(TILE_SIZE, 4)
	hp_bg.color = Color(0.2, 0.2, 0.2)
	container.add_child(hp_bg)

	var hp_bar = ColorRect.new()
	hp_bar.position = Vector2(0, TILE_SIZE + 2)
	hp_bar.size = Vector2(TILE_SIZE, 4)
	hp_bar.color = Color(0.2, 0.8, 0.2)
	hp_bar.name = "hp_bar"
	container.add_child(hp_bar)

	tile_map.add_child(container)
	hero_markers[hero.id] = container


func _tile_color(type: String) -> Color:
	match type:
		"grass": return Color(0.35, 0.55, 0.25)
		"forest": return Color(0.18, 0.40, 0.15)
		"mountain": return Color(0.50, 0.45, 0.40)
		"water": return Color(0.20, 0.35, 0.65)
		_: return Color(0.35, 0.55, 0.25)


func _class_color(hero_class: String) -> Color:
	match hero_class:
		"战士": return Color(0.85, 0.15, 0.15)
		"法师": return Color(0.25, 0.35, 0.9)
		"游侠": return Color(0.15, 0.75, 0.25)
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
	if not map_loaded:
		return

	# Update hero marker positions and HP bars
	var active = GameManager.get_active_heroes()
	for hero in active:
		if hero_markers.has(hero.id):
			var marker = hero_markers[hero.id]
			marker.position = Vector2(hero.pos_x * TILE_SIZE, hero.pos_y * TILE_SIZE)
			_reveal_around(hero.pos_x, hero.pos_y)
			# Update HP bar
			var hp_bar = marker.get_node_or_null("hp_bar")
			if hp_bar:
				var ratio = float(hero.stats.get("hp", 1)) / float(hero.max_hp)
				hp_bar.size.x = TILE_SIZE * ratio
				hp_bar.color = Color(0.2, 0.8, 0.2) if ratio > 0.5 else Color(0.9, 0.7, 0.1) if ratio > 0.25 else Color(0.9, 0.15, 0.15)

	# Camera follows first active hero
	if active.size() > 0:
		camera.position = Vector2(active[0].pos_x * TILE_SIZE + TILE_SIZE / 2, active[0].pos_y * TILE_SIZE + TILE_SIZE / 2)

	# Status text
	var status_parts = []
	for hero in active:
		status_parts.append("%s(%d,%d) HP:%d 兵:%d" % [
			hero.name, hero.pos_x, hero.pos_y,
			hero.stats.get("hp", 0), hero.troops
		])
	status_label.text = " | ".join(status_parts) + " | 怪物:%d 资源:%d" % [monster_data.size(), resource_data.size()]

	info_label.text = "地图种子:%d | 金:%d 木:%d 石:%d" % [map_seed, ResourceManager.gold, ResourceManager.wood, ResourceManager.stone]

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
	var nearby_enemies = _scan_nearby(hero.pos_x, hero.pos_y, monster_data, 5)
	var nearby_resources = _scan_nearby(hero.pos_x, hero.pos_y, resource_data, 5)
	var visible_summary = _get_visible_summary(hero.pos_x, hero.pos_y)
	var town_dist = abs(hero.pos_x - 1) + abs(hero.pos_y - 1)

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
		_log_event("[color=gray]%s 思考中...(LLM未连接,自动移动)[/color]" % hero.name)
		_fallback_move(hero)
		_check_tile_events(hero)
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

			var tile_key = "%d,%d" % [new_x, new_y]
			if tile_types.get(tile_key, "grass") == "water":
				_fallback_move(hero)
				_check_tile_events(hero)
				return

			hero.pos_x = new_x
			hero.pos_y = new_y
			_log_event("[color=cyan]%s[/color] 向%s移动 (%d,%d)" % [hero.name, direction, new_x, new_y])
			_check_tile_events(hero)

		"attack":
			var target_pos = decision.get("target", "")
			if target_pos and monster_data.has(target_pos):
				_trigger_battle(hero, target_pos)
			else:
				_fallback_move(hero)
				_check_tile_events(hero)

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
			_check_tile_events(hero)


func _check_tile_events(hero: Dictionary):
	var pos_key = "%d,%d" % [hero.pos_x, hero.pos_y]
	if monster_data.has(pos_key):
		_trigger_battle(hero, pos_key)
		return
	if resource_data.has(pos_key):
		_gather_resource(hero, pos_key)


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

	monster_data.erase(monster_key)
	if monster_visuals.has(monster_key):
		monster_visuals[monster_key].queue_free()
		monster_visuals.erase(monster_key)

	_save_map_state()
	GameManager.start_battle(hero.id, [monster])


func _gather_resource(hero: Dictionary, res_key: String):
	var resource = resource_data[res_key]
	var res_type = resource.get("type", "gold")
	var amount = resource.get("amount", 5)
	ResourceManager.add_resource(res_type, amount)
	_log_event("[color=yellow]%s 采集了 %s x%d[/color]" % [hero.name, res_type, amount])

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

	for key in tile_types:
		var parts = key.split(",")
		var x = int(parts[0])
		var y = int(parts[1])
		var cell = ColorRect.new()
		cell.position = Vector2(x * TILE_SIZE, y * TILE_SIZE)
		cell.size = Vector2(TILE_SIZE, TILE_SIZE)
		cell.color = _tile_color(tile_types[key])
		tile_map.add_child(cell)

		var fog_cell = ColorRect.new()
		fog_cell.position = Vector2(x * TILE_SIZE, y * TILE_SIZE)
		fog_cell.size = Vector2(TILE_SIZE, TILE_SIZE)
		fog_cell.color = Color(0, 0, 0, 1)
		fog_cell.name = "fog_%d_%d" % [x, y]
		fog_map.add_child(fog_cell)
		if revealed.has("%d_%d" % [x, y]):
			fog_cell.visible = false

	# Town marker
	var town_pos = map_data.get("town_position", {"x": 1, "y": 1})
	var town_marker = ColorRect.new()
	town_marker.position = Vector2(town_pos.x * TILE_SIZE, town_pos.y * TILE_SIZE)
	town_marker.size = Vector2(TILE_SIZE, TILE_SIZE)
	town_marker.color = Color(0.2, 0.7, 0.9)
	tile_map.add_child(town_marker)

	for key in monster_data:
		var m = monster_data[key]
		var marker = _create_monster_visual(m)
		marker.name = "monster_%s" % key
		tile_map.add_child(marker)
		monster_visuals[key] = marker

	for key in resource_data:
		var r = resource_data[key]
		var marker = _create_resource_visual(r)
		marker.name = "resource_%s" % key
		tile_map.add_child(marker)
		resource_visuals[key] = marker

	if log_label:
		var full_text = ""
		for line in event_log:
			full_text += line + "\n"
		log_label.text = full_text

	_log_event("[color=green]地图已恢复[/color]")
