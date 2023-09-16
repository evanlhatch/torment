# Extend this class to get access to all kinds of convenience functionality
# concerning GameObjects

# NOTE: do not edit this class directly. Just keep the contents up to date
# with the GameObjectComponent.gd script (minus the class_name and the extends Node2D)

extends Area2D
class_name GameObjectComponentArea2D

var _gameObject : GameObject
var _externalSourceGameObject : GameObject = null

var _positionProvider : Node


# initGameObjectComponent has to be called first thing in the _ready function!
func initGameObjectComponent():
	_gameObject = Global.get_gameObject_in_parents(self)
	if not _gameObject:
		return
	if _gameObject.is_queued_for_deletion():
		_gameObject = null
		return
	_positionProvider = _gameObject.getChildNodeWithMethod("get_worldPosition")

func get_gameobject() -> GameObject:
	if not _gameObject:
		_gameObject = Global.get_gameObject_in_parents(self)
	return _gameObject

func set_externalSource(externalSource:GameObject):
	_externalSourceGameObject = externalSource

func get_externalSource() -> GameObject:
	return _externalSourceGameObject

func get_gameobjectWorldPosition() -> Vector2:
	if not _gameObject:
		printerr("%s initGameObjectComponent() wasn't called!")
		return Vector2.ZERO
	if not _positionProvider:
		_positionProvider = _gameObject.getChildNodeWithMethod("get_worldPosition")
		if not _positionProvider:
			printerr("parent gameobject of %s doesn't have a worldPosition provider!" % name)
			return Vector2.ZERO
	return _positionProvider.get_worldPosition()

func createModifiedIntValue(baseVal:int, modifierName:String, rankModifier:Callable = Callable()):
	var modVal = ModifiedIntValue.new()
	modVal.init(baseVal, modifierName, _gameObject, rankModifier)
	_allModifiedValues.append(modVal)
	return modVal

func createModifiedFloatValue(baseVal:float, modifierName:String, rankModifier:Callable = Callable()):
	var modVal = ModifiedFloatValue.new()
	modVal.init(baseVal, modifierName, _gameObject, rankModifier)
	_allModifiedValues.append(modVal)
	return modVal

var _allModifiedValues : Array
func get_modified_values() -> Array:
	return _allModifiedValues

class ValueDrawPool:
	var _initial_sequence:Array[int]
	var _pool_front:Array[int]
	var _pool_back:Array[int]
	
	func _init(initialPool:Array[int], initialiSequence:Array[int] = []):
		_initial_sequence = initialiSequence
		_pool_front = initialPool
	
	func draw_value() -> int:
		if _initial_sequence.size() > 0:
			return _initial_sequence.pop_front()
		if len(_pool_front) <= 0: swap_pools()
		var index = randi_range(0, len(_pool_front)-1)
		var drawn_value = _pool_front[index]
		_pool_front.remove_at(index)
		_pool_back.append(drawn_value)
		return drawn_value

	func swap_pools():
		var temp = _pool_back
		_pool_back = _pool_front
		_pool_front = temp


func createValueDrawPool(pool_values:Array[int], initial_sequence:Array[int] = []):
	return ValueDrawPool.new(pool_values, initial_sequence)

# distance_sort can be used to sort arrays of gameobjects by distance
# to ourself. use like this: hitGameObjects.sort_custom(distance_sort)
func distance_sort(a : GameObject, b : GameObject):
	var pos : Vector2 = get_gameobjectWorldPosition()
	var pos_a = a.getChildNodeWithMethod("get_worldPosition")
	var pos_b = b.getChildNodeWithMethod("get_worldPosition")
	var dist_a = Global.MAX_VALUE
	var dist_b = Global.MAX_VALUE
	if pos_a: dist_a = pos.distance_squared_to(pos_a.get_worldPosition())
	if pos_b: dist_b = pos.distance_squared_to(pos_b.get_worldPosition())
	return dist_a < dist_b
