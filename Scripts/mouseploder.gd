extends Area2D

func _input(event):
	if event is InputEventMouseButton and event.pressed:
		var overlappingBodies = get_overlapping_bodies()
		for body in overlappingBodies:
			if !body.has_method("add_velocity"):
				continue
			var distVec = body.global_position - global_position
			var dist = distVec.length_squared()
			var impulseLen = remap(dist, 0, 80*80, 500, 0)
			impulseLen = clamp(impulseLen, 0, 500)
			body.add_velocity(distVec.normalized() * impulseLen)

func _process(delta):
	set_position(get_global_mouse_position())

