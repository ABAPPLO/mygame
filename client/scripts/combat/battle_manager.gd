extends Node2D

var hero_data: Dictionary = {}
var enemies: Array = []
var original_hero_id: String = ""
var turn: int = 0
var battle_active: bool = false
var action_timer: float = 0.0
var action_interval: float = 1.5

var battle_log: RichTextLabel
var hero_hp_bar: ProgressBar
var troop_hp_bar: ProgressBar
var hero_name_label: Label
var enemy_label: Label
var enemy_hp_bar: ProgressBar
var turn_label: Label


func _ready():
	_build_scene()
	_init_battle()


func _build_scene():
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.06, 0.12, 1)
	bg.position = Vector2(0, 0)
	bg.size = Vector2(1280, 720)
	bg.z_index = -10
	add_child(bg)

	# Battle ground
	var ground = ColorRect.new()
	ground.color = Color(0.18, 0.22, 0.16, 1)
	ground.position = Vector2(140, 180)
	ground.size = Vector2(1000, 160)
	add_child(ground)

	# Hero sprite
	var hero_sprite = ColorRect.new()
	hero_sprite.color = Color(0.9, 0.2, 0.2)
	hero_sprite.position = Vector2(220, 200)
	hero_sprite.size = Vector2(60, 80)
	add_child(hero_sprite)

	var hero_lbl = Label.new()
	hero_lbl.text = "英雄"
	hero_lbl.position = Vector2(225, 178)
	hero_lbl.add_theme_font_size_override("font_size", 13)
	hero_lbl.add_theme_color_override("font_color", Color.WHITE)
	add_child(hero_lbl)

	# Enemy sprite
	var enemy_sprite = ColorRect.new()
	enemy_sprite.color = Color(0.6, 0.2, 0.6)
	enemy_sprite.position = Vector2(920, 200)
	enemy_sprite.size = Vector2(60, 80)
	enemy_sprite.name = "EnemySprite"
	add_child(enemy_sprite)

	enemy_label = Label.new()
	enemy_label.text = "敌人"
	enemy_label.position = Vector2(925, 178)
	enemy_label.add_theme_font_size_override("font_size", 13)
	enemy_label.add_theme_color_override("font_color", Color.WHITE)
	add_child(enemy_label)

	# VS
	var vs_label = Label.new()
	vs_label.text = "VS"
	vs_label.position = Vector2(600, 210)
	vs_label.add_theme_font_size_override("font_size", 36)
	vs_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	add_child(vs_label)

	# UI Layer
	var ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)

	var ui_root = Control.new()
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(ui_root)

	# Hero info
	hero_name_label = Label.new()
	hero_name_label.position = Vector2(10, 10)
	hero_name_label.size = Vector2(300, 25)
	hero_name_label.add_theme_font_size_override("font_size", 18)
	ui_root.add_child(hero_name_label)

	# Hero HP
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

	# Troop HP
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

	# Enemy HP
	var enemy_hp_lbl = Label.new()
	enemy_hp_lbl.position = Vector2(350, 40)
	enemy_hp_lbl.text = "敌人 HP"
	ui_root.add_child(enemy_hp_lbl)

	enemy_hp_bar = ProgressBar.new()
	enemy_hp_bar.position = Vector2(420, 40)
	enemy_hp_bar.size = Vector2(200, 20)
	enemy_hp_bar.value = 100
	enemy_hp_bar.modulate = Color(0.9, 0.2, 0.2)
	ui_root.add_child(enemy_hp_bar)

	# Turn
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
	ui_root.add_child(battle_log)

	# Buttons
	var action_btn = Button.new()
	action_btn.text = "手动释放技能"
	action_btn.position = Vector2(10, 340)
	action_btn.size = Vector2(160, 35)
	action_btn.pressed.connect(_on_action_button_pressed)
	ui_root.add_child(action_btn)

	var retreat_btn = Button.new()
	retreat_btn.text = "撤退返回"
	retreat_btn.position = Vector2(180, 340)
	retreat_btn.size = Vector2(120, 35)
	retreat_btn.pressed.connect(_on_retreat_button_pressed)
	ui_root.add_child(retreat_btn)

	var auto_btn = Button.new()
	auto_btn.text = "加速 x2"
	auto_btn.position = Vector2(310, 340)
	auto_btn.size = Vector2(100, 35)
	auto_btn.pressed.connect(_on_speed_button_pressed)
	ui_root.add_child(auto_btn)


func _init_battle():
	if GameManager.pending_battle.is_empty():
		_log("[color=red]没有战斗数据[/color]")
		return

	var hero_id = GameManager.pending_battle.get("hero_id", "")
	var hero = GameManager.get_hero(hero_id)
	if hero.is_empty():
		_log("[color=red]找不到英雄[/color]")
		return

	var enemy_list = GameManager.pending_battle.get("enemies", [])
	GameManager.pending_battle = {}

	hero_data = hero.duplicate(true)
	hero_data["troop_hp"] = hero.get("troops", 0) * 10
	original_hero_id = hero_id
	enemies = enemy_list.duplicate(true)

	# Deep copy enemy stats so we can modify them
	for i in range(enemies.size()):
		enemies[i] = enemies[i].duplicate(true)
		enemies[i]["stats"] = enemies[i]["stats"].duplicate()

	battle_active = true
	turn = 0

	hero_name_label.text = "[color=cyan]%s[/color] Lv%d %s (兵:%d)" % [
		hero.name, hero.level, hero.hero_class, hero.get("troops", 0)
	]
	if enemies.size() > 0:
		enemy_label.text = enemies[0].get("name", "???")
		enemy_hp_bar.max_value = enemies[0].stats.get("hp", 30)
		enemy_hp_bar.value = enemies[0].stats.get("hp", 30)

	_log("[b]===== 战斗开始 =====[/b]")
	_log("%s vs %s" % [hero.name, enemies[0].get("name", "???") if enemies.size() > 0 else "???"])
	_log("")
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
	if hero_hp <= 0:
		_end_battle(false)
		return

	# ---- Hero attacks ----
	var enemy = enemies[0]
	var hero_atk = hero_data.stats.get("atk", 10)
	var hero_def = hero_data.stats.get("def", 5) if hero_data.stats.has("def") else hero_data.stats.get("defense", 5)

	# Check for skill usage (auto)
	var skill_used = false
	for skill in hero_data.get("skills", []):
		if skill.get("current_cooldown", 0) <= 0:
			var multiplier = skill.get("damage_multiplier", 1.0)
			var skill_damage = max(1, int(hero_atk * multiplier) - enemy.stats.get("def", 2))
			enemy.stats.hp -= skill_damage
			skill["current_cooldown"] = skill.get("cooldown", 3)
			_log("第%d回合: [color=cyan]%s[/color] 使用 [color=yellow]%s[/color] -> [color=red]%s[/color] [b]%d[/b]伤害" % [
				turn, hero_data.name, skill.get("name", "技能"), enemy.get("name", "敌"), skill_damage
			])
			skill_used = true
			break

	if not skill_used:
		var damage = max(1, hero_atk - enemy.stats.get("def", 2))
		enemy.stats.hp -= damage
		_log("第%d回合: [color=cyan]%s[/color] 普攻 -> [color=red]%s[/color] [b]%d[/b]伤害" % [
			turn, hero_data.name, enemy.get("name", "敌"), damage
		])

	# Reduce cooldowns
	for skill in hero_data.get("skills", []):
		if skill.get("current_cooldown", 0) > 0:
			skill["current_cooldown"] -= 1

	# Check enemy defeat
	if enemy.stats.hp <= 0:
		_log("[color=yellow]%s 被击败了！[/color]" % enemy.get("name", "敌人"))
		enemies.pop_front()
		if enemies.size() > 0:
			enemy_label.text = enemies[0].get("name", "???")
			enemy_hp_bar.max_value = enemies[0].stats.get("hp", 30)
			enemy_hp_bar.value = enemies[0].stats.get("hp", 30)
		_update_display()
		if enemies.is_empty():
			_end_battle(true)
			return

	# ---- Enemy counterattack ----
	if enemies.size() > 0:
		var attacker = enemies[0]
		var e_damage = max(1, attacker.stats.atk - hero_def)
		if hero_data.get("troop_hp", 0) > 0:
			hero_data["troop_hp"] = max(0, hero_data.get("troop_hp", 0) - e_damage)
			_log("  [color=red]%s[/color] -> 部队 [b]%d[/b]伤害" % [attacker.get("name", "敌"), e_damage])
		else:
			hero_data.stats.hp -= e_damage
			_log("  [color=red]%s[/color] -> [color=cyan]%s[/color] [b]%d[/b]伤害" % [
				attacker.get("name", "敌"), hero_data.name, e_damage
			])
			if hero_data.stats.hp <= 0:
				_update_display()
				_end_battle(false)
				return

	_update_display()


func _update_display():
	if hero_hp_bar:
		var hp = max(0, float(hero_data.stats.get("hp", 0)))
		var max_hp = float(hero_data.get("max_hp", 1))
		hero_hp_bar.value = (hp / max_hp) * 100.0
	if troop_hp_bar:
		var max_troop_hp = float(hero_data.get("max_troops", 1)) * 10.0
		var troop_hp = max(0, float(hero_data.get("troop_hp", 0)))
		troop_hp_bar.value = (troop_hp / max_troop_hp) * 100.0 if max_troop_hp > 0 else 0
	if enemy_hp_bar and enemies.size() > 0:
		enemy_hp_bar.value = max(0, float(enemies[0].stats.get("hp", 0)) / enemy_hp_bar.max_value * 100.0)


func _log(msg: String):
	if battle_log:
		battle_log.append_text(msg + "\n")


func _end_battle(victory: bool):
	battle_active = false

	# Update hero stats back to GameManager
	var hero = GameManager.get_hero(original_hero_id)
	if not hero.is_empty():
		hero.stats.hp = hero_data.stats.get("hp", 0)
		hero.troops = max(0, int(hero_data.get("troop_hp", 0) / 10.0))

	if victory:
		var loot_gold = 0
		var loot_exp = 0
		# Calculate loot from ALL defeated enemies (original list)
		var original_enemies = GameManager.pending_battle.get("enemies", [])
		# Use the enemy data we have
		for e in enemies:
			var loot = e.get("loot", {})
			loot_gold += loot.get("gold", 0)
			loot_exp += loot.get("exp", 0)

		# Also give base loot if enemy list is empty (all defeated)
		if loot_gold == 0 and loot_exp == 0:
			loot_gold = 10
			loot_exp = 20

		_log("\n[color=green][b]======= 战斗胜利！ =======[/b][/color]")
		_log("获得 [color=yellow]%d 金币[/color]  [color=cyan]%d 经验[/color]" % [loot_gold, loot_exp])

		ResourceManager.add_resource("gold", loot_gold)
		GameManager.add_exp_to_hero(original_hero_id, loot_exp)

		GameManager.last_battle_result = {
			"victory": true,
			"hero_id": original_hero_id,
			"loot": {"gold": loot_gold, "exp": loot_exp}
		}
	else:
		_log("\n[color=red][b]======= 战斗失败... =======[/b][/color]")
		if not hero.is_empty():
			hero.stats.hp = max(10, int(hero.max_hp * 0.3))
		GameManager.last_battle_result = {
			"victory": false,
			"hero_id": original_hero_id,
		}

	# Auto return to map after delay
	await get_tree().create_timer(2.5).timeout
	GameManager.change_state(GameManager.GameState.MAP)


func _on_action_button_pressed():
	if not battle_active or enemies.is_empty():
		return
	var enemy = enemies[0]
	var hero_atk = hero_data.stats.get("atk", 10)
	var damage = max(1, int(hero_atk * 2.5) - enemy.stats.get("def", 2))
	enemy.stats.hp -= damage
	_log("[color=green]*手动技能*[/color] %s -> [b]%d[/b] 伤害！" % [hero_data.name, damage])
	if enemy.stats.hp <= 0:
		_log("[color=yellow]%s 被击败了！[/color]" % enemy.get("name", "敌人"))
		enemies.pop_front()
		if enemies.size() > 0:
			enemy_label.text = enemies[0].get("name", "???")
	_update_display()


func _on_retreat_button_pressed():
	battle_active = false
	# Hero takes some damage on retreat
	var hero = GameManager.get_hero(original_hero_id)
	if not hero.is_empty():
		hero.stats.hp = max(5, hero.stats.get("hp", 0) - 10)
	_log("[color=gray]%s 撤退了[/color]" % hero_data.name)
	GameManager.last_battle_result = {
		"victory": false,
		"hero_id": original_hero_id,
	}
	await get_tree().create_timer(1.0).timeout
	GameManager.change_state(GameManager.GameState.MAP)


func _on_speed_button_pressed():
	if action_interval > 0.5:
		action_interval = 0.5
		_log("[color=gray]战斗加速 x2[/color]")
	else:
		action_interval = 1.5
		_log("[color=gray]战斗速度恢复[/color]")
