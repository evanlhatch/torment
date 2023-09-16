extends GameObjectComponent2D

const SPEEDFACTOR : float = 1.0/90.0

@export var SphereScene : PackedScene

@export var PositionOffset : Vector2 = Vector2(0.0, -16.0)
@export var BaseDamage : int = 10
@export var DamageInterval : float = 0.5
@export var BaseCriticalChance : float = 0.0
@export var BaseCriticalBonus : float = 0.0
@export var BaseOrbitSpeed : float = 90.0
@export var BaseOrbitSize : float = 100.0
@export var BaseSphereSize : float = 0.6
@export var BaseSphereCount : int = 3
@export var BaseSphereRadius : float = 14
@export var ModifierCategories : Array[String] = ["Projectile"]
@export var HitLocatorPools : Array[String] = ["Enemies", "Breakables"]
@export var DamageCategories : Array[String]

@export_group("scaling modifiers")
@export var OrbitSpeedScalingFactor : float = 2.5
@export var OrbitSizeScalingFactor : float = 1.5

@export_group("internal state")
@export var _weapon_index : int = -1

signal DamageApplied(damageCategories:Array[String], damageAmount:float, applyReturn:Array, targetNode:GameObject, critical:bool)
signal AstronomersOrbTouched(targetNode:GameObject)

var _modifiedDamage
var _modifiedCritChance
var _modifiedCritBonus
var _modifiedSpeed
var _modifiedOrbitSize
var _modifiedSphereSize
var _modifiedCount
var _alreadyDamaged : Array[GameObject] = []
var _remainingTimeToClearDamaged = 0
var _spheres : Array[Node2D] = []
var _orbitEccentricity : float = 0
var _currentRotation : float = 0

func _on_player_died():
	_gameObject = null
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED


func _enter_tree():
	initGameObjectComponent()
	if _gameObject != null:
		visible = true
		process_mode = Node.PROCESS_MODE_PAUSABLE
		_modifiedDamage = createModifiedIntValue(BaseDamage, "Damage")
		_modifiedCritChance = createModifiedFloatValue(BaseCriticalChance, "CritChance")
		_modifiedCritBonus = createModifiedFloatValue(BaseCriticalBonus, "CritBonus")
		_modifiedSpeed = createModifiedFloatValue(BaseOrbitSpeed, "MovementSpeed")
		_modifiedOrbitSize = createModifiedFloatValue(BaseOrbitSize, "Range")
		_modifiedOrbitSize.connect("ValueUpdated", update_sphere_configuration)
		_modifiedSphereSize = createModifiedFloatValue(BaseSphereSize, "Area")
		_modifiedSphereSize.connect("ValueUpdated", update_sphere_size)
		_modifiedCount = createModifiedIntValue(BaseSphereCount, "EmitCount")
		_modifiedCount.connect("ValueUpdated", update_sphere_configuration)
		applyModifierCategories()
		update_sphere_configuration(0,0)
		update_sphere_size(0,0)
		Global.World.connect("PlayerDied", _on_player_died)
	else:
		visible = false
		var parent = get_parent()
		if parent and parent.has_method("get_weapon_index"):
			_weapon_index = parent.get_weapon_index()
		else: _weapon_index = -1

func applyModifierCategories():
	_modifiedDamage.setModifierCategories(ModifierCategories)
	_modifiedCritChance.setModifierCategories(ModifierCategories)
	_modifiedCritBonus.setModifierCategories(ModifierCategories)
	_modifiedSpeed.setModifierCategories(ModifierCategories)
	_modifiedOrbitSize.setModifierCategories(ModifierCategories)
	_modifiedSphereSize.setModifierCategories(ModifierCategories)
	_modifiedCount.setModifierCategories(ModifierCategories)

func transformCategories(onlyWithDamageCategory:String, addModifierCategories:Array[String], removeModifierCategories:Array[String], addDamageCategories:Array[String], removeDamageCategories:Array[String]):
	if not DamageCategories.has(onlyWithDamageCategory):
		return
	for addMod in addModifierCategories:
		if not ModifierCategories.has(addMod):
			ModifierCategories.append(addMod)
	for remMod in removeModifierCategories:
		ModifierCategories.erase(remMod)
	for addCat in addDamageCategories:
		if not DamageCategories.has(addCat):
			DamageCategories.append(addCat)
	for remMod in removeDamageCategories:
		DamageCategories.erase(remMod)
	applyModifierCategories()
		

func _exit_tree():
	_allModifiedValues.clear()
	_gameObject = null
	_modifiedDamage = null
	_modifiedCritChance = null
	_modifiedCritBonus = null
	_modifiedSpeed = null
	_modifiedOrbitSize = null
	_modifiedSphereSize = null
	_modifiedCount = null
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED

var _tempHits : Array[GameObject] = []
func _process(delta):
#ifdef PROFILING
#	updateAstronomersOrbs(delta)
#func updateAstronomersOrbs(delta):
#endif
	if _gameObject == null: return
	if _positionProvider:
		global_position = _positionProvider.get_worldPosition() + PositionOffset
	
	_remainingTimeToClearDamaged -= delta
	if _remainingTimeToClearDamaged <= 0:
		_remainingTimeToClearDamaged += DamageInterval
		_alreadyDamaged.clear()
		
	updateOrbs(delta, true)

func updateOrbs(delta:float, applyDamage:bool):
	_currentRotation = lerpf(_currentRotation, _currentRotation + get_totalOrbitSpeed() * SPEEDFACTOR, delta)
	_currentRotation = fmod(_currentRotation, 2.0 * PI)
	var angle_increment = 2 * PI / float(_spheres.size())
	var angle = _currentRotation
	var i : int = 0
	var orbitSize : float = get_totalOrbitSize()
	var phase_offset : float = 0.25 * Time.get_ticks_msec() / 1000.0
	for c in _spheres:
		var distFromCenter : float = orbitSize
		if _orbitEccentricity != 0:
			distFromCenter += _orbitEccentricity * (1.0 + sin(_currentRotation + i * PI * 0.95 + phase_offset)) / 2.0
		c.position = (Vector2.UP * distFromCenter).rotated(angle)
		angle += angle_increment
		i += 1
	
		if not applyDamage:
			continue
			
		_tempHits.clear()
		for locatorPool in HitLocatorPools:
			_tempHits.append_array(Global.World.Locators.get_gameobjects_in_circle(
				locatorPool, c.global_position, BaseSphereRadius * get_totalSphereSize()))
		for hitGO in _tempHits:
			if _alreadyDamaged.has(hitGO):
				continue
			var additionalDamageFactor : float = 0.0
			if _orbitEccentricity > 0:
				additionalDamageFactor = (distFromCenter-orbitSize) / _orbitEccentricity
			gameObjectDamaged(hitGO, additionalDamageFactor)
			_alreadyDamaged.append(hitGO)
			AstronomersOrbTouched.emit(hitGO)


func gameObjectDamaged(hit_game_object:GameObject, addDamageFactor:float):
	var health_component = hit_game_object.getChildNodeWithMethod("applyDamage")
	if health_component:
		var critical:bool = randf() <= get_totalCritChance()
		var damage = 0
		if critical:
			damage = get_totalCritDamage()
		else:
			damage = get_totalDamage()
		damage += damage * addDamageFactor 
		var damageReturn = health_component.applyDamage(damage, _gameObject, critical, _weapon_index)
		DamageApplied.emit(DamageCategories, damage, damageReturn, hit_game_object, critical)


func update_sphere_configuration(_valueBefore, _valueAfter):
	var target_count = get_totalSphereCount()
	var count_delta = target_count - _spheres.size()
	if count_delta > 0:
		for _i in count_delta:
			var newSphere = SphereScene.instantiate()
			newSphere.scale = Vector2.ONE * get_totalSphereSize()
			add_child(newSphere)
			_spheres.append(newSphere)
	elif count_delta < 0:
		for _i in -count_delta:
			var removed_sphere = _spheres.pop_back()
			removed_sphere.queue_free()
	
	updateOrbs(0, false)


func update_sphere_size(_valueBefore, _valueAfter):
	for c in _spheres:
		c.scale = Vector2.ONE * get_totalSphereSize()

func get_totalDamage() -> int: return _modifiedDamage.Value()
func get_totalCritChance() -> float: return _modifiedCritChance.Value()
func get_totalCritBonus() -> float: return _modifiedCritBonus.Value()
func get_totalOrbitSize() -> float: 
	var additionalScaledOrbitSize = (_modifiedOrbitSize.Value() - BaseOrbitSize) * OrbitSizeScalingFactor
	return BaseOrbitSize + additionalScaledOrbitSize
func get_totalOrbitSpeed() -> float:
	var additionalScaledOrbitSpeed = (_modifiedSpeed.Value() - BaseOrbitSpeed) * OrbitSpeedScalingFactor
	return BaseOrbitSpeed + additionalScaledOrbitSpeed
func get_totalSphereSize() -> float: return _modifiedSphereSize.Value()
func get_totalSphereCount() -> int: return _modifiedCount.Value()


func get_totalCritDamage() -> int:
	var totalDamage = get_totalDamage()
	return totalDamage + int(ceil(totalDamage * get_totalCritBonus()))
