extends GameObjectComponent2D

@export var Radius : float = 10
@export var HitLocatorPools : Array[String] = ["Enemies"]
@export var BaseDamage : int = 2
@export var BaseCriticalChance : float = 0.0
@export var BaseCriticalBonus : float = 0.0
@export var DamageInterval : float = 0.5
@export var Lifetime : float = 2.0
@export var BurnChance : float = 1.0
# this has to be of type BurnEffect!
@export var BurnEffectScene : PackedScene
@export var ModifierCategories : Array[String] = ["Fire", "Elemental"]
@export var DamageCategories : Array[String] = ["Fire"]
@export var UseModifier : bool = true

@export_group("Audio Settings")
@export var AudioFX : AudioFXResource
@export var AudioEndFX : AudioFXResource

@export_group("Telegraphing")
@export var TelegraphingColor : Color = Color(1.0, 0.6, 0.0, 0.5)
@export var TelegraphDuration : float = 0.0

@export_group("internal state")
@export var _baseSize : float = -1
@export var _weapon_index : int = -1

var _modifiedDamage
var _modifiedCritChance
var _modifiedCritBonus
var _modifiedBurnChance
var _modifiedSize

signal DamageApplied(damageCategories:Array[String], damageAmount:float, applyReturn:Array, targetNode:GameObject, critical:bool)

var timer : float
var endAnimationTime : float
var animationNode : AnimatedSprite2D

var _burnEffectPrototype : EffectBase
var _damage_is_active : bool

func _ready():
	initGameObjectComponent()
	_modifiedDamage = createModifiedIntValue(BaseDamage, "Damage")
	_modifiedDamage.setModifierCategories(ModifierCategories)

	_modifiedCritChance = createModifiedFloatValue(BaseCriticalChance, "CritChance")
	_modifiedCritChance.setModifierCategories(ModifierCategories)

	_modifiedCritBonus = createModifiedFloatValue(BaseCriticalBonus, "CritBonus")
	_modifiedCritBonus.setModifierCategories(ModifierCategories)

	_modifiedBurnChance = createModifiedFloatValue(BurnChance, "BurnChance")
	_modifiedBurnChance.setModifierCategories(ModifierCategories)

	if _baseSize < 0.0: _baseSize = scale.x
	_modifiedSize = createModifiedFloatValue(_baseSize, "Area")
	_modifiedSize.setModifierCategories(ModifierCategories)
	_modifiedSize.ValueUpdated.connect(sizeWasUpdated)


	if BurnEffectScene != null:
		_burnEffectPrototype = BurnEffectScene.instantiate()
	timer = DamageInterval

	animationNode = $Animation

	if TelegraphDuration > 0:
		var scaledRadius : float = scale.x * Radius
		animationNode.visible = false
		Fx.show_area_telegraph(
				global_position,
				TelegraphingColor,
				scaledRadius,
				TelegraphDuration,
				start_fire)
	else:
		start_fire()

func start_fire():
	_damage_is_active = true
	animationNode.visible = true
	endAnimationTime = (
		animationNode.sprite_frames.get_frame_count("end") /
		animationNode.sprite_frames.get_animation_speed("end"))
	animationNode.connect("animation_finished", _on_animation_finished)
	animationNode.play("start")
	FxAudioPlayer.play_sound_2D(
			AudioFX,
			get_gameobjectWorldPosition(),
			false, false, -3.0)

func _exit_tree():
	if _burnEffectPrototype != null:
		_burnEffectPrototype.queue_free()
		_burnEffectPrototype = null

func get_worldPosition() ->  Vector2:
	return global_position


func set_worldPosition(new_position : Vector2):
	global_position = new_position


func _on_animation_finished():
	if animationNode.animation == "start":
		animationNode.play("idle")

func _process(delta):
	if Engine.is_editor_hint():
		queue_redraw()
		return
	timer -= delta
	if timer <= 0:
		timer = DamageInterval
		hurt()
	Lifetime -= delta
	if Lifetime <= endAnimationTime:
		animationNode.play("end")
		if AudioEndFX != null:
			FxAudioPlayer.play_sound_2D(
				AudioEndFX,
				get_gameobjectWorldPosition(),
				false, false, -3.0)
	if Lifetime <= 0:
		queue_free()

var _tempHits : Array[GameObject] = []
func hurt():
	if not _damage_is_active: return
	var scaledRadius : float = scale.x * Radius
	_tempHits.clear()
	for pool in HitLocatorPools:
		_tempHits.append_array(Global.World.Locators.get_gameobjects_in_circle(
				pool, global_position, scaledRadius))
	for gameObject in _tempHits:
		var healthComponent = gameObject.getChildNodeWithMethod("applyDamage")
		if healthComponent:
			var critical:bool
			if UseModifier:
				critical = randf() <= _modifiedCritChance.Value()
			else:
				critical = randf() <= BaseCriticalChance
			var damage = 0
			if critical:
				damage = get_totalCritDamage()
			else:
				if UseModifier:
					damage = _modifiedDamage.Value()
				else:
					damage = BaseDamage
			var mySource : GameObject = _gameObject.get_rootSourceGameObject()
			# fire damage cannot be blocked
			var damageReturn = healthComponent.applyDamage(damage, mySource, critical, _weapon_index, true)
			if mySource != null and is_instance_valid(mySource):
				mySource.injectEmitSignal("DamageApplied", [DamageCategories, damage, damageReturn, gameObject, critical])
			if _burnEffectPrototype != null:
				if UseModifier:
					if randf() < _modifiedBurnChance.Value():
						gameObject.add_effect(_burnEffectPrototype, mySource)
				else:
					if randf() < BurnChance:
						gameObject.add_effect(_burnEffectPrototype, mySource)


func sizeWasUpdated(_before:float, valueNow:float):
	scale = Vector2.ONE * valueNow


func get_totalCritDamage() -> int:
	if not UseModifier:
		return BaseDamage + ceili(BaseDamage * BaseCriticalBonus)
	var totalDamage : int = _modifiedDamage.Value()
	return totalDamage + ceili(totalDamage * _modifiedCritBonus.Value())

