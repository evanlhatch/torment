extends GameObjectComponent

@export var WraithDeathScene : PackedScene
@export var WaitTime : float = 0.5

signal AttackTriggered(attack_index:int)

var positionProvider : Node
var facingProvider : Node

var _delay_timer : Timer

func _ready():
	initGameObjectComponent()
	_delay_timer = Timer.new()
	add_child(_delay_timer)
	positionProvider = _gameObject.getChildNodeWithMethod("get_worldPosition")
	facingProvider = _gameObject.getChildNodeWithMethod("get_facingDirection")
	await get_tree().process_frame
	
	var dir = facingProvider.get_facingDirection()
	
	_delay_timer.start(WaitTime); await _delay_timer.timeout
	AttackTriggered.emit(0)
	
	_delay_timer.start(0.5); await _delay_timer.timeout
	positionProvider.jump_to(
		positionProvider.get_worldPosition() + dir * 230.0,
		0.5, 0.5)
	_delay_timer.start(0.5); await _delay_timer.timeout
	
	Fx.show_custom_effect(
		WraithDeathScene,
		get_gameobjectWorldPosition() + Vector2(0, -13.0),
		facingProvider.get_facingDirection(),
		Vector2.ONE,
		Color.WHITE)
	_gameObject.queue_free()
