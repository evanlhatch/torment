extends Node2D

@export var Damage : float = 8.0
@export var DamageRadius : float = 20.0
@export var HitLocatorPools : Array[String]
@export var TelegraphingColor : Color = Color(1.0, 0.6, 0.0, 0.5)
@export var AudioFX : AudioFXResource
@export var FxMethodName : String = "show_cone_wave"
@export var BlastSoundVolume : float = -4.0
@export var DamageCategories : Array[String] = ["Physical"]
@export var StartOnReady : bool = false
@export var DefaultTelegraphDuration : float = 0.8

@export_group("Cone Settings")
@export var ConeRange : float = 32.0
@export var ConeAngle : float = 20.0
@export var EffectSpeed : float = 3.0
@export var ConeLifetime : float = 1.0
@export var ConeColor : Color = Color.WHITE
@export var DirectionOffset : float = 0.0

signal ExternalDamageApplied(damageCategories:Array[String], damageAmount:float, applyReturn:Array, targetNode:GameObject)

var _damageSource : GameObject
var _direction : Vector2

func _ready():
	if StartOnReady:
		# wait one frame, because the position is sometimes set
		# after the object has been attached to the world...
		await get_tree().process_frame
		start(null, Vector2.DOWN)

func start(damageSource : GameObject, direction : Vector2, telegraph_duration : float = -1):
	if telegraph_duration < 0:
		telegraph_duration = DefaultTelegraphDuration
	_damageSource = damageSource
	_direction = direction
	if telegraph_duration > 0:
		Fx.show_area_telegraph(
			global_position,
			TelegraphingColor,
			DamageRadius,
			telegraph_duration,
			trigger_slash)
	else: trigger_slash()


func trigger_slash():
	if Fx.has_method(FxMethodName):
		Fx.call(
			FxMethodName,
			global_position - _direction * DirectionOffset,
			_direction,
			ConeRange,
			ConeAngle,
			EffectSpeed,
			ConeLifetime,
			ConeColor)
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
	queue_free()
