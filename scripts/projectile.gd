extends Node2D

var time_to_queue_free := 1.0
var damage := 10
var can_apply_damage := true

func _physics_process(delta: float) -> void:
	position.x += 5
	
	time_to_queue_free -= delta
	if time_to_queue_free <= 0.0:
		call_deferred("queue_free")

func take_damage() -> void:
	call_deferred("queue_free")
