extends Node
## ═══════════════════════════════════════════════════════════════
## محرك اللعبة المركزي — قبضة الجنرال
## يحتوي: الموارد، المنشآت، القوات، المعارك، الخريطة، البحث
## ═══════════════════════════════════════════════════════════════

# ─── إشارات ───
signal resources_changed
signal buildings_changed
signal troops_changed
signal battle_started
signal battle_updated(data: Dictionary)
signal battle_ended(won: bool, loot: Dictionary)
signal map_updated
signal research_progress_changed(tech_id: String, progress: float)
signal research_completed(tech_id: String)
signal screen_changed(screen: String)

# ─── ثوابت الألوان ───
const COLOR_BG := Color(0.02, 0.03, 0.06, 1.0)
const COLOR_GOLD := Color(0.788, 0.635, 0.153, 1.0)
const COLOR_RED := Color(0.937, 0.267, 0.267, 1.0)
const COLOR_BLUE := Color(0.251, 0.627, 0.878, 1.0)
const COLOR_ORANGE := Color(0.878, 0.439, 0.125, 1.0)
const COLOR_GREEN := Color(0.2, 0.7, 0.3, 1.0)
const COLOR_DARK_PANEL := Color(0.05, 0.08, 0.16, 0.9)

# ─── الموارد ───
var scrap: int = 500:
	set(v):
		scrap = v
		resources_changed.emit()

var fuel: int = 300:
	set(v):
		fuel = v
		resources_changed.emit()

var intel: int = 100:
	set(v):
		intel = v
		resources_changed.emit()

var last_online_time: int = 0

# ─── الشاشة الحالية ───
var current_screen: String = "war_room":
	set(v):
		current_screen = v
		screen_changed.emit(v)

# ─── أنواع التضاريس ───
enum Terrain { PLAINS, FOREST, MOUNTAIN, DESERT, URBAN }
var terrain_names: Dictionary = {
	Terrain.PLAINS: "سهل", Terrain.FOREST: "غابة",
	Terrain.MOUNTAIN: "جبل", Terrain.DESERT: "صحراء", Terrain.URBAN: "حضري"
}
var terrain_defense: Dictionary = {
	Terrain.PLAINS: 1.0, Terrain.FOREST: 1.3,
	Terrain.MOUNTAIN: 1.5, Terrain.DESERT: 0.8, Terrain.URBAN: 1.4
}
var selected_terrain: int = Terrain.PLAINS

# ─── الطقس ───
enum Weather { CLEAR, RAIN, SANDSTORM, FOG, SNOW, NIGHT }
var weather_names: Dictionary = {
	Weather.CLEAR: "صافي ☀️", Weather.RAIN: "مطر 🌧️",
	Weather.SANDSTORM: "عاصفة رملية 🏜️", Weather.FOG: "ضباب 🌫️",
	Weather.SNOW: "ثلج ❄️", Weather.NIGHT: "ليل 🌙"
}
var weather_attack_mult: Dictionary = {
	Weather.CLEAR: {"infantry": 1.0, "armor": 1.0, "aviation": 1.0},
	Weather.RAIN: {"infantry": 0.85, "armor": 0.9, "aviation": 0.6},
	Weather.SANDSTORM: {"infantry": 0.7, "armor": 0.6, "aviation": 0.4},
	Weather.FOG: {"infantry": 0.9, "armor": 0.95, "aviation": 0.3},
	Weather.SNOW: {"infantry": 0.7, "armor": 0.75, "aviation": 0.8},
	Weather.NIGHT: {"infantry": 0.6, "armor": 0.5, "aviation": 0.4}
}
var current_weather: int = Weather.CLEAR

# ─── المنشآت ───
var buildings: Array[Dictionary] = []

func _init_buildings() -> void:
	buildings = [
		{"id": "scrapyard", "name_ar": "مقلب الخردة", "icon": "⚙️", "level": 1, "active": true,
		 "base_cost": 100, "base_production": 2, "resource_type": "scrap"},
		{"id": "fuel_depot", "name_ar": "مخزن الوقود", "icon": "⛽", "level": 1, "active": true,
		 "base_cost": 150, "base_production": 1, "resource_type": "fuel"},
		{"id": "intel_center", "name_ar": "مركز المعلومات", "icon": "📋", "level": 1, "active": true,
		 "base_cost": 200, "base_production": 0.5, "resource_type": "intel"},
		{"id": "war_factory", "name_ar": "مصنع الحرب", "icon": "🏭", "level": 1, "active": false,
		 "base_cost": 300, "base_production": 0, "resource_type": "scrap"},
		{"id": "training_camp", "name_ar": "معسكر التدريب", "icon": "⛺", "level": 1, "active": false,
		 "base_cost": 250, "base_production": 0, "resource_type": "scrap"},
	]

func get_building_upgrade_cost(building: Dictionary) -> int:
	var base: int = building["base_cost"]
	var level: int = building["level"]
	return int(base * pow(1.15, level))

func get_building_production(building: Dictionary) -> float:
	if not building["active"]:
		return 0.0
	var base: float = building["base_production"]
	var level: int = building["level"]
	return base * level

func upgrade_building(building_id: String) -> bool:
	for b in buildings:
		if b["id"] == building_id:
			var cost: int = get_building_upgrade_cost(b)
			if scrap >= cost:
				scrap -= cost
				b["level"] = b["level"] + 1
				buildings_changed.emit()
				return true
	return false

func toggle_building(building_id: String) -> void:
	for b in buildings:
		if b["id"] == building_id:
			b["active"] = not b["active"]
			buildings_changed.emit()
			return

func get_total_production_per_second() -> Dictionary:
	var result := {"scrap": 0.0, "fuel": 0.0, "intel": 0.0}
	for b in buildings:
		var prod: float = get_building_production(b)
		result[b["resource_type"]] += prod
	return result

# ─── القوات ───
enum TroopType { INFANTRY, ARMOR, AVIATION }
var troop_names: Dictionary = {
	TroopType.INFANTRY: "مشاة", TroopType.ARMOR: "مدرعات", TroopType.AVIATION: "طيران"
}
var troop_icons: Dictionary = {
	TroopType.INFANTRY: "🔫", TroopType.ARMOR: "🛡️", TroopType.AVIATION: "✈️"
}
var troop_stats: Dictionary = {
	TroopType.INFANTRY: {"attack": 15, "defense": 10, "cost_scrap": 10, "cost_fuel": 0},
	TroopType.ARMOR: {"attack": 30, "defense": 25, "cost_scrap": 30, "cost_fuel": 5},
	TroopType.AVIATION: {"attack": 45, "defense": 5, "cost_scrap": 50, "cost_fuel": 15},
}

# الشركات
var companies: Array[Dictionary] = []

func _init_companies() -> void:
	companies = [
		{"id": "inf_0", "type": TroopType.INFANTRY, "squads": []},
		{"id": "arm_0", "type": TroopType.ARMOR, "squads": []},
		{"id": "air_0", "type": TroopType.AVIATION, "squads": []},
	]

func get_company_troop_count(company: Dictionary) -> int:
	var total := 0
	for squad in company["squads"]:
		total += squad["size"]
	return total

func add_squad(company_id: String) -> bool:
	for c in companies:
		if c["id"] == company_id and c["squads"].size() < 10:
			c["squads"].append({"id": "sq_%d" % c["squads"].size(), "size": 0, "commander": null})
			troops_changed.emit()
			return true
	return false

func recruit_troops(company_id: String, squad_index: int, count: int) -> int:
	for c in companies:
		if c["id"] == company_id:
			if squad_index >= c["squads"].size():
				return 0
			var squad: Dictionary = c["squads"][squad_index]
			var stats: Dictionary = troop_stats[c["type"]]
			var max_size: int = 10
			var available: int = mini(count, max_size - squad["size"])
			if available <= 0:
				return 0
			var total_cost_scrap: int = stats["cost_scrap"] * available
			var total_cost_fuel: int = stats["cost_fuel"] * available
			if scrap >= total_cost_scrap and fuel >= total_cost_fuel:
				scrap -= total_cost_scrap
				fuel -= total_cost_fuel
				squad["size"] += available
				troops_changed.emit()
				return available
	return 0

func get_total_troops_by_type(troop_type: int) -> int:
	var total := 0
	for c in companies:
		if c["type"] == troop_type:
			total += get_company_troop_count(c)
	return total

# ─── نشر القوات للمعركة ───
var deployment: Array = [] # 3 موجات × 2 خانة

func _init_deployment() -> void:
	deployment = [
		[{"type": -1, "count": 0}, {"type": -1, "count": 0}],
		[{"type": -1, "count": 0}, {"type": -1, "count": 0}],
		[{"type": -1, "count": 0}, {"type": -1, "count": 0}],
	]

func assign_to_slot(wave: int, slot: int, troop_type: int) -> void:
	if wave >= deployment.size() or slot >= deployment[wave].size():
		return
	var available: int = get_total_troops_by_type(troop_type)
	if available < 5:
		return
	var current: Dictionary = deployment[wave][slot]
	if current["type"] == troop_type:
		var add: int = mini(5, available - current["count"])
		if add > 0:
			deployment[wave][slot]["count"] += add
	elif current["type"] == -1:
		deployment[wave][slot] = {"type": troop_type, "count": 5}

func clear_deployment() -> void:
	_init_deployment()

func get_deployed_power() -> int:
	var total_power := 0
	for wave in deployment:
		var wave_mult := 1.0
		for i in range(wave.size()):
			var slot: Dictionary = wave[i]
			if slot["type"] < 0:
				continue
			var stats: Dictionary = troop_stats[slot["type"]]
			var base_power: int = stats["attack"] * slot["count"]
			var terrain_mult: float = terrain_defense.get(selected_terrain, 1.0)
			var weather_data: Dictionary = weather_attack_mult.get(current_weather, weather_attack_mult[Weather.CLEAR])
			var troop_key: String = ["infantry", "armor", "aviation"][slot["type"]]
			var weather_mult: float = weather_data.get(troop_key, 1.0)
			total_power += int(base_power * terrain_mult * wave_mult * weather_mult)
		wave_mult = 1.5 # كل موجة أقوى
	return total_power

func get_deployed_count() -> int:
	var total := 0
	for wave in deployment:
		for slot in wave:
			total += slot["count"]
	return total

# ─── المعركة ───
var battle_active: bool = false
var battle_data: Dictionary = {}

func start_battle(enemy_power: int, sector_name: String) -> bool:
	if get_deployed_count() == 0:
		return false
	battle_active = true
	var player_power := get_deployed_power()
	battle_data = {
		"enemy_power": enemy_power,
		"enemy_current_hp": enemy_power,
		"player_power": player_power,
		"player_current_hp": player_power,
		"elapsed": 0.0,
		"log": ["⚔️ بدء الهجوم على " + sector_name],
		"sector_name": sector_name,
		"tactics_cooldowns": {"smoke": 0.0, "air_support": 0.0, "retreat": 0.0},
		"tactics_active": {},
	}
	battle_started.emit()
	return true

func update_battle(delta: float) -> void:
	if not battle_active:
		return
	battle_data["elapsed"] += delta
	# أضرار اللاعب
	var player_dps: float = battle_data["player_power"] * 0.1
	battle_data["enemy_current_hp"] -= player_dps * delta
	# أضرار العدو
	var enemy_dps: float = battle_data["enemy_power"] * 0.08
	# تأثير التكتيكات
	if battle_data["tactics_active"].get("smoke", false):
		enemy_dps *= 0.3
	if battle_data["tactics_active"].get("air_support", false):
		player_dps *= 1.5
	# تحديث الهجوم
	battle_data["enemy_current_hp"] -= player_dps * delta
	battle_data["player_current_hp"] -= enemy_dps * delta
	# تحديث التكتيكات
	for tactic in battle_data["tactics_cooldowns"]:
		if battle_data["tactics_cooldowns"][tactic] > 0:
			battle_data["tactics_cooldowns"][tactic] -= delta
	for tactic in battle_data["tactics_active"].duplicate():
		if battle_data["tactics_active"][tactic] > 0:
			battle_data["tactics_active"][tactic] -= delta
			if battle_data["tactics_active"][tactic] <= 0:
				battle_data["tactics_active"].erase(tactic)
				battle_data["log"].append("⏹️ انتهى تأثير " + tactic)
	# فحص النهاية
	if battle_data["enemy_current_hp"] <= 0:
		end_battle(true)
	elif battle_data["player_current_hp"] <= 0:
		end_battle(false)
	else:
		battle_updated.emit(battle_data.duplicate())

func activate_tactic(tactic: String) -> bool:
	if not battle_active:
		return false
	match tactic:
		"smoke":
			if fuel < 20 or battle_data["tactics_cooldowns"]["smoke"] > 0:
				return false
			fuel -= 20
			battle_data["tactics_active"]["smoke"] = 8.0
			battle_data["tactics_cooldowns"]["smoke"] = 20.0
			battle_data["log"].append("🚬 ستارة دخان! -20 وقود")
		"air_support":
			if fuel < 40 or battle_data["tactics_cooldowns"]["air_support"] > 0:
				return false
			fuel -= 40
			battle_data["tactics_active"]["air_support"] = 5.0
			battle_data["tactics_cooldowns"]["air_support"] = 30.0
			battle_data["log"].append("✈️ دعم جوي! -40 وقود")
		"retreat":
			end_battle(false)
			battle_data["log"].append("🏳️ انسحاب!")
			return true
	return true

func end_battle(won: bool) -> void:
	battle_active = false
	var loot := {"scrap": 0, "fuel": 0, "intel": 0}
	if won:
		var base: int = battle_data["enemy_power"]
		loot = {"scrap": base * 2, "fuel": base, "intel": int(base * 0.5)}
		scrap += loot["scrap"]
		fuel += loot["fuel"]
		intel += loot["intel"]
		battle_data["log"].append("🏆 نصر! غنائم: " + str(loot["scrap"]) + " خردة")
	else:
		battle_data["log"].append("💔 هزيمة...")
	clear_deployment()
	battle_ended.emit(won, loot)

# ─── خريطة العالم ───
var world_sectors: Array[Dictionary] = []

enum SectorStatus { UNEXPLORED, EXPLORED, CLEARED }

func _init_world_map() -> void:
	world_sectors = []
	var sector_names := [
		"وادي الذئاب", "التلال الصخرية", "ممر الشمال", "قاعدة العدو",
		"سهل القتال", "الغابة المظلمة", "الجبل العالي", "المطار القديم",
		"القرية المحاصرة", "نهر الحديد", "المدينة المحطمة", "مصنع الذخيرة",
		"الميناء المهجور", "الجسر الاستراتيجي", "الطريق السريع", "الملجأ السري",
		"قمة الجبل", "الوادي الأخضر", "مخيم الأعداء", "القلعة المنسية",
		"السهول المفتوحة", "مزرعة العدو", "الخنادق القديمة", "نقطة التفتيش",
		"المستودع", "برج المراقبة", "السد الكبير", "البوابة الشرقية",
	]
	var idx := 0
	for row in range(7):
		for col in range(4):
			var is_explored: bool = (row == 3 and col == 0) # الخلية المبدئية
			var power: int = 50 + (row + col) * 30 + randi() % 40
			var loot_val: int = power / 2
			world_sectors.append({
				"id": "s_%d_%d" % [row, col],
				"row": row, "col": col,
				"name": sector_names[idx] if idx < sector_names.size() else "قطاع %d" % idx,
				"status": SectorStatus.EXPLORED if is_explored else SectorStatus.UNEXPLORED,
				"enemy_power": power,
				"loot": {"scrap": loot_val, "fuel": loot_val / 2, "intel": loot_val / 4},
				"terrain": randi() % 5,
			})
			idx += 1

func scout_sector(sector_id: String) -> bool:
	if intel < 15:
		return false
	for s in world_sectors:
		if s["id"] == sector_id and s["status"] == SectorStatus.UNEXPLORED:
			intel -= 15
			s["status"] = SectorStatus.EXPLORED
			map_updated.emit()
			return true
	return false

func clear_sector(sector_id: String) -> void:
	for s in world_sectors:
		if s["id"] == sector_id:
			s["status"] = SectorStatus.CLEARED
			map_updated.emit()
			return

# ─── البحث والتطوير ───
var tech_tree: Array[Dictionary] = []
var research_in_progress: String = ""
var research_progress: float = 0.0
var completed_techs: Array[String] = []

func _init_tech_tree() -> void:
	tech_tree = [
		{"id": "t1_1", "name": "ذخيرة محسّنة", "icon": "🎯", "tier": 1,
		 "desc": "+15% هجوم للمشاة", "cost_scrap": 200, "cost_intel": 50,
		 "time": 30.0, "prereqs": [], "effect": "infantry_attack_15"},
		{"id": "t1_2", "name": "درع متطور", "icon": "🛡️", "tier": 1,
		 "desc": "+15% دفاع للمدرعات", "cost_scrap": 250, "cost_intel": 60,
		 "time": 35.0, "prereqs": [], "effect": "armor_defense_15"},
		{"id": "t1_3", "name": "رادار متقدم", "icon": "📡", "tier": 1,
		 "desc": "-50% تكلفة الاستطلاع", "cost_scrap": 150, "cost_intel": 80,
		 "time": 25.0, "prereqs": [], "effect": "scout_discount_50"},
		{"id": "t2_1", "name": "قنابل عنقودية", "icon": "💣", "tier": 2,
		 "desc": "+25% هجوم لجميع القوات", "cost_scrap": 500, "cost_intel": 150,
		 "time": 60.0, "prereqs": ["t1_1"], "effect": "all_attack_25"},
		{"id": "t2_2", "name": "دروع تفاعلية", "icon": "🔩", "tier": 2,
		 "desc": "+25% دفاع لجميع القوات", "cost_scrap": 550, "cost_intel": 160,
		 "time": 65.0, "prereqs": ["t1_2"], "effect": "all_defense_25"},
		{"id": "t2_3", "name": "طقس الفضاء", "icon": "🛰️", "tier": 2,
		 "desc": "إلغاء تأثير الطقس", "cost_scrap": 400, "cost_intel": 200,
		 "time": 70.0, "prereqs": ["t1_3"], "effect": "weather_immunity"},
		{"id": "t3_1", "name": "صواريخ باليستية", "icon": "🚀", "tier": 3,
		 "desc": "+50% هجوم + قصف المدفعية", "cost_scrap": 1200, "cost_intel": 400,
		 "time": 120.0, "prereqs": ["t2_1", "t2_2"], "effect": "ballistic_50"},
		{"id": "t3_2", "name": "شبكة دفاعية", "icon": "🏰", "tier": 3,
		 "desc": "+40% دفاع + حماية القواعد", "cost_scrap": 1000, "cost_intel": 350,
		 "time": 110.0, "prereqs": ["t2_2"], "effect": "defense_network_40"},
	]

func can_research(tech_id: String) -> bool:
	if research_in_progress != "":
		return false
	if tech_id in completed_techs:
		return false
	for tech in tech_tree:
		if tech["id"] == tech_id:
			if scrap < tech["cost_scrap"] or intel < tech["cost_intel"]:
				return false
			for prereq in tech["prereqs"]:
				if prereq not in completed_techs:
					return false
			return true
	return false

func start_research(tech_id: String) -> bool:
	if not can_research(tech_id):
		return false
	for tech in tech_tree:
		if tech["id"] == tech_id:
			scrap -= tech["cost_scrap"]
			intel -= tech["cost_intel"]
			research_in_progress = tech_id
			research_progress = 0.0
			return true
	return false

func update_research(delta: float) -> void:
	if research_in_progress == "":
		return
	for tech in tech_tree:
		if tech["id"] == research_in_progress:
			research_progress += (delta / tech["time"]) * 100.0
			research_progress_changed.emit(research_in_progress, research_progress)
			if research_progress >= 100.0:
				completed_techs.append(research_in_progress)
				research_completed.emit(research_in_progress)
				research_in_progress = ""
				research_progress = 0.0
			return

# ─── الروح المعنوية ───
var player_morale: float = 70.0

func get_morale_mult() -> float:
	return 0.5 + (player_morale / 100.0) * 0.5 # 0.5 - 1.0

# ─── Idle (إنتاج تلقائي) ───
var idle_timer: float = 0.0

func _idle_tick(delta: float) -> void:
	idle_timer += delta
	if idle_timer >= 1.0:
		idle_timer -= 1.0
		var prod: Dictionary = get_total_production_per_second()
		scrap += int(prod["scrap"])
		fuel += int(prod["fuel"])
		intel += int(prod["intel"])

# ─── الحفظ والتحميل ───
const SAVE_PATH := "user://generals_fist_save.json"

func save_game() -> void:
	var data := {
		"scrap": scrap, "fuel": fuel, "intel": intel,
		"buildings": buildings, "companies": companies,
		"deployment": deployment, "world_sectors": world_sectors,
		"selected_terrain": selected_terrain, "current_weather": current_weather,
		"player_morale": player_morale,
		"completed_techs": completed_techs,
		"last_online_time": Time.get_unix_time_from_system(),
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return false
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return false
	var data: Dictionary = json.get_data()
	# استعادة الموارد
	scrap = data.get("scrap", 500)
	fuel = data.get("fuel", 300)
	intel = data.get("intel", 100)
	# استعادة المنشآت
	if data.has("buildings"):
		buildings = data["buildings"]
	# استعادة الشركات
	if data.has("companies"):
		companies = data["companies"]
	# استعادة النشر
	if data.has("deployment"):
		deployment = data["deployment"]
	# استعادة الخريطة
	if data.has("world_sectors"):
		world_sectors = data["world_sectors"]
	# البحث
	selected_terrain = data.get("selected_terrain", Terrain.PLAINS)
	current_weather = data.get("current_weather", Weather.CLEAR)
	player_morale = data.get("player_morale", 70.0)
	completed_techs = data.get("completed_techs", [])
	last_online_time = data.get("last_online_time", 0)
	# حساب الإنتاج أثناء الغياب
	_process_idle_offline()
	return true

func _process_idle_offline() -> void:
	if last_online_time == 0:
		return
	var now: int = Time.get_unix_time_from_system()
	var elapsed_seconds: int = now - last_online_time
	if elapsed_seconds > 0:
		var prod: Dictionary = get_total_production_per_second()
		scrap += int(prod["scrap"] * elapsed_seconds)
		fuel += int(prod["fuel"] * elapsed_seconds)
		intel += int(prod["intel"] * elapsed_seconds)
	last_online_time = now

# ─── التهيئة ───
func _ready() -> void:
	_init_buildings()
	_init_companies()
	_init_deployment()
	_init_world_map()
	_init_tech_tree()
	# محاولة تحميل حفظ سابق
	if not load_game():
		print("[GameManager] بداية لعبة جديدة")

func _process(delta: float) -> void:
	_idle_tick(delta)
	update_research(delta)
	if battle_active:
		update_battle(delta)
