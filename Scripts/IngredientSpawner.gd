extends Node

@export var CupbearerQuestID : String = "q_Viaduct_Cupbearer_1"
@export var IngredientScenesNormal : Array[PackedScene]
@export var IngredientScenesAgony : Array[PackedScene]
@export var MinSpawnDist : float = 5500
@export var MaxSpawnDist : float = 6800

@export_group("Level Geometry Exceptions")
@export var SpawnOnViaduct : bool = false
@export var ViaductDirection : Vector2 = Vector2(84, -64)

var spawned_ingredients : Array[GameObject]

func _ready():
	if not Global.is_world_ready():
		await Global.WorldReady

	var IngredientScenes = IngredientScenesNormal
	if Global.World.TormentRank.enable_torment_rank:
		IngredientScenes = IngredientScenesAgony

	if IngredientScenes.size() < 1: return

	if not Global.QuestPool.is_quest_complete(CupbearerQuestID):
		queue_free()
		return

	if Global.World.IngredientSpawners == null:
		Global.World.IngredientSpawners = []
	Global.World.IngredientSpawners.append(self)

	spawned_ingredients = []
	var start_direction = Vector2(randf(), randf()).normalized()
	var angle_increment = (2.0 * PI) / float(len(IngredientScenes))

	if SpawnOnViaduct:
		start_direction = ViaductDirection.normalized()
		angle_increment = PI

	for ingredient_scene in IngredientScenes:
		var ingredient : GameObject = ingredient_scene.instantiate()
		ingredient.global_position = start_direction * randf_range(MinSpawnDist, MaxSpawnDist)
		Global.attach_toWorld(ingredient, false)

		spawned_ingredients.append(ingredient)
		start_direction = start_direction.rotated(angle_increment)

func get_world_ingredients() -> Array[GameObject]:
	return spawned_ingredients
