extends Control

signal hero_selected(hero_id: String)

@onready var hero_list_container = $VBox/HeroList
@onready var hero_detail = $VBox/HeroDetail

var selected_hero_id: String = ""


func _ready():
	_refresh_hero_list()


func _refresh_hero_list():
	for child in hero_list_container.get_children():
		child.queue_free()

	for hero in GameManager.heroes:
		var btn = Button.new()
		btn.text = "%s Lv%d %s" % [hero.name, hero.level, hero.hero_class]
		btn.custom_minimum_size = Vector2(200, 40)
		var hero_id = hero.id
		btn.pressed.connect(_on_hero_button_pressed.bind(hero_id))
		hero_list_container.add_child(btn)


func _on_hero_button_pressed(hero_id: String):
	selected_hero_id = hero_id
	_show_hero_detail(hero_id)
	hero_selected.emit(hero_id)


func _show_hero_detail(hero_id: String):
	var hero = GameManager.get_hero(hero_id)
	if hero.is_empty():
		return

	var status = "在城镇中" if hero.in_town else "探索中 (%d, %d)" % [hero.pos_x, hero.pos_y]
	var equip_w = hero.equipment_weapon if hero.equipment_weapon else "无"
	var equip_a = hero.equipment_armor if hero.equipment_armor else "无"

	hero_detail.text = """%s - %s Lv%d
%s

HP: %d/%d | 攻击: %d | 防御: %d | 速度: %d
天赋: %s - %s
部队: %d/%d
武器: %s
护甲: %s
经验: %d/%d

状态: %s""" % [
		hero.name, hero.hero_class, hero.level,
		hero.personality,
		hero.stats.get("hp", 0), hero.max_hp,
		hero.stats.get("atk", 0), hero.stats.get("def", 0) if hero.stats.has("def") else hero.stats.get("defense", 0),
		hero.stats.get("spd", 0),
		hero.talent.get("name", ""), hero.talent.get("description", ""),
		hero.troops, hero.max_troops,
		equip_w, equip_a,
		hero.exp, hero.level * 100,
		status,
	]
