extends Node2D
class_name CollectableManager

const ReactivateFromHomingDist : float = 500
const OffscreenMovementSpeed : float = 500
const BucketGridSize : int = 400

class CollectableData:
	var CollectableGO : GameObject
	var GlobalPosition : Vector2
	var Bucket : Vector2i
	var LocatorPool : String
	var PointerWorldObject : PointerToWorldObjectSpawner
	var RemainingTimeToPlayer : float
	var Collector : Node

var _allCollectables : Array[CollectableData]
var _freeCollectableIndices : Array[int]
var _collectableGOIndexMap : Dictionary
var _activeCollectableBuckets : Dictionary
var _inactiveCollectableBuckets : Dictionary
var _homingCollectableIndices : Array[int]


func addToCollectables() -> int:
	if _freeCollectableIndices.is_empty():
		_allCollectables.append(CollectableData.new())
		return _allCollectables.size()-1
	return _freeCollectableIndices.pop_back()

func freeCollectable(index:int):
	# todo: remove checks after development
	if _freeCollectableIndices.has(index):
		printerr("cant free: already free!")
		return
	_freeCollectableIndices.append(index)

func RegisterCollectable(collectable:GameObject):
	if _collectableGOIndexMap.has(collectable.get_instance_id()):
		printerr("cant register collectable: already there!")
		return
	var dataIndex : int = addToCollectables()
	_collectableGOIndexMap[collectable.get_instance_id()] = dataIndex
	var data : CollectableData = _allCollectables[dataIndex]
	data.CollectableGO = collectable
	var positionProvider : Node = collectable.getChildNodeWithMethod("get_worldPosition")
	data.GlobalPosition = positionProvider.get_worldPosition()
	data.Bucket = data.GlobalPosition / BucketGridSize
	var locator : Locator = collectable.getChildNodeWithMethod("SetLocatorActive")
	data.LocatorPool = locator.LocatorPoolName
	for child in collectable.get_children():
		if child is PointerToWorldObjectSpawner:
			data.PointerWorldObject = child
			break
	addToActiveCollectables(dataIndex, data.Bucket)

func addToActiveCollectables(dataIndex:int, bucket:Vector2i):
	var bucketList = _activeCollectableBuckets.get(bucket)
	if bucketList == null:
		var list : Array[int] = [dataIndex]
		_activeCollectableBuckets[bucket] = list
	else:
		bucketList.append(dataIndex)

func removeFromActiveCollectables(dataIndex:int, bucket:Vector2i):
	var bucketList = _activeCollectableBuckets.get(bucket)
	if bucketList != null:
		bucketList.erase(dataIndex)
		if bucketList.is_empty():
			_activeCollectableBuckets.erase(bucket)

func addToInactiveCollectables(dataIndex:int, bucket:Vector2i):
	var bucketList = _inactiveCollectableBuckets.get(bucket)
	if bucketList == null:
		var list : Array[int] = [dataIndex]
		_inactiveCollectableBuckets[bucket] = list
	else:
		bucketList.append(dataIndex)

func removeFromInactiveCollectables(dataIndex:int, bucket:Vector2i):
	var bucketList = _inactiveCollectableBuckets.get(bucket)
	if bucketList != null:
		bucketList.erase(dataIndex)
		if bucketList.is_empty():
			_inactiveCollectableBuckets.erase(bucket)

func UnregisterCollectable(collectable:GameObject):
	var dataIndex : int = _collectableGOIndexMap.get(collectable.get_instance_id(), -1)
	if dataIndex == -1:
		return
	var bucket : Vector2i = _allCollectables[dataIndex].Bucket
	freeCollectable(dataIndex)
	removeFromActiveCollectables(dataIndex, bucket)
	removeFromInactiveCollectables(dataIndex, bucket)
	_collectableGOIndexMap.erase(collectable.get_instance_id())

func uninitialize():
	# inactive and homing collectables are not in a tree anymore
	# and have to be freed by us!
	for indexList in _inactiveCollectableBuckets.values():
		for dataIndex in indexList:
			_allCollectables[dataIndex].CollectableGO.queue_free()
	_inactiveCollectableBuckets.clear()
	for dataIndex in _homingCollectableIndices:
		_allCollectables[dataIndex].CollectableGO.queue_free()
	_homingCollectableIndices.clear()

func check_for_collectable_at_location(location:Vector2, radius:float) -> bool:
	var bucket : Vector2i = location / BucketGridSize
	var indexList = _activeCollectableBuckets.get(bucket)
	if indexList != null:
		for dataIndex in indexList:
			if _allCollectables[dataIndex].GlobalPosition.distance_squared_to(location) < radius*radius:
				return true
	indexList = _inactiveCollectableBuckets.get(bucket)
	if indexList != null:
		for dataIndex in indexList:
			if _allCollectables[dataIndex].GlobalPosition.distance_squared_to(location) < radius*radius:
				return true
	return false

func trigger_collect_for_all_in_pool(poolName:String, collector:Node):
	for bucketKey in _activeCollectableBuckets.keys():
		var bucket : Array[int] = _activeCollectableBuckets[bucketKey]
		for i in range(bucket.size(), 0, -1):
			var dataIndex : int = bucket[i-1]
			if _allCollectables[dataIndex].LocatorPool == poolName:
				var data := _allCollectables[dataIndex]
				bucket.remove_at(i-1)
				freeCollectable(dataIndex)
				_collectableGOIndexMap.erase(data.CollectableGO.get_instance_id())
				var collectProvider = data.CollectableGO.getChildNodeWithMethod("collect")
				if collectProvider:
					if collectProvider.has_signal("Collected"):
						collectProvider.Collected.connect(collector.collectableWasCollected.bind(data.CollectableGO))
					collectProvider.collect(collector)
		if bucket.is_empty():
			_activeCollectableBuckets.erase(bucketKey)
	var playerPosProvider : Node = Global.World.Player.getChildNodeWithMethod("get_worldPosition")
	if playerPosProvider == null:
		return
	var playerPos : Vector2 = playerPosProvider.get_worldPosition()
	for bucketKey in _inactiveCollectableBuckets.keys():
		var bucket : Array[int] = _inactiveCollectableBuckets[bucketKey]
		for i in range(bucket.size(), 0, -1):
			var dataIndex : int = bucket[i-1]
			if _allCollectables[dataIndex].LocatorPool == poolName:
				var data := _allCollectables[dataIndex]
				bucket.remove_at(i-1)
				data.Collector = collector
				data.RemainingTimeToPlayer = (data.GlobalPosition.distance_to(playerPos) - ReactivateFromHomingDist) / OffscreenMovementSpeed
				if data.RemainingTimeToPlayer < 0: data.RemainingTimeToPlayer = 0
				_homingCollectableIndices.append(dataIndex)
		if bucket.is_empty():
			_inactiveCollectableBuckets.erase(bucketKey)

func updateCollectableManager(delta:float):
	if not Global.is_world_ready() or Global.World == null or Global.World.Player == null:
		return
	var playerPosProvider : Node = Global.World.Player.getChildNodeWithMethod("get_worldPosition")
	if playerPosProvider == null:
		return
	var playerPos : Vector2 = playerPosProvider.get_worldPosition()
	var playerBucket : Vector2i = playerPos / BucketGridSize
	for bucketKey in _activeCollectableBuckets.keys():
		var bucketShouldBeInactive : bool = \
			bucketKey.x < playerBucket.x - 1 or bucketKey.x > playerBucket.x + 1 or \
			bucketKey.y < playerBucket.y - 1 or bucketKey.y > playerBucket.y + 1
		if not bucketShouldBeInactive:
			continue
		# this active bucket should be inactive! deactivate all the gameobjects
		var bucketList : Array[int] = _activeCollectableBuckets[bucketKey]
		for dataIndex in bucketList:
			var data := _allCollectables[dataIndex]
			if data.PointerWorldObject != null:
				data.PointerWorldObject.reparent(Global.World)
			if data.CollectableGO.get_parent() != null:
				data.CollectableGO.get_parent().remove_child(data.CollectableGO)
		# and then move the complete bucket over to the inactive buckets.
		if _inactiveCollectableBuckets.has(bucketKey):
			_inactiveCollectableBuckets[bucketKey].append_array(bucketList)
		else:
			_inactiveCollectableBuckets[bucketKey] = bucketList
		_activeCollectableBuckets.erase(bucketKey)
	
	for bucketKey in _inactiveCollectableBuckets.keys():
		var bucketShouldBeInactive : bool = \
			bucketKey.x < playerBucket.x - 1 or bucketKey.x > playerBucket.x + 1 or \
			bucketKey.y < playerBucket.y - 1 or bucketKey.y > playerBucket.y + 1
		if bucketShouldBeInactive:
			continue
		# this inactive bucket should be active! activate all the gameobjects
		var bucketList : Array[int] = _inactiveCollectableBuckets[bucketKey]
		for dataIndex in bucketList:
			var data := _allCollectables[dataIndex]
			if data.PointerWorldObject != null:
				data.PointerWorldObject.reparent(data.CollectableGO)
			Global.World.add_child(data.CollectableGO)
			data.CollectableGO.global_position = data.GlobalPosition
		# and then move the complete bucket over to the active buckets.
		if _activeCollectableBuckets.has(bucketKey):
			_activeCollectableBuckets[bucketKey].append_array(bucketList)
		else:
			_activeCollectableBuckets[bucketKey] = bucketList
		_inactiveCollectableBuckets.erase(bucketKey)
	
	for i in range(_homingCollectableIndices.size(), 0, -1):
		var dataIndex : int = _homingCollectableIndices[i-1]
		_allCollectables[dataIndex].RemainingTimeToPlayer -= delta
		if _allCollectables[dataIndex].RemainingTimeToPlayer <= 0:
			var data := _allCollectables[dataIndex]
			_homingCollectableIndices.remove_at(i-1)
			freeCollectable(dataIndex)
			_collectableGOIndexMap.erase(data.CollectableGO.get_instance_id())
			if data.PointerWorldObject != null:
				data.PointerWorldObject.reparent(data.CollectableGO)
			Global.World.add_child(data.CollectableGO)
			var newWorldPos : Vector2 = playerPos + (data.GlobalPosition - playerPos).normalized() * ReactivateFromHomingDist
			data.CollectableGO.global_position = newWorldPos
			if data.Collector == null or data.Collector.is_queued_for_deletion():
				continue
			var collectProvider = data.CollectableGO.getChildNodeWithMethod("collect")
			if collectProvider:
				if collectProvider.has_signal("Collected"):
					collectProvider.Collected.connect(data.Collector.collectableWasCollected.bind(data.CollectableGO))
				collectProvider.collect(data.Collector)

