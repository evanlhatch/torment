extends GameObjectComponent2D

# this has to be of type StunEffect!
@export var StunEffectNode : PackedScene

@export var EmitInterval : float = 1.0

@export var Radius : float = 80
@export var HitLocatorPool : String = "Enemies"

@export_group("Visuals")
@export var NoiseTex : NoiseTexture2D
var noise_time : float

@export_group("internal state")
@export var _baseSize : float = -1.0
@export var _baseRange : float = -1.0

var _effectPrototype : EffectBase
var emit_timer : float
var _directionProvider
var _modifiedSize
var _modifiedStunBuildup
var _modifiedStunDuration
var _modifiedRange

func _enter_tree():
	if _baseSize < 0: _baseSize = scale.x
	if _baseRange < 0: _baseRange = $HitArea.position.x
	initGameObjectComponent()
	if _gameObject:
		emit_timer = 0.0
		visible = true
		_directionProvider = _gameObject.getChildNodeWithMethod("get_aimDirection")
		_effectPrototype = StunEffectNode.instantiate()
		_modifiedStunBuildup = createModifiedFloatValue(_effectPrototype.StunBuildup, "StunBuildup")
		_modifiedStunDuration = createModifiedFloatValue(_effectPrototype.StunDuration, "StunDuration")
		_modifiedSize = createModifiedFloatValue(_baseSize, "Area")
		_modifiedSize.connect("ValueUpdated", sizeWasUpdated)
		_modifiedRange = createModifiedFloatValue(_baseRange, "Range")
		_modifiedRange.connect("ValueUpdated", rangeWasUpdated)
		sizeWasUpdated(_baseSize, _modifiedSize.Value())


func _exit_tree():
	_allModifiedValues.clear()
	if _effectPrototype != null:
		_effectPrototype.queue_free()
		_effectPrototype = null
	_gameObject = null
	_modifiedSize = null
	_modifiedStunBuildup = null
	_modifiedStunDuration = null
	_modifiedRange = null
	_effectPrototype = null
	visible = false


func _process(delta):
	if _gameObject == null: return
	if _positionProvider:
		global_position = _positionProvider.get_worldPosition()
		noise_time += delta * 2.0
		if (noise_time >= 2*PI):
			noise_time -= 2*PI
		NoiseTex.noise.offset.z = sin(noise_time) * 12.0
	
	if _directionProvider:
		var dir = _directionProvider.get_aimDirection();
		rotation = atan2(dir.y, dir.x)
	
	if emit_timer <= 0:
		emit()
		emit_timer += EmitInterval
	emit_timer -= delta

func emit():
	if _gameObject == null or _directionProvider == null: return
	_effectPrototype.StunBuildup = _modifiedStunBuildup.Value()
	_effectPrototype.StunDuration = _modifiedStunDuration.Value()
	var scaledRadius : float = Radius * _modifiedSize.Value()
	var hits = Global.World.Locators.get_gameobjects_in_circle(HitLocatorPool, $HitArea.global_position, scaledRadius)
	var mySource : GameObject = _gameObject.get_rootSourceGameObject()
	for hit_gameObject in hits:
		var hitPositionProvider = hit_gameObject.getChildNodeWithMethod("get_worldPosition")
		if not hitPositionProvider:
			continue
		hit_gameObject.add_effect(_effectPrototype, mySource)


func sizeWasUpdated(_oldValue:float, totalSize:float): 
	scale = Vector2.ONE * totalSize
	$HitArea.position.x = _modifiedRange.Value() + get_radiusOffset()


func rangeWasUpdated(_oldValue:float, totalRange:float):
	$HitArea.position.x = totalRange + get_radiusOffset()


func get_radiusOffset() -> float:
	return (_baseRange / scale.x) * _baseSize - _baseRange
