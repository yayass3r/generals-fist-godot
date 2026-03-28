extends Control
## ═══════════════════════════════════════════════════════════════
## غرفة العمليات — نشر القوات وإعداد المعركة
## ═══════════════════════════════════════════════════════════════

@onready var power_label: Label = $TopPanel/PowerBox/PowerVal
@onready var terrain_label: Label = $TopPanel/TerrainBox/HBox/TerrainVal
@onready var weather_label: Label = $TopPanel/WeatherBox/HBox/WeatherVal
@onready var morale_label: Label = $TopPanel/MoraleBox/HBox/MoraleVal
@onready var troop_panel: PanelContainer = $TroopSelector
@onready var waves_container: VBoxContainer = $ScrollContainer/WavesContainer
@onready var attack_btn: Button = $AttackBtn

var _troop_hbox: HBoxContainer = null  # مرجع لأزرار القوات للتحديث

func _ready() -> void:
        _build_troop_selector_ui()
        _build_terrain_weather_buttons()
        _refresh_ui()
        game_manager.resources_changed.connect(_refresh_ui)
        game_manager.troops_changed.connect(_refresh_ui)
        game_manager.research_completed.connect(func(_id): _refresh_ui())
        game_manager.weather_changed.connect(_refresh_ui)
        game_manager.troop_upgrades_changed.connect(_refresh_ui)
        game_manager.convoys_updated.connect(_refresh_ui)
        attack_btn.pressed.connect(_on_attack)

# ══ إصلاح الخطأ 3: إنشاء أزرار اختيار القوات ديناميكياً ══
func _build_troop_selector_ui() -> void:
        # إزالة التسمية القديمة واستبدالها بـ VBox يحتوي تسمية + أزرار + زر مسح
        var old_label = troop_panel.get_node_or_null("TroopLabel")
        if old_label:
                troop_panel.remove_child(old_label)
                old_label.queue_free()

        var vbox = VBoxContainer.new()
        vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        vbox.add_theme_constant_override("separation", 4)

        # التسمية
        var label = Label.new()
        label.text = "اختر القوات للنشر:"
        label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
        label.add_theme_font_size_override("font_size", 10)
        vbox.add_child(label)

        # صف أزرار القوات + زر مسح
        _troop_hbox = HBoxContainer.new()
        _troop_hbox.add_theme_constant_override("separation", 6)
        _troop_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
        _troop_hbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER

        for troop_type in range(3):
                var btn = Button.new()
                btn.custom_minimum_size = Vector2(105, 34)
                btn.set_meta("troop_type", troop_type)
                var style = StyleBoxFlat.new()
                style.bg_color = Color(0.08, 0.12, 0.22, 0.9)
                style.border_color = Color(0.3, 0.3, 0.4, 0.5)
                style.set_border_width_all(1)
                style.set_corner_radius_all(6)
                btn.add_theme_stylebox_override("normal", style)
                btn.add_theme_font_size_override("font_size", 11)
                btn.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 1))
                btn.pressed.connect(_on_troop_selected.bind(troop_type))
                _troop_hbox.add_child(btn)

        # زر مسح النشر
        var clear_btn = Button.new()
        clear_btn.text = "🗑️ مسح"
        clear_btn.custom_minimum_size = Vector2(65, 34)
        var clear_style = StyleBoxFlat.new()
        clear_style.bg_color = Color(0.15, 0.05, 0.05, 0.9)
        clear_style.border_color = Color(0.5, 0.2, 0.2, 0.5)
        clear_style.set_border_width_all(1)
        clear_style.set_corner_radius_all(6)
        clear_btn.add_theme_stylebox_override("normal", clear_style)
        clear_btn.add_theme_font_size_override("font_size", 11)
        clear_btn.add_theme_color_override("font_color", Color(0.9, 0.5, 0.5, 1))
        clear_btn.pressed.connect(_on_clear_deployment)
        _troop_hbox.add_child(clear_btn)

        vbox.add_child(_troop_hbox)
        troop_panel.add_child(vbox)

# ══ إصلاح الخطأ 3: أزرار تغيير التضاريس والطقس ══
func _build_terrain_weather_buttons() -> void:
        # زر تدوير التضاريس
        var terrain_box = $TopPanel/TerrainBox/HBox
        var terrain_btn = Button.new()
        terrain_btn.text = "🔄"
        terrain_btn.custom_minimum_size = Vector2(24, 24)
        terrain_btn.add_theme_font_size_override("font_size", 10)
        terrain_btn.pressed.connect(_on_terrain_next)
        terrain_box.add_child(terrain_btn)

        # زر تدوير الطقس
        var weather_box = $TopPanel/WeatherBox/HBox
        var weather_btn = Button.new()
        weather_btn.text = "🔄"
        weather_btn.custom_minimum_size = Vector2(24, 24)
        weather_btn.add_theme_font_size_override("font_size", 10)
        weather_btn.pressed.connect(_on_weather_next)
        weather_box.add_child(weather_btn)

func _refresh_ui() -> void:
        power_label.text = str(game_manager.get_deployed_power())
        terrain_label.text = game_manager.terrain_names[game_manager.selected_terrain]
        weather_label.text = game_manager.weather_names[game_manager.current_weather]
        morale_label.text = "%d%%" % int(game_manager.player_morale)
        # معلومات الطقس الديناميكي
        var forecast = game_manager.get_weather_forecast()
        var weather_box = $TopPanel/WeatherBox/HBox
        for ch in weather_box.get_children():
                if ch is Label and ch.text.find("تحديث") >= 0:
                        weather_box.remove_child(ch)
                        ch.queue_free()
        var fc_label = Label.new()
        fc_label.text = " [%s]" % forecast
        fc_label.add_theme_font_size_override("font_size", 9)
        fc_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
        weather_box.add_child(fc_label)
        # تحديث أزرار القوات بالنص والعدد
        if _troop_hbox:
                for btn in _troop_hbox.get_children():
                        if btn is Button and btn.has_meta("troop_type"):
                                var ttype: int = btn.get_meta("troop_type")
                                var count: int = game_manager.get_total_troops_by_type(ttype)
                                # حساب المنشور فعلياً
                                var deployed: int = 0
                                for w in game_manager.deployment:
                                        for s in w:
                                                if s["type"] == ttype:
                                                        deployed += s["count"]
                                var display := "%s %s (%d" % [game_manager.troop_icons[ttype], game_manager.troop_names[ttype], count]
                                if deployed > 0:
                                        display += "/%d" % deployed
                                display += ")"
                                btn.text = display
                                # تلوين الأزرار حسب التوفر
                                if count >= 5:
                                        btn.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 1))
                                else:
                                        btn.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4, 1))
        # تحديث الموجات
        _refresh_waves()

func _refresh_waves() -> void:
        for child in waves_container.get_children():
                child.queue_free()
        for wave_idx in range(3):
                var wave_box = _create_wave_box(wave_idx)
                waves_container.add_child(wave_box)

func _create_wave_box(wave_idx: int) -> PanelContainer:
        var panel = PanelContainer.new()
        var style = StyleBoxFlat.new()
        style.bg_color = Color(0.05, 0.08, 0.16, 0.8)
        style.border_color = Color(0.2, 0.2, 0.3, 0.5)
        style.set_border_width_all(1)
        style.set_corner_radius_all(8)
        style.set_content_margin_all(8)
        panel.add_theme_stylebox_override("panel", style)
        var vbox = VBoxContainer.new()
        vbox.add_theme_constant_override("separation", 6)
        # عنوان الموجة
        var wave_mult := 1.5 if wave_idx > 0 else 1.0
        var title = Label.new()
        title.text = "الموجة %d (x%.1f)" % [(wave_idx + 1), wave_mult]
        title.add_theme_font_size_override("font_size", 13)
        title.add_theme_color_override("font_color", Color(0.788, 0.635, 0.153, 1))
        vbox.add_child(title)
        # خانتان مع زر إزالة
        var hbox = HBoxContainer.new()
        hbox.add_theme_constant_override("separation", 8)
        for slot_idx in range(2):
                var slot_btn = Button.new()
                slot_btn.custom_minimum_size = Vector2(155, 44)
                var slot_data: Dictionary = game_manager.deployment[wave_idx][slot_idx]
                if slot_data["type"] >= 0:
                        slot_btn.text = "%s %s x%d" % [
                                game_manager.troop_icons[slot_data["type"]],
                                game_manager.troop_names[slot_data["type"]],
                                slot_data["count"]
                        ]
                        # ربط الضغط المطول لإزالة الخانة
                        var w_idx := wave_idx
                        var s_idx := slot_idx
                        slot_btn.pressed.connect(func():
                                game_manager.remove_from_slot(w_idx, s_idx)
                                _refresh_ui()
                        )
                else:
                        slot_btn.text = "— فارغ —"
                        slot_btn.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3, 1))
                var btn_style = StyleBoxFlat.new()
                btn_style.bg_color = Color(0.08, 0.12, 0.22, 0.8)
                btn_style.border_color = Color(0.3, 0.3, 0.4, 0.5)
                btn_style.set_border_width_all(1)
                btn_style.set_corner_radius_all(6)
                slot_btn.add_theme_stylebox_override("normal", btn_style)
                slot_btn.add_theme_font_size_override("font_size", 12)
                hbox.add_child(slot_btn)
        vbox.add_child(hbox)
        panel.add_child(vbox)
        return panel

func _on_troop_selected(troop_type: int) -> void:
        # تعبئة أول خانة فارغة أو إضافة لنفس النوع
        for w in range(3):
                for s in range(2):
                        var slot: Dictionary = game_manager.deployment[w][s]
                        if slot["type"] == -1:
                                game_manager.assign_to_slot(w, s, troop_type)
                                _refresh_ui()
                                return
                        elif slot["type"] == troop_type:
                                game_manager.assign_to_slot(w, s, troop_type)
                                _refresh_ui()
                                return

func _on_terrain_next() -> void:
        game_manager.selected_terrain = (game_manager.selected_terrain + 1) % 5
        _refresh_ui()

func _on_weather_next() -> void:
        game_manager.current_weather = (game_manager.current_weather + 1) % 6
        _refresh_ui()

func _on_clear_deployment() -> void:
        game_manager.clear_deployment()
        _refresh_ui()

func _on_attack() -> void:
        if game_manager.get_deployed_count() == 0:
                attack_btn.text = "❌ نشر القوات أولاً!"
                await get_tree().create_timer(1.5).timeout
                attack_btn.text = "⚔️ هجوم!"
                return
        attack_btn.text = "⚔️ جاري الهجوم..."
        # المعركة تبدأ من الخريطة — هنا معركة تدريبية
        var enemy_power = 200 + randi() % 300
        game_manager.start_battle(enemy_power, "قطاع أمامي")
