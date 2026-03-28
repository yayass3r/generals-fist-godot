extends Control
## ═══════════════════════════════════════════════════════════════
## الثكنات — تجنيد القوات + الضباط + البحث والتطوير
## ═══════════════════════════════════════════════════════════════

@onready var tab_barracks: Button = $TabBar/HBox/TabBarracks
@onready var tab_officers: Button = $TabBar/HBox/TabOfficers
@onready var tab_upgrades: Button = $TabBar/HBox/TabUpgrades
@onready var tab_research: Button = $TabBar/HBox/TabResearch
@onready var barracks_content: ScrollContainer = $BarracksContent
@onready var officers_content: ScrollContainer = $OfficersContent
@onready var upgrades_content: ScrollContainer = $UpgradesContent
@onready var research_content: ScrollContainer = $ResearchContent

func _ready() -> void:
        tab_barracks.pressed.connect(func(): _show_tab("barracks"))
        tab_officers.pressed.connect(func(): _show_tab("officers"))
        tab_upgrades.pressed.connect(func(): _show_tab("upgrades"))
        tab_research.pressed.connect(func(): _show_tab("research"))
        game_manager.troops_changed.connect(_build_barracks)
        game_manager.research_completed.connect(_on_research_done)
        game_manager.officers_changed.connect(_build_officers)
        game_manager.resources_changed.connect(func(): _build_officers(); _build_upgrades())
        game_manager.troop_upgrades_changed.connect(_build_upgrades)
        _build_barracks()
        _build_officers()
        _build_upgrades()
        _build_research()
        _show_tab("barracks")

func _show_tab(tab: String) -> void:
        barracks_content.visible = tab == "barracks"
        officers_content.visible = tab == "officers"
        upgrades_content.visible = tab == "upgrades"
        research_content.visible = tab == "research"
        tab_barracks.modulate = Color(0.3, 0.9, 0.4) if tab == "barracks" else Color(0.4, 0.4, 0.4)
        tab_officers.modulate = Color(0.9, 0.8, 0.2) if tab == "officers" else Color(0.4, 0.4, 0.4)
        tab_upgrades.modulate = Color(0.8, 0.4, 0.9) if tab == "upgrades" else Color(0.4, 0.4, 0.4)
        tab_research.modulate = Color(0.251, 0.627, 0.878) if tab == "research" else Color(0.4, 0.4, 0.4)

# ═══════════════════════════════════════
# تبويب القوات
# ═══════════════════════════════════════

func _build_barracks() -> void:
        for child in barracks_content.get_children():
                child.queue_free()
        var vbox = VBoxContainer.new()
        vbox.add_theme_constant_override("separation", 10)
        barracks_content.add_child(vbox)
        var title = Label.new()
        title.text = "🏰 التشكيلات العسكرية"
        title.add_theme_font_size_override("font_size", 16)
        title.add_theme_color_override("font_color", Color(0.788, 0.635, 0.153, 1))
        vbox.add_child(title)
        for company in game_manager.companies:
                var card = _create_company_card(company)
                vbox.add_child(card)

func _create_company_card(company: Dictionary) -> PanelContainer:
        var panel = PanelContainer.new()
        var style = StyleBoxFlat.new()
        style.bg_color = Color(0.05, 0.08, 0.16, 0.9)
        style.border_color = Color(0.2, 0.25, 0.35, 0.5)
        style.set_border_width_all(1)
        style.set_corner_radius_all(10)
        style.set_content_margin_all(10)
        panel.add_theme_stylebox_override("panel", style)
        var vbox = VBoxContainer.new()
        vbox.add_theme_constant_override("separation", 6)
        var header = HBoxContainer.new()
        var name_label = Label.new()
        var ttype: int = company["type"]
        name_label.text = "%s %s" % [game_manager.troop_icons[ttype], game_manager.troop_names[ttype]]
        name_label.add_theme_font_size_override("font_size", 15)
        name_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1))
        header.add_child(name_label)
        var count_label = Label.new()
        var total: int = game_manager.get_company_troop_count(company)
        count_label.text = "القوات: %d/100" % total
        count_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
        count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        header.add_child(count_label)
        vbox.add_child(header)
        var stats: Dictionary = game_manager.troop_stats[ttype]
        var info = Label.new()
        info.text = "هجوم: %d | دفاع: %d | تكلفة: %d⚙️ + %d⛽" % [stats["attack"], stats["defense"], stats["cost_scrap"], stats["cost_fuel"]]
        info.add_theme_font_size_override("font_size", 11)
        info.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4, 1))
        vbox.add_child(info)
        var btn_box = HBoxContainer.new()
        btn_box.add_theme_constant_override("separation", 6)
        var add_btn = Button.new()
        add_btn.text = "+ فصيلة"
        add_btn.custom_minimum_size = Vector2(100, 36)
        add_btn.add_theme_font_size_override("font_size", 11)
        var add_style = StyleBoxFlat.new()
        add_style.bg_color = Color(0.2, 0.3, 0.5, 0.8)
        add_style.set_corner_radius_all(6)
        add_btn.add_theme_stylebox_override("normal", add_style)
        add_btn.pressed.connect(func(): game_manager.add_squad(company["id"]))
        btn_box.add_child(add_btn)
        var recruit_btn = Button.new()
        recruit_btn.text = "+5 تجنيد"
        recruit_btn.custom_minimum_size = Vector2(100, 36)
        recruit_btn.add_theme_font_size_override("font_size", 11)
        var rec_style = StyleBoxFlat.new()
        rec_style.bg_color = Color(0.2, 0.5, 0.3, 0.8)
        rec_style.set_corner_radius_all(6)
        recruit_btn.add_theme_stylebox_override("normal", rec_style)
        recruit_btn.pressed.connect(func():
                var recruited: int = game_manager.recruit_troops(company["id"], 0, 5)
                if recruited > 0:
                        _build_barracks()
        )
        btn_box.add_child(recruit_btn)
        vbox.add_child(btn_box)
        for i in range(company["squads"].size()):
                var squad: Dictionary = company["squads"][i]
                var sq_label = Label.new()
                sq_label.text = "  📋 فصيلة %d: %d/10 مقاتل" % [i + 1, squad["size"]]
                sq_label.add_theme_font_size_override("font_size", 11)
                sq_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
                vbox.add_child(sq_label)
        panel.add_child(vbox)
        return panel

# ═══════════════════════════════════════
# تبويب الضباط
# ═══════════════════════════════════════

func _build_officers() -> void:
        for child in officers_content.get_children():
                child.queue_free()
        var vbox = VBoxContainer.new()
        vbox.add_theme_constant_override("separation", 10)
        officers_content.add_child(vbox)
        # عنوان
        var title = Label.new()
        title.text = "🎖️ سلسلة القيادة"
        title.add_theme_font_size_override("font_size", 16)
        title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2, 1))
        vbox.add_child(title)
        var desc = Label.new()
        desc.text = "عيّن ضباطاً لتحسين قدرات قواتك في المعركة"
        desc.add_theme_font_size_override("font_size", 11)
        desc.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
        vbox.add_child(desc)
        # عدد الضباط النشطين
        var active_count = game_manager.get_officer_active_count()
        var count_label = Label.new()
        count_label.text = "الضباط النشطون: %d/4" % active_count
        count_label.add_theme_font_size_override("font_size", 12)
        count_label.add_theme_color_override("font_color", Color(0.251, 0.627, 0.878, 1))
        vbox.add_child(count_label)
        # بطاقات الضباط
        for officer in game_manager.officers:
                var card = _create_officer_card(officer)
                vbox.add_child(card)

func _create_officer_card(officer: Dictionary) -> PanelContainer:
        var panel = PanelContainer.new()
        var is_active: bool = officer["active"]
        var style = StyleBoxFlat.new()
        if is_active:
                style.bg_color = Color(0.08, 0.14, 0.08, 0.9)
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
        # الرأس - الأيقونة + الاسم + المستوى
        var header = HBoxContainer.new()
        var icon_label = Label.new()
        icon_label.text = officer["icon"]
        icon_label.add_theme_font_size_override("font_size", 24)
        header.add_child(icon_label)
        var name_box = VBoxContainer.new()
        name_box.add_theme_constant_override("separation", -2)
        name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        var name_label = Label.new()
        name_label.text = officer["name"]
        name_label.add_theme_font_size_override("font_size", 15)
        if is_active:
                name_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4, 1))
        else:
                name_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
        name_box.add_child(name_label)
        var level_label = Label.new()
        if is_active:
                level_label.text = "المستوى %d/%d" % [officer["level"], officer["max_level"]]
                level_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2, 1))
        else:
                level_label.text = "غير معيّن"
                level_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
        level_label.add_theme_font_size_override("font_size", 11)
        name_box.add_child(level_label)
        header.add_child(name_box)
        vbox.add_child(header)
        # الوصف
        var desc_label = Label.new()
        desc_label.text = officer["desc"]
        desc_label.add_theme_font_size_override("font_size", 11)
        desc_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4, 1))
        vbox.add_child(desc_label)
        # التأثير الحالي
        if is_active:
                var current_effect: float = officer["effect_per_level"] * officer["level"]
                var effect_label = Label.new()
                var stat_name = "هجوم" if officer["effect_type"] in ["attack", "all_attack"] else "دفاع"
                if officer["troop_type"] == -1:
                        effect_label.text = "📊 التأثير الحالي: +%d%% %s لجميع القوات" % [int(current_effect * 100), stat_name]
                else:
                        var troop_name = ["المشاة", "المدرعات", "الطيران"][officer["troop_type"]]
                        effect_label.text = "📊 التأثير الحالي: +%d%% %s %s" % [int(current_effect * 100), stat_name, troop_name]
                effect_label.add_theme_font_size_override("font_size", 11)
                effect_label.add_theme_color_override("font_color", Color(0.251, 0.627, 0.878, 1))
                vbox.add_child(effect_label)
        # شريط التقدم
        if is_active:
                var prog_hbox = HBoxContainer.new()
                var prog_label = Label.new()
                prog_label.text = "تقدم: "
                prog_label.add_theme_font_size_override("font_size", 10)
                prog_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
                prog_hbox.add_child(prog_label)
                for lvl in range(officer["max_level"]):
                        var dot = Label.new()
                        if lvl < officer["level"]:
                                dot.text = "🟢"
                        else:
                                dot.text = "⚫"
                        dot.add_theme_font_size_override("font_size", 8)
                        prog_hbox.add_child(dot)
                vbox.add_child(prog_hbox)
        # الأزرار
        var btn_box = HBoxContainer.new()
        btn_box.add_theme_constant_override("separation", 8)
        if not is_active:
                var hire_btn = Button.new()
                var cost: int = officer["cost"]
                var can_afford: bool = game_manager.scrap >= cost
                hire_btn.text = "🎖️ تعيين (%d⚙️)" % cost
                hire_btn.custom_minimum_size = Vector2(180, 38)
                hire_btn.add_theme_font_size_override("font_size", 12)
                var hire_style = StyleBoxFlat.new()
                if can_afford:
                        hire_style.bg_color = Color(0.251, 0.627, 0.878, 1)
                else:
                        hire_style.bg_color = Color(0.2, 0.2, 0.25, 0.8)
                hire_style.set_corner_radius_all(6)
                hire_btn.add_theme_stylebox_override("normal", hire_style)
                if can_afford:
                        hire_btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
                else:
                        hire_btn.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4, 1))
                hire_btn.pressed.connect(func():
                        game_manager.hire_officer(officer["id"])
                        _build_officers()
                )
                btn_box.add_child(hire_btn)
        else:
                # زر ترقية
                if officer["level"] < officer["max_level"]:
                        var upg_cost: int = int(officer["cost"] * pow(1.3, officer["level"]))
                        var can_upg: bool = game_manager.scrap >= upg_cost
                        var upg_btn = Button.new()
                        upg_btn.text = "⬆️ ترقية (%d⚙️)" % upg_cost
                        upg_btn.custom_minimum_size = Vector2(180, 38)
                        upg_btn.add_theme_font_size_override("font_size", 12)
                        var upg_style = StyleBoxFlat.new()
                        if can_upg:
                                upg_style.bg_color = Color(0.2, 0.7, 0.3, 1)
                        else:
                                upg_style.bg_color = Color(0.2, 0.2, 0.25, 0.8)
                        upg_style.set_corner_radius_all(6)
                        upg_btn.add_theme_stylebox_override("normal", upg_style)
                        if can_upg:
                                upg_btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
                        else:
                                upg_btn.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4, 1))
                        upg_btn.pressed.connect(func():
                                game_manager.upgrade_officer(officer["id"])
                                _build_officers()
                        )
                        btn_box.add_child(upg_btn)
                else:
                        var max_label = Label.new()
                        max_label.text = "🏆 المستوى الأقصى!"
                        max_label.add_theme_font_size_override("font_size", 12)
                        max_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2, 1))
                        btn_box.add_child(max_label)
        vbox.add_child(btn_box)
        panel.add_child(vbox)
        return panel

# ═══════════════════════════════════════
# تبويب ترقية القوات
# ═══════════════════════════════════════

func _build_upgrades() -> void:
        for child in upgrades_content.get_children():
                child.queue_free()
        var vbox = VBoxContainer.new()
        vbox.add_theme_constant_override("separation", 10)
        upgrades_content.add_child(vbox)
        # عنوان
        var title = Label.new()
        title.text = "⬆️ ترقية القوات"
        title.add_theme_font_size_override("font_size", 16)
        title.add_theme_color_override("font_color", Color(0.8, 0.4, 0.9, 1))
        vbox.add_child(title)
        var desc = Label.new()
        desc.text = "حسّن إحصائيات أنواع القوات المختلفة"
        desc.add_theme_font_size_override("font_size", 11)
        desc.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
        vbox.add_child(desc)
        # بطاقات ترقية كل نوع
        for troop_type in range(3):
                var card = _create_upgrade_card(troop_type)
                vbox.add_child(card)
        # معلومات القوافل
        var sep = Label.new()
        sep.text = "────────────────────"
        sep.add_theme_color_override("font_color", Color(0.2, 0.2, 0.3, 1))
        vbox.add_child(sep)
        var conv_title = Label.new()
        conv_title.text = "🚛 قوافل الإمداد"
        conv_title.add_theme_font_size_override("font_size", 16)
        conv_title.add_theme_color_override("font_color", Color(0.251, 0.627, 0.878, 1))
        vbox.add_child(conv_title)
        # قوافل نشطة
        for c in game_manager.active_convoys:
                var elapsed: float = c["time_total"] - c["time_remaining"]
                var pct: float = clampf(elapsed / c["time_total"], 0.0, 1.0)
                var cl = Label.new()
                cl.text = "📦 قافلة: %d⚙️ %d⛽ %d📋 — %d%%" % [c["scrap"], c["fuel_carry"], c["intel"], int(pct * 100)]
                cl.add_theme_font_size_override("font_size", 11)
                cl.add_theme_color_override("font_color", Color(0.788, 0.635, 0.153, 1))
                vbox.add_child(cl)
        if game_manager.active_convoys.is_empty():
                var no_conv = Label.new()
                no_conv.text = "لا توجد قوافل نشطة"
                no_conv.add_theme_font_size_override("font_size", 11)
                no_conv.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4, 1))
                vbox.add_child(no_conv)
        # زر إرسال قافلة
        var conv_box = HBoxContainer.new()
        conv_box.add_theme_constant_override("separation", 6)
        var send_btn = Button.new()
        send_btn.text = "🚛 أرسل قافلة (-20⛽)"
        send_btn.custom_minimum_size = Vector2(200, 38)
        send_btn.add_theme_font_size_override("font_size", 12)
        var s_style = StyleBoxFlat.new()
        s_style.bg_color = Color(0.251, 0.627, 0.878, 1)
        s_style.set_corner_radius_all(6)
        send_btn.add_theme_stylebox_override("normal", s_style)
        send_btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
        send_btn.pressed.connect(func():
                game_manager.launch_convoy(50, 25, 10)
                _build_upgrades()
        )
        conv_box.add_child(send_btn)
        vbox.add_child(conv_box)
        # إحصائيات القوافل
        var stats_label = Label.new()
        stats_label.text = "القوافل المكتملة: %d | النشطة: %d/3" % [game_manager.completed_convoys_count, game_manager.get_active_convoy_count()]
        stats_label.add_theme_font_size_override("font_size", 11)
        stats_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
        vbox.add_child(stats_label)

func _create_upgrade_card(troop_type: int) -> PanelContainer:
        var panel = PanelContainer.new()
        var info: Dictionary = game_manager.troop_upgrades.get(troop_type, {})
        var level: int = info.get("level", 0)
        var max_level: int = info.get("max_level", 5)
        var style = StyleBoxFlat.new()
        if level >= max_level:
                style.bg_color = Color(0.08, 0.18, 0.08, 0.9)
                style.border_color = Color(0.3, 0.8, 0.4, 0.4)
        else:
                style.bg_color = Color(0.05, 0.08, 0.16, 0.9)
                style.border_color = Color(0.8, 0.4, 0.9, 0.3)
        style.set_border_width_all(1)
        style.set_corner_radius_all(10)
        style.set_content_margin_all(10)
        panel.add_theme_stylebox_override("panel", style)
        var vbox = VBoxContainer.new()
        vbox.add_theme_constant_override("separation", 6)
        # الرأس
        var header = HBoxContainer.new()
        var icon_l = Label.new()
        icon_l.text = info.get("icon", "🔫")
        icon_l.add_theme_font_size_override("font_size", 24)
        header.add_child(icon_l)
        var name_box = VBoxContainer.new()
        name_box.add_theme_constant_override("separation", -2)
        name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        var name_l = Label.new()
        name_l.text = info.get("name", "ترقية")
        name_l.add_theme_font_size_override("font_size", 15)
        name_l.add_theme_color_override("font_color", Color(0.8, 0.4, 0.9, 1))
        name_box.add_child(name_l)
        var lvl_l = Label.new()
        lvl_l.text = "المستوى %d/%d" % [level, max_level]
        lvl_l.add_theme_font_size_override("font_size", 11)
        lvl_l.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2, 1))
        name_box.add_child(lvl_l)
        header.add_child(name_box)
        vbox.add_child(header)
        # الوصف
        var desc_l = Label.new()
        desc_l.text = info.get("desc", "")
        desc_l.add_theme_font_size_override("font_size", 11)
        desc_l.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4, 1))
        vbox.add_child(desc_l)
        # التأثير الحالي
        if level > 0:
                var atk_b: float = info.get("bonus_attack", 0.0)
                var def_b: float = info.get("bonus_defense", 0.0)
                var effect_l = Label.new()
                effect_l.text = "📊 حالياً: +%d%% هجوم | +%d%% دفاع" % [int(atk_b * 100), int(def_b * 100)]
                effect_l.add_theme_font_size_override("font_size", 11)
                effect_l.add_theme_color_override("font_color", Color(0.251, 0.627, 0.878, 1))
                vbox.add_child(effect_l)
        # زر الترقية
        if level < max_level:
                var cost: int = game_manager.get_troop_upgrade_cost(troop_type)
                var can: bool = game_manager.scrap >= cost
                var btn = Button.new()
                btn.text = "⬆️ ترقية (%d⚙️)" % cost
                btn.custom_minimum_size = Vector2(180, 38)
                btn.add_theme_font_size_override("font_size", 12)
                var b_style = StyleBoxFlat.new()
                b_style.bg_color = Color(0.8, 0.4, 0.9, 1) if can else Color(0.2, 0.2, 0.25, 0.8)
                b_style.set_corner_radius_all(6)
                btn.add_theme_stylebox_override("normal", b_style)
                btn.add_theme_color_override("font_color", Color(1, 1, 1, 1) if can else Color(0.4, 0.4, 0.4, 1))
                var tt = troop_type
                btn.pressed.connect(func():
                        game_manager.upgrade_troops(tt)
                        _build_upgrades()
                )
                vbox.add_child(btn)
        else:
                var max_l = Label.new()
                max_l.text = "🏆 المستوى الأقصى!"
                max_l.add_theme_font_size_override("font_size", 12)
                max_l.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2, 1))
                vbox.add_child(max_l)
        panel.add_child(vbox)
        return panel

# ═══════════════════════════════════════
# تبويب البحث
# ═══════════════════════════════════════

func _build_research() -> void:
        for child in research_content.get_children():
                child.queue_free()
        var vbox = VBoxContainer.new()
        vbox.add_theme_constant_override("separation", 8)
        research_content.add_child(vbox)
        var title = Label.new()
        title.text = "🔬 البحث والتطوير"
        title.add_theme_font_size_override("font_size", 16)
        title.add_theme_color_override("font_color", Color(0.251, 0.627, 0.878, 1))
        vbox.add_child(title)
        if game_manager.research_in_progress != "":
                var prog_label = Label.new()
                var pct: int = int(game_manager.research_progress)
                prog_label.text = "⏳ جاري البحث... %d%%" % pct
                prog_label.add_theme_font_size_override("font_size", 13)
                prog_label.add_theme_color_override("font_color", Color(0.788, 0.635, 0.153, 1))
                vbox.add_child(prog_label)
        for tech in game_manager.tech_tree:
                var card = _create_tech_card(tech)
                vbox.add_child(card)

func _create_tech_card(tech: Dictionary) -> PanelContainer:
        var panel = PanelContainer.new()
        var completed: bool = tech["id"] in game_manager.completed_techs
        var can_do: bool = game_manager.can_research(tech["id"])
        var style = StyleBoxFlat.new()
        if completed:
                style.bg_color = Color(0.1, 0.2, 0.1, 0.9)
                style.border_color = Color(0.2, 0.7, 0.3, 0.5)
        elif can_do:
                style.bg_color = Color(0.05, 0.08, 0.16, 0.9)
                style.border_color = Color(0.251, 0.627, 0.878, 0.3)
        else:
                style.bg_color = Color(0.04, 0.04, 0.06, 0.9)
                style.border_color = Color(0.15, 0.15, 0.2, 0.3)
        style.set_border_width_all(1)
        style.set_corner_radius_all(8)
        style.set_content_margin_all(8)
        panel.add_theme_stylebox_override("panel", style)
        var vbox = VBoxContainer.new()
        vbox.add_theme_constant_override("separation", 4)
        var header = Label.new()
        header.text = "%s %s (الطبقة %d)" % [tech["icon"], tech["name"], tech["tier"]]
        header.add_theme_font_size_override("font_size", 14)
        if completed:
                header.add_theme_color_override("font_color", Color(0.2, 0.8, 0.3, 1))
        else:
                header.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
        vbox.add_child(header)
        var desc = Label.new()
        desc.text = tech["desc"]
        desc.add_theme_font_size_override("font_size", 11)
        desc.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4, 1))
        vbox.add_child(desc)
        var cost = Label.new()
        cost.text = "التكلفة: %d⚙️ + %d📋 | الوقت: %dث" % [tech["cost_scrap"], tech["cost_intel"], int(tech["time"])]
        cost.add_theme_font_size_override("font_size", 11)
        cost.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
        vbox.add_child(cost)
        if not completed and can_do:
                var btn = Button.new()
                btn.text = "🔬 بحث"
                btn.custom_minimum_size = Vector2(100, 34)
                btn.add_theme_font_size_override("font_size", 12)
                var btn_style = StyleBoxFlat.new()
                btn_style.bg_color = Color(0.251, 0.627, 0.878, 1)
                btn_style.set_corner_radius_all(6)
                btn.add_theme_stylebox_override("normal", btn_style)
                btn.pressed.connect(func():
                        game_manager.start_research(tech["id"])
                        _build_research()
                )
                vbox.add_child(btn)
        elif completed:
                var done = Label.new()
                done.text = "✅ مكتمل"
                done.add_theme_color_override("font_color", Color(0.2, 0.8, 0.3, 1))
                done.add_theme_font_size_override("font_size", 12)
                vbox.add_child(done)
        panel.add_child(vbox)
        return panel

func _on_research_done(_tech_id: String) -> void:
        _build_research()
