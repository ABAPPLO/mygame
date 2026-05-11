extends Node2D

const TILE_SIZE = 32
const MAP_SIZE = 32
const VIEW_RADIUS = 4

var tile_map: TileMapLayer
var fog_map: TileMapLayer
var hero_markers: Dictionary = {}
var monster_markers: Dictionary = {}
var resource_markers: Dictionary = {}
var map_data: Dictionary = {}
var revealed: Dictionary = {}
var map_seed: int = 0
var info_label: Label
var camera: Camera2D


func _ready():
	_setup_map_layers()
	_setup_camera()
	_build_ui()
	_generate_map()
	_place_monsters()
	_place_resources()
	_place_heroes()


func _setup_map_layers():
	tile_map = TileMapLayer.new()
	tile_map.name = "TileMap"
	add_child(tile_map)

	fog_map = TileMapLayer.new()
	fog_map.name = "Fog"
	fog_map.modulate = Color(0, 0, 0, 0.85)
	add_child(fog_map)


func _setup_camera():
	camera = Camera2D.new()
	camera.zoom = Vector2(2, 2)
	camera.position = Vector2(2 * TILE_SIZE, 2 * TILE_SIZE)
	add_child(camera)


func _build_ui():
	var ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)

	var ui_root = Control.new()
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(ui_root)

	var back_btn = Button.new()
	back_btn.text = "<< 返回城镇"
	back_btn.position = Vector2(10, 10)
	back_btn.size = Vector2(130, 35)
	back_btn.pressed.connect(_on_back_button_pressed)
	ui_root.add_child(back_btn)

	info_label = Label.new()
	info_label.position = Vector2(150, 10)
	info_label.size = Vector2(500, 30)
	info_label.add_theme_font_size_override("font_size", 16)
	ui_root.add_child(info_label)


func _generate_map():
	map_data = await NetworkManager.generate_map()
	if map_data.has("error"):
		info_label.text = "地图生成失败: " + str(map_data.error)
		return

	map_seed = map_data.get("seed", 0)
	info_label.text = "地图种子: %d | 探索中..." % map_seed

	var tiles = map_data.get("tiles", [])
	for y in range(MAP_SIZE):
		for x in range(MAP_SIZE):
			if y < tiles.size() and x < tiles[y].size():
				var tile_type = tiles[y][x].get("type", "grass")
				var color = _tile_color(tile_type)
				var cell = ColorRect.new()
				cell.position = Vector2(x * TILE_SIZE, y * TILE_SIZE)
				cell.size = Vector2(TILE_SIZE, TILE_SIZE)
				cell.color = color
				tile_map.add_child(cell)

				# Fog
				var fog_cell = ColorRect.new()
				fog_cell.position = Vector2(x * TILE_SIZE, y * TILE_SIZE)
				fog_cell.size = Vector2(TILE_SIZE, TILE_SIZE)
				fog_cell.color = Color(0, 0, 0, 1)
				fog_cell.name = "fog_%d_%d" % [x, y]
				fog_map.add_child(fog_cell)


func _tile_color(type: String) -> Color:
	match type:
		"grass": return Color(0.35, 0.55, 0.25)
		"forest": return Color(0.18, 0.40, 0.15)
		"mountain": return Color(0.50, 0.45, 0.40)
		"water": return Color(0.20, 0.35, 0.65)
		_: return Color(0.35, 0.55, 0.25)


func _place_monsters():
	for m in map_data.get("monsters", []):
		var marker = ColorRect.new()
		marker.position = Vector2(m.x * TILE_SIZE + 8, m.y * TILE_SIZE + 8)
		marker.size = Vector2(16, 16)
		marker.color = Color(1, 0.3, 0.3, 0.8)
		marker.name = "monster_%d_%d" % [m.x, m.y]
		tile_map.add_child(marker)
		monster_markers[Vector2(m.x, m.y)] = m


func _place_resources():
	for r in map_data.get("resources", []):
		var marker = ColorRect.new()
		marker.position = Vector2(r.x * TILE_SIZE + 10, r.y * TILE_SIZE + 10)
		marker.size = Vector2(12, 12)
		marker.color = Color(1, 0.85, 0.2, 0.8)
		marker.name = "resource_%d_%d" % [r.x, r.y]
		tile_map.add_child(marker)
		resource_markers[Vector2(r.x, r.y)] = r


func _place_heroes():
	for hero in GameManager.heroes:
		if not hero.in_town:
			_create_hero_marker(hero)
			_reveal_around(hero.pos_x, hero.pos_y)


func _create_hero_marker(hero: Dictionary):
	var marker = ColorRect.new()
	marker.size = Vector2(20, 20)
	marker.color = _class_color(hero.hero_class)
	marker.name = hero.id
	tile_map.add_child(marker)
	hero_markers[hero.id] = marker

	var lbl = Label.new()
	lbl.text = hero.name
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.position = Vector2(-10, -15)
	marker.add_child(lbl)


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


func _process(_delta):
	for hero in GameManager.heroes:
		if not hero.in_town and hero_markers.has(hero.id):
			var marker = hero_markers[hero.id]
			marker.position = Vector2(hero.pos_x * TILE_SIZE + 6, hero.pos_y * TILE_SIZE + 6)
			_reveal_around(hero.pos_x, hero.pos_y)

	var active = GameManager.heroes.filter(func(h): return not h.in_town)
	if active.size() > 0:
		camera.position = Vector2(active[0].pos_x * TILE_SIZE, active[0].pos_y * TILE_SIZE)


func _on_back_button_pressed():
	for hero in GameManager.heroes:
		if not hero.in_town:
			hero.in_town = true
			hero.pos_x = 1
			hero.pos_y = 1
	GameManager.change_state(GameManager.GameState.TOWN)
