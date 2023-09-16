extends PointLight2D

func _ready() -> void:
	if not Global.is_world_ready():
		await Global.WorldReady
	energy = Global.World.PlayerSelfLightEnergy
