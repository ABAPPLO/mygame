extends Node2D

var tavern_heroes: Array = []
var available_equipment: Array = []
var info_label: Label
var hero_list_label: RichTextLabel
var tavern_btn: Button
var tavern_status: Label


func _ready():
	# === 2D World (buildings on screen) ===
	var ground = ColorRect.new()
	ground.color = Color(0.25, 0.32, 0.18, 1)
	ground.position = Vector2(40, 80)
	ground.size = Vector2(1200, 350)
	add_child(ground)

	_create_building(Vector2(80, 120), Vector2(180, 140), Color(0.55, 0.35, 0.18), "酒馆")
	_create_building(Vector2(500, 120), Vector2(180, 140), Color(0.45, 0.28, 0.18), "兵营")
	_create_building(Vector2(900, 120), Vector2(180, 140), Color(0.38, 0.32, 0.28), "铁匠铺")

	# Town label
	var town_title = Label.new()
	town_title.text = "- 城  镇 -"
	town_title.position = Vector2(530, 90)
	town_title.add_theme_font_size_override("font_size", 24)
	town_title.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
	add_child(town_title)

	# === UI Layer (screen-space) ===
	var ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)

	var ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(ui)

	# Top bar background
	var top_bar = ColorRect.new()
	top_bar.position = Vector2(0, 0)
	top_bar.size = Vector2(1280, 45)
	top_bar.color = Color(0.05, 0.08, 0.05, 0.85)
	ui.add_child(top_bar)

	# Resource display
	info_label = Label.new()
	info_label.position = Vector2(10, 8)
	info_label.size = Vector2(500, 30)
	info_label.add_theme_font_size_override("font_size", 17)
	info_label.add_theme_color_override("font_color", Color(1, 0.9, 0.7))
	ui.add_child(info_label)

	# Buttons row
	var btn_y = 50
	var btn_h = 38

	tavern_btn = Button.new()
	tavern_btn.text = "酒馆招募 (10金)"
	tavern_btn.position = Vector2(10, btn_y)
	tavern_btn.size = Vector2(160, btn_h)
	tavern_btn.pressed.connect(_on_tavern_button_pressed)
	ui.add_child(tavern_btn)

	tavern_status = Label.new()
	tavern_status.position = Vector2(175, btn_y + 8)
	tavern_status.size = Vector2(200, 25)
	tavern_status.add_theme_font_size_override("font_size", 13)
	tavern_status.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	ui.add_child(tavern_status)

	var barracks_btn = Button.new()
	barracks_btn.text = "兵营招兵"
	barracks_btn.position = Vector2(380, btn_y)
	barracks_btn.size = Vector2(130, btn_h)
	barracks_btn.pressed.connect(_on_barracks_button_pressed)
	ui.add_child(barracks_btn)

	var blacksmith_btn = Button.new()
	blacksmith_btn.text = "铁匠铺装备"
	blacksmith_btn.position = Vector2(520, btn_y)
	blacksmith_btn.size = Vector2(140, btn_h)
	blacksmith_btn.pressed.connect(_on_blacksmith_button_pressed)
	ui.add_child(blacksmith_btn)

	var map_btn = Button.new()
	map_btn.text = ">>> 出发探索 >>>"
	map_btn.position = Vector2(680, btn_y)
	map_btn.size = Vector2(160, btn_h)
	map_btn.pressed.connect(_on_map_button_pressed)
	ui.add_child(map_btn)

	# Hero list panel
	var hero_panel = Panel.new()
	hero_panel.position = Vector2(0, 460)
	hero_panel.size = Vector2(700, 260)
	hero_panel.modulate = Color(0, 0, 0, 0.5)
	ui.add_child(hero_panel)

	var hero_title = Label.new()
	hero_title.text = "英雄列表"
	hero_title.position = Vector2(10, 465)
	hero_title.add_theme_font_size_override("font_size", 16)
	hero_title.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	ui.add_child(hero_title)

	hero_list_label = RichTextLabel.new()
	hero_list_label.position = Vector2(10, 490)
	hero_list_label.size = Vector2(680, 220)
	hero_list_label.bbcode_enabled = true
	ui.add_child(hero_list_label)

	# Initial display
	_update_info_display()

	# Load data from server
	tavern_status.text = "加载中..."
	_refresh_tavern()
	_load_equipment()


func _create_building(pos: Vector2, size: Vector2, color: Color, label_text: String):
	# Roof
	var roof = ColorRect.new()
	roof.position = Vector2(pos.x - 5, pos.y - 15)
	roof.size = Vector2(size.x + 10, 20)
	roof.color = Color(color.r * 0.6, color.g * 0.6, color.b * 0.6)
	add_child(roof)

	# Building body
	var building = ColorRect.new()
	building.position = pos
	building.size = size
	building.color = color
	add_child(building)

	# Door
	var door = ColorRect.new()
	door.position = Vector2(pos.x + size.x / 2 - 12, pos.y + size.y - 30)
	door.size = Vector2(24, 30)
	door.color = Color(color.r * 0.5, color.g * 0.5, color.b * 0.5)
	add_child(door)

	# Label
	var lbl = Label.new()
	lbl.text = label_text
	lbl.position = Vector2(pos.x + size.x / 2 - 25, pos.y + 15)
	lbl.add_theme_font_size_override("font_size", 18)
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
	var text = ""
	if GameManager.heroes.is_empty():
		text = "[i]  (空) 去酒馆招募英雄吧！[/i]"
	else:
		for h in GameManager.heroes:
			var status = "[color=green]在城[/color]" if h.in_town else "[color=cyan]探索中(%d,%d)[/color]" % [h.pos_x, h.pos_y]
			var hp = h.stats.get("hp", 0)
			var weapon = h.equipment_weapon if h.equipment_weapon else "-"
			text += "  [color=yellow]%s[/color] Lv%d [color=white]%s[/color] | HP:%d 攻:%d 防:%d 兵:%d/%d | %s | 武器:%s\n" % [
				h.name, h.level, h.hero_class, hp,
				h.stats.get("atk", 0), h.stats.get("def", 0) if h.stats.has("def") else h.stats.get("defense", 0),
				h.troops, h.max_troops, status, weapon
			]
	hero_list_label.text = text


func _refresh_tavern():
	var result = await NetworkManager.refresh_tavern()
	if result and result.has("heroes"):
		tavern_heroes = result.heroes
		if tavern_heroes.is_empty():
			tavern_status.text = "酒馆暂无英雄"
		else:
			var names = []
			for h in tavern_heroes:
				names.append(h.get("name", "?"))
			tavern_status.text = "可招募: " + ", ".join(names)
	else:
		tavern_status.text = "[连接失败]"


func _load_equipment():
	var result = await NetworkManager.get_equipment()
	if result and result.has("weapons"):
		available_equipment = result.weapons + result.get("armors", [])


func _on_tavern_button_pressed():
	if tavern_heroes.is_empty():
		tavern_status.text = "刷新中..."
		await _refresh_tavern()
		if tavern_heroes.is_empty():
			tavern_status.text = "酒馆暂无英雄"
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
	var hero_name = hero_template.get("name", "Unknown")
	info_label.text = "[+] 招募了 %s！" % hero_name
	tavern_status.text = "已招募 %s" % hero_name
	_update_info_display()


func _on_barracks_button_pressed():
	for h in GameManager.heroes:
		if h.in_town and h.troops < h.max_troops:
			var recruit_amount = 5
			var cost = recruit_amount
			if ResourceManager.can_afford({"gold": cost}):
				ResourceManager.spend({"gold": cost})
				h.troops = mini(h.troops + recruit_amount, h.max_troops)
				info_label.text = "[+] %s 招募了 %d 士兵 (共%d/%d)" % [h.name, recruit_amount, h.troops, h.max_troops]
				_update_info_display()
				return
	info_label.text = "[!] 没有在城英雄可招兵，或金币不足"


func _on_blacksmith_button_pressed():
	if available_equipment.is_empty():
		await _load_equipment()
		if available_equipment.is_empty():
			info_label.text = "[!] 装备加载失败"
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

	# Send first in-town hero to explore
	for h in GameManager.heroes:
		if h.in_town:
			h.in_town = false
			h.pos_x = 2
			h.pos_y = 2
			info_label.text = "%s 出发探索！" % h.name
			break
	GameManager.change_state(GameManager.GameState.MAP)
