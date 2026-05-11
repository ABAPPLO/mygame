extends Node2D

var tavern_heroes: Array = []
var available_equipment: Array = []
var info_label: Label
var hero_list_label: RichTextLabel


func _ready():
	# Build town background
	var bg = ColorRect.new()
	bg.color = Color(0.12, 0.18, 0.10, 1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.z_index = -10
	var canvas = CanvasLayer.new()
	canvas.layer = -1
	add_child(canvas)
	canvas.add_child(bg)
	bg.position = Vector2(-640, -360)
	bg.size = Vector2(1280, 720)

	# Town ground
	var ground = ColorRect.new()
	ground.color = Color(0.25, 0.32, 0.18, 1)
	ground.position = Vector2(-500, -250)
	ground.size = Vector2(1000, 500)
	ground.z_index = -5
	add_child(ground)

	# Buildings
	_create_building(Vector2(-400, -180), Vector2(120, 100), Color(0.55, 0.35, 0.18), "酒馆")
	_create_building(Vector2(-120, -180), Vector2(120, 100), Color(0.45, 0.28, 0.18), "兵营")
	_create_building(Vector2(160, -180), Vector2(120, 100), Color(0.38, 0.32, 0.28), "铁匠铺")

	# UI Layer
	var ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)

	var ui_root = Control.new()
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(ui_root)

	# Resource display
	info_label = Label.new()
	info_label.position = Vector2(10, 10)
	info_label.size = Vector2(500, 30)
	info_label.add_theme_font_size_override("font_size", 18)
	ui_root.add_child(info_label)

	# Buttons
	var btn_y = 45
	var btn_height = 40
	var tavern_btn = Button.new()
	tavern_btn.text = "酒馆招募(10金)"
	tavern_btn.position = Vector2(10, btn_y)
	tavern_btn.size = Vector2(150, btn_height)
	tavern_btn.pressed.connect(_on_tavern_button_pressed)
	ui_root.add_child(tavern_btn)

	var barracks_btn = Button.new()
	barracks_btn.text = "兵营招兵"
	barracks_btn.position = Vector2(170, btn_y)
	barracks_btn.size = Vector2(130, btn_height)
	barracks_btn.pressed.connect(_on_barracks_button_pressed)
	ui_root.add_child(barracks_btn)

	var blacksmith_btn = Button.new()
	blacksmith_btn.text = "铁匠铺装备"
	blacksmith_btn.position = Vector2(310, btn_y)
	blacksmith_btn.size = Vector2(130, btn_height)
	blacksmith_btn.pressed.connect(_on_blacksmith_button_pressed)
	ui_root.add_child(blacksmith_btn)

	var map_btn = Button.new()
	map_btn.text = "出发探索 >>"
	map_btn.position = Vector2(450, btn_y)
	map_btn.size = Vector2(130, btn_height)
	map_btn.pressed.connect(_on_map_button_pressed)
	ui_root.add_child(map_btn)

	# Hero list
	hero_list_label = RichTextLabel.new()
	hero_list_label.position = Vector2(10, 470)
	hero_list_label.size = Vector2(600, 200)
	hero_list_label.bbcode_enabled = true
	ui_root.add_child(hero_list_label)

	_update_info_display()
	_refresh_tavern()
	_load_equipment()


func _create_building(pos: Vector2, size: Vector2, color: Color, label_text: String):
	var building = ColorRect.new()
	building.position = pos
	building.size = size
	building.color = color
	add_child(building)

	var roof = ColorRect.new()
	roof.position = Vector2(pos.x - 10, pos.y - 20)
	roof.size = Vector2(size.x + 20, 25)
	roof.color = Color(color.r * 0.7, color.g * 0.7, color.b * 0.7)
	add_child(roof)

	var lbl = Label.new()
	lbl.text = label_text
	lbl.position = Vector2(pos.x + 20, pos.y + size.y / 2 - 10)
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	add_child(lbl)


func _update_info_display():
	if info_label:
		info_label.text = "金币: %d  |  木材: %d  |  石材: %d  |  水晶: %d" % [
			ResourceManager.gold, ResourceManager.wood,
			ResourceManager.stone, ResourceManager.crystal
		]
	_update_hero_list()


func _update_hero_list():
	if not hero_list_label:
		return
	var text = "[b]英雄列表:[/b]\n"
	if GameManager.heroes.is_empty():
		text += "  (空) 去酒馆招募英雄吧！"
	else:
		for h in GameManager.heroes:
			var status = "在城" if h.in_town else "探索中(%d,%d)" % [h.pos_x, h.pos_y]
			var hp = h.stats.get("hp", 0)
			text += "  [color=yellow]%s[/color] Lv%d %s | HP:%d 兵:%d/%d | %s\n" % [
				h.name, h.level, h.hero_class, hp, h.troops, h.max_troops, status
			]
	hero_list_label.text = text


func _refresh_tavern():
	var result = await NetworkManager.refresh_tavern()
	if result and result.has("heroes"):
		tavern_heroes = result.heroes


func _load_equipment():
	var result = await NetworkManager.get_equipment()
	if result and result.has("weapons"):
		available_equipment = result.weapons + result.get("armors", [])


func _on_tavern_button_pressed():
	if tavern_heroes.is_empty():
		_refresh_tavern()
		return
	if GameManager.heroes.size() >= GameManager.max_heroes:
		info_label.text = "[!] 英雄已满！最多 %d 个" % GameManager.max_heroes
		return
	var cost = 10
	if not ResourceManager.can_afford({"gold": cost}):
		info_label.text = "[!] 金币不足！需要 %d 金" % cost
		return
	ResourceManager.spend({"gold": cost})
	var hero_template = tavern_heroes.pop_front()
	GameManager.add_hero(hero_template)
	info_label.text = "[+] 招募了 %s！" % hero_template.get("name", "Unknown")
	_update_info_display()


func _on_barracks_button_pressed():
	for h in GameManager.heroes:
		if h.in_town and h.troops < h.max_troops:
			var recruit_amount = 5
			var cost = recruit_amount
			if ResourceManager.can_afford({"gold": cost}):
				ResourceManager.spend({"gold": cost})
				h.troops = mini(h.troops + recruit_amount, h.max_troops)
				info_label.text = "[+] %s 招募了 %d 士兵" % [h.name, recruit_amount]
				_update_info_display()
				return
	info_label.text = "[!] 没有在城英雄可招兵，或金币不足"


func _on_blacksmith_button_pressed():
	if available_equipment.is_empty():
		_load_equipment()
		return
	for h in GameManager.heroes:
		if h.in_town:
			var equip = available_equipment[0]
			var cost = equip.get("cost", 0)
			if ResourceManager.can_afford({"gold": cost}):
				ResourceManager.spend({"gold": cost})
				if equip.get("type") == "weapon":
					h.equipment_weapon = equip.id
					h.stats.atk = h.stats.get("atk", 0) + equip.get("stats", {}).get("atk", 0)
					info_label.text = "[+] %s 装备了 %s！" % [h.name, equip.get("name", "")]
				elif equip.get("type") == "armor":
					h.equipment_armor = equip.id
					var def_key = "def" if h.stats.has("def") else "defense"
					h.stats[def_key] = h.stats.get(def_key, 0) + equip.get("stats", {}).get("def", 0)
					info_label.text = "[+] %s 装备了 %s！" % [h.name, equip.get("name", "")]
				_update_info_display()
				return
	info_label.text = "[!] 没有在城英雄或金币不足"


func _on_map_button_pressed():
	if GameManager.heroes.is_empty():
		info_label.text = "[!] 请先招募英雄！"
		return
	for h in GameManager.heroes:
		if h.in_town:
			h.in_town = false
			h.pos_x = 2
			h.pos_y = 2
			break
	GameManager.change_state(GameManager.GameState.MAP)
