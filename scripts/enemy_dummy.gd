extends Area2D

@export var can_shoot := false
@export var enemy_name:String = "ENEMY"
@export var damage := 0

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var label: Label = $Label
@onready var marker: Marker2D = $Marker2D

const PROJECTILE = preload("res://scenes/Projectile.tscn")

var can_apply_damage := true
var can_apply_damage_reseter := 3.0

func _ready() -> void:
	label.text = enemy_name
	
func _process(delta: float) -> void:
	can_apply_damage_reseter -= delta
	
	if can_apply_damage_reseter <= 0:
		can_apply_damage_reseter = 3.0
		can_apply_damage = true

func take_damage() -> void:
	animation_player.play("damage_taken")
	can_apply_damage = false

func _on_body_entered(_body: Node2D) -> void:
	animation_player.play("apply_damage")
	can_apply_damage = false

func _on_timer_timeout() -> void:
	if can_shoot && can_apply_damage:
		var new_projectile = PROJECTILE.instantiate()
		new_projectile.global_position = marker.global_position
		get_tree().root.add_child(new_projectile)
