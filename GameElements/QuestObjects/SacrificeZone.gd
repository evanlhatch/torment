extends Node2D

@export var SacrificeCount : int = 100
@export var Radius : int = 120

signal SacrificeEvent(position:Vector2)

func _ready():
	if not Global.is_world_ready():
		await Global.WorldReady
	Global.World.connect("DeathEvent", _on_death_event)
	set_radius(Radius)

func _on_death_event(deadObject:GameObject, _killedBy:GameObject):
	if not is_visible_in_tree(): return
	var death_position_provider = deadObject.getChildNodeWithMethod("get_worldPosition")
	if death_position_provider == null: return
	var sacrifice_position = death_position_provider.get_worldPosition()
	if Geometry2D.is_point_in_circle(
		sacrifice_position,
		global_position, Radius):
		SacrificeEvent.emit(sacrifice_position)
		SacrificeCount -= 1
		if SacrificeCount <= 0: queue_free()

func set_radius(radius : int):
	Radius = radius
	$GPUParticles2D.process_material.emission_ring_radius = radius - 4
	$GPUParticles2D.process_material.emission_ring_inner_radius = radius - 4
