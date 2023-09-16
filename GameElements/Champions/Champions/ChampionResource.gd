extends Resource

class_name ChampionResource

const HEALTH_DIFFICULTY_MULTIPLIER : float = 1.0
const DAMAGE_DIFFICULTY_MULTIPLIER : float = 0.1
const HEALTH_BAR_SCENE_PATH : String = "res://UI/BossHealthBar.tscn"

@export var BaseMonsterScene : PackedScene
@export var BaseHealth : float = 5000
@export var WorldHealthMultiplier : float = 1.0
@export var DamageMultiplier : float = 1.5
@export var ScaleMultiplier : float = 1.3
@export var MinDifficulty : float = 0
@export var SpawnProbability : float = 0.3
@export var RequiredTag : String = ""

func SpawnChampion(difficulty:float) -> GameObject:
	var spawned : GameObject = BaseMonsterScene.instantiate()
	var healthBuffAmount = BaseHealth + Global.World.getWorldStrength() * WorldHealthMultiplier
	var healthModifier := Modifier.create("MaxHealth", spawned)
	healthModifier.setAdditiveMod(healthBuffAmount * HEALTH_DIFFICULTY_MULTIPLIER)
	# so that the modifier (RefCounted), doesn't get destroyed immediately:
	spawned.set_meta("champion_health_modifier", healthModifier)
	spawned.triggerModifierUpdated("MaxHealth")
	
	if DamageMultiplier != 1.0 or difficulty != 1.0:
		var modifier := Modifier.create("Damage", spawned)
		modifier.setMultiplierMod(DamageMultiplier + DamageMultiplier * (difficulty - 1.0) * DAMAGE_DIFFICULTY_MULTIPLIER)
		# so that the modifier (RefCounted), doesn't get destroyed immediately:
		spawned.set_meta("champion_damage_modifier", modifier)
		spawned.triggerModifierUpdated("Damage")
	var health_bar : Node = load(HEALTH_BAR_SCENE_PATH).instantiate()
	spawned.add_child(health_bar)
	
	Global.attach_toWorld(spawned, false)
	
	var nodes_with_difficulty : Array
	spawned.getChildNodesWithMethod("set_difficulty", nodes_with_difficulty)
	for nodeWithDifficulty in nodes_with_difficulty:
		nodeWithDifficulty.set_difficulty(difficulty, 1)
	
	var spriteAnimControl : Node = spawned.getChildNodeWithMethod("set_sprite_animation_state")
	if spriteAnimControl != null:
		spriteAnimControl.set_outline(Color.ORANGE)
		spriteAnimControl.scale *= ScaleMultiplier
	
	spawned.add_to_group("Champion")	
	if Global.is_world_ready():
		Global.World.emit_signal("EnemyAppeared", spawned)

	return spawned



func choose_this_champion(difficulty: float) -> bool:
	if RequiredTag != "" and not Global.World.Tags.isTagActive(RequiredTag):
		return false
	if difficulty < MinDifficulty:
		return false
	return randf() < SpawnProbability