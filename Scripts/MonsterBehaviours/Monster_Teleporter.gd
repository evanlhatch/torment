extends Node2D

@export_enum("Rectangular", "Circular", "Circular_Lane") var TeleporterGeometry : int = 0

@export_group("Circular Parameters")
@export var CircleRadius : float = 500

@export_group("Lane_Parameters")
@export var LaneDistance : float = 500
@export_enum("None", "NE", "NW", "SE", "SW") var LaneDirection 

const UP_TO_DIAGONAL_ANGLE = deg_to_rad(53.0)
var lane_vector : Vector2


func _enter_tree():
	match(LaneDirection):
		0: lane_vector = Vector2.ZERO
		1: lane_vector = Vector2.UP.rotated(UP_TO_DIAGONAL_ANGLE)
		2: lane_vector = Vector2.UP.rotated(-UP_TO_DIAGONAL_ANGLE)
		3: lane_vector = Vector2.DOWN.rotated(-UP_TO_DIAGONAL_ANGLE)
		4: lane_vector = Vector2.DOWN.rotated(UP_TO_DIAGONAL_ANGLE)

func _process(delta):
	var hits = []
	if TeleporterGeometry == 0:
		var minX = $West.global_position.x
		var maxX = $East.global_position.x
		var minY = $North.global_position.y
		var maxY = $South.global_position.y
		hits = Global.World.Locators.get_gameobjects_outside_rectangle(
			"Enemies", minX, maxX, minY, maxY)
		var teleportable_hits = Global.World.Locators.get_gameobjects_outside_rectangle(
			"Teleportable", minX, maxX, minY, maxY)
		hits.append_array(teleportable_hits)
	
	elif TeleporterGeometry == 1 or TeleporterGeometry == 2:
		hits = Global.World.Locators.get_gameobjects_outside_circle(
			"Enemies", global_position, CircleRadius)
		var teleportable_hits = Global.World.Locators.get_gameobjects_outside_circle(
			"Teleportable", global_position, CircleRadius)
		hits.append_array(teleportable_hits)

	if TeleporterGeometry == 0 or TeleporterGeometry == 1:
		for outsideGO in hits:
			if outsideGO.is_in_group("Disposable"):
				outsideGO.queue_free()
			else:
				var positionProvider = outsideGO.getChildNodeWithMethod("get_worldPosition")
				if positionProvider != null and positionProvider.is_in_group("Teleportable"):
					if Global.World.NavigationCaverns.world_has_navigation_caverns(): 
						var vectorToCenter : Vector2 = global_position - positionProvider.global_position
						var dirToCenter : float = vectorToCenter.angle()
						var teleportToCavern : NavigationCavern = Global.World.NavigationCaverns.getCavernAtViewAngle(dirToCenter)
						if teleportToCavern == null:
							# fallback: when there is no cavern in the opposite direction of the monster,
							# just take the closest in view...
							teleportToCavern = Global.World.NavigationCaverns.getNearestCavernInView()
						var dirToCavern : Vector2 = global_position.direction_to(teleportToCavern.global_position)
						var offsetToBackWall : Vector2 = dirToCavern.rotated(randf_range(-PI * 0.5, PI * 0.5)) * teleportToCavern.Radius * 0.8
						positionProvider.global_position = teleportToCavern.global_position + offsetToBackWall
					else:
						var vectorFromCenter = positionProvider.global_position - global_position
						positionProvider.global_position -= vectorFromCenter * 1.9
	
	elif TeleporterGeometry == 2:
		for outsideGO in hits:
			if outsideGO.is_in_group("Disposable"):
				outsideGO.queue_free()
			else:
				var positionProvider = outsideGO.getChildNodeWithMethod("get_worldPosition")
				if positionProvider != null and positionProvider.is_in_group("Teleportable"):
					var vectorFromCenter : Vector2 = positionProvider.global_position - global_position
					if vectorFromCenter.dot(lane_vector) > 0.0:
						positionProvider.global_position -= lane_vector * LaneDistance * 1.9
					else:
						positionProvider.global_position += lane_vector * LaneDistance * 1.9
