class_name AchievementCatalog
extends RefCounted
## Static catalog of all 18 CLASH Meta-Progression Achievements & Cosmetic Titles.

const CATEGORY_COMBAT: String = "Combat Mastery"
const CATEGORY_CIRCUIT: String = "The Circuit"
const CATEGORY_CHALLENGES: String = "Boss & Sponsor Challenges"
const CATEGORY_COLLECTION: String = "Dojo & Collection"


static func get_all() -> Array[Dictionary]:
	return [
		# --- COMBAT MASTERY ---
		{
			"id": "first_blood",
			"name": "First Blood",
			"description": "Win your first match in any mode.",
			"category": CATEGORY_COMBAT,
			"token_reward": 5,
			"title_reward": "Contender",
			"type": "career_stat",
			"stat_key": "wins",
			"target": 1,
		},
		{
			"id": "untouchable",
			"name": "Untouchable",
			"description": "Win a match without taking a single point of HP damage.",
			"category": CATEGORY_COMBAT,
			"token_reward": 10,
			"title_reward": "Untouchable",
			"type": "career_stat",
			"stat_key": "flawless_wins",
			"target": 1,
		},
		{
			"id": "iron_reflexes",
			"name": "Iron Reflexes",
			"description": "Land 10 successful Parries across your career.",
			"category": CATEGORY_COMBAT,
			"token_reward": 10,
			"title_reward": "Iron Reflex",
			"type": "career_stat",
			"stat_key": "parries",
			"target": 10,
		},
		{
			"id": "phantom_step",
			"name": "Phantom Step",
			"description": "Evade 10 incoming attacks with Dodge across your career.",
			"category": CATEGORY_COMBAT,
			"token_reward": 10,
			"title_reward": "Ghost Step",
			"type": "career_stat",
			"stat_key": "dodges",
			"target": 10,
		},
		{
			"id": "turn_the_tables",
			"name": "Turn the Tables",
			"description": "Steal Offence with Reversal 10 times across your career.",
			"category": CATEGORY_COMBAT,
			"token_reward": 10,
			"title_reward": "Counter-Striker",
			"type": "career_stat",
			"stat_key": "reversals",
			"target": 10,
		},
		{
			"id": "shatterpoint",
			"name": "Shatterpoint",
			"description": "Shatter enemy Blocks with Guard Break 15 times.",
			"category": CATEGORY_COMBAT,
			"token_reward": 10,
			"title_reward": "",
			"type": "career_stat",
			"stat_key": "guard_breaks",
			"target": 15,
		},
		{
			"id": "wallbreaker",
			"name": "Cornered",
			"description": "Inflict 5 Wall Crushes on pinned opponents.",
			"category": CATEGORY_COMBAT,
			"token_reward": 10,
			"title_reward": "Wallbreaker",
			"type": "career_stat",
			"stat_key": "wall_crushes_inflicted",
			"target": 5,
		},
		{
			"id": "ultimate_finisher",
			"name": "Ultimate Finisher",
			"description": "Win a match on a clash where you unleashed a Super.",
			"category": CATEGORY_COMBAT,
			"token_reward": 10,
			"title_reward": "Showstopper",
			"type": "career_stat",
			"stat_key": "super_finishes",
			"target": 1,
		},
		{
			"id": "relentless_combo",
			"name": "Unstoppable Flow",
			"description": "Chain a combo of at least 5 hits in a single match.",
			"category": CATEGORY_COMBAT,
			"token_reward": 10,
			"title_reward": "",
			"type": "career_stat",
			"stat_key": "max_combo",
			"target": 5,
		},

		# --- THE CIRCUIT ---
		{
			"id": "league_1_champ",
			"name": "League Champion",
			"description": "Conquer the League 1 Finals in The Circuit.",
			"category": CATEGORY_CIRCUIT,
			"token_reward": 15,
			"title_reward": "Circuit Champion",
			"type": "career_stat",
			"stat_key": "highest_league",
			"target": 1,
		},
		{
			"id": "league_2_champ",
			"name": "Double Crown",
			"description": "Conquer League 2 in The Circuit.",
			"category": CATEGORY_CIRCUIT,
			"token_reward": 20,
			"title_reward": "Circuit Legend",
			"type": "career_stat",
			"stat_key": "highest_league",
			"target": 2,
		},
		{
			"id": "steady_footing",
			"name": "Steady Footing",
			"description": "Win a Circuit League without suffering a single Wall Crush.",
			"category": CATEGORY_CIRCUIT,
			"token_reward": 20,
			"title_reward": "Unbreakable",
			"type": "career_stat",
			"stat_key": "clean_wall_leagues",
			"target": 1,
		},
		{
			"id": "fourfold_master",
			"name": "Fourfold Mastery",
			"description": "Win a Circuit League with all 4 fighter classes.",
			"category": CATEGORY_CIRCUIT,
			"token_reward": 30,
			"title_reward": "Fourfold Master",
			"type": "class_leagues",
			"stat_key": "league_wins_by_class",
			"target": 4,
		},

		# --- BOSS & SPONSOR CHALLENGES ---
		{
			"id": "giant_slayer",
			"name": "Double Trouble",
			"description": "Defeat a Double-Modifier Finals Boss in League 2+.",
			"category": CATEGORY_CHALLENGES,
			"token_reward": 25,
			"title_reward": "Giant Slayer",
			"type": "career_stat",
			"stat_key": "double_boss_wins",
			"target": 1,
		},
		{
			"id": "grudge_settled",
			"name": "Grudge Settled",
			"description": "Defeat your Corporate Sponsor's Rival in a Grudge Match.",
			"category": CATEGORY_CHALLENGES,
			"token_reward": 15,
			"title_reward": "Corporate Shark",
			"type": "career_stat",
			"stat_key": "rival_wins",
			"target": 1,
		},

		# --- DOJO & COLLECTION ---
		{
			"id": "dojo_graduate",
			"name": "Dojo Graduate",
			"description": "Clear 10 Dojo Trials.",
			"category": CATEGORY_COLLECTION,
			"token_reward": 10,
			"title_reward": "Dojo Disciple",
			"type": "trials_count",
			"stat_key": "",
			"target": 10,
		},
		{
			"id": "dojo_grandmaster",
			"name": "Dojo Grandmaster",
			"description": "Clear all 28 Dojo Trials.",
			"category": CATEGORY_COLLECTION,
			"token_reward": 25,
			"title_reward": "Dojo Grandmaster",
			"type": "trials_count",
			"stat_key": "",
			"target": 28,
		},
		{
			"id": "custom_crafter",
			"name": "Custom Crafter",
			"description": "Build and save your first Custom Fighter for Quick Match.",
			"category": CATEGORY_COLLECTION,
			"token_reward": 5,
			"title_reward": "Architect",
			"type": "custom_fighters_count",
			"stat_key": "",
			"target": 1,
		},
	]


static func get_by_id(ach_id: String) -> Dictionary:
	for a: Dictionary in get_all():
		if str(a.get("id", "")) == ach_id:
			return a
	return {}


static func get_unlocked_titles(meta: GlobalSaveData) -> Array[String]:
	var titles: Array[String] = []
	if meta == null:
		return titles
	for a: Dictionary in get_all():
		var t: String = str(a.get("title_reward", ""))
		if t != "" and str(a.get("id", "")) in meta.unlocked_achievements:
			if t not in titles:
				titles.append(t)
	return titles
