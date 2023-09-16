extends RefCounted

class_name NavigationCavernsSystem

var _allCaverns : Array[NavigationCavern]
var _cavernPathFinding : AStar2D = AStar2D.new()

enum NavigationCavernLocations {
	Invalid,
	InsideCavern,
	NearCavern,
	InsideConnection
}

class NavigationAgentData:
	var CurrentState : NavigationCavernLocations
	var NearestCavern : NavigationCavern
	var InsideConnection : NavigationCavernConnection
	var PositionProvider : Node
	var NavTargetOverride : NavigationCavernTargetOverride
var _monsterNavigationAgents : Array[NavigationAgentData]
var _monsterNavigationAgentsFreeIndices : Array[int]
var _monsterIndices : Dictionary

var _playerNavAgent : NavigationAgentData
var _playerCavernIndex : int = -1

class CavernCircularView:
	var CavernIndex : int
	var StartAngle : float
	var EndAngle : float
	var CavernCenterDist : float
var _currentScreenCavernView : Array[CavernCircularView]

func init():
	var nodes_to_check : Array[Node] = Global.World.get_children()
	var check_index : int = 0
	while check_index < nodes_to_check.size():
		var checknode : Node = nodes_to_check[check_index]
		if checknode.has_method("get_class_name") and checknode.get_class_name() == "NavigationCavern":
			_allCaverns.append(checknode)
			_cavernPathFinding.add_point(_allCaverns.size()-1, checknode.global_position)
		nodes_to_check.append_array(checknode.get_children())
		check_index += 1
	for i in _allCaverns.size():
		var current : NavigationCavern = _allCaverns[i]
		for connection in _allCaverns[i].Connections:
			var connectedCavernIndex : int = _allCaverns.find(current.get_node(connection.ToCavern))
			_cavernPathFinding.connect_points(i, connectedCavernIndex)
	for worldChild in Global.World.get_children():
		if worldChild.has_signal("WrappingFloorWrapped"):
			worldChild.WrappingFloorWrapped.connect(repositionCavernsInPathfinding)
			break

	_playerNavAgent = NavigationAgentData.new()
	_playerNavAgent.PositionProvider = Global.World.Player.getChildNodeWithMethod("get_worldPosition")

func repositionCavernsInPathfinding():
	for i in _allCaverns.size():
		var current : NavigationCavern = _allCaverns[i]
		_cavernPathFinding.set_point_position(i, current.global_position)

func world_has_navigation_caverns() -> bool:
	return not _allCaverns.is_empty()

func addToNavigationAgents() -> int:
	if _monsterNavigationAgentsFreeIndices.is_empty():
		_monsterNavigationAgents.append(NavigationAgentData.new())
		return _monsterNavigationAgents.size()-1
	return _monsterNavigationAgentsFreeIndices.pop_back()

func freeNavigationAgent(index:int):
	# todo: remove checks after development
	if _monsterNavigationAgentsFreeIndices.has(index):
		printerr("cant free: already free!")
		return
	_monsterNavigationAgentsFreeIndices.append(index)
	_monsterNavigationAgentsFreeIndices.sort()

func RegisterNavigationAgent(monsterNav:NavigationCavernTargetOverride):
	var monster : GameObject = monsterNav._gameObject
	if _monsterIndices.has(monster.get_instance_id()):
		printerr("cant register navigation agent: already there!")
		return
	var dataIndex : int = addToNavigationAgents()
	_monsterIndices[monster.get_instance_id()] = dataIndex
	var data : NavigationAgentData = _monsterNavigationAgents[dataIndex]
	data.CurrentState = NavigationCavernLocations.Invalid
	data.NearestCavern = null
	data.InsideConnection = null
	data.PositionProvider = monster.getChildNodeWithMethod("get_worldPosition")
	data.NavTargetOverride = monsterNav

func UnregisterNavigationAgent(monsterNav:NavigationCavernTargetOverride):
	var monster : GameObject = monsterNav._gameObject
	var dataIndex : int = _monsterIndices.get(monster.get_instance_id(), -1)
	if dataIndex == -1:
		return
	freeNavigationAgent(dataIndex)
	_monsterIndices.erase(monster.get_instance_id())

func get_closest_cavern(global_point : Vector2) -> NavigationCavern:
	var closest_cavern : NavigationCavern = null
	var closest_dist_squared : float = 999999999

	for cavern in _allCaverns:
		var dist_squared = cavern.global_position.distance_to(global_point) - cavern.Radius
		if dist_squared < closest_dist_squared:
			closest_dist_squared = dist_squared
			closest_cavern = cavern

	return closest_cavern

func get_closest_cavern_with_wrapping(global_point : Vector2) -> NavigationCavern:
	var closestDistSq : float = 9999999
	var closestCavern : NavigationCavern
	for cavern in _allCaverns:
		var distSq : float = cavern.get_distanceSQ_to_center_wrapped(global_point)
		if distSq < closestDistSq:
			closestDistSq = distSq
			closestCavern = cavern
	return closestCavern

func update():
	if not world_has_navigation_caverns(): return
	var playerChanged := update_navigation_agent(_playerNavAgent)
	if playerChanged: _playerCavernIndex = _allCaverns.find(_playerNavAgent.NearestCavern)
	var currentIndexInFree : int = 0
	var monsterIndex : int = 0
	while true:
		# skip all free indices...
		while currentIndexInFree < _monsterNavigationAgentsFreeIndices.size() && \
			_monsterNavigationAgentsFreeIndices[currentIndexInFree] == monsterIndex:
				monsterIndex += 1
				currentIndexInFree += 1
		if monsterIndex >= _monsterNavigationAgents.size():
			break
		var monsterChanged := update_navigation_agent(_monsterNavigationAgents[monsterIndex])
		if monsterChanged or playerChanged:
			find_path_to_player(_monsterNavigationAgents[monsterIndex])
		monsterIndex+=1

func update_navigation_agent(navAgent:NavigationAgentData) -> bool:
	if navAgent.PositionProvider == null or not is_instance_valid(navAgent.PositionProvider):
		return false
	var globalPos : Vector2 = navAgent.PositionProvider.get_worldPosition()
	if navAgent.NearestCavern != null and navAgent.NearestCavern.is_inside_cavern(globalPos):
		if navAgent.CurrentState == NavigationCavernLocations.InsideCavern:
			# still inside same cavern -> no change
			return false
		navAgent.CurrentState = NavigationCavernLocations.InsideCavern
		return true
	var nearest_cavern : NavigationCavern = get_closest_cavern(globalPos)
	if nearest_cavern != navAgent.NearestCavern and nearest_cavern.is_inside_cavern(globalPos):
		navAgent.NearestCavern = nearest_cavern
		navAgent.InsideConnection = null
		navAgent.CurrentState = NavigationCavernLocations.InsideCavern
		return true
	var inside_connection := nearest_cavern.get_inside_corridor(globalPos)
	if inside_connection != null and inside_connection == navAgent.InsideConnection:
		# still inside same connection -> no change
		return false
	if inside_connection != null and inside_connection != navAgent.InsideConnection:
		navAgent.InsideConnection = inside_connection
		navAgent.NearestCavern = nearest_cavern
		navAgent.CurrentState = NavigationCavernLocations.InsideConnection
		return true
	if inside_connection == null and navAgent.CurrentState == NavigationCavernLocations.InsideConnection:
		navAgent.InsideConnection = null
		navAgent.NearestCavern = nearest_cavern
		navAgent.CurrentState = NavigationCavernLocations.NearCavern
		return true
	if navAgent.NearestCavern != nearest_cavern:
		navAgent.InsideConnection = null
		navAgent.NearestCavern = nearest_cavern
		navAgent.CurrentState = NavigationCavernLocations.NearCavern
		return true
	if navAgent.CurrentState != NavigationCavernLocations.NearCavern:
		navAgent.CurrentState = NavigationCavernLocations.NearCavern
		return true
	return false

func find_path_to_player(monsterNavAgent:NavigationAgentData):
	if monsterNavAgent.NearestCavern == _playerNavAgent.NearestCavern:
		monsterNavAgent.NavTargetOverride._has_override = false
	else:
		var monsterCavernIndex : int = _allCaverns.find(monsterNavAgent.NearestCavern)
		var path := _cavernPathFinding.get_id_path(monsterCavernIndex, _playerCavernIndex)
		if path.size() > 1:
			monsterNavAgent.NavTargetOverride._has_override = true
			var nextCavern := _allCaverns[path[1]]
			if monsterNavAgent.CurrentState == NavigationCavernLocations.InsideConnection && \
				monsterNavAgent.InsideConnection.ToCavernRuntimeNode == nextCavern:
					monsterNavAgent.NavTargetOverride._override_position = nextCavern.global_position
					return
			var monsterLocalPos : Vector2 = monsterNavAgent.PositionProvider.get_worldPosition() - monsterNavAgent.NearestCavern.global_position
			var targetConnection : NavigationCavernConnection = monsterNavAgent.NearestCavern.get_connection_to_cavern(nextCavern)
			var connectionLineDir : Vector2 = targetConnection.RuntimeCorridorDir.orthogonal()
			var monsterPosInConnectionSpace : Vector2 = Vector2(
				connectionLineDir.dot(monsterLocalPos),
				targetConnection.RuntimeCorridorDir.dot(monsterLocalPos))
			var radiusToUse : float
			if monsterPosInConnectionSpace.y < 0:
				radiusToUse = monsterNavAgent.NearestCavern.Radius
			else:
				var factorToCenter : float = monsterPosInConnectionSpace.y / monsterNavAgent.NearestCavern.Radius
				radiusToUse = lerpf(monsterNavAgent.NearestCavern.Radius, targetConnection.CorridorWidth, factorToCenter)
			var posOnConnectionLine : float = monsterPosInConnectionSpace.x / radiusToUse
			posOnConnectionLine = 0.9 * clampf(posOnConnectionLine, -1, 1) * targetConnection.CorridorWidth / 2.0

			monsterNavAgent.NavTargetOverride._override_position = \
				monsterNavAgent.NearestCavern.global_position \
				+ targetConnection.RuntimeCorridorStartOffset * 1.1 \
				+ connectionLineDir * posOnConnectionLine
		else:
			monsterNavAgent.NavTargetOverride._has_override = false

func updateCurrentCavernScreenView(screenCenter:Vector2, maxCavernDist:float, minOuterRimDist:float):
	_currentScreenCavernView.clear()
	for cavernIndex in _allCaverns.size():
		var cavern := _allCaverns[cavernIndex]
		var distSquared : float = cavern.global_position.distance_squared_to(screenCenter)
		if distSquared > maxCavernDist*maxCavernDist:
			continue
		var dist : float = sqrt(distSquared)
		if dist + cavern.Radius < minOuterRimDist:
			continue
		var viewEntry : CavernCircularView = CavernCircularView.new()
		viewEntry.CavernCenterDist = dist
		viewEntry.CavernIndex = cavernIndex
		var halfAngleCoverage : float = atan(cavern.Radius / dist)
		var distVec : Vector2 = cavern.global_position - screenCenter
		var cavernAnglePos : float = distVec.angle()
		viewEntry.StartAngle = cavernAnglePos - halfAngleCoverage
		viewEntry.EndAngle = cavernAnglePos + halfAngleCoverage
		_currentScreenCavernView.append(viewEntry)

func getCavernAtViewAngle(viewangle:float) -> NavigationCavern:
	var closestDist : float = 9999999
	var closestCavern : NavigationCavern
	var viewangleMinusTAU := viewangle - TAU
	var viewanglePlusTAU := viewangle + TAU
	for cavernView in _currentScreenCavernView:
		var inView : bool = cavernView.StartAngle < viewangle and cavernView.EndAngle > viewangle
		inView = inView or (cavernView.StartAngle < viewangleMinusTAU and cavernView.EndAngle > viewangleMinusTAU)
		inView = inView or (cavernView.StartAngle < viewanglePlusTAU and cavernView.EndAngle > viewanglePlusTAU)
		if not inView:
			continue
		if cavernView.CavernCenterDist < closestDist:
			closestDist = cavernView.CavernCenterDist
			closestCavern = _allCaverns[cavernView.CavernIndex]
	return closestCavern

func getNearestCavernInView() -> NavigationCavern:
	var closestDist : float = 9999999
	var closestCavern : NavigationCavern
	for cavernView in _currentScreenCavernView:
		if cavernView.CavernCenterDist < closestDist:
			closestDist = cavernView.CavernCenterDist
			closestCavern = _allCaverns[cavernView.CavernIndex]
	return closestCavern
