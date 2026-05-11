extends CharacterBody2D

var hero_data: HeroData
var move_speed: float = 100.0
var target_position: Vector2 = Vector2.ZERO
var is_moving: bool = false
var ai_timer: float = 0.0
var ai_decision_interval: float = 3.0

signal hero_died(hero_id: String)
signal hero_reached_target(hero_id: String)


func setup(data: HeroData):
	hero_data = data
	position = Vector2(data.pos_x * 32, data.pos_y * 32)
	_update_sprite()


func _update_sprite():
	$Sprite2D.modulate = _class_color()


func _class_color() -> Color:
	match hero_data.hero_class:
		"战士": return Color.RED
		"法师": return Color.BLUE
		"游侠": return Color.GREEN
		_: return Color.WHITE


func _physics_process(delta):
	if is_moving:
		var direction = (target_position - position).normalized()
		velocity = direction * move_speed
		if position.distance_to(target_position) < 5.0:
			position = target_position
			is_moving = false
			velocity = Vector2.ZERO
			hero_reached_target.emit(hero_data.id)
		move_and_slide()

	if not hero_data.in_town:
		ai_timer += delta
		if ai_timer >= ai_decision_interval and not is_moving:
			ai_timer = 0.0
			_request_ai_decision()


func move_to(tile_x: int, tile_y: int):
	target_position = Vector2(tile_x * 32, tile_y * 32)
	hero_data.pos_x = tile_x
	hero_data.pos_y = tile_y
	is_moving = true


func _request_ai_decision():
	var data = {
		"hero_id": hero_data.id,
		"hero_name": hero_data.name,
		"hero_class": hero_data.hero_class,
		"personality": hero_data.personality,
		"level": hero_data.level,
		"hp": hero_data.stats.get("hp", 0),
		"max_hp": hero_data.max_hp,
		"troops": hero_data.troops,
		"talent_name": hero_data.talent.get("name", ""),
		"talent_desc": hero_data.talent.get("description", ""),
		"x": hero_data.pos_x,
		"y": hero_data.pos_y,
		"visible_info": "",
		"nearby_enemies": "",
		"nearby_resources": "",
		"town_distance": _distance_to_town(),
	}
	var result = await NetworkManager.ai_explore(data)
	if result and not result.has("error"):
		_execute_decision(result)


func _execute_decision(decision: Dictionary):
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
			move_to(hero_data.pos_x + dx, hero_data.pos_y + dy)
		"rest":
			hero_data.stats.hp = mini(hero_data.stats.hp + 5, hero_data.max_hp)
		"return_town":
			hero_data.in_town = true
			hero_data.pos_x = 1
			hero_data.pos_y = 1
			position = Vector2(32, 32)


func _distance_to_town() -> int:
	return abs(hero_data.pos_x - 1) + abs(hero_data.pos_y - 1)
