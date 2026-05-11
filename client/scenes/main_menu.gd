extends Control


func _ready():
	# Build UI dynamically
	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.14, 1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.offset_left = -120
	vbox.offset_top = -100
	vbox.offset_right = 120
	vbox.offset_bottom = 100
	add_child(vbox)

	var title = Label.new()
	title.text = "AI Hero Chronicle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	vbox.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "像素风 AI 英雄沙盒 RPG"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(subtitle)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	vbox.add_child(spacer)

	var new_game_btn = Button.new()
	new_game_btn.text = "新游戏"
	new_game_btn.custom_minimum_size = Vector2(200, 45)
	new_game_btn.pressed.connect(_on_new_game)
	vbox.add_child(new_game_btn)

	var quit_btn = Button.new()
	quit_btn.text = "退出游戏"
	quit_btn.custom_minimum_size = Vector2(200, 45)
	quit_btn.pressed.connect(_on_quit)
	vbox.add_child(quit_btn)


func _on_new_game():
	GameManager.new_game()
	GameManager.change_state(GameManager.GameState.TOWN)


func _on_quit():
	get_tree().quit()
