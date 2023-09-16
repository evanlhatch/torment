extends Node2D

enum Falloff
{
	Linear,
	Quadratic
}


func RadialBlast(
	blastPosition:Vector2,
	radius:float,
	force:float,
	falloff:Falloff,
	locatorPools:Array[String] = []) -> Array:

	if locatorPools == null or locatorPools.size() == 0:
		locatorPools = ["Enemies"]


	var hit_gamObjects = []
	for pool in locatorPools:
		var hits = Global.World.Locators.get_gameobjects_in_circle(
			pool, blastPosition, radius)

		for gameObject in hits:
			# make sure objects with multiple collision shaped don't get pushed twice
			if hit_gamObjects.has(gameObject): continue
			hit_gamObjects.append(gameObject)

			var physicsObject = gameObject.getChildNodeWithMethod("add_velocity")
			if !physicsObject:
				continue
			
			if physicsObject.has_method("set_pushed_counter"):
				physicsObject.set_pushed_counter(0.3)
			
			var distVec = physicsObject.global_position - blastPosition
			var dist = distVec.length_squared()
			if is_zero_approx(dist):
				continue
			
			var impulseLen = 0
			if falloff == Falloff.Linear:
				impulseLen = remap(sqrt(dist), 0, radius, force, 0)
			elif falloff == Falloff.Quadratic:
				impulseLen = remap(dist, 0, radius * radius, force, 0)
				
			impulseLen = clamp(impulseLen, 0, force)
			physicsObject.add_velocity(distVec.normalized() * impulseLen)
	return hit_gamObjects


func PushSingleObject(
	targetObject:GameObject,
	pushDirection:Vector2,
	impulse:float):
	
	var physicsObject = targetObject.getChildNodeWithMethod("add_velocity")
	if !physicsObject:
		return

	if physicsObject.has_method("set_pushed_counter"):
		physicsObject.set_pushed_counter(0.3)

	physicsObject.add_velocity(pushDirection.normalized() * impulse)


func TryToApplyKnockback(
	targetObject:GameObject,
	knockbackPower:float,
	pushDirection:Vector2,
	impulse:float) -> bool:

	var physicsObject = targetObject.getChildNodeWithMethod("add_velocity")
	if !physicsObject:
		return false

	# only apply to physicsObjects that handle knockback and that don't resist our power!
	if not physicsObject.has_method("can_resist_knockback") or physicsObject.can_resist_knockback(knockbackPower):
		return false

	if physicsObject.has_method("set_pushed_counter"):
		physicsObject.set_pushed_counter(0.25)

	physicsObject.add_velocity(pushDirection.normalized() * impulse)

	return true
