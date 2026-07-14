extends CharacterBody2D

enum State {
	IDLE,
	CHASE,
	RETURN,
	ATTACK,
	DEAD
}

@export_category("Stats")
@export var speed: int = 128
@export var attack_damage: int = 10
@export var attack_speed: float = 1.0
@export var hitpoints : int = 180
@export var aggro_range: float = 256.0
@export var attack_range: float = 80
@export_category("Related Scenes")
@export var death_packed : PackedScene

var state : State = State.IDLE

@onready var spawn_point: Vector2 = global_position
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var animation_playback: AnimationNodeStateMachinePlayback = $AnimationTree["parameters/playback"]
@onready var player: CharacterBody2D = get_tree().get_first_node_in_group("player")
@onready var navigation_agent_2d: NavigationAgent2D = $NavigationAgent2D


func _ready() -> void:
	animation_tree.set("active", true)


func _physics_process(_delta: float) -> void:
	if state == State.DEAD:
		return
	if state == State.ATTACK:
		return
	if distance_to_player() <= attack_range:
		state = State.ATTACK
		attack()
	elif distance_to_player() <= aggro_range:
		state = State.CHASE
		move()
	elif global_position.distance_to(spawn_point) > 32:
		state = State.RETURN
		move()
	elif state != State.IDLE:
		state = State.IDLE
		update_animation()
	
#
func distance_to_player() -> float:
	return global_position.distance_to(player.global_position)


#
func move() -> void:
	if state == State.CHASE:
		navigation_agent_2d.target_position = player.global_position
	elif state == State.RETURN:
		navigation_agent_2d.target_position = spawn_point
	
	var next_path_position: Vector2 = navigation_agent_2d.get_next_path_position()
	velocity = global_position.direction_to(next_path_position) * speed

	if navigation_agent_2d.avoidance_enabled:
		navigation_agent_2d.set_velocity_forced(velocity)
	else:
		_on_navigation_agent_2d_velocity_computed(velocity)
	
	move_and_slide()
	
	# Sprite flipping (only in idle/run)
	if state ==  State.IDLE or State.CHASE:
		if velocity.x < -0.01:
			$Sprite2D.flip_h = true
		elif velocity.x > 0.01:
			$Sprite2D.flip_h = false
	
	#update animatoin
	update_animation()
	
#
func update_animation() -> void:
	match state:
		State.IDLE:
			animation_playback.travel("idle")
		State.CHASE:
			animation_playback.travel("run")
		State.RETURN:
			animation_playback.travel("run")
		State.ATTACK:
			animation_playback.travel("attack")


func attack() -> void:
	var player_position : Vector2 = player.global_position
	var attack_direction : Vector2 = (player_position - global_position).normalized()
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
	var death_scene : Node2D = death_packed.instantiate()
	death_scene.position = global_position + Vector2(0.0, -32.0)
	%Effects.add_child(death_scene)
	queue_free()


func _on_hit_box_area_entered(area: Area2D) -> void:
	area.owner.take_damage(attack_damage)


func _on_navigation_agent_2d_velocity_computed(safe_velocity: Vector2) -> void:
	navigation_agent_2d.velocity = safe_velocity
