extends Control
## ═══════════════════════════════════════════════════════════════
## جذر اللعبة — التنقل بين الشاشات + شريط الموارد
## ═══════════════════════════════════════════════════════════════

@onready var content_container: Control = $ContentContainer
@onready var scrap_label: Label = $TopBar/ResourceBar/HBox/ScrapLabel
@onready var fuel_label: Label = $TopBar/ResourceBar/HBox/FuelLabel
@onready var intel_label: Label = $TopBar/ResourceBar/HBox/IntelLabel
@onready var scrap_rate: Label = $TopBar/ResourceBar/HBox/ScrapRate
@onready var fuel_rate: Label = $TopBar/ResourceBar/HBox/FuelRate
@onready var intel_rate: Label = $TopBar/ResourceBar/HBox/IntelRate
@onready var nav_war: Button = $BottomNav/HBox/NavWar
@onready var nav_map: Button = $BottomNav/HBox/NavMap
@onready var nav_barracks: Button = $BottomNav/HBox/NavBarracks
@onready var battle_overlay: Control = $BattleOverlay

var current_scene: Control = null

func _ready() -> void:
	# ربط الإشارات
	game_manager.resources_changed.connect(_update_resources)
	game_manager.screen_changed.connect(_update_nav_highlight)
	game_manager.battle_started.connect(_on_battle_started)
	game_manager.battle_ended.connect(_on_battle_ended)
	# أزرار التنقل
	nav_war.pressed.connect(func(): _switch_screen("war_room"))
	nav_map.pressed.connect(func(): _switch_screen("world_map"))
	nav_barracks.pressed.connect(func(): _switch_screen("barracks"))
	# تحميل الشاشة الافتراضية
	_switch_screen("war_room")
	_update_resources()

func _switch_screen(screen_name: String) -> void:
	game_manager.current_screen = screen_name
	# حذف المشهد الحالي
	if current_scene:
		current_scene.queue_free()
		current_scene = null
	# تحميل المشهد الجديد
	var scene_path := ""
	match screen_name:
		"war_room":
			scene_path = "res://scenes/war_room.tscn"
		"world_map":
			scene_path = "res://scenes/world_map.tscn"
		"barracks":
			scene_path = "res://scenes/barracks.tscn"
	if scene_path != "":
		var scene = load(scene_path)
		current_scene = scene.instantiate()
		content_container.add_child(current_scene)

func _update_resources() -> void:
	scrap_label.text = str(game_manager.scrap)
	fuel_label.text = str(game_manager.fuel)
	intel_label.text = str(game_manager.intel)
	var prod = game_manager.get_total_production_per_second()
	scrap_rate.text = "+%d/ث" % int(prod["scrap"]) if prod["scrap"] > 0 else ""
	fuel_rate.text = "+%d/ث" % int(prod["fuel"]) if prod["fuel"] > 0 else ""
	intel_rate.text = "+%.1f/ث" % prod["intel"] if prod["intel"] > 0 else ""

func _update_nav_highlight(screen: String) -> void:
	nav_war.modulate = Color(1, 0.85, 0.2) if screen == "war_room" else Color(0.5, 0.5, 0.5)
	nav_map.modulate = Color(0.3, 0.7, 0.95) if screen == "world_map" else Color(0.5, 0.5, 0.5)
	nav_barracks.modulate = Color(0.3, 0.9, 0.4) if screen == "barracks" else Color(0.5, 0.5, 0.5)

func _on_battle_started() -> void:
	battle_overlay.visible = true
	var scene = load("res://scenes/battle.tscn")
	var battle_ui = scene.instantiate()
	battle_overlay.add_child(battle_ui)
	_switch_screen("")

func _on_battle_ended(_won: bool, _loot: Dictionary) -> void:
	await get_tree().create_timer(1.0).timeout
	for child in battle_overlay.get_children():
		child.queue_free()
	battle_overlay.visible = false
	_switch_screen("war_room")
