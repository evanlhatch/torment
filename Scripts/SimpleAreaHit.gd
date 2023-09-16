extends Node2D

@export var Damage : float = 8.0
@export var DamageRadius : float = 20.0
@export var HitLocatorPools : Array[String]
@export var FxMethodName : String = "show_blast_purple"
@export var AudioFX : AudioFXResource
@export var SoundVolume : float = -4.0
@export var DamageCategories : Array[String] = ["Fire"]
@export var PushForce : float = 0
@export var StartOnReady : bool = false

signal ExternalDamageApplied(damageCategories:Array[String], damageAmount:float, applyReturn:Array, targetNode:GameObject)

var _damageSource : GameObject

func _ready():
	if StartOnReady:
		# wait one frame, because the position is sometimes set
		# after the object has been attached to the world...
		await get_tree().process_frame
		trigger_fire_hit(null)
		queue_free()

func trigger_fire_hit(damageSource : GameObject):
	if not Fx.has_method(FxMethodName): return
	Fx.call(FxMethodName, global_position)
	FxAudioPlayer.play_sound_2D(AudioFX, global_position, false, false, SoundVolume)
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
