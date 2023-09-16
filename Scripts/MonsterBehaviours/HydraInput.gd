extends GameObjectComponent

@export var JumpThreshold : float = 250
@export var MinTimeForAttack : float = 1.8
@export var MaxTimeForAttack : float = 2.7

@export_group("Sprite References")
@export var Body1 : AnimatedSprite2D
@export var Head1 : AnimatedSprite2D
@export var Body2 : AnimatedSprite2D
@export var Head2 : AnimatedSprite2D
@export var Body3 : AnimatedSprite2D
@export var Head3 : AnimatedSprite2D
@export var FlashIntensity : float = 1.0

@export_group("Emitters and Scene References")
@export var FlameEmitter : Node
@export var BoltEmitter : Node
@export var GhostHeadScene : PackedScene

var _all_sprites : Array[AnimatedSprite2D]
var _timer : Timer
var _position_provider : Node
var targetPosProvider : Node
var flash_timer : int
var changing_position : bool
var attack_timer : float
var _action_draw_pool

var health : Node
var health_threshold : int
var head_count : int
var dying : bool

@onready var ghost_heads : Array[GameObject] = []

signal rise_complete
signal dive_complete

func _ready():
	initGameObjectComponent()
	_timer = Timer.new()
	add_child(_timer)
	_all_sprites.append_array([Body1, Head1, Body2, Head2, Body3, Head3])
	_position_provider = _gameObject.getChildNodeWithMethod("get_viaductPosition")
	health = _gameObject.getChildNodeWithSignal("ReceivedDamage")
	health.ReceivedDamage.connect(_on_damage)
	health.Killed.connect(_on_killed)
	health_threshold = health.get_maxHealth() * 0.6667
	head_count = 3
	set_aim_dir_orthogonal_to_edge()
	attack_timer = MaxTimeForAttack
	_action_draw_pool = createValueDrawPool([0,0,1,1])
	if (Global.World.Player != null and not Global.World.Player.is_queued_for_deletion()):
		set_target(Global.World.Player)
	
	# initialize position
	if is_targetProvider_valid():
		var start_pos = _position_provider.get_viaduct_pos_of_point(targetPosProvider.get_worldPosition())
		_position_provider.set_viaductPosition(start_pos)
	
	Body1.visible = false
	Body2.visible = false
	Body3.visible = false
	
	_timer.start(.5); await _timer.timeout
	play_rise_animations()


func _process(delta):
	update_flash()
	if is_targetProvider_valid():
		_position_provider.set_targetViaductPos(
			_position_provider.get_viaduct_pos_of_point(targetPosProvider.get_worldPosition()))
	if not changing_position:
		if absf(_position_provider.pos_delta) > JumpThreshold:
			change_position_quickly(
				_position_provider.get_viaduct_pos_of_point(targetPosProvider.get_worldPosition())
				+ (signf(_position_provider.pos_delta) * 1.5 - 0.5) * 100.0)
		if attack_timer >= 0.0:
			attack_timer -= delta
			if attack_timer <= 0.0:
				attack()
				attack_timer = randf_range(MinTimeForAttack, MaxTimeForAttack)


func play_animation_on_head(head_index:int, animation_name:String, reverse:bool = false, frame_offset:int = 0):
	var sprites : Array[AnimatedSprite2D] = []
	match(head_index):
		0: sprites.append(Head1); sprites.append(Body1)
		1: sprites.append(Head2); sprites.append(Body2)
		2: sprites.append(Head3); sprites.append(Body3)
	for s in sprites:
		if reverse: s.play_backwards(animation_name)
		else: s.play(animation_name)
		if frame_offset > 0:
			s.frame = frame_offset


func play_idle_after_animation(sprite:AnimatedSprite2D):
	await sprite.animation_finished
	if not dying: sprite.play("idle_SE")


func play_rise_animations():
	Body1.visible = true
	play_animation_on_head(0, "rise_SE")
	play_idle_after_animation(Body1)
	play_idle_after_animation(Head1)
	
	if head_count > 1:
		_timer.start(0.6); await _timer.timeout
		Body2.visible = true
		play_animation_on_head(1, "rise_SE")
		play_idle_after_animation(Body2)
		play_idle_after_animation(Head2)
	
	if head_count > 2:
		_timer.start(0.72); await _timer.timeout
		Body3.visible = true
		play_animation_on_head(2, "rise_SE")
		play_idle_after_animation(Body3)
		play_idle_after_animation(Head3)
	await get_tree().process_frame
	rise_complete.emit()


func play_rise_reverse():
	play_animation_on_head(0, "rise_SE", true)
	await Body1.animation_finished
	Body1.visible = false
	if head_count > 1:
		play_animation_on_head(1, "rise_SE", true)
		await Body2.animation_finished
		Body2.visible = false
	if head_count > 2:
		play_animation_on_head(2, "rise_SE", true)
		await Body3.animation_finished
		Body3.visible = false
	await get_tree().process_frame
	dive_complete.emit()


func change_position_quickly(target_position:float):
	if dying: return
	changing_position = true
	health.setInvincibleForTime(2.5)
	play_rise_reverse()
	await dive_complete
	_position_provider.set_viaductPosition(target_position)
	await get_tree().process_frame
	play_rise_animations()
	await rise_complete
	health.setInvincibleForTime(-1)
	changing_position = false
	

func set_target(targetNode : Node):
	targetPosProvider = targetNode.getChildNodeWithMethod("get_worldPosition")

var _aim_direction : Vector2
func get_aimDirection() -> Vector2:
	return _aim_direction

func set_aim_dir_orthogonal_to_edge():
	_aim_direction = _position_provider.viaduct_dir_norm.rotated(PI * 0.45)

func set_aim_dir_towards_target():
	if is_targetProvider_valid():
		_aim_direction = (targetPosProvider.get_worldPosition() - _position_provider.get_worldPosition()).normalized()

func is_targetProvider_valid():
	return targetPosProvider != null and not targetPosProvider.is_queued_for_deletion()

func _on_damage(_amount:int, _byNode:Node, _weapon_index:int):
	flash_timer = 4
	for s in _all_sprites:
		s.material.set_shader_parameter("flash_modifier", FlashIntensity)
	if health.get_health() <= health_threshold:
		head_count -= 1
		attacking_head = wrapi(attacking_head, 0, head_count)
		if head_count == 2:
			health_threshold = health.get_maxHealth() * 0.3333
			play_animation_on_head(2, "die_SE")
			spawn_ghost_head(1.0)
			await Body3.animation_finished
			Body3.visible = false
		elif head_count == 1:
			health_threshold = 0
			play_animation_on_head(1, "die_SE")
			spawn_ghost_head(-1.0)
			await Body2.animation_finished
			Body2.visible = false

func spawn_ghost_head(circling_direction:float):
	var head = GhostHeadScene.instantiate()
	head.global_position = get_gameobjectWorldPosition()
	Global.attach_toWorld(head)
	var head_input = head.getChildNodeWithProperty("circling_direction")
	head_input.circling_direction = circling_direction
	ghost_heads.append(head)

func _on_killed(_byNode:Node):
	dying = true
	play_animation_on_head(0, "die_SE")
	await Body1.animation_finished
	for h in ghost_heads:
		var health = h.getChildNodeWithMethod("instakill")
		health.instakill()
	_gameObject.queue_free()

func update_flash():
	if flash_timer > 0:
		flash_timer -= 1
		if flash_timer == 0:
			for s in _all_sprites:
				s.material.set_shader_parameter("flash_modifier", 0.0)


var attacking_head : int
func attack():
	if dying: return
	match(attacking_head):
		0:
			play_animation_on_head(0, "attack_SE")
			play_idle_after_animation(Body1)
			play_idle_after_animation(Head1)
		1:
			play_animation_on_head(1, "attack_SE")
			play_idle_after_animation(Body2)
			play_idle_after_animation(Head2)
		2:
			play_animation_on_head(2, "attack_SE")
			play_idle_after_animation(Body3)
			play_idle_after_animation(Head3)
	attacking_head = wrapi(attacking_head + 1, 0, head_count)
	match(_action_draw_pool.draw_value()):
		0: attack_pattern_A()
		1: attack_pattern_B()


func attack_pattern_A():
	set_aim_dir_towards_target()
	FlameEmitter.set_emitting(true, true)
	_timer.start(0.4); await _timer.timeout
	FlameEmitter.set_emitting(false)

func attack_pattern_B():
	set_aim_dir_orthogonal_to_edge()
	BoltEmitter.set_emitting(true, true)
	_timer.start(0.4); await _timer.timeout
	BoltEmitter.set_emitting(false)
