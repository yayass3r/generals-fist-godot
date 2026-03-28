extends Control
## ═══════════════════════════════════════════════════════════════
## شاشة المهام — يومية + أسبوعية
## ═══════════════════════════════════════════════════════════════

@onready var tab_daily: Button = $TabBar/HBox/TabDaily
@onready var tab_weekly: Button = $TabBar/HBox/TabWeekly
@onready var daily_content: ScrollContainer = $DailyContent
@onready var weekly_content: ScrollContainer = $WeeklyContent

func _ready() -> void:
	tab_daily.pressed.connect(func(): _show_tab("daily"))
	tab_weekly.pressed.connect(func(): _show_tab("weekly"))
	game_manager.missions_updated.connect(_refresh_all)
	game_manager.resources_changed.connect(_refresh_all)
	_build_daily()
	_build_weekly()
	_show_tab("daily")

func _show_tab(tab: String) -> void:
	daily_content.visible = tab == "daily"
	weekly_content.visible = tab == "weekly"
	tab_daily.modulate = Color(0.251, 0.627, 0.878) if tab == "daily" else Color(0.4, 0.4, 0.4)
	tab_weekly.modulate = Color(0.9, 0.7, 0.2) if tab == "weekly" else Color(0.4, 0.4, 0.4)
	if tab == "daily":
		_build_daily()
	else:
		_build_weekly()

func _refresh_all() -> void:
	_build_daily()
	_build_weekly()

# ═══════════════════════════════════════
# المهام اليومية
# ═══════════════════════════════════════

func _build_daily() -> void:
	for child in daily_content.get_children():
		child.queue_free()
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	daily_content.add_child(vbox)
	# عنوان
	var title = Label.new()
	title.text = "📅 المهام اليومية"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.251, 0.627, 0.878, 1))
	vbox.add_child(title)
	# وقت التحديث
	var refresh_label = Label.new()
	var now: int = Time.get_unix_time_from_system()
	var last: int = game_manager.last_daily_refresh
	var remaining: int = 28800 - (now - last)
	var hours: int = remaining / 3600
	var mins: int = (remaining % 3600) / 60
	refresh_label.text = "⏰ التحديث التالي: %dس %dد" % [hours, mins]
	refresh_label.add_theme_font_size_override("font_size", 11)
	refresh_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
	vbox.add_child(refresh_label)
	# فحص التقدم
	game_manager.check_mission_progress()
	# بطاقات المهام
	var completed_count := 0
	for mission in game_manager.daily_missions:
		var card = _create_mission_card(mission, "daily")
		vbox.add_child(card)
		if mission["completed"]:
			completed_count += 1
	# ملخص
	var summary = Label.new()
	summary.text = "الإنجاز: %d/3 مهام" % completed_count
	summary.add_theme_font_size_override("font_size", 12)
	summary.add_theme_color_override("font_color", Color(0.788, 0.635, 0.153, 1))
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(summary)

# ═══════════════════════════════════════
# المهام الأسبوعية
# ═══════════════════════════════════════

func _build_weekly() -> void:
	for child in weekly_content.get_children():
		child.queue_free()
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	weekly_content.add_child(vbox)
	# عنوان
	var title = Label.new()
	title.text = "📆 المهام الأسبوعية"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2, 1))
	vbox.add_child(title)
	# وقت التحديث
	var refresh_label = Label.new()
	var now: int = Time.get_unix_time_from_system()
	var last: int = game_manager.last_weekly_refresh
	var remaining: int = 259200 - (now - last)
	if remaining < 0:
		remaining = 0
	var days: int = remaining / 86400
	var hours: int = (remaining % 86400) / 3600
	refresh_label.text = "⏰ التحديث التالي: %dي %dس" % [days, hours]
	refresh_label.add_theme_font_size_override("font_size", 11)
	refresh_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
	vbox.add_child(refresh_label)
	# فحص التقدم
	game_manager.check_mission_progress()
	# بطاقات المهام
	var completed_count := 0
	for mission in game_manager.weekly_missions:
		var card = _create_mission_card(mission, "weekly")
		vbox.add_child(card)
		if mission["completed"]:
			completed_count += 1
	# ملخص
	var summary = Label.new()
	summary.text = "الإنجاز: %d/3 مهام" % completed_count
	summary.add_theme_font_size_override("font_size", 12)
	summary.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2, 1))
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(summary)

# ═══════════════════════════════════════
# بطاقة المهمة
# ═══════════════════════════════════════

func _create_mission_card(mission: Dictionary, mtype: String) -> PanelContainer:
	var panel = PanelContainer.new()
	var is_completed: bool = mission["completed"]
	var is_claimed: bool = mission["claimed"]
	var style = StyleBoxFlat.new()
	if is_claimed:
		style.bg_color = Color(0.06, 0.06, 0.08, 0.9)
		style.border_color = Color(0.15, 0.15, 0.2, 0.3)
	elif is_completed:
		style.bg_color = Color(0.08, 0.18, 0.08, 0.9)
		style.border_color = Color(0.3, 0.8, 0.4, 0.4)
	else:
		style.bg_color = Color(0.05, 0.08, 0.16, 0.9)
		style.border_color = Color(0.2, 0.25, 0.35, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	# الرأس
	var header = HBoxContainer.new()
	var icon_label = Label.new()
	icon_label.text = mission["icon"]
	icon_label.add_theme_font_size_override("font_size", 22)
	header.add_child(icon_label)
	var desc_label = Label.new()
	desc_label.text = mission["desc"]
	desc_label.add_theme_font_size_override("font_size", 14)
	if is_claimed:
		desc_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4, 1))
	elif is_completed:
		desc_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4, 1))
	else:
		desc_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1))
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(desc_label)
	vbox.add_child(header)
	# شريط التقدم
	if not is_completed:
		var progress: int = mini(mission["progress"], mission["target"])
		var pct: float = float(progress) / float(mission["target"]) if mission["target"] > 0 else 0.0
		var prog_text = Label.new()
		prog_text.text = "التقدم: %d/%d (%d%%)" % [progress, mission["target"], int(pct * 100)]
		prog_text.add_theme_font_size_override("font_size", 11)
		prog_text.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
		vbox.add_child(prog_text)
		# شريط بصري
		var bar_bg = PanelContainer.new()
		var bar_style = StyleBoxFlat.new()
		bar_style.bg_color = Color(0.1, 0.1, 0.15, 1)
		bar_style.set_corner_radius_all(4)
		bar_style.set_content_margin_all(2)
		bar_bg.add_theme_stylebox_override("panel", bar_style)
		bar_bg.custom_minimum_size = Vector2(0, 12)
		var bar_fill = ColorRect.new()
		bar_fill.color = Color(0.251, 0.627, 0.878, 1) if mtype == "daily" else Color(0.9, 0.7, 0.2, 1)
		bar_fill.custom_minimum_size = Vector2(int(bar_bg.size.x * pct), 8) if bar_bg.size.x > 0 else Vector2(1, 8)
		bar_bg.add_child(bar_fill)
		vbox.add_child(bar_bg)
	# المكافأة
	var reward_text = "🎁 %d⚙️ + %d⛽ + %d✨" % [mission["reward_scrap"], mission["reward_fuel"], mission["reward_xp"]]
	var reward_label = Label.new()
	reward_label.text = reward_text
	reward_label.add_theme_font_size_override("font_size", 11)
	reward_label.add_theme_color_override("font_color", Color(0.788, 0.635, 0.153, 1))
	vbox.add_child(reward_label)
	# الحالة / الزر
	if is_claimed:
		var done_label = Label.new()
		done_label.text = "✅ تم استلام المكافأة"
		done_label.add_theme_font_size_override("font_size", 12)
		done_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3, 1))
		vbox.add_child(done_label)
	elif is_completed:
		var claim_btn = Button.new()
		claim_btn.text = "🎁 استلم المكافأة!"
		claim_btn.custom_minimum_size = Vector2(180, 38)
		claim_btn.add_theme_font_size_override("font_size", 13)
		var btn_style = StyleBoxFlat.new()
		btn_style.bg_color = Color(0.2, 0.7, 0.3, 1)
		btn_style.set_corner_radius_all(8)
		claim_btn.add_theme_stylebox_override("normal", btn_style)
		claim_btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		var mid = mission["id"]
		claim_btn.pressed.connect(func():
			game_manager.claim_mission(mid)
			_build_daily()
			_build_weekly()
		)
		vbox.add_child(claim_btn)
	else:
		var pending_label = Label.new()
		pending_label.text = "⏳ جاري التنفيذ..."
		pending_label.add_theme_font_size_override("font_size", 11)
		pending_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
		vbox.add_child(pending_label)
	panel.add_child(vbox)
	return panel
