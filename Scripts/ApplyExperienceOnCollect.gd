extends GameObjectComponent

@export var ProbabilityToApply : float = 1
@export var ExperienceAmount : int = 1
@export var AudioFX : AudioFXResource
@export var SoundVolume : float = -16.0

@export_group("Consolidation Parameters")
@export var ConsolidationRadius : float = 36.0
@export var ConsolidationAmountThreshold : int = 20
@export var ConsolidationLocatorPool : String = "Collectable"
@export var ConsolidatedObjectScene : PackedScene
@export var Consolidable : bool = true

func _ready():
	initGameObjectComponent()
	_gameObject.connectToSignal("Collected", addExperience)
	if Consolidable: try_to_consolidate()

func addExperience(toNode:GameObject):
	if ProbabilityToApply >= 1 or randf() < ProbabilityToApply:
		if toNode == Global.World.Player:
			Global.World.addExperience(ExperienceAmount)
			var addPitch = clamp(inverse_lerp(
				Global.World.ExperienceThresholdPrev, Global.World.ExperienceThreshold, Global.World.Experience),
				0.0,1.0) * 0.8
			FxAudioPlayer.play_sound_mono(AudioFX, false, false, SoundVolume, addPitch)

func get_experienceValue() -> int:
	return ExperienceAmount

func set_experienceValue(new_xp_value:int):
	ExperienceAmount = new_xp_value

func try_to_consolidate():
	await get_tree().process_frame
	var hits = Global.World.Locators.get_gameobjects_in_circle(
		ConsolidationLocatorPool,
		get_gameobjectWorldPosition(),
		ConsolidationRadius)

	if len(hits) < ConsolidationAmountThreshold:
		return

	var consolidableGameObject = []
	var experienceGetters = []
	for go in hits:
		if go.is_queued_for_deletion(): continue
		var xp_getter = go.getChildNodeWithMethod("get_experienceValue")
		if xp_getter and xp_getter.Consolidable:
			consolidableGameObject.push_back(go)
			experienceGetters.push_back(xp_getter)

	if len(consolidableGameObject) < ConsolidationAmountThreshold:
		return

	var heap = ConsolidatedObjectScene.instantiate()
	heap.global_position = get_gameobjectWorldPosition()
	Global.attach_toWorld(heap)
	var heap_xp_setter = heap.getChildNodeWithMethod("set_experienceValue")
	for i in range(len(experienceGetters)):
		heap_xp_setter.set_experienceValue(
			heap_xp_setter.get_experienceValue() +
			experienceGetters[i].get_experienceValue())
		experienceGetters[i].Consolidable = false
		# the old xp collectable has to be removed from the collectable
		# manager (can't do that on its own, since there is no "on_destroy")
		Global.World.Collectables.UnregisterCollectable(consolidableGameObject[i])
		consolidableGameObject[i].queue_free()
	heap_xp_setter.set_experienceValue(heap_xp_setter.get_experienceValue() + get_experienceValue())
	Consolidable = false
	_gameObject.queue_free()
