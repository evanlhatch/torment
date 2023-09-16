extends Node2D

@export var Damage : float = 40.0
@export var DamageRadius : float = 10.0
@export var HitLocatorPools : Array[String]
@export var TelegraphingColor : Color = Color(1.0, 0.6, 0.0, 0.5)
@export var DamageCategories : Array[String] = ["Lightning"]
@export var DefaultTelegraphDuration : float = 0.8
@export var LightningArcScene : PackedScene

signal ExternalDamageApplied(damageCategories:Array[String], damageAmount:float, applyReturn:Array, targetNode:GameObject)

var _damageSource : GameObject
var _startNode : Node2D
var _startPos : Vector2

func start(
	damageSource : GameObject,
	startNode : Node2D,
	telegraph_duration : float = -1):
	if telegraph_duration < 0:
		telegraph_duration = DefaultTelegraphDuration
	_damageSource = damageSource
	_startNode = startNode
	_startPos = _startNode.global_position
	if telegraph_duration > 0:
		Fx.show_area_telegraph(
			global_position,
			TelegraphingColor,
			DamageRadius * 1.5,
			telegraph_duration,
			trigger_lightning)
	else: trigger_lightning()


func trigger_lightning():
	await get_tree().create_timer(0.1, false).timeout
	var arc = LightningArcScene.instantiate()
	Global.attach_toWorld(arc)
	if is_instance_valid(_startNode):
		arc.play_effect(_startNode, null, Vector2.ZERO, global_position)
	else:
		arc.play_effect(null, null, _startPos, global_position)
	for pool in HitLocatorPools:
		var hits = Global.World.Locators.get_gameobjects_in_circle(
				pool, global_position, DamageRadius)
		for gameObject in hits:
			var healthComponent = gameObject.getChildNodeWithMethod("applyDamage")
			if healthComponent != null:
				var damageReturn = null
				if (_damageSource != null and not _damageSource.is_queued_for_deletion()):
					damageReturn = healthComponent.applyDamage(Damage, _damageSource)
				else:
					damageReturn = healthComponent.applyDamage(Damage, null)
				ExternalDamageApplied.emit(DamageCategories, Damage, damageReturn, gameObject, false)
	queue_free()
