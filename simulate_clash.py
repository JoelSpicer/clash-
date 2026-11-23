import random
from collections import defaultdict
import statistics

# =====================================================================
# 1. CLASH! COMBAT DEFINITIONS (Plug your exact GDScript values here)
# =====================================================================
STARTING_HP = 100
MOMENTUM_SIZES = [3, 5, 7, 10]  # Testing different Momentum cap sizes
NUM_MATCHES_PER_CAP = 750       # 750 * 4 caps = 3,000 total encounters
MAX_TURNS = 50                  # Safeguard against infinite defensive loops

# Action Archetypes: (type, base_dmg, block, mom_gain, mom_cost, status_applied)
# Types: "OFFENCE", "DEFENCE", "UTILITY", "FINISHER"
ACTIONS = {
    "Light_Strike":   {"type": "OFFENCE",  "dmg": 12, "block": 0,  "mom_gain": 1, "mom_cost": 0, "status": None},
    "Heavy_Smash":    {"type": "OFFENCE",  "dmg": 25, "block": 0,  "mom_gain": 2, "mom_cost": 0, "status": "Self_Opening"},
    "Precision_Cut":  {"type": "OFFENCE",  "dmg": 15, "block": 0,  "mom_gain": 1, "mom_cost": 1, "status": "Injured"},
    "Feint_Jab":      {"type": "OFFENCE",  "dmg": 8,  "block": 0,  "mom_gain": 1, "mom_cost": 0, "status": "Opportunity"},
    "Basic_Guard":    {"type": "DEFENCE",  "dmg": 0,  "block": 18, "mom_gain": 1, "mom_cost": 0, "status": None},
    "Parry_Stance":   {"type": "DEFENCE",  "dmg": 5,  "block": 12, "mom_gain": 2, "mom_cost": 0, "status": "Target_Opening"},
    "Bide_Focus":     {"type": "UTILITY",  "dmg": 0,  "block": 8,  "mom_gain": 2, "mom_cost": 0, "status": "Bide"},
    "Clash_Finisher": {"type": "FINISHER", "dmg": 45, "block": 0,  "mom_gain": 0, "mom_cost": 3, "status": "Injured"},
}

class FighterState:
    def __init__(self, max_momentum: int):
        self.hp: float = STARTING_HP
        self.momentum: int = 0
        self.max_momentum: int = max_momentum
        self.statuses: dict = {
            "Bide": False,         # Stores power: 1.5x damage on next offensive hit
            "Injured": 0,          # Bleed/Weaken: deals 4 dmg per turn, reduces outgoing dmg by 20%
            "Opening": False,      # Vulnerable: takes 1.4x incoming damage
            "Opportunity": False,  # Next action generates +1 bonus momentum & ignores 50% block
        }
        self.actions_used = defaultdict(int)

    def add_momentum(self, amount: int):
        self.momentum = max(0, min(self.max_momentum, self.momentum + amount))


# =====================================================================
# 2. SIMULTANEOUS TURN RESOLUTION ENGINE
# =====================================================================
def select_action(fighter: FighterState) -> str:
    """Selects a valid action (ensuring sufficient Momentum for cost)."""
    valid = [name for name, data in ACTIONS.items() if fighter.momentum >= data["mom_cost"]]
    return random.choice(valid)

def resolve_turn(p1: FighterState, p2: FighterState, act1_name: str, act2_name: str):
    a1, a2 = ACTIONS[act1_name], ACTIONS[act2_name]
    p1.actions_used[act1_name] += 1
    p2.actions_used[act2_name] += 1

    # Pay Momentum costs
    p1.add_momentum(-a1["mom_cost"])
    p2.add_momentum(-a2["mom_cost"])

    # Calculate Raw Outgoing Damage & Block
    for attacker, defender, act, def_act in [(p1, p2, a1, a2), (p2, p1, a2, a1)]:
        dmg = float(act["dmg"])
        block = float(def_act["block"])

        # Apply Attacker Status Modifiers
        if dmg > 0:
            if attacker.statuses["Bide"]:
                dmg *= 1.5
                attacker.statuses["Bide"] = False
            if attacker.statuses["Injured"] > 0:
                dmg *= 0.8
            if defender.statuses["Opening"]:
                dmg *= 1.4
                defender.statuses["Opening"] = False

        # Opportunity pierces block and grants bonus momentum
        if attacker.statuses["Opportunity"]:
            block *= 0.5
            attacker.add_momentum(1)
            attacker.statuses["Opportunity"] = False

        # Apply Damage vs Block
        net_dmg = max(0.0, dmg - block)
        defender.hp -= net_dmg

        # Momentum Gain (scaled slightly by current momentum advantage)
        attacker.add_momentum(act["mom_gain"])

        # Status Application
        st = act["status"]
        if st == "Bide":
            attacker.statuses["Bide"] = True
        elif st == "Opportunity":
            attacker.statuses["Opportunity"] = True
        elif st == "Self_Opening":
            attacker.statuses["Opening"] = True
        elif st == "Target_Opening" and act["type"] == "DEFENCE" and def_act["type"] == "OFFENCE":
            # Parry only triggers Opening if opponent attacked
            defender.statuses["Opening"] = True
        elif st == "Injured" and net_dmg > 0:
            defender.statuses["Injured"] = 2

    # End-of-Turn Status Tick (Injured DoT)
    for p in (p1, p2):
        if p.statuses["Injured"] > 0:
            p.hp -= 4.0
            p.statuses["Injured"] -= 1


# =====================================================================
# 3. MONTE CARLO RUNNER (3,000 MATCHES)
# =====================================================================
def run_simulations():
    action_wins = defaultdict(int)
    action_Appearances = defaultdict(int)
    cap_metrics = {}

    for cap in MOMENTUM_SIZES:
        lengths = []
        first_mom_lead_wins = 0
        first_mom_lead_total = 0
        cap_reached_wins = 0
        cap_reached_total = 0

        for _ in range(NUM_MATCHES_PER_CAP):
            p1, p2 = FighterState(cap), FighterState(cap)
            first_leader = None
            first_cap_reacher = None
            turns = 0

            while p1.hp > 0 and p2.hp > 0 and turns < MAX_TURNS:
                turns += 1
                act1 = select_action(p1)
                act2 = select_action(p2)
                resolve_turn(p1, p2, act1, act2)

                # Track who gains the first momentum advantage
                if first_leader is None and p1.momentum != p2.momentum:
                    first_leader = 1 if p1.momentum > p2.momentum else 2

                # Track who hits Max Momentum cap first
                if first_cap_reacher is None:
                    if p1.momentum == cap and p2.momentum < cap:
                        first_cap_reacher = 1
                    elif p2.momentum == cap and p1.momentum < cap:
                        first_cap_reacher = 2

            lengths.append(turns)
            winner = 1 if p1.hp > p2.hp else (2 if p2.hp > p1.hp else 0)

            if winner in (1, 2):
                win_player = p1 if winner == 1 else p2
                lose_player = p2 if winner == 1 else p1
                for a_name, count in win_player.actions_used.items():
                    action_wins[a_name] += count
                    action_Appearances[a_name] += count
                for a_name, count in lose_player.actions_used.items():
                    action_Appearances[a_name] += count

                if first_leader is not None:
                    first_mom_lead_total += 1
                    if first_leader == winner:
                        first_mom_lead_wins += 1

                if first_cap_reacher is not None:
                    cap_reached_total += 1
                    if first_cap_reacher == winner:
                        cap_reached_wins += 1

        cap_metrics[cap] = {
            "avg_turns": round(statistics.mean(lengths), 2),
            "median_turns": statistics.median(lengths),
            "min_turns": min(lengths),
            "max_turns": max(lengths),
            "first_lead_win_rate": round((first_mom_lead_wins / max(1, first_mom_lead_total)) * 100, 1),
            "max_cap_snowball_rate": round((cap_reached_wins / max(1, cap_reached_total)) * 100, 1),
        }

    # Print Report
    print("=== MOMENTUM CAP & SNOWBALL ANALYSIS (3,000 ENCOUNTERS) ===")
    for cap, data in cap_metrics.items():
        print(f"Max Momentum {cap:2d} | Avg Turns: {data['avg_turns']:5.2f} (Min {data['min_turns']}, Max {data['max_turns']}) "
              f"| Turn-1 Lead Win%: {data['first_lead_win_rate']}% | Hit-Cap-First Win%: {data['max_cap_snowball_rate']}%")

    print("\n=== ACTION WIN-CONTRIBUTION & OUTLIER RATES ===")
    for act_name in sorted(ACTIONS.keys()):
        total = action_Appearances[act_name]
        win_pct = (action_wins[act_name] / max(1, total)) * 100
        print(f"{act_name:16s} | Total Uses: {total:5d} | Win Contribution: {win_pct:5.2f}%")

if __name__ == "__main__":
    run_simulations()