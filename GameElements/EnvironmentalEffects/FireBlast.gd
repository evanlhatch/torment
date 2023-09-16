extends Node2D

@export var Damage : float = 8.0
@export var DamageRadius : float = 20.0
@export var HitLocatorPools : Array[String]
@export var TelegraphingColor : Color = Color(1.0, 0.6, 0.0, 0.5)
@export var AudioFX : AudioFXResource
@export var FxMethodName : String = "show_blast_purple"
@export var BlastSoundVolume : float = -4.0
@export var DamageCategories : Array[String] = ["Fire"]
@export var StartOnReady : bool = false
@export var DefaultTelegraphDuration : float = 0.8
@export var PushForce : float = 0

signal ExternalDamageApplied(damageCategories:Array[String], damageAmount:float, applyReturn:Array, targetNode:GameObject)

var _damageSource : GameObject

func _ready():
	if StartOnReady:
		# wait one frame, because the position is sometimes set
		# after the object has been attached to the world...
		await get_tree().process_frame
		start(null)

func start(damageSource : GameObject, telegraph_duration : float = -1):
	if telegraph_duration < 0:
		telegraph_duration = DefaultTelegraphDuration
	_damageSource = damageSource
	if telegraph_duration > 0:
		Fx.show_area_telegraph(
			global_position,
			TelegraphingColor,
			DamageRadius * 1.5,
			telegraph_duration,
			trigger_blast)
	else: trigger_blast()


func trigger_blast():
	if Fx.has_method(FxMethodName):
		Fx.call(FxMethodName, global_position)
	FxAudioPlayer.play_sound_2D(AudioFX, global_position, false, false, BlastSoundVolume)
	await get_tree().create_timer(0.1, false).timeout
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

	if PushForce > 0:
		Forces.RadialBlast(global_position, 50, PushForce, Forces.Falloff.Quadratic, HitLocatorPools)

	queue_free()
