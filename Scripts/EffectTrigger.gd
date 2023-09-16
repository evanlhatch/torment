extends GameObjectComponent

@export_enum("Hit Splat", "Cone30", "Custom", "Blast") var EffectType : int
@export_enum("On Damage", "On Attack", "On Emit", "On Death", "On Hit", "OnEndOfLife") var OnEvent : int
@export var EffectPositionOffset : Vector2
@export var EffectScale : Vector2 = Vector2.ONE
@export var EffectColor : Color = Color.WHITE
@export var CustomEffectScene : PackedScene
@export var CustomTexture : Texture2D = null
@export var TransferNodeToEffect : Node2D
@export var WidthScale : float = 1.0
@export var SpeedScale : float = 1.0
@export var HasPlayEffectMethod : bool = true
@export var CustomFacingProvider : Node
@export var IsAbilityEffect : bool = false

var facingProvider : Node
var angleProvider : Node
var rangeProvider : Node

func _ready():
	initGameObjectComponent()
	if OnEvent == 0:
		_gameObject.connectToSignal("ReceivedDamage", _on_damage_received)
	elif OnEvent == 1:
		_gameObject.connectToSignal("AttackTriggered", trigger_effect)
	elif OnEvent == 2:
		_gameObject.connectToSignal("Emitted", trigger_effect.bind(0))
	elif OnEvent == 3:
		_gameObject.connectToSignal("Killed", _on_killed_received)
		_gameObject.connectToSignal("Instakilled", _on_killed_received)
	elif OnEvent == 4:
		_gameObject.connectToSignal("OnHit", _on_hit_received)
	elif OnEvent == 5:
		_gameObject.connectToSignal("OnEndOfLife", _on_end_of_life_received)

	if CustomFacingProvider != null: facingProvider = CustomFacingProvider
	else: facingProvider = _gameObject.getChildNodeWithMethod("get_facingDirection")
	angleProvider = _gameObject.getChildNodeWithMethod("get_totalAngle")
	rangeProvider = _gameObject.getChildNodeWithMethod("get_totalRange")

func _on_damage_received(_amount:int, _byNode:Node, _weapon_index:int):
	trigger_effect(Vector2.ZERO, Vector2.ZERO, 0)

func _on_killed_received(_byNode:Node):
	trigger_effect(Vector2.ZERO, Vector2.ZERO, 0)

func _on_hit_received(_source:Node, _hitNumber:int):
	trigger_effect(Vector2.ZERO, Vector2.ZERO, 0)

func _on_end_of_life_received():
	trigger_effect(Vector2.ZERO, Vector2.ZERO, 0)

func trigger_effect(center_offset:Vector2, direction:Vector2, _attack_index:int):
	var facing : Vector2 = direction
	if facing == Vector2.ZERO and facingProvider != null:
		facing = facingProvider.get_facingDirection()
	match EffectType:
		0:
			Fx.show_hit_splat(
				get_gameobjectWorldPosition() + EffectPositionOffset + center_offset,
				facing)
		1:
			var coneRange = 32.0
			var coneAngle = 20.0
			if rangeProvider: coneRange = rangeProvider.get_totalRange()
			if angleProvider: coneAngle = angleProvider.get_totalAngle()
			Fx.show_cone_wave(
				get_gameobjectWorldPosition() + EffectPositionOffset + center_offset,
				facing,
				coneRange, coneAngle,
				3.0 * SpeedScale, 1.0, EffectColor, Callable(),
				CustomTexture, WidthScale, IsAbilityEffect)
		2:
			var effectNode = Fx.show_custom_effect(
				CustomEffectScene,
				get_gameobjectWorldPosition() + EffectPositionOffset + center_offset,
				facing,
				EffectScale,
				EffectColor,
				HasPlayEffectMethod)
			if TransferNodeToEffect:
				TransferNodeToEffect.get_parent().remove_child(TransferNodeToEffect)
				effectNode.add_child(TransferNodeToEffect)
				TransferNodeToEffect.position = Vector2.ZERO
		3:
			Fx.show_blast(get_gameobjectWorldPosition() + EffectPositionOffset + center_offset)
