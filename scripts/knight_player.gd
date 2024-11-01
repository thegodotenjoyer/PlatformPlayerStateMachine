extends CharacterBody2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var collision_shape_attack: CollisionShape2D = $AreaAttack/CollisionShapeAttack
@onready var collision_shape_base: CollisionShape2D = $AreaBody/CollisionShapeBase
@onready var collision_shape_crouching: CollisionShape2D = $AreaBody/CollisionShapeCrouching
@onready var collision_shape_die: CollisionShape2D = $AreaBody/CollisionShapeDie
@onready var collision_shape_jump_attack: CollisionShape2D = $AreaAttack/CollisionShapeJumpAttack
@onready var collision_shape_shield_block: CollisionShape2D = $AreaShield/CollisionShapeShieldBlock
@onready var coyote_timer: Timer = $CoyoteTimer
@onready var ray_cast_top: RayCast2D = $RayCastTop
@onready var ray_cast_upper_left: RayCast2D = $RayCastUpperLeft
@onready var ray_cast_upper_right: RayCast2D = $RayCastUpperRight

const ATTACK_DURATION_RATE := 0.3
const ATTACK_STEP_SPEED_X := 50
const BASH_SPEED_X := 200.0
const CROUCH_WALK_SPEED_X := 150.0
const DASH_ATTACK_DURATION_RATE := 0.25
const DASH_MAX_CHARGES := 2
const DASH_RECHARGE_RATE := 0.9
const DASH_SPEED_X := 1400.0
const DASH_STOP_THRESHOLD := 450.0
const FALL_STAGE_Y := 100.0
const HURT_DURATION_RATE := 0.5
const JUMP_SPEED_Y := -400.0
const LANDING_DELAY_RATE := 0.25
const LANDING_THRESHOLD_Y := 450.0
const MAX_TOTAL_JUMPS := 2
const SHIELD_BASH_DELAY_RATE := 0.25
const SHIELD_BLOCK_DURATION_RATE := 0.25
const WALK_SPEED_X := 300.0
const WALL_SLIDE_JUMP_SPEED_X := 1200
const WALL_SLIDE_PRESSING_SPEED_Y := 100.0
const WALL_SLIDE_SPEED_Y := 5.0

var main_sm: LimboHSM = LimboHSM.new()

var attack_duration := ATTACK_DURATION_RATE
var dash_attack_delay := DASH_ATTACK_DURATION_RATE
var dash_charges := 0
var dash_recharge := DASH_RECHARGE_RATE
var hurt_duration := HURT_DURATION_RATE
var landing_duration := LANDING_DELAY_RATE
var shield_bash_duration := SHIELD_BASH_DELAY_RATE
var shield_block_duration := SHIELD_BLOCK_DURATION_RATE
var speed_X := WALK_SPEED_X
var total_jumps := 0

# Set value to true if character fall fast enough to trigger LANDING state.
var has_landing_velocity := false

# Used to move character when player is not pressing any directional button (A or D)
var has_momentum := false

# CHARACTER PROPERTIES
var health := 100
signal health_changed(value: int)

func _ready() -> void:
	_define_state_machine()

func _physics_process(delta: float) -> void:
	_dash_recharge(delta)
	
	# Check if character has enough velocity.Y to landing state
	if velocity.y >= LANDING_THRESHOLD_Y:
		has_landing_velocity = true
		
	# Coyote jump logic
	var was_on_floor = is_on_floor()
	
	move_and_slide()
	
	# Coyote jump logic
	if was_on_floor and not is_on_floor():
		coyote_timer.start()
	
	_update_character_collision_shape()
	_debug_state()

func _define_state_machine() -> void:
	var attack_state := LimboState.new().named("attack").call_on_enter(_attack_start).call_on_update(_attack_update).call_on_exit(_attack_exit)
	var crouch_state := LimboState.new().named("crouch").call_on_enter(_crouch_start).call_on_update(_crouch_update).call_on_exit(_crouch_exit)
	var crouch_walk_state := LimboState.new().named("crouch_walk").call_on_enter(_crouch_walk_start).call_on_update(_crouch_walk_update).call_on_exit(_crouch_exit)
	var dash_state := LimboState.new().named("dash").call_on_enter(_dash_start).call_on_update(_dash_update).call_on_exit(_dash_exit)
	var dash_attack_state := LimboState.new().named("dash_attack").call_on_enter(_dash_attack_start).call_on_update(_dash_attack_update).call_on_exit(_dash_attack_exit)
	var die_state := LimboState.new().named("die").call_on_enter(_die_start).call_on_update(_die_update)
	var fall_state := LimboState.new().named("fall").call_on_enter(_fall_start).call_on_update(_fall_update).call_on_exit(_fall_exit)
	var hurt_state := LimboState.new().named("hurt").call_on_enter(_hurt_start).call_on_update(_hurt_update)
	var idle_state := LimboState.new().named("idle").call_on_enter(_idle_start).call_on_update(_idle_update)
	var jump_state := LimboState.new().named("jump").call_on_enter(_jump_start).call_on_update(_jump_update)
	var jump_attack_state := LimboState.new().named("jump_attack").call_on_enter(_jump_attack_start).call_on_update(_jump_attack_update).call_on_exit(_jump_attack_exit)
	var landing_state := LimboState.new().named("landing").call_on_enter(_landing_start).call_on_update(_landing_update)
	var shield_bash_state := LimboState.new().named("shield_bash").call_on_enter(_shield_bash_start).call_on_update(_shield_bash_update).call_on_exit(_shield_bash_exit)
	var shield_block_state := LimboState.new().named("shield_block").call_on_enter(_shield_block_start).call_on_update(_shield_block_update).call_on_exit(_shield_block_exit)
	var shield_block_ready_state := LimboState.new().named("shield_block_ready").call_on_enter(_shield_block_ready_start).call_on_update(_shield_block_ready_update).call_on_exit(_shield_block_ready_exit)
	var walk_state := LimboState.new().named("walk").call_on_enter(_walk_start).call_on_update(_walk_update)
	var wall_jump_state := LimboState.new().named("wall_jump").call_on_enter(_wall_jump_start).call_on_update(_wall_jump_update)
	var wall_slide_state := LimboState.new().named("wall_slide").call_on_enter(_wall_slide_start).call_on_update(_wall_slide_update)
	
	main_sm.get_leaf_state()
	
	add_child(main_sm)
	main_sm.add_child(attack_state)
	main_sm.add_child(crouch_state)
	main_sm.add_child(crouch_walk_state)
	main_sm.add_child(dash_state)
	main_sm.add_child(dash_attack_state)
	main_sm.add_child(die_state)
	main_sm.add_child(fall_state)
	main_sm.add_child(hurt_state)
	main_sm.add_child(idle_state)
	main_sm.add_child(jump_state)
	main_sm.add_child(jump_attack_state)
	main_sm.add_child(landing_state)
	main_sm.add_child(shield_bash_state)
	main_sm.add_child(shield_block_state)
	main_sm.add_child(shield_block_ready_state)
	main_sm.add_child(walk_state)
	main_sm.add_child(wall_jump_state)
	main_sm.add_child(wall_slide_state)
	main_sm.initial_state = fall_state
	
	# any
	main_sm.add_transition(main_sm.ANYSTATE, idle_state, "state_ended")
	main_sm.add_transition(main_sm.ANYSTATE, hurt_state, "to_hurt")
	main_sm.add_transition(main_sm.ANYSTATE, die_state, "to_die")
	
	# attack
	main_sm.add_transition(attack_state, jump_state, "to_jump")
	
	# crouch
	main_sm.add_transition(crouch_state, crouch_walk_state, "to_crouch_walk")
	main_sm.add_transition(crouch_state, jump_state, "to_jump")
	
	# crouch_walk
	main_sm.add_transition(crouch_walk_state, jump_state, "to_jump")
	
	# dash
	main_sm.add_transition(dash_state, fall_state, "to_fall")
	main_sm.add_transition(dash_state, wall_slide_state, "to_wall_slide")
	
	# dash_attack
	main_sm.add_transition(dash_attack_state, fall_state, "to_fall")
	main_sm.add_transition(dash_attack_state, shield_block_state, "to_shield_block")
	
	# fall
	main_sm.add_transition(fall_state, crouch_state, "to_crouch")
	main_sm.add_transition(fall_state, landing_state, "to_landing")
	main_sm.add_transition(fall_state, wall_slide_state, "to_wall_slide")
	
	# idle
	main_sm.add_transition(idle_state, attack_state, "to_attack")
	main_sm.add_transition(idle_state, crouch_state, "to_crouch")
	main_sm.add_transition(idle_state, fall_state, "to_fall")
	main_sm.add_transition(idle_state, jump_state, "to_jump")
	main_sm.add_transition(idle_state, shield_block_state, "to_shield_block")
	main_sm.add_transition(idle_state, walk_state, "to_walk")
	
	# jump
	main_sm.add_transition(jump_state, dash_state, "to_dash")
	main_sm.add_transition(jump_state, fall_state, "to_fall")
	main_sm.add_transition(jump_state, jump_state, "to_jump")
	main_sm.add_transition(jump_state, jump_attack_state, "to_jump_attack")
	main_sm.add_transition(jump_state, wall_slide_state, "to_wall_slide")
	
	# jump_attack
	main_sm.add_transition(jump_attack_state, fall_state, "to_fall")
	main_sm.add_transition(jump_attack_state, landing_state, "to_landing")
	
	# hield_bash
	main_sm.add_transition(shield_bash_state, shield_block_state, "to_shield_block")
	
	# shield_block
	main_sm.add_transition(shield_block_state, fall_state, "to_fall")
	main_sm.add_transition(shield_block_state, jump_state, "to_jump")
	main_sm.add_transition(shield_block_state, shield_block_ready_state, "to_shield_block_ready")
	
	# shield_block_ready
	main_sm.add_transition(shield_block_ready_state, dash_attack_state, "to_dash_attack")
	main_sm.add_transition(shield_block_ready_state, fall_state, "to_fall")
	main_sm.add_transition(shield_block_ready_state, jump_state, "to_jump")
	main_sm.add_transition(shield_block_ready_state, shield_bash_state, "to_shield_bash")
	
	# walk
	main_sm.add_transition(walk_state, crouch_state, "to_crouch")
	main_sm.add_transition(walk_state, dash_state, "to_dash")
	main_sm.add_transition(walk_state, jump_state, "to_jump")
	
	# wall_jump
	main_sm.add_transition(wall_jump_state, dash_state, "to_dash")
	main_sm.add_transition(wall_jump_state, fall_state, "to_fall")
	main_sm.add_transition(wall_jump_state, jump_attack_state, "to_jump_attack")
	main_sm.add_transition(wall_jump_state, jump_state, "to_jump")
	
	# wall_slide
	main_sm.add_transition(wall_slide_state, fall_state, "to_fall")
	main_sm.add_transition(wall_slide_state, wall_jump_state, "to_wall_jump")
	
	main_sm.initialize(self)
	main_sm.set_active(true)


func _attack_start() -> void:
	animated_sprite.play("attack_01")
	collision_shape_attack.disabled = false

func _attack_update(delta: float) -> void:
	_process_velocity()
	_process_gravity(delta)
	
	if Input.get_axis("left", "right") != 0 or Input.is_action_just_released("attack"):
		main_sm.dispatch("state_ended")
	elif Input.is_action_just_pressed("jump"):
		_try_jump()
	else:
		attack_duration -= delta
		if attack_duration <= 0:
			attack_duration = ATTACK_DURATION_RATE
			if Input.is_action_pressed("attack"):
				if animated_sprite.animation == "attack_01":
					animated_sprite.play("attack_02")
				else:
					animated_sprite.play("attack_01")

func _attack_exit() -> void:
	collision_shape_attack.disabled = true
	attack_duration = ATTACK_DURATION_RATE

func _crouch_start() -> void:
	animated_sprite.play("crouch")
	collision_shape_crouching.disabled = false
	collision_shape_base.disabled = true

func _crouch_update(delta: float) -> void:
	_process_velocity()
	_process_gravity(delta)
	
	if Input.is_action_just_pressed("jump"):
		_try_jump()
	elif velocity.x != 0:
		main_sm.dispatch("to_crouch_walk")
	elif not ray_cast_top.is_colliding() and (Input.is_action_just_pressed("up") or not is_on_floor()):
		main_sm.dispatch("state_ended")

func _crouch_exit() -> void:
	speed_X = WALK_SPEED_X
	collision_shape_crouching.disabled = true
	collision_shape_base.disabled = false

func _crouch_walk_start() -> void:
	animated_sprite.play("crouch_walk")
	speed_X = CROUCH_WALK_SPEED_X
	collision_shape_crouching.disabled = false
	collision_shape_base.disabled = true

func _crouch_walk_update(delta: float) -> void:
	_process_velocity()
	_process_gravity(delta)
	
	if velocity.x == 0:
		animated_sprite.play("crouch_stop")
	else:
		animated_sprite.play("crouch_walk")
	
	if Input.is_action_just_pressed("jump"):
		_try_jump()
	elif not ray_cast_top.is_colliding() and (Input.is_action_just_pressed("up") or not is_on_floor()):
		main_sm.dispatch("state_ended")

func _dash_start() -> void:
	animated_sprite.play("dash")
	speed_X = DASH_SPEED_X
	dash_charges -= 1
	has_momentum = true

func _dash_update(delta: float) -> void:
	_process_velocity()
	_process_gravity(delta)
	
	speed_X = lerp(speed_X, WALK_SPEED_X, 0.1)
	
	if is_on_wall() and not _try_wall_slide():
		main_sm.dispatch("state_ended")
	elif speed_X <= DASH_STOP_THRESHOLD:
		if is_on_floor():
			main_sm.dispatch("state_ended")
		else:
			main_sm.dispatch("to_fall")

func _dash_exit() -> void:
	speed_X = WALK_SPEED_X
	
func _dash_attack_start() -> void:
	animated_sprite.play("dash_attack")
	dash_charges -= 1
	speed_X = DASH_SPEED_X

func _dash_attack_update(delta: float) -> void:
	_process_gravity(delta)
	
	dash_attack_delay -= delta
	if dash_attack_delay <= 0:
		# Starting moving after a few milleseconds
		_process_velocity()
		collision_shape_attack.disabled = false
		speed_X = lerp(speed_X, WALK_SPEED_X, 0.15)
		has_momentum = true

	# This logic stops dash state at different speed when collinding to a wall or not
	if (is_on_wall() and speed_X <= 450.0) or (not is_on_wall() and speed_X <= 350.0):
		if is_on_floor():
			main_sm.dispatch("state_ended")
		else:
			main_sm.dispatch("to_fall")

func _dash_attack_exit() -> void:
	speed_X = WALK_SPEED_X
	collision_shape_attack.disabled = true
	dash_attack_delay = DASH_ATTACK_DURATION_RATE
	has_momentum = false

func _die_start() -> void:
	animated_sprite.play("die")
	collision_shape_base.disabled = true
	collision_shape_crouching.disabled = true
	velocity.x = 0

func _die_update(delta: float) -> void:
	_process_gravity(delta)
	collision_shape_die.disabled = false
	Engine.time_scale = 0.3

func _fall_start() -> void:
	animated_sprite.play("fall")

func _fall_update(delta: float) -> void:
	_process_velocity()
	_process_gravity(delta)
	
	if is_on_floor():
		if has_landing_velocity:
			main_sm.dispatch("to_landing")
		elif Input.is_action_pressed("down"):
			main_sm.dispatch("to_crouch")
		else:
			main_sm.dispatch("state_ended")
	elif is_on_wall() :
		_try_wall_slide()

func _fall_exit() -> void:
	has_landing_velocity = false
	has_momentum = false

func _hurt_start() -> void:
	animated_sprite.play("hurt")

func _hurt_update(delta: float) -> void:
	_process_velocity(false)
	_process_gravity(delta)
	
	hurt_duration -= delta
	if hurt_duration <= 0:
		hurt_duration = HURT_DURATION_RATE
		main_sm.dispatch("state_ended")

func _idle_start() -> void:
	animated_sprite.play("idle")
	total_jumps = 0
	speed_X = WALK_SPEED_X
	has_momentum = false

func _idle_update(delta: float) -> void:
	_process_velocity()
	_process_gravity(delta)
	
	if velocity.x != 0 and is_on_floor():
		main_sm.dispatch("to_walk")
	elif Input.is_action_just_pressed("jump"):
		_try_jump()
	elif velocity.y >= FALL_STAGE_Y:
		main_sm.dispatch("to_fall")
	elif Input.is_action_pressed("attack"):
		main_sm.dispatch("to_attack")
	elif Input.is_action_pressed("shield_block"):
		main_sm.dispatch("to_shield_block")
	elif Input.is_action_just_pressed("down"):
		main_sm.dispatch("to_crouch")

func _jump_start() -> void:
	animated_sprite.play("jump")
	velocity.y = JUMP_SPEED_Y
	total_jumps += 1

func _jump_update(delta: float) -> void:
	_process_velocity()
	_process_gravity(delta)
	
	if velocity.y >= FALL_STAGE_Y:
		main_sm.dispatch("to_fall")
	elif is_on_wall():
		_try_wall_slide()
	elif Input.is_action_just_pressed("dash"):
		_try_dash()
	elif Input.is_action_pressed("attack"):
		_try_jump_attack()
	elif Input.is_action_just_pressed("jump"):
		_try_double_jump()
	elif is_on_floor():
		main_sm.dispatch("state_ended")

func _jump_attack_start () -> void:
	animated_sprite.play("jump_attack")
	collision_shape_jump_attack.disabled = false

func _jump_attack_update(delta: float) -> void:
	_process_velocity()
	_process_gravity(delta)
	
	if is_on_floor():
		if has_landing_velocity:
			main_sm.dispatch("to_landing")
		else:
			main_sm.dispatch("state_ended")
	elif Input.is_action_just_released("attack"):
		main_sm.dispatch("to_fall")

func _jump_attack_exit() -> void:
	collision_shape_jump_attack.disabled = true

func _landing_start() -> void:
	animated_sprite.play("landing")
	velocity.x = 0

func _landing_update(delta: float) -> void:
	_process_gravity(delta)
	
	landing_duration -= delta
	if landing_duration <= 0.0:
		landing_duration = LANDING_DELAY_RATE
		
		main_sm.dispatch("state_ended")

func _shield_bash_start() -> void:
	animated_sprite.play("shield_bash")
	collision_shape_attack.disabled = false

func _shield_bash_update(delta: float) -> void:
	_process_gravity(delta)
	_process_velocity()
	shield_bash_duration -= delta
	
	# TODO: change to position
	if animated_sprite.flip_h:
		velocity.x = lerp(0.0, velocity.x + BASH_SPEED_X * -1, 0.50)
	else:
		velocity.x = lerp(0.0, velocity.x + BASH_SPEED_X, 0.50)
	
	if Input.is_action_just_released("shield_block"):
		main_sm.dispatch("state_ended")
	elif shield_bash_duration <= 0.0:
		main_sm.dispatch("to_shield_block")

func _shield_bash_exit() -> void:
		speed_X = WALK_SPEED_X
		collision_shape_attack.disabled = true
		shield_bash_duration = SHIELD_BASH_DELAY_RATE

func _shield_block_start() -> void:
	animated_sprite.play("shield_block")

func _shield_block_update(delta: float) -> void:
	_process_velocity()
	_process_gravity(delta)
	
	if is_on_floor():
		shield_block_duration -= delta
		
		if Input.is_action_just_released("shield_block"):
			main_sm.dispatch("state_ended")
		elif shield_block_duration <= 0:
			main_sm.dispatch("to_shield_block_ready")
		elif Input.is_action_just_pressed("jump"):
			main_sm.dispatch("to_jump")
	else:
		main_sm.dispatch("to_fall")

func _shield_block_exit() -> void:
	shield_block_duration = SHIELD_BLOCK_DURATION_RATE

func _shield_block_ready_start() -> void:
	collision_shape_shield_block.disabled = false
	animated_sprite.play("shield_block_ready")

func _shield_block_ready_update(delta: float) -> void:
	_process_velocity()
	_process_gravity(delta)
	
	if is_on_floor():
		if velocity.x != 0 or Input.is_action_just_released("shield_block"):
			main_sm.dispatch("state_ended")
		elif Input.is_action_just_pressed("attack"):
			main_sm.dispatch("to_shield_bash")
		elif Input.is_action_just_pressed("dash"):
			main_sm.dispatch("to_dash_attack")
		elif Input.is_action_just_pressed("jump"):
			main_sm.dispatch("to_jump")
	else:
		main_sm.dispatch("to_fall")

func _shield_block_ready_exit() -> void:
	collision_shape_shield_block.disabled = true

func _walk_start() -> void:
	animated_sprite.play("walk")
	speed_X = WALK_SPEED_X

func _walk_update(delta: float) -> void:
	_process_velocity()
	_process_gravity(delta)
	
	if velocity.x == 0 or not is_on_floor():
		main_sm.dispatch("state_ended")
	elif Input.is_action_just_pressed("jump"):
		_try_jump()
	elif Input.is_action_just_pressed("dash"):
		_try_dash()
	elif Input.is_action_just_pressed("down"):
		main_sm.dispatch("to_crouch")

func _wall_jump_start() -> void:
	animated_sprite.play("jump")
	velocity.y = JUMP_SPEED_Y
	total_jumps = 1
	has_momentum = true
	
	if animated_sprite.flip_h:
		velocity.x = WALL_SLIDE_JUMP_SPEED_X
	else:
		velocity.x = -WALL_SLIDE_JUMP_SPEED_X
		
	if animated_sprite.flip_h:
		_flip_sprite(1)
	else:
		_flip_sprite(-1)

func _wall_jump_update(delta: float) -> void:
	_process_velocity()
	_process_gravity(delta)
	
	if velocity.y >= FALL_STAGE_Y:
		main_sm.dispatch("to_fall")
	elif Input.is_action_just_pressed("dash"):
		_try_dash()
	elif Input.is_action_pressed("attack"):
		_try_jump_attack()
	elif Input.is_action_just_pressed("jump"):
		_try_double_jump()
	elif is_on_floor():
		main_sm.dispatch("state_ended")

func _wall_slide_start() -> void:
	animated_sprite.play("wall_slide")
	velocity.y = WALL_SLIDE_SPEED_Y

func _wall_slide_update(_delta: float) -> void:
	_process_velocity()
	
	if is_on_floor() or not is_on_wall():
		main_sm.dispatch("state_ended")
	elif Input.is_action_just_pressed("jump"):
		main_sm.dispatch("to_wall_jump")
	elif Input.is_action_just_pressed("down"):
		velocity.y = WALL_SLIDE_PRESSING_SPEED_Y
	elif Input.is_action_just_released("down"):
		velocity.y = WALL_SLIDE_SPEED_Y


func _update_character_collision_shape() -> void:
	if collision_shape_base.disabled == false:
		_update_helper(collision_shape, collision_shape_base)
	elif collision_shape_crouching.disabled == false:
		_update_helper(collision_shape, collision_shape_crouching)
	elif collision_shape_die.disabled == false:
		_update_helper(collision_shape, collision_shape_die)
 
func _update_helper(c1 : CollisionShape2D, c2 : CollisionShape2D) -> void:
	c1.shape = c2.shape
	c1.position = c2.position

func _dash_recharge(delta: float) -> void:
	if dash_charges < DASH_MAX_CHARGES:
		dash_recharge -= delta
		
		if dash_recharge <= 0:
			dash_recharge = DASH_RECHARGE_RATE
			dash_charges += 1

func _flip_sprite(direction : float) -> void:
	if direction > 0:
		animated_sprite.flip_h = false
		collision_shape_crouching.position.x = 6
		collision_shape_attack.position.x = 20
		collision_shape_die.position.x = -8
		collision_shape_shield_block.position.x = 19
	elif direction < 0:
		animated_sprite.flip_h = true
		collision_shape_attack.position.x = -20
		collision_shape_crouching.position.x = -6
		collision_shape_die.position.x = 8
		collision_shape_shield_block.position.x = -19

func _process_gravity(delta: float) -> void:
	velocity += get_gravity() * delta

func _process_velocity(should_flip: bool = true) -> void:
	var direction := Input.get_axis("left", "right")
	
	if direction:
		has_momentum = false
		velocity.x = direction * speed_X
	elif has_momentum:
		if animated_sprite.flip_h:
			velocity.x = -1 * speed_X
		else:
			velocity.x = speed_X
	else:
		velocity.x = move_toward(velocity.x, 0, speed_X)
		
	if should_flip:
		_flip_sprite(direction)

func _try_dash() -> void:
	if dash_charges > 0:
		main_sm.dispatch("to_dash")

func _try_double_jump() -> void:
	if total_jumps < MAX_TOTAL_JUMPS: 
		main_sm.dispatch("to_jump")

func _try_jump() -> void:
	if (is_on_floor() or not coyote_timer.is_stopped()) and not ray_cast_top.is_colliding():
		main_sm.dispatch("to_jump")

func _try_jump_attack() -> void:
	if not ray_cast_upper_left.is_colliding() and not ray_cast_upper_right.is_colliding():
		main_sm.dispatch("to_jump_attack")

func _try_wall_slide() -> bool:
	if ray_cast_upper_left.is_colliding() and animated_sprite.flip_h:
		main_sm.dispatch("to_wall_slide")
		return true
		
	if ray_cast_upper_right.is_colliding() and not animated_sprite.flip_h:
		main_sm.dispatch("to_wall_slide")
		return true
	
	return false


# NON STATE RELATED
func apply_damage() -> void:
	pass

func take_damage(damage: int) -> void:
	if collision_shape_shield_block.disabled == false:
		return
	
	health -= damage
	health_changed.emit(health)
	
	if health > 0:
		main_sm.call_deferred("dispatch", "to_hurt")
	else:
		main_sm.call_deferred("dispatch", "to_die")

func _on_area_shield_area_entered(area: Area2D) -> void:
	#print('area_shield', area)
	if area.name == "Projectile":
		area.queue_free()
	
	position.x += 5

func _on_area_attack_area_entered(area: Area2D) -> void:
	area.take_damage()
	#print('area_attack', area)

func _on_area_body_area_entered(area: Area2D) -> void:
	#print('area_body', area)
	if area.can_apply_damage:
		take_damage(area.damage)
	
	if area.name == "Projectile":
		area.queue_free()


# DEBUG
@onready var current_state: Label = $CurrentState
func _debug_state() -> void:
	var state_name := main_sm.get_active_state().name
	
	if current_state.text != state_name:
		current_state.text = state_name
		#print(current_state.text)
