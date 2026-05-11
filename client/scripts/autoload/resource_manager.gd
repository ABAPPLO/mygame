extends Node

signal resources_changed()

var gold: int = 100
var wood: int = 50
var stone: int = 30
var crystal: int = 0

func spend(cost: Dictionary) -> bool:
	if gold < cost.get("gold", 0): return false
	if wood < cost.get("wood", 0): return false
	if stone < cost.get("stone", 0): return false
	if crystal < cost.get("crystal", 0): return false

	gold -= cost.get("gold", 0)
	wood -= cost.get("wood", 0)
	stone -= cost.get("stone", 0)
	crystal -= cost.get("crystal", 0)
	resources_changed.emit()
	return true

func add_resource(resource_type: String, amount: int):
	match resource_type:
		"gold": gold += amount
		"wood": wood += amount
		"stone": stone += amount
		"crystal": crystal += amount
		"gold_vein": gold += amount
	resources_changed.emit()

func can_afford(cost: Dictionary) -> bool:
	if gold < cost.get("gold", 0): return false
	if wood < cost.get("wood", 0): return false
	if stone < cost.get("stone", 0): return false
	if crystal < cost.get("crystal", 0): return false
	return true

func get_save_data() -> Dictionary:
	return {"gold": gold, "wood": wood, "stone": stone, "crystal": crystal}

func load_data(data: Dictionary):
	gold = data.get("gold", 100)
	wood = data.get("wood", 50)
	stone = data.get("stone", 30)
	crystal = data.get("crystal", 0)
	resources_changed.emit()
