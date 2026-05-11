extends Node2D

signal battle_ended(result: Dictionary)

var hero_data: Dictionary = {}
var enemies: Array = []
var turn: int = 0
var battle_active: bool = false
var action_timer: float = 0.0
var action_interval: float = 1.5

var battle_log: RichTextLabel
var hero_hp_bar: ProgressBar
var troop_hp_bar: ProgressBar
var hero_name_label: Label
var enemy_label: Label
var turn_label: Label


func _ready():
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.06, 0.12, 1)
	bg.position = Vector2(-640, -360)
	bg.size = Vector2(1280, 720)
	bg.z_index = -10
	add_child(bg)

	# Battle ground
	var ground = ColorRect.new()
	ground.color = Color(0.18, 0.22, 0.16, 1)
	ground.position = Vector2(-500, -80)
	ground.size = Vector2(1000, 160)
	add_child(ground)

	# Hero sprite area
	var hero_sprite = ColorRect.new()
	hero_sprite.color = Color(0.9, 0.2, 0.2)
	hero_sprite.position = Vector2(-350, -50)
	hero_sprite.size = Vector2(50, 70)
	add_child(hero_sprite)

	var hero_lbl = Label.new()
	hero_lbl.text = "英雄"
	hero_lbl.position = Vector2(-355, -70)
	hero_lbl.add_theme_font_size_override("font_size", 12)
	add_child(hero_lbl)

	# Enemy area
	var enemy_sprite = ColorRect.new()
	enemy_sprite.color = Color(0.6, 0.2, 0.6)
	enemy_sprite.position = Vector2(250, -50)
	enemy_sprite.size = Vector2(50, 70)
	enemy_sprite.name = "EnemySprite"
	add_child(enemy_sprite)

	enemy_label = Label.new()
	enemy_label.text = "敌人"
	enemy_label.position = Vector2(245, -70)
	enemy_label.add_theme_font_size_override("font_size", 12)
	add_child(enemy_label)

	# VS label
	var vs_label = Label.new()
	vs_label.text = "VS"
	vs_label.position = Vector2(-20, -40)
	vs_label.add_theme_font_size_override("font_size", 32)
	vs_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	add_child(vs_label)

	# UI
	var ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)

	var ui_root = Control.new()
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(ui_root)

	hero_name_label = Label.new()
	hero_name_label.position = Vector2(10, 10)
	hero_name_label.size = Vector2(300, 25)
	hero_name_label.add_theme_font_size_override("font_size", 18)
	ui_root.add_child(hero_name_label)

	# HP bars
	var hero_hp_lbl = Label.new()
	hero_hp_lbl.position = Vector2(10, 40)
	hero_hp_lbl.text = "英雄 HP"
	ui_root.add_child(hero_hp_lbl)

	hero_hp_bar = ProgressBar.new()
	hero_hp_bar.position = Vector2(80, 40)
	hero_hp_bar.size = Vector2(200, 20)
	hero_hp_bar.value = 100
	hero_hp_bar.modulate = Color(0.2, 0.8, 0.2)
	ui_root.add_child(hero_hp_bar)

	var troop_hp_lbl = Label.new()
	troop_hp_lbl.position = Vector2(10, 65)
	troop_hp_lbl.text = "部队 HP"
	ui_root.add_child(troop_hp_lbl)

	troop_hp_bar = ProgressBar.new()
	troop_hp_bar.position = Vector2(80, 65)
	troop_hp_bar.size = Vector2(200, 20)
	troop_hp_bar.value = 100
	troop_hp_bar.modulate = Color(0.3, 0.5, 0.9)
	ui_root.add_child(troop_hp_bar)

	turn_label = Label.new()
	turn_label.position = Vector2(10, 95)
	turn_label.text = "回合: 0"
	turn_label.add_theme_font_size_override("font_size", 16)
	ui_root.add_child(turn_label)

	# Battle log
	battle_log = RichTextLabel.new()
	battle_log.position = Vector2(10, 380)
	battle_log.size = Vector2(600, 250)
	battle_log.bbcode_enabled = true
	battle_log.text = "[b]战斗开始！[/b]\n"
	ui_root.add_child(battle_log)

	# Buttons
	var action_btn = Button.new()
	action_btn.text = "手动释放技能"
	action_btn.position = Vector2(10, 340)
	action_btn.size = Vector2(160, 35)
	action_btn.pressed.connect(_on_action_button_pressed)
	ui_root.add_child(action_btn)

	var back_btn = Button.new()
	back_btn.text = "放弃战斗/返回"
	back_btn.position = Vector2(180, 340)
	back_btn.size = Vector2(150, 35)
	back_btn.pressed.connect(_on_back_button_pressed)
	ui_root.add_child(back_btn)


func setup(hero: Dictionary, enemy_list: Array):
	hero_data = hero.duplicate(true)
	hero_data["troop_hp"] = hero.get("troops", 0) * 10
	enemies = enemy_list.duplicate(true)
	battle_active = true
	turn = 0
	if hero_name_label:
		hero_name_label.text = "%s Lv%d %s" % [hero.name, hero.level, hero.hero_class]
	if enemy_label and enemies.size() > 0:
		enemy_label.text = enemies[0].get("name", "Unknown")
	_update_display()


func _process(delta):
	if not battle_active:
		return

	action_timer += delta
	if action_timer >= action_interval:
		action_timer = 0.0
		_execute_turn()


func _execute_turn():
	turn += 1
	turn_label.text = "回合: %d" % turn

	if enemies.is_empty():
		_end_battle(true)
		return

	var hero_hp = hero_data.stats.get("hp", 0)
	var troop_hp = hero_data.get("troop_hp", 0)
	if hero_hp <= 0 and troop_hp <= 0:
		_end_battle(false)
		return

	# Hero attacks
	var enemy = enemies[0]
	var hero_atk = hero_data.stats.get("atk", 10)
	var hero_def = hero_data.stats.get("def", 5) if hero_data.stats.has("def") else hero_data.stats.get("defense", 5)
	var damage = max(1, hero_atk - enemy.stats.get("def", 2))
	enemy.stats.hp -= damage
	_log("第%d回合: [color=cyan]%s[/color] -> [color=red]%s[/color] 造成 [b]%d[/b] 伤害" % [turn, hero_data.name, enemy.get("name", "Enemy"), damage])

	if enemy.stats.hp <= 0:
		_log("[color=yellow]%s 被击败了！[/color]" % enemy.get("name", "Enemy"))
		enemies.pop_front()
		if enemies.size() > 0:
			enemy_label.text = enemies[0].get("name", "Next")

	# Enemy counterattack
	if enemies.size() > 0:
		var attacker = enemies[0]
		var e_damage = max(1, attacker.stats.atk - hero_def)
		if hero_data.get("troop_hp", 0) > 0:
			hero_data["troop_hp"] = hero_data.get("troop_hp", 0) - e_damage
			_log("  [color=red]%s[/color] 反击部队 -> [b]%d[/b] 伤害" % [attacker.get("name", "Enemy"), e_damage])
		else:
			hero_data.stats.hp -= e_damage
			_log("  [color=red]%s[/color] 反击 [color=cyan]%s[/color] -> [b]%d[/b] 伤害" % [attacker.get("name", "Enemy"), hero_data.name, e_damage])

	_update_display()


func _update_display():
	if hero_hp_bar:
		var hp = float(hero_data.stats.get("hp", 1))
		var max_hp = float(hero_data.get("max_hp", 1))
		hero_hp_bar.value = (hp / max_hp) * 100.0
	if troop_hp_bar:
		var max_troop_hp = float(hero_data.get("max_troops", 1)) * 10.0
		var troop_hp = float(hero_data.get("troop_hp", 0))
		troop_hp_bar.value = (troop_hp / max_troop_hp) * 100.0


func _log(msg: String):
	if battle_log:
		battle_log.append_text(msg + "\n")


func _end_battle(victory: bool):
	battle_active = false

	if victory:
		var loot_gold = 0
		var loot_exp = 0
		for e in enemies:
			var loot = e.get("loot", {})
			loot_gold += loot.get("gold", 0)
			loot_exp += loot.get("exp", 0)
		_log("\n[color=green][b]战斗胜利！[/b][/color]")
		_log("获得 [color=yellow]%d 金币[/color] [color=cyan]%d 经验[/color]" % [loot_gold, loot_exp])
		ResourceManager.add_resource("gold", loot_gold)
		GameManager.add_exp_to_hero(hero_data.id, loot_exp)
		var result = {"victory": true, "hero_id": hero_data.id, "loot": {"gold": loot_gold, "exp": loot_exp}}
		battle_ended.emit(result)
	else:
		_log("\n[color=red][b]战斗失败...[/b][/color]")
		battle_ended.emit({"victory": false, "hero_id": hero_data.id})


func _on_action_button_pressed():
	if not battle_active or enemies.is_empty():
		return
	var enemy = enemies[0]
	var hero_atk = hero_data.stats.get("atk", 10)
	var damage = max(1, int(hero_atk * 2.0) - enemy.stats.get("def", 2))
	enemy.stats.hp -= damage
	_log("[color=green]*手动释放*[/color] %s -> [b]%d[/b] 暴击伤害！" % [hero_data.name, damage])
	if enemy.stats.hp <= 0:
		_log("[color=yellow]%s 被击败了！[/color]" % enemy.get("name", "Enemy"))
		enemies.pop_front()
	_update_display()


func _on_back_button_pressed():
	battle_active = false
	GameManager.change_state(GameManager.GameState.TOWN)
