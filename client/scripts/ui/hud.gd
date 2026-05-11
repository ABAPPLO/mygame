extends Control

@onready var gold_label = $ResourceBar/GoldLabel
@onready var wood_label = $ResourceBar/WoodLabel
@onready var stone_label = $ResourceBar/StoneLabel
@onready var crystal_label = $ResourceBar/CrystalLabel


func _ready():
	_update_display()
	ResourceManager.resources_changed.connect(_update_display)


func _update_display():
	gold_label.text = "金币: %d" % ResourceManager.gold
	wood_label.text = "木材: %d" % ResourceManager.wood
	stone_label.text = "石材: %d" % ResourceManager.stone
	crystal_label.text = "水晶: %d" % ResourceManager.crystal
