extends Node

const REPORT_PATH = "user://detailed_balance_report.csv"

# We assume a neutral start for all tests to keep the baseline consistent.
# (You could expand this to test "Advantage State" vs "Disadvantage State" later)
const STARTING_SP = 4
const STARTING_HP = 7

func _ready():
	print("--- STARTING DETAILED BALANCE ANALYSIS ---")
	run_analysis()

func run_analysis():
	var all_actions = _load_all_actions()
	print("Loaded " + str(all_actions.size()) + " actions.")
	
	# 1. Expanded Header for Granular Data
	var headers = [
		"P1 Action", "P2 Action", "P1 Type", "P2 Type",
		"Priority Win",       # Who acted first?
		"P1 Cost", "P2 Cost", # How much they paid
		
		"P1 Raw Dmg", "P2 Raw Dmg",       # Potential Damage
		"P1 Dmg Negated", "P2 Dmg Negated", # Damage stopped by Block/Dodge/Parry
		"P1 Net Dmg", "P2 Net Dmg",       # Actual HP lost
		
		"P1 Def Value", "P2 Def Value",   # Block/Dodge amount used
		"P1 Def Wasted", "P2 Def Wasted", # Overkill defense (Efficiency metric)
		
		"P1 HP Delta", "P2 HP Delta",     # Net Health Change (Heal - Dmg)
		"P1 SP Delta", "P2 SP Delta",     # Net Stamina Change (Recover - Cost - Tiring)
		
		"Mom Shift",          # Direction of momentum
		"Tags"                # Special interactions (Reversal, Stun, etc)
	]
	
	var csv = ",".join(headers) + "\n"
	
	# 2. Simulate
	for p1_card in all_actions:
		for p2_card in all_actions:
			var row = _simulate_granular_clash(p1_card, p2_card)
			csv += row + "\n"
			
	# 3. Save
	var file = FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file:
		file.store_string(csv)
		file.close()
		print("SUCCESS! Report saved to: " + ProjectSettings.globalize_path(REPORT_PATH))
		get_tree().quit()
	else:
		printerr("Failed to save report.")

func _simulate_granular_clash(c1: ActionData, c2: ActionData) -> String:
	var tags = []
	
	# --- A. SETUP COSTS & REPEATS ---
	var p1_reps = max(1, c1.repeat_count)
	var p2_reps = max(1, c2.repeat_count)
	
	var p1_total_cost = c1.cost * p1_reps
	var p2_total_cost = c2.cost * p2_reps
	
	# --- B. DETERMINE PRIORITY (Who is "Active") ---
	# "Active" means you successfully executed your move (didn't get interrupted).
	# In a clash, the loser might still act if they are Defensive, 
	# but for this sim, we mostly care about who wins the "Clash Priority".
	var priority_winner = "DRAW"
	
	if c1.type == ActionData.Type.OFFENCE and c2.type == ActionData.Type.DEFENCE:
		priority_winner = "P1"
	elif c2.type == ActionData.Type.OFFENCE and c1.type == ActionData.Type.DEFENCE:
		priority_winner = "P2"
	elif c1.cost < c2.cost:
		priority_winner = "P1"
	elif c2.cost < c1.cost:
		priority_winner = "P2"
	
	# Assume both act simultaneously for calculation, unless interrupted logic applies.
	# (In your game, Defence cards usually happen even if they lose priority, 
	# so we will simulate BOTH cards resolving effects against each other).
	var p1_active = true
	var p2_active = true
	
	# --- C. DODGE & PARRY CHECKS (The Negation Layer) ---
	
	# P1 defending against P2
	var p1_is_dodged = (c2.dodge_value > 0 and c2.dodge_value >= p1_total_cost)
	var p1_parries = c1.is_parry
	
	# P2 defending against P1
	var p2_is_dodged = (c1.dodge_value > 0 and c1.dodge_value >= p2_total_cost)
	var p2_parries = c2.is_parry
	
	if p1_is_dodged: tags.append("P1_Dodged")
	if p2_is_dodged: tags.append("P2_Dodged")
	
	# --- D. DAMAGE & DEFENSE CALCULATION ---
	
	# P1 Attacks -> P2 Defends
	var p1_raw_dmg = c1.damage * p1_reps
	var p2_def_val = c2.block_value + c2.dodge_value # Total defensive output
	var p2_mitigated = 0
	
	if p2_is_dodged:
		# P1 dodged P2's attack? No, wait. 
		# If P2 is dodged, P2's attack fails. 
		# If P1 is dodged, P1's attack fails.
		pass
		
	if p1_is_dodged:
		# P2 Dodged P1: 100% Negation
		p2_mitigated = p1_raw_dmg
	else:
		# P2 Blocks P1
		p2_mitigated = min(p1_raw_dmg, c2.block_value) # You can only block what exists
		
	var p1_net_dmg = max(0, p1_raw_dmg - p2_mitigated)
	if c1.guard_break and c2.block_value > 0:
		p1_net_dmg = p1_raw_dmg # Ignore block
		p2_mitigated = 0
		tags.append("P1_GuardBreak")

	# P2 Attacks -> P1 Defends
	var p2_raw_dmg = c2.damage * p2_reps
	var p1_def_val = c1.block_value + c1.dodge_value
	var p1_mitigated = 0
	
	if p2_is_dodged:
		p1_mitigated = p2_raw_dmg
	else:
		p1_mitigated = min(p2_raw_dmg, c1.block_value)
		
	var p2_net_dmg = max(0, p2_raw_dmg - p1_mitigated)
	if c2.guard_break and c1.block_value > 0:
		p2_net_dmg = p2_raw_dmg
		p1_mitigated = 0
		tags.append("P2_GuardBreak")

	# --- E. EFFICIENCY METRICS (Wasted Stats) ---
	# Did P1 use a Dodge 4 on a Cost 1 move? Wasted = 3.
	var p1_def_wasted = 0
	if c1.dodge_value > 0:
		if p2_is_dodged: p1_def_wasted = max(0, c1.dodge_value - p2_total_cost)
		else: p1_def_wasted = c1.dodge_value # Failed dodge = 100% wasted
	elif c1.block_value > 0:
		p1_def_wasted = max(0, c1.block_value - p2_raw_dmg)

	var p2_def_wasted = 0
	if c2.dodge_value > 0:
		if p1_is_dodged: p2_def_wasted = max(0, c2.dodge_value - p1_total_cost)
		else: p2_def_wasted = c2.dodge_value
	elif c2.block_value > 0:
		p2_def_wasted = max(0, c2.block_value - p1_raw_dmg)

	# --- F. RESOURCE DELTAS (The "Score") ---
	
	# HP Delta = (Heals) - (Damage Taken)
	var p1_hp_delta = c1.heal_value - p2_net_dmg
	var p2_hp_delta = c2.heal_value - p1_net_dmg
	
	# SP Delta = (Recover) - (Cost) - (Tiring Taken)
	# Note: Defence cards usually get +1 Recover in game logic
	var p1_rec = c1.recover_value + (1 if c1.type == ActionData.Type.DEFENCE else 0)
	var p2_rec = c2.recover_value + (1 if c2.type == ActionData.Type.DEFENCE else 0)
	
	var p1_sp_delta = p1_rec - p1_total_cost - c2.tiring
	var p2_sp_delta = p2_rec - p2_total_cost - c1.tiring
	
	# --- G. MOMENTUM ---
	# (Includes the Parry fix)
	var p1_push = c1.momentum_gain * p1_reps
	var p2_push = c2.momentum_gain * p2_reps
	
	if p2_parries: p1_push -= c1.momentum_gain
	if p1_parries: p2_push -= c2.momentum_gain
	
	if p1_is_dodged: p1_push = 0
	if p2_is_dodged: p2_push = 0
	
	var mom_shift = p1_push - p2_push
	
	# Check Reversal
	# If Mom moves towards P1 (Positive) but P2 used Reversal?
	# (Simplified vacuum check)
	if c1.reversal and mom_shift < 0: tags.append("P1_Reversal")
	if c2.reversal and mom_shift > 0: tags.append("P2_Reversal")

	# --- H. OUTPUT ---
	var row_data = [
		c1.display_name, c2.display_name, 
		"OFF" if c1.type == 0 else "DEF", "OFF" if c2.type == 0 else "DEF",
		priority_winner,
		p1_total_cost, p2_total_cost,
		p1_raw_dmg, p2_raw_dmg,
		p2_mitigated, p1_mitigated, # Note swap: P2 mitigated P1's damage
		p1_net_dmg, p2_net_dmg,     # P1 Net = Damage P1 DEALT (Wait, no. Net Dmg usually means Dmg TAKEN in logs, but here let's stick to Dmg DEALT by P1)
		# Actually, specifically for balance, "P1 Net Dmg" usually means "Damage P1 dealt to P2".
		# Let's keep that convention.
		
		c1.block_value + c1.dodge_value, c2.block_value + c2.dodge_value,
		p1_def_wasted, p2_def_wasted,
		p1_hp_delta, p2_hp_delta,
		p1_sp_delta, p2_sp_delta,
		mom_shift,
		";".join(tags)
	]
	
	# Convert all to string
	var str_row = []
	for item in row_data: str_row.append(str(item))
	return ",".join(str_row)

# (Keep _load_all_actions and _scan_dir the same as before)
func _load_all_actions() -> Array[ActionData]:
	var actions: Array[ActionData] = []
	var path = "res://Data/Actions/"
	actions.append_array(_scan_dir(path))
	var class_folders = ["Heavy", "Patient", "Quick", "Technical"]
	for folder in class_folders:
		actions.append_array(_scan_dir(path + "Class/" + folder + "/"))
	return actions

func _scan_dir(path) -> Array[ActionData]:
	var list: Array[ActionData] = []
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file = dir.get_next()
		while file != "":
			if file.ends_with(".tres") or file.ends_with(".res"):
				var res = load(path + file)
				if res is ActionData:
					list.append(res)
			file = dir.get_next()
	return list
