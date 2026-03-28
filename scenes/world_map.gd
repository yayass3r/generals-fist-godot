extends Control
## ═══════════════════════════════════════════════════════════════
## خريطة العالم — شبكة سداسية مع ضباب الحرب
## ═══════════════════════════════════════════════════════════════

@onready var grid_container: GridContainer = $ScrollContainer/GridContainer
@onready var info_panel: PanelContainer = $InfoPanel
@onready var info_name: Label = $InfoPanel/VBox/NameLabel
@onready var info_power: Label = $InfoPanel/VBox/PowerLabel
@onready var info_loot: Label = $InfoPanel/VBox/LootLabel
@onready var info_status: Label = $InfoPanel/VBox/StatusLabel
@onready var scout_btn: Button = $InfoPanel/VBox/ScoutBtn
@onready var attack_map_btn: Button = $InfoPanel/VBox/AttackMapBtn
@onready var back_btn: Button = $TopBar/BackBtn

var selected_sector: Dictionary = {}

func _ready() -> void:
	game_manager.map_updated.connect(_refresh_map)
	back_btn.pressed.connect(func(): game_manager.current_screen = "war_room")
	scout_btn.pressed.connect(_on_scout)
	attack_map_btn.pressed.connect(_on_attack_sector)
	_build_map()
	info_panel.visible = false

func _build_map() -> void:
	for child in grid_container.get_children():
		child.queue_free()
	grid_container.add_theme_constant_override("h_separation", 4)
	grid_container.add_theme_constant_override("v_separation", 4)
	for sector in game_manager.world_sectors:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(90, 70)
		var status: int = sector["status"]
		var style = StyleBoxFlat.new()
		match status:
			0: # UNEXPLORED
				style.bg_color = Color(0.1, 0.1, 0.18, 1)
				btn.text = "❓\n???"
			1: # EXPLORED
				style.bg_color = Color(0.1, 0.16, 0.24, 1)
				style.border_color = Color(0.251, 0.627, 0.878, 0.4)
				btn.text = "%s\n⚡%d" % [sector["name"].substr(0, 8), sector["enemy_power"]]
			2: # CLEARED
				style.bg_color = Color(0.1, 0.24, 0.18, 1)
				style.border_color = Color(0.2, 0.7, 0.3, 0.4)
				btn.text = "%s\n✅" % sector["name"].substr(0, 8)
		style.set_border_width_all(1)
		style.set_corner_radius_all(8)
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_font_size_override("font_size", 10)
		btn.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1))
		btn.set_meta("sector_id", sector["id"])
		btn.pressed.connect(_on_sector_pressed.bind(sector))
		grid_container.add_child(btn)

func _on_sector_pressed(sector: Dictionary) -> void:
	selected_sector = sector
	info_panel.visible = true
	info_name.text = "📍 %s" % sector["name"]
	info_power.text = "⚡ قوة العدو: %d" % sector["enemy_power"]
	info_loot.text = "🎁 الغنائم: %d خردة / %d وقود" % [sector["loot"]["scrap"], sector["loot"]["fuel"]]
	var status_text := ["❓ غير مستكشف", "🔍 مستكشف", "✅ تم تطهيره"]
	info_status.text = status_text[sector["status"]]
	scout_btn.visible = sector["status"] == 0
	attack_map_btn.visible = sector["status"] == 1

func _on_scout() -> void:
	if selected_sector.is_empty():
		return
	if game_manager.scout_sector(selected_sector["id"]):
		info_status.text = "🔍 مستكشف!"
		_build_map()
		_on_sector_pressed(selected_sector)
	else:
		info_status.text = "❌ تحتاج 15 معلومات!"

func _on_attack_sector() -> void:
	if selected_sector.is_empty():
		return
	if game_manager.get_deployed_count() == 0:
		info_status.text = "❌ نشر القوات أولاً من غرفة العمليات!"
		return
	var enemy_power: int = selected_sector["enemy_power"]
	game_manager.start_battle(enemy_power, selected_sector["name"])
	if game_manager.battle_active:
		game_manager.clear_sector(selected_sector["id"])

func _refresh_map() -> void:
	_build_map()
