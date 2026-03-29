extends Control
## ═══════════════════════════════════════════════════════════════
## مشهد المعركة — قتال实时 مع تكتيكات + تأثيرات بصرية
## ═══════════════════════════════════════════════════════════════

@onready var enemy_hp_bar: ProgressBar = $TopSection/EnemyBox/HBox/ProgressBar
@onready var enemy_label: Label = $TopSection/EnemyBox/HBox/EnemyLabel
@onready var player_hp_bar: ProgressBar = $PlayerSection/PlayerBox/HBox/ProgressBar
@onready var player_label: Label = $PlayerSection/PlayerBox/HBox/PlayerLabel
@onready var log_text: RichTextLabel = $LogSection/LogText
@onready var smoke_btn: Button = $TacticsSection/HBox/SmokeBtn
@onready var air_btn: Button = $TacticsSection/HBox/AirBtn
@onready var retreat_btn: Button = $TacticsSection/HBox/RetreatBtn
@onready var result_panel: PanelContainer = $ResultPanel
@onready var result_title: Label = $ResultPanel/VBox/ResultTitle
@onready var result_loot: Label = $ResultPanel/VBox/ResultLoot
@onready var result_btn: Button = $ResultPanel/VBox/ResultBtn
@onready var vs_label: Label = $VSLabel

# متغيرات التأثيرات البصرية
var shake_offset: Vector2 = Vector2.ZERO
var shake_intensity: float = 0.0
var prev_enemy_hp: float = -1.0
var prev_player_hp: float = -1.0
var enemy_flash_timer: float = 0.0
var player_flash_timer: float = 0.0
var battle_fade_alpha: float = 0.0
var damage_numbers: Array = []  # [{label: Label, timer: float, velocity: Vector2}]

func _ready() -> void:
        game_manager.battle_updated.connect(_on_battle_update)
        game_manager.battle_ended.connect(_on_battle_end)
        smoke_btn.pressed.connect(func(): game_manager.activate_tactic("smoke"))
        air_btn.pressed.connect(func(): game_manager.activate_tactic("air_support"))
        retreat_btn.pressed.connect(func(): game_manager.activate_tactic("retreat"))
        result_btn.pressed.connect(_on_result_close)
        result_panel.visible = false
        # تعيين HP القصوى
        if game_manager.battle_data.has("enemy_power"):
                enemy_hp_bar.max_value = game_manager.battle_data["enemy_power"]
                enemy_hp_bar.value = game_manager.battle_data["enemy_current_hp"]
        if game_manager.battle_data.has("player_power"):
                player_hp_bar.max_value = game_manager.battle_data["player_power"]
                player_hp_bar.value = game_manager.battle_data["player_current_hp"]
        # تعيين HP المبدئي
        prev_enemy_hp = enemy_hp_bar.value
        prev_player_hp = player_hp_bar.value
        # تأثير الظهور
        battle_fade_alpha = 1.0
        # تغيير حجم VSLabel
        vs_label.scale = Vector2(0.1, 0.1)

func _process(delta: float) -> void:
        if not game_manager.battle_active:
                return
        var data: Dictionary = game_manager.battle_data
        if data.is_empty():
                return
        # تحديث أشرطة HP
        enemy_hp_bar.max_value = data["enemy_power"]
        enemy_hp_bar.value = maxi(0, data["enemy_current_hp"])
        player_hp_bar.max_value = data["player_power"]
        player_hp_bar.value = maxi(0, data["player_current_hp"])
        # تحديث النصوص
        var enemy_pct: float = (data["enemy_current_hp"] / data["enemy_power"]) * 100
        var player_pct: float = (data["player_current_hp"] / data["player_power"]) * 100
        enemy_label.text = "👾 عدو: %d%%" % int(enemy_pct)
        player_label.text = "👤 أنت: %d%%" % int(player_pct)

        # ─── تأثيرات بصرية ───
        # تأثير وميض شريط HP العدو (عندما يخسر HP)
        if prev_enemy_hp >= 0 and data["enemy_current_hp"] < prev_enemy_hp:
                var dmg: float = prev_enemy_hp - data["enemy_current_hp"]
                if dmg > data["enemy_power"] * 0.02:
                        enemy_flash_timer = 0.3
                        _spawn_damage_number(data["enemy_current_hp"], data["enemy_power"], dmg, true)
        # تأثير وميض شريط HP اللاعب
        if prev_player_hp >= 0 and data["player_current_hp"] < prev_player_hp:
                var dmg: float = prev_player_hp - data["player_current_hp"]
                if dmg > data["player_power"] * 0.02:
                        player_flash_timer = 0.3
                        shake_intensity = mini(8.0, dmg * 0.01)
                        _spawn_damage_number(data["player_current_hp"], data["player_power"], dmg, false)

        prev_enemy_hp = data["enemy_current_hp"]
        prev_player_hp = data["player_current_hp"]

        # تحديث وميض شريط HP
        if enemy_flash_timer > 0:
                enemy_flash_timer -= delta
                enemy_hp_bar.modulate = Color(1.5, 0.3, 0.3, 1.0)
        else:
                enemy_hp_bar.modulate = Color(1.0, 1.0, 1.0, 1.0)
        if player_flash_timer > 0:
                player_flash_timer -= delta
                player_hp_bar.modulate = Color(1.5, 0.3, 0.3, 1.0)
        else:
                player_hp_bar.modulate = Color(1.0, 1.0, 1.0, 1.0)

        # ألوان شريط HP حسب النسبة
        _update_hp_bar_color(enemy_hp_bar, enemy_pct)
        _update_hp_bar_color(player_hp_bar, player_pct)

        # تأثير الاهتزاز
        if shake_intensity > 0.1:
                shake_offset = Vector2(
                        randf_range(-shake_intensity, shake_intensity),
                        randf_range(-shake_intensity, shake_intensity)
                )
                shake_intensity *= 0.9
        else:
                shake_intensity = 0.0
                shake_offset = Vector2.ZERO

        # تحديث أرقام الضرر العائمة
        for i in range(damage_numbers.size() - 1, -1, -1):
                var dn: Dictionary = damage_numbers[i]
                dn["timer"] -= delta
                dn["label"].position += dn["velocity"] * delta
                dn["velocity"].y -= 30.0 * delta  # صعود
                if dn["timer"] <= 0:
                        dn["label"].queue_free()
                        damage_numbers.remove_at(i)
                else:
                        var alpha: float = mini(1.0, dn["timer"] * 3.0)
                        dn["label"].modulate.a = alpha

        # تأثير ظهور المعركة
        if battle_fade_alpha > 0:
                battle_fade_alpha -= delta * 3.0
                battle_fade_alpha = maxi(0.0, battle_fade_alpha)

        # تحديث أزرار التكتيكات
        var cd_smoke: float = data["tactics_cooldowns"]["smoke"]
        var cd_air: float = data["tactics_cooldowns"]["air_support"]
        smoke_btn.disabled = cd_smoke > 0 or game_manager.fuel < 20
        air_btn.disabled = cd_air > 0 or game_manager.fuel < 40
        if cd_smoke > 0:
                smoke_btn.text = "🚬 دخان (%dث)" % int(ceil(cd_smoke))
        else:
                smoke_btn.text = "🚬 ستارة دخان -20⛽"
        if cd_air > 0:
                air_btn.text = "✈️ جوي (%dث)" % int(ceil(cd_air))
        else:
                air_btn.text = "✈️ دعم جوي -40⛽"

        # تطبيق الاهتزاز على VSLabel
        vs_label.position = shake_offset

func _update_hp_bar_color(bar: ProgressBar, pct: float) -> void:
        var fill_style: StyleBoxFlat = bar.get_theme_stylebox("fill")
        if fill_style and fill_style is StyleBoxFlat:
                if pct > 60:
                        fill_style.bg_color = Color(0.2, 0.8, 0.3, 1.0)
                elif pct > 30:
                        fill_style.bg_color = Color(0.9, 0.8, 0.1, 1.0)
                else:
                        fill_style.bg_color = Color(0.937, 0.267, 0.267, 1.0)

func _spawn_damage_number(current_hp: float, max_hp: float, damage: float, is_enemy: bool) -> void:
        var label := Label.new()
        label.text = "-%d" % int(damage)
        label.add_theme_font_size_override("font_size", 18)
        if is_enemy:
                label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2, 1.0))
        else:
                label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3, 1.0))
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label.anchor_left = 0.5
        label.anchor_right = 0.5
        label.position.x = randf_range(100.0, get_viewport_rect().size.x - 100.0)
        label.position.y = 120.0 if is_enemy else get_viewport_rect().size.y - 260.0
        add_child(label)
        damage_numbers.append({
                "label": label,
                "timer": 1.5,
                "velocity": Vector2(randf_range(-20, 20), -40.0),
        })

func _on_battle_update(data: Dictionary) -> void:
        # إضافة آخر سطر من السجل
        log_text.append_text(data["log"][-1] + "\n")
        # التمرير للأسفل
        log_text.scroll_to_line(log_text.get_line_count() - 1)

func _on_battle_end(won: bool, loot: Dictionary) -> void:
        result_panel.visible = true
        # تأثير تكبير النتيجة
        result_panel.scale = Vector2(0.3, 0.3)
        result_panel.modulate.a = 0.0
        var tween := create_tween()
        tween.set_parallel(true)
        tween.tween_property(result_panel, "scale", Vector2(1.0, 1.0), 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
        tween.tween_property(result_panel, "modulate:a", 1.0, 0.3)
        tween.set_parallel(false)

        if won:
                result_title.text = "🏆 نصر!"
                result_title.add_theme_color_override("font_color", Color(0.2, 0.8, 0.3, 1))
                result_loot.text = "الغنائم:\n⚙️ %d خردة\n⛽ %d وقود\n📋 %d معلومات" % [loot["scrap"], loot["fuel"], loot["intel"]]
                # عرض النجوم للحملات
                if game_manager.battle_is_campaign and loot.get("stars", 0) > 0:
                        var stars_str := ""
                        for s in range(loot["stars"]):
                                stars_str += "⭐"
                        result_loot.text += "\n%s" % stars_str
        else:
                result_title.text = "💔 هزيمة"
                result_title.add_theme_color_override("font_color", Color(0.937, 0.267, 0.267, 1))
                result_loot.text = "لا غنائم. حاول مرة أخرى!"

        # إيقاف الاهتزاز
        shake_intensity = 0.0
        vs_label.position = Vector2.ZERO

func _on_result_close() -> void:
        result_panel.visible = false
