extends RefCounted
## Battle Engine - Combat calculations and battle simulation
## Used by game_manager for combat resolution

class_name BattleEngine

# --- Combat Formula ---
# Power = Σ(unitBase × terrainBonus × waveMultiplier) × weatherEffect × moraleMultiplier

static func calculate_unit_power(
	troop_type: String,
	count: int,
	terrain: String,
	weather: String,
	is_night: bool,
	commander_bonus: float,
	attack_tech_bonus: float,
	morale: int
) -> float:
	var gm = Engine.get_main_loop().root.get_node_or_null("/root/game_manager")
	if not gm:
		return 0.0

	var tdata: Dictionary = gm.troop_types.get(troop_type, {})
	if tdata.is_empty():
		return 0.0

	var base_attack: float = float(tdata.get("attack", 0))
	var unit_count: float = float(count)

	# Terrain multiplier
	var terrain_key: String = terrain + "_bonus"
	var terrain_mult: float = float(tdata.get(terrain_key, 1.0))

	# Weather effect
	var weather_key: String = weather + "_bonus"
	var weather_mult: float = float(tdata.get(weather_key, 1.0))

	# Commander bonus
	var cmd_mult: float = 1.0 + commander_bonus + attack_tech_bonus

	# Morale multiplier (0-100 scale -> 0.5 to 1.5)
	var morale_mult: float = 0.5 + (float(morale) / 100.0)

	# Night penalty
	var night_mult: float = 1.0
	if is_night:
		night_mult = 0.85

	return base_attack * unit_count * terrain_mult * weather_mult * cmd_mult * morale_mult * night_mult


static func calculate_unit_defense(
	troop_type: String,
	count: int,
	commander_bonus: float,
	defense_tech_bonus: float
) -> float:
	var gm = Engine.get_main_loop().root.get_node_or_null("/root/game_manager")
	if not gm:
		return 0.0

	var tdata: Dictionary = gm.troop_types.get(troop_type, {})
	if tdata.is_empty():
		return 0.0

	var base_def: float = float(tdata.get("defense", 0))
	var unit_count: float = float(count)
	var def_mult: float = 1.0 + commander_bonus + defense_tech_bonus

	return base_def * unit_count * def_mult


static func simulate_tick(
	player_power: float,
	player_defense: float,
	enemy_power: float,
	delta: float
) -> Dictionary:
	var player_damage: float = player_power * delta * 0.1
	var raw_enemy_damage: float = enemy_power * delta * 0.05
	var def_reduction: float = player_defense * 0.01 * delta
	var enemy_damage: float = maxf(raw_enemy_damage - def_reduction, raw_enemy_damage * 0.2)

	return {
		"player_damage_dealt": player_damage,
		"enemy_damage_dealt": enemy_damage,
	}


static func calculate_battle_rewards(enemy_level: int) -> Dictionary:
	return {
		"scrap": 50 * enemy_level,
		"fuel": 20 * enemy_level,
		"intel": 10 * enemy_level,
		"morale": 5,
	}


static func get_tactic_effect(tactic_id: String, enemy_hp: float, player_max_hp: float) -> Dictionary:
	match tactic_id:
		"smoke_screen":
			return {
				"enemy_damage": 0.0,
				"player_heal": player_max_hp * 0.15,
				"description": "ستارة دخان! تقليل ضرر العدو!"
			}
		"air_support":
			return {
				"enemy_damage": enemy_hp * 0.30,
				"player_heal": 0.0,
				"description": "دعم جوي! ضربة جوية قوية!"
			}
		"retreat":
			return {
				"enemy_damage": 0.0,
				"player_heal": 0.0,
				"description": "انسحاب استراتيجي"
			}
		_:
			return {"enemy_damage": 0.0, "player_heal": 0.0, "description": ""}
