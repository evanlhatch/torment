extends AnimatedSprite2D

@export var destroyAnimation : String = "break"
@export var FlashIntensity : float = 1.0
@export var DirectionalDestruction : bool = false

var remaining_flash_frames : int

func _ready():
	material = material.duplicate()
	var gameObject = Global.get_gameObject_in_parents(self)
	gameObject.connectToSignal("ReceivedDamage", on_damage_received)
	gameObject.connectToSignal("Killed", on_killed)

func on_damage_received(_amount : int, _source : Node, _weapon_index : int):
	var needs_timer : bool = remaining_flash_frames == 0
	remaining_flash_frames = 4
	if needs_timer:
		async_flash()

func on_killed(killedBy:Node):
	var temp_position = global_position
	get_parent().remove_child(self)
	global_position = temp_position
	Global.attach_toWorld(self)
	connect("animation_finished", on_break_animation_finished)
	connect("animation_looped", on_break_animation_finished)
	if DirectionalDestruction:
		var dir = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
		if killedBy != null:
			var position_provider = killedBy.getChildNodeWithMethod("get_worldPosition")
			if position_provider != null:
				dir = (position_provider.get_worldPosition() - global_position).normalized()
		play("%s_%s" % [destroyAnimation, DirectionsUtil.get_direction_string_from_vector(dir, true)])
	else:
		play(destroyAnimation)

func async_flash():
	material.set_shader_parameter("flash_modifier", FlashIntensity * Global.FlashModulation)

	while remaining_flash_frames > 0:
		remaining_flash_frames -= 1
		await get_tree().process_frame
	
	material.set_shader_parameter("flash_modifier", 0)
		

func on_break_animation_finished():
	queue_free()
