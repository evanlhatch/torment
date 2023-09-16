extends Line2D

@export var TelegraphDelay : float = 1.0
@export var EffectDuration : float = 0.6
@export var AttackDistance : float = 300
@export var LanceEffect : Sprite2D
@export var LanceParticles : Sprite2D
@export var LanceAudio : AudioFXResource

@export_group("Damage Parameters")
@export var Damage : int = 90
@export var SamplePointRadius : float = 15
@export var SamplePointDistance : float = 30
@export var DamageCategories : Array[String] = ["Physical"]
@export var HitLocatorPools : Array[String] = ["Player"]

@export_group("Color Settings")
@export var LanceColor : Color = Color("00eec4ff")
@export var LanceColorParticles : Color = Color("00eec450")
@export var LanceColorFade : Color = Color("00eec400")

@export_group("Ghost Sprite")
@export var GhostSprite :  AnimatedSprite2D


signal ExternalDamageApplied(damageCategories:Array[String], damageAmount:float, applyReturn:Array, targetNode:GameObject)

var _damageSource : Node

func start_attack(direction : Vector2, damageSource : Node):
	set_ghost_animation_direction(direction)
	_damageSource = damageSource
	points[1] = direction.normalized() * AttackDistance
	LanceEffect.rotation = points[1].angle() + PI * 0.5
	LanceEffect.material.set_shader_parameter("modulate_color", LanceColorFade)
	LanceParticles.material.set_shader_parameter("modulate_color", LanceColorFade)
	if GhostSprite != null:
		GhostSprite.animation_finished.connect(play_ghost_idle_animation, CONNECT_ONE_SHOT)
		GhostSprite.play("rise_%s" % ghost_direction_suffix)
	await get_tree().create_timer(TelegraphDelay).timeout
	material.set_shader_parameter("modulate_color", LanceColorFade)
	LanceEffect.material.set_shader_parameter("modulate_color", LanceColor)
	LanceParticles.material.set_shader_parameter("modulate_color", LanceColorParticles)
	var tween = create_tween()
	tween.set_parallel()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUART)
	tween.tween_property(
		LanceEffect.get_material(),
		"shader_parameter/modulate_color",
		LanceColorFade, EffectDuration)
	LanceEffect.scale = Vector2.ONE * 0.8
	tween.tween_property(LanceEffect, "scale", Vector2.ONE * 1.1, EffectDuration)
	tween.tween_property(
		LanceParticles.get_material(),
		"shader_parameter/modulate_color",
		LanceColorFade, EffectDuration)
	tween.tween_property(LanceParticles, "scale", Vector2.ONE * 1.2, EffectDuration)
	deal_damage(global_position, direction)
	FxAudioPlayer.play_sound_2D(LanceAudio, global_position, false, false, 0.0)
	await get_tree().create_timer(EffectDuration).timeout
	if GhostSprite != null:
		GhostSprite.play("die_%s" % ghost_direction_suffix)
		await GhostSprite.animation_finished
	queue_free()

func deal_damage(lance_position:Vector2, lance_direction:Vector2):
	var hits = []
	var damaged = []
	var sample_count = AttackDistance / SamplePointDistance
	for pool in HitLocatorPools:
		var pos = lance_position
		for i in sample_count:
			hits.append_array(Global.World.Locators.get_gameobjects_in_circle(
					pool, pos, SamplePointRadius))
			pos += lance_direction * SamplePointDistance
	for gameObject in hits:
		if damaged.has(gameObject): continue
		damaged.append(gameObject)
		var healthComponent = gameObject.getChildNodeWithMethod("applyDamage")
		if healthComponent != null:
			var damageReturn = null
			if (_damageSource != null and not _damageSource.is_queued_for_deletion()):
				damageReturn = healthComponent.applyDamage(Damage, _damageSource)
			else:
				damageReturn = healthComponent.applyDamage(Damage, null)
			ExternalDamageApplied.emit(DamageCategories, Damage, damageReturn, gameObject, false)

var ghost_direction_suffix : String = "NE"
func set_ghost_animation_direction(direction:Vector2):
	if not is_instance_valid(GhostSprite): return
	if Vector2.UP.dot(direction) > 0:
		ghost_direction_suffix = "NE"
		GhostSprite.flip_h = Vector2.RIGHT.dot(direction) < 0
	else:
		ghost_direction_suffix = "SW"
		GhostSprite.flip_h = Vector2.RIGHT.dot(direction) > 0

func play_ghost_idle_animation():
	GhostSprite.play("walk_%s" % ghost_direction_suffix)
