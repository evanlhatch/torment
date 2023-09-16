extends GameObjectComponent

@export_flags_2d_physics var CollisionMask : int
@export var PushSpeed : float = 10.0

func _ready():
	initGameObjectComponent()

func _physics_process(delta):
	if not is_instance_valid(Global.World.Player):
		return
	var space_state = _gameObject.get_world_2d().direct_space_state
	var params = PhysicsPointQueryParameters2D.new()
	params.collision_mask = CollisionMask
	params.position = _gameObject.global_position
	var collisions = space_state.intersect_point(params)
	if len(collisions) > 0:
		var playerPos = Global.World.Player.getChildNodeWithMethod("get_worldPosition")
		var dir_to_player : Vector2 = playerPos.get_worldPosition() - _gameObject.global_position
		if dir_to_player.length_squared() < 1024: return
		_gameObject.global_position += dir_to_player.normalized() * PushSpeed
