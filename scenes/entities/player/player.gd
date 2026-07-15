class_name Player
extends CharacterBody2D

signal game_over(victorious: bool)

enum State {
	IDLE,
	RUN,
	ATTACK,
	DEAD
}

@export_category("Stats")
@export var speed : int = 500
@export var attack_damage : int = 60 
@export var hitpoints: int = 150

var state : State = State.IDLE
var move_direction : Vector2 = Vector2.ZERO
var attack_speed : float

@onready var animation_tree: AnimationTree = $AnimationTree
@onready var animation_playback: AnimationNodeStateMachinePlayback = $AnimationTree.get("parameters/playback")


func _ready() -> void:
	animation_tree.set("active", true)
	calculate_stats()
	
	
func calculate_stats() -> void:
	attack_speed = Equations.calculate_attack_speed()

	var time_factor : float = Equations.BASE_ATTACK_SPEED / attack_speed
	animation_tree.set("parameters/attack/TimeScale/scale", time_factor)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			attack()


func _physics_process(_delta: float) -> void:
	if not state == State.ATTACK:
		movement_loop()

	
func movement_loop() -> void:
	move_direction.x = int(Input.is_action_pressed("right")) - int(Input.is_action_pressed("left"))
	move_direction.y = int(Input.is_action_pressed("down")) - int(Input.is_action_pressed("up"))
	var motion : Vector2 = move_direction.normalized() * speed
	set_deferred("velocity", motion)
	
	move_and_slide()
	
	# Sprite flipping (only in idle/run)
	if state == State.IDLE or state == State.RUN:
		if move_direction.x < -0.01:
			$Sprite2D.flip_h = true
		if move_direction.x > 0.01:
			$Sprite2D.flip_h = false
	
	if motion != Vector2.ZERO and state == State.IDLE:
		state = State.RUN
		update_animation()
		
	if motion == Vector2.ZERO and state == State.RUN:
		state = State.IDLE
		update_animation()


func update_animation() -> void:
	match state:
		State.IDLE:
			animation_playback.travel("idle")
		State.RUN:
			animation_playback.travel("run")
		State.ATTACK:
			animation_playback.travel("attack")

func attack() -> void:
	# Verify is player is not already attacking, and set the player state 
	if state == State.ATTACK:
		return
	state = State.ATTACK
	
	# Find the attack direction and push to animatiotree blendspace2D
	var mouse_position : Vector2 = get_global_mouse_position()
	var attack_direction : Vector2 = (mouse_position - global_position).normalized()
	$Sprite2D.flip_h = attack_direction.x < 0 and abs(attack_direction.x) >= abs(attack_direction.y)
	animation_tree.set("parameters/attack/BlendSpace2D/blend_position", attack_direction)
	update_animation()
	
	# Return the player state after attacke has finished
	await get_tree().create_timer(attack_speed).timeout
	state = State.IDLE
	

func take_damage(damage_taken: int) -> void:
	hitpoints -= damage_taken
	if hitpoints <= 0:
		death()


func death() -> void:
	print("I dead!")
	game_over.emit(false)


func _on_hit_box_area_entered(area: Area2D) -> void:
	area.owner.take_damage(attack_damage)
