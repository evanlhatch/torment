extends GameObjectComponent

@export var AddMaxHealth : float = 0
@export var AddMaxHealthPercent : float = 0.15
@export var RemoveAfterTime : float = -1
@export var AddHealthOnActivate : bool = true

@export var ChangeEveryXLevels : int = 0
@export var ChangeMultiplier : float = 0
@export var ChangeAdditive : float = 0

@export var Name : String
func get_modifier_name() -> String:
	return Name

var _maxHealthMod : Modifier
var _remainingLevelsToChange : int = 0

func _enter_tree():
	initGameObjectComponent()

	if _gameObject == null:
		process_mode = PROCESS_MODE_DISABLED
		return
	process_mode = PROCESS_MODE_INHERIT if RemoveAfterTime > 0 or get_child_count() > 0 else PROCESS_MODE_DISABLED

	if ChangeEveryXLevels > 0:
		await Global.awaitWorldReady()
		Global.World.ExperienceThresholdReached.connect(on_level_up)
		_remainingLevelsToChange = ChangeEveryXLevels
	
	_maxHealthMod = Modifier.create("MaxHealth", _gameObject)
	_maxHealthMod.setName(Name)
	_maxHealthMod.setAdditiveMod(AddMaxHealth)
	_maxHealthMod.setMultiplierMod(AddMaxHealthPercent)
	if AddHealthOnActivate:
		var healthComponent = _gameObject.getChildNodeWithMethod("add_health")
		if healthComponent != null:
			var maxHealthBefore : int = healthComponent.get_maxHealth()
			_gameObject.triggerModifierUpdated("MaxHealth")
			var maxHealthAfter : int = healthComponent.get_maxHealth()
			if maxHealthAfter > maxHealthBefore:
				healthComponent.add_health(maxHealthAfter - maxHealthBefore)
		else:
			_gameObject.triggerModifierUpdated("MaxHealth")
	else:
		_gameObject.triggerModifierUpdated("MaxHealth")

func on_level_up():
	_remainingLevelsToChange -= 1
	if _remainingLevelsToChange <= 0:
		_remainingLevelsToChange = ChangeEveryXLevels
		_maxHealthMod.setMultiplierMod(_maxHealthMod.getMultiplierMod() + ChangeMultiplier)
		_maxHealthMod.setAdditiveMod(_maxHealthMod.getAdditiveMod() + ChangeAdditive)
		# special case for max health: should also add the health!
		if AddHealthOnActivate:
			var healthComponent = _gameObject.getChildNodeWithMethod("add_health")
			if healthComponent != null:
				var maxHealthBefore : int = healthComponent.get_maxHealth()
				_gameObject.triggerModifierUpdated("MaxHealth")
				var maxHealthAfter : int = healthComponent.get_maxHealth()
				if maxHealthAfter > maxHealthBefore:
					healthComponent.add_health(maxHealthAfter - maxHealthBefore)
			else:
				_gameObject.triggerModifierUpdated("MaxHealth")
		else:
			_gameObject.triggerModifierUpdated("MaxHealth")

func _exit_tree():
	_maxHealthMod = null
	_gameObject = null

func _process(delta):
	if RemoveAfterTime < 0:
		return
	RemoveAfterTime -= delta
	if RemoveAfterTime <= 0:
		queue_free()
