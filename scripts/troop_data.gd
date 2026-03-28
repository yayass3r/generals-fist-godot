extends RefCounted
## Troop and Building Data Definitions
## Centralized data reference for all units and structures

class_name TroopData

# ============================================================
# TROOP DEFINITIONS
# ============================================================
const TROOPS: Dictionary = {
	"infantry": {
		"id": "infantry",
		"name": "مشاة",
		"name_en": "Infantry",
		"description": "وحدات المشاة الأساسية - متعددة الاستخدامات",
		"cost_scrap": 10,
		"cost_fuel": 0,
		"attack": 15,
		"defense": 10,
		"hp": 100,
		"terrain_bonuses": {
			"plains": 1.0,
			"forest": 1.3,
			"mountain": 0.8,
			"desert": 0.9,
			"urban": 1.1,
		},
		"weather_bonuses": {
			"clear": 1.0,
			"rain": 0.85,
			"sandstorm": 0.7,
			"fog": 0.9,
		},
		"icon_color": "4ade80",   # Green
		"unlock_level": 1,
	},
	"armor": {
		"id": "armor",
		"name": "مدرعات",
		"name_en": "Armor",
		"description": "الدروع الثقيلة - قوة نار هائلة",
		"cost_scrap": 30,
		"cost_fuel": 5,
		"attack": 30,
		"defense": 25,
		"hp": 200,
		"terrain_bonuses": {
			"plains": 1.3,
			"forest": 0.7,
			"mountain": 0.5,
			"desert": 1.2,
			"urban": 0.9,
		},
		"weather_bonuses": {
			"clear": 1.0,
			"rain": 0.8,
			"sandstorm": 0.6,
			"fog": 1.0,
		},
		"icon_color": "40a0e0",   # Blue
		"unlock_level": 1,
	},
	"aviation": {
		"id": "aviation",
		"name": "طيران",
		"name_en": "Aviation",
		"description": "القوات الجوية - سرعة وقوة تدمير",
		"cost_scrap": 50,
		"cost_fuel": 15,
		"attack": 45,
		"defense": 5,
		"hp": 80,
		"terrain_bonuses": {
			"plains": 1.2,
			"forest": 0.9,
			"mountain": 1.1,
			"desert": 1.1,
			"urban": 1.0,
		},
		"weather_bonuses": {
			"clear": 1.0,
			"rain": 0.6,
			"sandstorm": 0.5,
			"fog": 0.7,
		},
		"icon_color": "e07020",   # Orange
		"unlock_level": 1,
	},
}

# ============================================================
# BUILDING DEFINITIONS
# ============================================================
const BUILDINGS: Dictionary = {
	"scrapyard": {
		"id": "scrapyard",
		"name": "مقلب الخردة",
		"name_en": "Scrapyard",
		"description": "يجمع خردة المعدنية",
		"base_cost": 50,
		"cost_resource": "scrap",
		"base_generation": 2.0,
		"generates": "scrap",
		"max_level": 50,
		"icon_color": "c9a227",
	},
	"fuel_depot": {
		"id": "fuel_depot",
		"name": "مخزن الوقود",
		"name_en": "Fuel Depot",
		"description": "ينتج الوقود للعمليات",
		"base_cost": 75,
		"cost_resource": "scrap",
		"base_generation": 1.5,
		"generates": "fuel",
		"max_level": 50,
		"icon_color": "e07020",
	},
	"intel_center": {
		"id": "intel_center",
		"name": "مركز المعلومات",
		"name_en": "Intel Center",
		"description": "يجمع معلومات استخباراتية",
		"base_cost": 100,
		"cost_resource": "scrap",
		"base_generation": 0.5,
		"generates": "intel",
		"max_level": 50,
		"icon_color": "40a0e0",
	},
	"war_factory": {
		"id": "war_factory",
		"name": "مصنع الحرب",
		"name_en": "War Factory",
		"description": "يسرع إنتاج الموارد بنسبة 10% لكل مستوى",
		"base_cost": 200,
		"cost_resource": "scrap",
		"base_generation": 0.0,
		"generates": "production_speed",
		"max_level": 20,
		"icon_color": "ef4444",
	},
	"training_camp": {
		"id": "training_camp",
		"name": "معسكر التدريب",
		"name_en": "Training Camp",
		"description": "يقلل تكلفة التجنيد بنسبة 5% لكل مستوى",
		"base_cost": 150,
		"cost_resource": "scrap",
		"base_generation": 0.0,
		"generates": "recruit_speed",
		"max_level": 20,
		"icon_color": "4ade80",
	},
}

# ============================================================
# TERRAIN DEFINITIONS
# ============================================================
const TERRAINS: Dictionary = {
	"plains": {
		"id": "plains",
		"name": "سهل",
		"name_en": "Plains",
		"description": "أرض منبسطة - لا مكافأة ولا عقوبة",
		"color": "#2a4a2a",
		"difficulty": 1,
	},
	"forest": {
		"id": "forest",
		"name": "غابة",
		"name_en": "Forest",
		"description": "غابات كثيفة - المشاة تتفوق",
		"color": "#1a3a1a",
		"difficulty": 2,
	},
	"mountain": {
		"id": "mountain",
		"name": "جبل",
		"name_en": "Mountain",
		"description": "تضاريس وعرة - المدرعات تعاني",
		"color": "#3a3a3a",
		"difficulty": 3,
	},
	"desert": {
		"id": "desert",
		"name": "صحراء",
		"name_en": "Desert",
		"description": "أرض قاحلة - المدرعات تتفوق",
		"color": "#4a3a1a",
		"difficulty": 2,
	},
	"urban": {
		"id": "urban",
		"name": "حضري",
		"name_en": "Urban",
		"description": "مناطق مبنية - المشاة والطيران",
		"color": "#2a2a3a",
		"difficulty": 3,
	},
}

# ============================================================
# WEATHER DEFINITIONS
# ============================================================
const WEATHERS: Dictionary = {
	"clear": {
		"id": "clear",
		"name": "صافٍ",
		"name_en": "Clear",
		"description": "طقس مثالي للقتال",
		"icon": "☀",
	},
	"rain": {
		"id": "rain",
		"name": "مطر",
		"name_en": "Rain",
		"description": "يقلل فعالية الطيران",
		"icon": "🌧",
	},
	"sandstorm": {
		"id": "sandstorm",
		"name": "عاصفة رملية",
		"name_en": "Sandstorm",
		"description": "يؤثر على جميع الوحدات",
		"icon": "🌪",
	},
	"fog": {
		"id": "fog",
		"name": "ضباب",
		"name_en": "Fog",
		"description": "يقلل الرؤية والفعالية",
		"icon": "🌫",
	},
}

# ============================================================
# TACTICS DEFINITIONS
# ============================================================
const TACTICS: Dictionary = {
	"smoke_screen": {
		"id": "smoke_screen",
		"name": "ستارة دخان",
		"name_en": "Smoke Screen",
		"description": "تقليل ضرر العدو + شفاء 15%",
		"cost_fuel": 20,
		"cooldown": 15.0,
		"effect_type": "defense",
	},
	"air_support": {
		"id": "air_support",
		"name": "دعم جوي",
		"name_en": "Air Support",
		"description": "ضربة جوية تتسبب بـ 30% ضرر للعدو",
		"cost_fuel": 40,
		"cooldown": 30.0,
		"effect_type": "attack",
	},
	"retreat": {
		"id": "retreat",
		"name": "انسحاب",
		"name_en": "Retreat",
		"description": "انسحاب استراتيجي من المعركة",
		"cost_fuel": 0,
		"cooldown": 5.0,
		"effect_type": "utility",
	},
}

# ============================================================
# HELPER FUNCTIONS
# ============================================================

static func get_troop_type_list() -> Array:
	return ["infantry", "armor", "aviation"]


static func get_building_type_list() -> Array:
	return ["scrapyard", "fuel_depot", "intel_center", "war_factory", "training_camp"]


static func get_terrain_type_list() -> Array:
	return ["plains", "forest", "mountain", "desert", "urban"]


static func get_weather_type_list() -> Array:
	return ["clear", "rain", "sandstorm", "fog"]
