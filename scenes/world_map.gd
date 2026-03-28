extends Control
## ═══════════════════════════════════════════════════════════════
## خريطة العالم — شبكة مع ضباب الحرب + التحصينات
## ═══════════════════════════════════════════════════════════════

@onready var grid_container: GridContainer = $ScrollContainer/GridContainer
@onready var info_panel: PanelContainer = $InfoPanel
@onready var info_name: Label = $InfoPanel/VBox/NameLabel
@onready var info_power: Label = $InfoPanel/VBox/PowerLabel
@onready var info_loot: Label = $InfoPanel/VBox/LootLabel
@onready var info_status: Label = $InfoPanel/VBox/StatusLabel
@onready var info_fort: Label = $InfoPanel/VBox/FortLabel
@onready var btn_box: HBoxContainer = $InfoPanel/VBox/BtnBox
@onready var scout_btn: Button = $InfoPanel/VBox/BtnBox/ScoutBtn
@onready var attack_map_btn: Button = $InfoPanel/VBox/BtnBox/AttackMapBtn
@onready var fort_box: HBoxContainer = $InfoPanel/VBox/FortBox
@onready var back_btn: Button = $TopBar/BackBtn

var selected_sector: Dictionary = {}

# أنواع التحصينات المتاحة
var fort_types := [
	{"id": "mines", "name": "💣 ألغام", "desc": "+10% ضرر للعدو/مستوى"},
	{"id": "barricades", "name": "🚧 متاريس", "desc": "+8% دفاع/مستوى"},
	{"id": "watchtower", "name": "🗼 برج مراقبة", "desc": "+5% استطلاع/مستوى"},
	{"id": "supply_base", "name": "📦 قاعدة إمداد", "desc": "+إنتاج موارد/مستوى"},
	{"id": "hospital", "name": "🏥 مستشفى", "desc": "-12% خسائر/مستوى"},
]

func _ready() -> void:
	game_manager.map_updated.connect(_refresh_map)
	game_manager.fortifications_changed.connect(func(): _on_sector_pressed(selected_sector))
	game_manager.resources_changed.connect(func(): _on_sector_pressed(selected_sector))
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
		var fort_count: int = game_manager.get_sector_fort_count(sector["id"])
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
				var fort_text = ""
				if fort_count > 0:
					fort_text = " 🏗️%d" % fort_count
				btn.text = "%s\n✅%s" % [sector["name"].substr(0, 8), fort_text]
		style.set_border_width_all(1)
		style.set_corner_radius_all(8)
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_font_size_override("font_size", 10)
		btn.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1))
		btn.set_meta("sector_id", sector["id"])
		btn.pressed.connect(_on_sector_pressed.bind(sector))
		grid_container.add_child(btn)

func _on_sector_pressed(sector: Dictionary) -> void:
	if sector.is_empty():
		return
	selected_sector = sector
	info_panel.visible = true
	info_name.text = "📍 %s" % sector["name"]
	info_power.text = "⚡ قوة العدو: %d" % sector["enemy_power"]
	info_loot.text = "🎁 الغنائم: %d خردة / %d وقود" % [sector["loot"]["scrap"], sector["loot"]["fuel"]]
	var status_text := ["❓ غير مستكشف", "🔍 مستكشف", "✅ تم تطهيره"]
	info_status.text = status_text[sector["status"]]
	scout_btn.visible = sector["status"] == 0
	attack_map_btn.visible = sector["status"] == 1
	# التحصينات - تظهر فقط للقطاعات المحررة
	var is_cleared: bool = sector["status"] == 2
	fort_box.visible = is_cleared
	info_fort.visible = is_cleared
	if is_cleared:
		_build_fort_buttons(sector)

func _build_fort_buttons(sector: Dictionary) -> void:
	for child in fort_box.get_children():
		child.queue_free()
	var sector_id: String = sector["id"]
	var current_forts: int = game_manager.get_sector_fort_count(sector_id)
	var max_forts: int = 2
	if current_forts >= max_forts:
		info_fort.text = "🏗️ التحصينات: %d/%d (ممتلئ)" % [current_forts, max_forts]
		info_fort.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3, 1))
		var full_label = Label.new()
		full_label.text = "⚠️ القطاع ممتلئ (%d/%d)" % [current_forts, max_forts]
		full_label.add_theme_font_size_override("font_size", 11)
		full_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
		fort_box.add_child(full_label)
		return
	info_fort.text = "🏗️ التحصينات: %d/%d — اضغط لبناء" % [current_forts, max_forts]
	info_fort.add_theme_color_override("font_color", Color(0.2, 0.7, 0.3, 1))
	# عرض التحصينات المبنية
	for f in game_manager.fortifications:
		if f["sector_id"] == sector_id:
			var fort_info = _get_fort_info(f["type"])
			var fl = Label.new()
			fl.text = "%s مستوى %d" % [fort_info["name"], f["level"]]
			fl.add_theme_font_size_override("font_size", 11)
			fl.add_theme_color_override("font_color", Color(0.3, 0.8, 0.4, 1))
			fort_box.add_child(fl)
	# أزرار البناء
	for ft in fort_types:
		var cost: int = game_manager.get_fortification_cost(ft["id"])
		var can_build: bool = game_manager.scrap >= cost
		var btn = Button.new()
		btn.text = "%s (%d⚙️)" % [ft["name"], cost]
		btn.custom_minimum_size = Vector2(72, 38)
		btn.add_theme_font_size_override("font_size", 9)
		var btn_style = StyleBoxFlat.new()
		if can_build:
			btn_style.bg_color = Color(0.2, 0.6, 0.3, 0.9)
			btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		else:
			btn_style.bg_color = Color(0.15, 0.15, 0.2, 0.8)
			btn.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4, 1))
		btn_style.set_corner_radius_all(6)
		btn.add_theme_stylebox_override("normal", btn_style)
		btn.tooltip_text = ft["desc"]
		btn.pressed.connect(func():
			game_manager.build_fortification(sector_id, ft["id"])
			_build_map()
			_on_sector_pressed(sector)
		)
		fort_box.add_child(btn)

func _get_fort_info(fort_type: String) -> Dictionary:
	for ft in fort_types:
		if ft["id"] == fort_type:
			return ft
	return {"name": "؟؟؟", "desc": ""}

func _on_scout() -> void:
	if selected_sector.is_empty():
		return
	if game_manager.scout_sector(selected_sector["id"]):
		info_status.text = "🔍 مستكشف!"
		_build_map()
		_on_sector_pressed(selected_sector)
	else:
		var cost := 15 - game_manager._tech_scout_discount
		info_status.text = "❌ تحتاج %d معلومات!" % cost

func _on_attack_sector() -> void:
	if selected_sector.is_empty():
		return
	if game_manager.get_deployed_count() == 0:
		info_status.text = "❌ نشر القوات أولاً من غرفة العمليات!"
		return
	var enemy_power: int = selected_sector["enemy_power"]
	var sector_id: String = selected_sector["id"]
	var sector_name: String = selected_sector["name"]
	game_manager.start_battle(enemy_power, sector_name, sector_id)

func _refresh_map() -> void:
	_build_map()
