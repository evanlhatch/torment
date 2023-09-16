extends Node

const GUARANTEE_CYCLES : float = 2.0 #max. of cycles before an item is guaranteed to be picked
const CHANCES_BASE : float = 100.0 #the smaller this number the stronger chance shifting applies


@export var base_item : PackedScene
@export var pickup_items : Array[PickupDistributionItemResource]

var picks : Array[int] = []
var guaranteed_pick : Array[int] = []

var items : Array[PackedScene]
var chances : Array[float]

func _ready():
	await Global.WorldReady
	set_item_chances(pickup_items)
	picks.resize(items.size())
	guaranteed_pick.resize(items.size())
	for n in len(chances):
		picks[n] = 0
		guaranteed_pick[n] = floori(max(len(guaranteed_pick) * GUARANTEE_CYCLES, floori(GUARANTEE_CYCLES / chances[n])))
	

func set_item_chances(new_items : Array[PickupDistributionItemResource]):
	chances = []
	items = []
	var base_chance : float = 1.0
	for new_item in new_items:
		var activatedByTag : String = new_item.ActivatedByTag
		if not activatedByTag.is_empty() and not Global.World.Tags.isTagActive(activatedByTag):
			continue
		items.append(new_item.ItemScene)
		chances.append(new_item.PickChance)
		
		base_chance -= new_item.PickChance
	if base_chance < 0.0:
		print("Chances exceed 100%")
		for n in len(chances):
			chances[n] = chances[n]/(1.0-base_chance)
		return
	chances.push_front(base_chance)
	items.push_front(base_item)


func pick_item() -> PackedScene:
	for n in len(guaranteed_pick):
		if guaranteed_pick[n] <= 0:
			picks[n] += 1
			guaranteed_pick[n] = floori(max(len(guaranteed_pick) * GUARANTEE_CYCLES, floori(GUARANTEE_CYCLES / chances[n])))
			return items[n]

	var temp_chances : Array[float] = get_temp_chances()
	var random_number = randf()
	for n in len(temp_chances):
		random_number -= temp_chances[n]
		if random_number <= 0.0:
			picks[n] += 1
			for i in len(guaranteed_pick):
				guaranteed_pick[i] -= 1
			guaranteed_pick[n] = floori(max(len(guaranteed_pick) * GUARANTEE_CYCLES, floori(GUARANTEE_CYCLES / chances[n])))
			return items[n]
	return items[0]


func get_temp_chances() -> Array[float]:
	var temp_chances : Array[float] = []
	var total_chances : float = 0.0
	for n in len(picks):
		temp_chances.append(picks[n]/CHANCES_BASE*chances[n])
		total_chances += temp_chances[n]
	for n in len(temp_chances):
		temp_chances[n] = (chances[n] * total_chances) - temp_chances[n] + chances[n]
	return temp_chances

