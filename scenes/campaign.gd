extends Control
## ═══════════════════════════════════════════════════════════════
## مشهد الحملات — 25 مرحلة مع BOSS ونجوم وقصة
## ═══════════════════════════════════════════════════

@onready var scroll: ScrollContainer = $ScrollContainer
@onready var stages_container: VBoxContainer = $ScrollContainer/StagesContainer
@onready var level_label: Label = $TopBar/HBox/LevelLabel
@onready var xp_label: Label = $TopBar/HBox/XpLabel
@onready var xp_bar: ProgressBar = $TopBar/HBox/XpBar
@onready var stars_label: Label = $TopBar/HBox/StarsLabel
@onready var skill_btn: Button = $TopBar/HBox/SkillBtn
@onready var story_panel: PanelContainer = $StoryPanel
@onready var story_title: Label = $StoryPanel/VBox/StoryTitle
@onready var story_text: Label = $StoryPanel/VBox/StoryText
@onready var story_start_btn: Button = $StoryPanel/VBox/StoryStartBtn
@onready var story_close_btn: Button = $StoryPanel/VBox/StoryCloseBtn
@onready var skill_panel: PanelContainer = $SkillPanel
@onready var skill_points_label: Label = $SkillPanel/VBox/PointsLabel
@onready var skill_attack_btn: Button = $SkillPanel/VBox/AttackBtn
@onready var skill_defense_btn: Button = $SkillPanel/VBox/DefenseBtn
@onready var skill_production_btn: Button = $SkillPanel/VBox/ProductionBtn
@onready var skill_morale_btn: Button = $SkillPanel/VBox/MoraleBtn
@onready var skill_close_btn: Button = $SkillPanel/VBox/SkillCloseBtn

var _selected_stage_idx: int = -1

func _ready() -> void:
	game_manager.level_up.connect(_on_level_up)
	game_manager.campaign_updated.connect(_build_stages)
	game_manager.campaign_stage_completed.connect(_on_stage_completed)
	game_manager.battle_ended.connect(_on_battle_ended)
	skill_btn.pressed.connect(_show_skills)
	story_start_btn.pressed.connect(_on_story_start)
	story_close_btn.pressed.connect(func(): story_panel.visible = false)
	skill_close_btn.pressed.connect(func(): skill_panel.visible = false)
	skill_attack_btn.pressed.connect(func(): game_manager.spend_skill_point("attack"); _refresh_skills())
	skill_defense_btn.pressed.connect(func(): game_manager.spend_skill_point("defense"); _refresh_skills())
	skill_production_btn.pressed.connect(func(): game_manager.spend_skill_point("production"); _refresh_skills())
	skill_morale_btn.pressed.connect(func(): game_manager.spend_skill_point("morale"); _refresh_skills())
	story_panel.visible = false
	skill_panel.visible = false
	_refresh_top_bar()
	_build_stages()

func _refresh_top_bar() -> void:
	level_label.text = "⭐ مستوى %d" % game_manager.player_level
	var xp_now: int = game_manager.player_xp - game_manager.xp_for_level(game_manager.player_level)
	var xp_need: int = game_manager.xp_to_next_level() - game_manager.xp_for_level(game_manager.player_level)
	xp_bar.max_value = maxf(1.0, float(xp_need))
	xp_bar.value = clampf(float(xp_now), 0.0, float(xp_need))
	xp_label.text = "%d/%d XP" % [xp_now, xp_need]
	stars_label.text = "⭐ %d" % game_manager.get_total_campaign_stars()
	skill_btn.visible = game_manager.level_skill_points > 0
	if game_manager.level_skill_points > 0:
		skill_btn.text = "📊 مهارات (%d)" % game_manager.level_skill_points
	else:
		skill_btn.text = "📊 مهارات"

func _on_level_up(_new_level: int) -> void:
	_refresh_top_bar()

func _build_stages() -> void:
	for child in stages_container.get_children():
		child.queue_free()
	var chapters := [
		{"name": "📖 الفصل 1: البداية", "range": [0, 5]},
		{"name": "📖 الفصل 2: التصعيد", "range": [5, 10]},
		{"name": "📖 الفصل 3: الهجوم الكبير", "range": [10, 15]},
		{"name": "📖 الفصل 4: الحرب الشاملة", "range": [15, 20]},
		{"name": "📖 الفصل 5: النصر النهائي", "range": [20, 25]},
	]
	for chapter in chapters:
		var chapter_label = Label.new()
		chapter_label.text = chapter["name"]
		chapter_label.add_theme_font_size_override("font_size", 14)
		chapter_label.add_theme_color_override("font_color", Color(0.788, 0.635, 0.153, 1))
		stages_container.add_child(chapter_label)
		var grid = GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		for idx in range(chapter["range"][0], mini(chapter["range"][1], game_manager.campaign_stages.size())):
			var stage: Dictionary = game_manager.campaign_stages[idx]
			var btn = _create_stage_button(idx, stage)
			grid.add_child(btn)
		stages_container.add_child(grid)

func _create_stage_button(idx: int, stage: Dictionary) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(120, 60)
	var is_completed: bool = game_manager.is_campaign_stage_completed(idx)
	var is_unlocked: bool = game_manager.is_campaign_stage_unlocked(idx)
	var stars: int = game_manager.get_campaign_stage_stars(idx)
	var is_boss: bool = stage.get("is_boss", false)
	# النص
	var stars_text := ""
	if is_completed:
		stars_text = "⭐" if stars == 0 else "⭐×%d" % stars
	btn.text = "%s\n%s\n%s" % [stage.get("icon", "⚔️"), stage["name"], stars_text if is_completed else ""]
	btn.add_theme_font_size_override("font_size", 9)
	# الألوان
	var style = StyleBoxFlat.new()
	if is_completed:
		if is_boss:
			style.bg_color = Color(0.15, 0.1, 0.2, 1.0)
			style.border_color = Color(0.788, 0.635, 0.153, 0.8)
		else:
			style.bg_color = Color(0.08, 0.18, 0.08, 1.0)
			style.border_color = Color(0.2, 0.7, 0.3, 0.4)
	elif is_unlocked:
		if is_boss:
			style.bg_color = Color(0.2, 0.08, 0.08, 1.0)
			style.border_color = Color(0.937, 0.267, 0.267, 0.6)
		else:
			style.bg_color = Color(0.08, 0.12, 0.22, 0.9)
			style.border_color = Color(0.3, 0.4, 0.6, 0.5)
	else:
		style.bg_color = Color(0.06, 0.06, 0.08, 1.0)
		style.border_color = Color(0.15, 0.15, 0.15, 0.5)
		btn.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3, 1))
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("normal", style)
	# التفاعل
	if is_unlocked and not is_completed:
		btn.pressed.connect(_on_stage_pressed.bind(idx))
	elif is_completed:
		btn.pressed.connect(_on_stage_pressed.bind(idx))
	btn.set_meta("stage_idx", idx)
	return btn

func _on_stage_pressed(idx: int) -> void:
	_selected_stage_idx = idx
	var stage: Dictionary = game_manager.campaign_stages[idx]
	story_title.text = "%s %s — المرحلة %d" % [stage.get("icon", ""), stage["name"], stage["id"]]
	# عرض القصة
	var is_completed: bool = game_manager.is_campaign_stage_completed(idx)
	var story: String = stage.get("story_before", "")
	if is_completed:
		story = "🔄 إعادة المعركة\n\n" + story
	story_text.text = story
	# معلومات إضافية
	var info := "\n\n⚡ قوة العدو: %d" % stage["enemy_power"]
	info += "\n🏔️ التضاريس: %s" % game_manager.terrain_names.get(stage.get("terrain", 0), "—")
	info += "\n🌤️ الطقس: %s" % game_manager.weather_names.get(stage.get("weather", 0), "—")
	var reward: Dictionary = stage.get("first_reward", {})
	info += "\n\n🎁 المكافأة الأولى: %d خردة, %d وقود, %d معلومات, %d XP" % [reward.get("scrap", 0), reward.get("fuel", 0), reward.get("intel", 0), reward.get("xp", 0)]
	if game_manager.is_campaign_stage_completed(idx):
		info += "\n\n⭐ النجوم: %d/3" % game_manager.get_campaign_stage_stars(idx)
	story_text.text += info
	story_start_btn.text = "⚔️ هجوم!" if not is_completed else "🔄 إعادة"
	story_panel.visible = true

func _on_story_start() -> void:
	if _selected_stage_idx < 0:
		return
	story_panel.visible = false
	if game_manager.start_campaign_battle(_selected_stage_idx):
		game_manager.current_screen = "war_room"

func _on_stage_completed(_stage_id: int, _stars: int) -> void:
	_build_stages()
	_refresh_top_bar()

func _on_battle_ended(won: bool, loot: Dictionary) -> void:
	if game_manager.battle_is_campaign:
		return  # تكتمل الحملة في end_battle
	if won:
		_refresh_top_bar()

func _show_skills() -> void:
	_refresh_skills()
	skill_panel.visible = true

func _refresh_skills() -> void:
	var pts: int = game_manager.level_skill_points
	skill_points_label.text = "📊 نقاط مهارات: %d" % pts
	var has_points: bool = pts > 0
	skill_attack_btn.text = "⚔️ هجوم (+5%%)\nالحالي: %d%%" % int(game_manager.level_bonus_attack * 100)
	skill_defense_btn.text = "🛡️ دفاع (+5%%)\nالحالي: %d%%" % int(game_manager.level_bonus_defense * 100)
	skill_production_btn.text = "🏭 إنتاج (+5%%)\nالحالي: %d%%" % int(game_manager.level_bonus_production * 100)
	skill_morale_btn.text = "💪 معنويات (+10)\nالحالية: %d%%" % int(game_manager.player_morale)
	skill_attack_btn.disabled = not has_points
	skill_defense_btn.disabled = not has_points
	skill_production_btn.disabled = not has_points
	skill_morale_btn.disabled = not has_points
	skill_btn.visible = has_points
	_refresh_top_bar()
