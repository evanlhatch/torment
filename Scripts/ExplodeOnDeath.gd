extends GameObjectComponent

@export_category("Effect Parameters")
@export var AudioFX : AudioFXResource
@export_enum("None", "Explosion", "WaveEffect", "ArcaneBlast") var TriggerFx : int = 1
@export var BlastSoundVolume : float = -4.0
@export var ExplodeWithDelay : float = 0.0
@export var EffectScale : float = 1.0
@export var SetDamageSourceToPlayer : bool = false

@export_category("Damage Parameters")
@export var ExplosionDamage : int = 32
@export var ExplosionRadius : float = 32
@export var HitLocatorPools : Array[String]
@export var PushForce : float = 0.0
@export var Blockable : bool = false
@export var CritChance : float = 0.0
@export var CritBonus : float = 0.0
@export var ModifierCategories : Array[String] = ["Fire"]
@export var DamageCategories : Array[String] = ["Fire"]

@export_group("Internal State")
@export var _weapon_index : int

signal DamageApplied(categories:Array[String], damageAmount:float, applyReturn:Array, targetNode:GameObject, critical:bool)

var _delay_timer : Timer
var _explosion_pos : Vector2
var _spawn_origin : Node

var _modifiedDamage
var _modifiedArea
var _modifiedCriticalHitChance
var _modifiedCriticalHitBonus

func _ready():
	initGameObjectComponent()
	_modifiedDamage = createModifiedIntValue(ExplosionDamage, "Damage")
	_modifiedArea = createModifiedFloatValue(ExplosionRadius, "Area")
	_modifiedCriticalHitChance = createModifiedFloatValue(CritChance, "CritChance")
	_modifiedCriticalHitBonus = createModifiedFloatValue(CritBonus, "CritBonus")
	applyModifierCategories()
	_gameObject.connectToSignal("Killed", _on_killed)
	if ExplodeWithDelay > 0.0:
		_delay_timer = Timer.new()
		add_child(_delay_timer)

func applyModifierCategories():
	_modifiedDamage.setModifierCategories(ModifierCategories)
	_modifiedArea.setModifierCategories(ModifierCategories)
	_modifiedCriticalHitChance.setModifierCategories(ModifierCategories)
	_modifiedCriticalHitBonus.setModifierCategories(ModifierCategories)

func _on_killed(killedBy : Node):
	_explosion_pos = get_gameobjectWorldPosition()
	if ExplodeWithDelay > 0.0:
		get_parent().remove_child(self)
		Global.add_child(self)
		_delay_timer.start(ExplodeWithDelay)
		await _delay_timer.timeout
	explode(_explosion_pos)
	queue_free()


func explode(position:Vector2):
	var radius = _modifiedArea.Value()
	if AudioFX != null:
		FxAudioPlayer.play_sound_2D(AudioFX, position, false, false, BlastSoundVolume)
	match TriggerFx:
		1: Fx.show_explosion_scaled(position, EffectScale* radius / ExplosionRadius, SetDamageSourceToPlayer)
		2: Fx.show_cone_wave(
			position,
			Vector2.RIGHT,
			radius,
			360, 3.0, 1.0,
			Color.WHITE, Callable(), null, 1.0, true)
		3: Fx.show_arcane_blast(position, EffectScale * radius / ExplosionRadius)
	var mySource = _gameObject.get_rootSourceGameObject()
	var damage = _modifiedDamage.Value()
	for pool in HitLocatorPools:
		var hits = Global.World.Locators.get_gameobjects_in_circle(
				pool, position, radius)
		for hitObject in hits:
			var critical : bool = false
			var actual_damage = damage
			var healthComponent = hitObject.getChildNodeWithMethod("applyDamage")
			if healthComponent != null:
				var damageReturn = null
				if _modifiedCriticalHitBonus.Value() > 0:
					var numCrits : int = floori(_modifiedCriticalHitChance.Value())
					var remainingChance : float = _modifiedCriticalHitChance.Value() - numCrits
					if randf() <= remainingChance:
						numCrits += 1
					critical = numCrits > 0
					actual_damage = damage + (damage * _modifiedCriticalHitBonus.Value()) * numCrits
				if (mySource != null and is_instance_valid(mySource) and not mySource.is_queued_for_deletion()):
					damageReturn = healthComponent.applyDamage(actual_damage, mySource, critical, _weapon_index, not Blockable)
					mySource.injectEmitSignal("DamageApplied", [DamageCategories, actual_damage, damageReturn, hitObject, critical])
				else:
					damageReturn = healthComponent.applyDamage(actual_damage, null, critical, _weapon_index, not Blockable)
				if mySource != _gameObject:
					DamageApplied.emit(DamageCategories, actual_damage, damageReturn, hitObject, critical)

	if PushForce > 0:
		Forces.RadialBlast(position, 50, PushForce, Forces.Falloff.Quadratic, HitLocatorPools)

func get_totalCritChance() -> float: return _modifiedCriticalHitChance.Value()
func get_totalCritBonus() -> float: return _modifiedCriticalHitBonus.Value()
func get_totalCritDamage() -> float:
		var damage = _modifiedDamage.Value()
		return damage + get_totalCritBonus() * damage

func set_weapon_index(weapon_index:int):
	_weapon_index = weapon_index
