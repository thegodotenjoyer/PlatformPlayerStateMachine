extends Node2D

@onready var knight_player: CharacterBody2D = $KnightPlayer
@onready var knight_player_health: Label = $HUD/KnightPlayerHealth

func _ready() -> void:
	knight_player_health.text = "Health: " + str(knight_player.health)
	knight_player.health_changed.connect(_on_knight_player_health_change)
	
func _on_knight_player_health_change(value: int) -> void:
	knight_player_health.text = "Health: " + str(value)

func _on_button_pressed() -> void:
	Engine.time_scale = 1
	get_tree().change_scene_to_file("res://scenes/Game.tscn")
