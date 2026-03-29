extends Node
## ═══════════════════════════════════════════════════════════════
## محرك اللعبة المركزي — قبضة الجنرال
## يحتوي: الموارد، المنشآت، القوات، المعارك، الخريطة، البحث،
##           المستوى، الحملات
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
signal xp_gained(amount: int, source: String)
signal level_up(new_level: int)
signal campaign_stage_completed(stage_id: int, stars: int)
signal campaign_updated
signal officers_changed
signal fortifications_changed
signal missions_updated
signal random_event_occurred(event: Dictionary)
signal weather_changed(new_weather: int)
signal convoys_updated
signal troop_upgrades_changed
signal achievements_changed
signal achievement_unlocked(achievement_id: String)
signal settings_changed
signal tutorial_step_changed(step: int)

# ─── ثوابت الألوان ───
const COLOR_BG := Color(0.02, 0.03, 0.06, 1.0)
const COLOR_GOLD := Color(0.788, 0.635, 0.153, 1.0)
const COLOR_RED := Color(0.937, 0.267, 0.267, 1.0)
const COLOR_BLUE := Color(0.251, 0.627, 0.878, 1.0)
const COLOR_ORANGE := Color(0.878, 0.439, 0.125, 1.0)
const COLOR_GREEN := Color(0.2, 0.7, 0.3, 1.0)
const COLOR_DARK_PANEL := Color(0.05, 0.08, 0.16, 0.9)

# ═══════════════════════════════════════════════════
# نظام مستوى الجنرال
# ═══════════════════════════════════════════════════
var player_level: int = 1:
        set(v):
                player_level = v
                level_up.emit(v)

var player_xp: int = 0

# مكافآت المستوى
var level_bonus_attack: float = 0.0
var level_bonus_defense: float = 0.0
var level_bonus_production: float = 0.0
# نقاط مهارات غير مستخدمة
var level_skill_points: int = 0

# جدول XP المطلوب لكل مستوى: XP = 50 * level^1.5
func xp_for_level(level: int) -> int:
        return int(50.0 * pow(float(level), 1.5))

func xp_to_next_level() -> int:
        return xp_for_level(player_level + 1)

func xp_current_level_progress() -> float:
        if player_level <= 0:
                return 0.0
        var needed: int = xp_for_level(player_level + 1) - xp_for_level(player_level)
        if needed <= 0:
                return 1.0
        var current: int = player_xp - xp_for_level(player_level)
        return clampf(float(current) / float(needed), 0.0, 1.0)

func add_xp(amount: int, source: String = "") -> int:
        if amount <= 0:
                return 0
        var actual: int = amount
        if source != "":
                actual = int(amount * get_xp_mult())
        player_xp += actual
        xp_gained.emit(actual, source)
        # فحص صعود المستوى
        _check_level_up()
        return actual

func _check_level_up() -> void:
        while player_xp >= xp_for_level(player_level + 1):
                player_level += 1
                level_skill_points += 1
                level_bonus_attack += 0.02  # +2% هجوم لكل مستوى
                level_bonus_defense += 0.015  # +1.5% دفاع لكل مستوى
                level_bonus_production += 0.03  # +3% إنتاج لكل مستوى
                # مكافأة موارد عند كل مستوى
                var bonus_scrap: int = player_level * 50
                var bonus_fuel: int = player_level * 25
                var bonus_intel: int = player_level * 10
                scrap += bonus_scrap
                fuel += bonus_fuel
                intel += bonus_intel
                level_up.emit(player_level)

func get_xp_mult() -> float:
        return 1.0

func spend_skill_point(stat: String) -> bool:
        if level_skill_points <= 0:
                return false
        match stat:
                "attack":
                        level_bonus_attack += 0.05
                "defense":
                        level_bonus_defense += 0.05
                "production":
                        level_bonus_production += 0.05
                "morale":
                        player_morale = mini(100.0, player_morale + 10.0)
                _:
                        return false
        level_skill_points -= 1
        return true

# ═══════════════════════════════════════════════════
# نظام الحملات
# ═══════════════════════════════════════════════════
var campaign_stages: Array[Dictionary] = []
var current_campaign_stage: int = 0  # المرحلة الحالية المتقدمة (0 = لم يبدأ بعد)
var battle_is_campaign: bool = false
var battle_campaign_stage_id: int = -1

func _init_campaigns() -> void:
        campaign_stages = [
                # ─── الفصل 1: البداية (مراحل 1-10) ───
                {"id": 1, "name": "أول نزال", "desc": "قوات معادية صغيرة تعترض الطريق. رسالة اختبار.", "icon": "🗡️",
                 "enemy_power": 80, "terrain": 0, "weather": 0, "is_boss": false,
                 "story_before": "مذيع: قوات معادية رصدت على الطريق الرئيسي. فرقة الاستطلاع جاهزة للتحرك، يا جنرال.",
                 "story_after": "مذيع: نصر سهل! لكن القتال الحقيقي لم يبدأ بعد.",
                 "first_reward": {"scrap": 100, "fuel": 50, "intel": 20, "xp": 30}},
                {"id": 2, "name": "مخيم المراقبة", "desc": "تقدم العدو باتجاه مخيمنا. يجب إيقافهم.", "icon": "🏕️",
                 "enemy_power": 120, "terrain": 0, "weather": 0, "is_boss": false,
                 "story_before": "جاسوسنا يبلغ: قافلة إمداد العدو على بعد كيلومترات. هذه فرصة لضرب خطوط إمدادهم.",
                 "story_after": "مذيع: خطوط إمداد العدو مدمرة! سيعانون نقصاً في الموارد.",
                 "first_reward": {"scrap": 150, "fuel": 60, "intel": 25, "xp": 40}},
                {"id": 3, "name": "الجسر الحصين", "desc": "جسر استراتيجي محمي بقوات مدرعة.", "icon": "🌉",
                 "enemy_power": 160, "terrain": 1, "weather": 0, "is_boss": false,
                 "story_before": "الجسر هو نقطة العبور الوحيدة. القوات المدرعة تحرسه بقوة.",
                 "story_after": "مذيع: الجسر آمن الآن! فتحنا معبراً جديداً لقواتنا.",
                 "first_reward": {"scrap": 200, "fuel": 80, "intel": 30, "xp": 55}},
                {"id": 4, "name": "الغابة المظلمة", "desc": "كمائن العدو في الغابة الكثيفة.", "icon": "🌲",
                 "enemy_power": 200, "terrain": 1, "weather": 5, "is_boss": false,
                 "story_before": "تحذير من المخابرات: كمائن متعددة في الغابة. الرؤية محدودة جداً في الظلام.",
                 "story_after": "مذيع: تم تطهير الغابة من الكمائن! قواتنا تتقدم بثقة.",
                 "first_reward": {"scrap": 220, "fuel": 90, "intel": 40, "xp": 65}},
                {"id": 5, "name": "قائد الكتيبة", "desc": "⚡ BOSS — قائد كتيبة العدو بدرع ثقيل.", "icon": "💀",
                 "enemy_power": 350, "terrain": 0, "weather": 0, "is_boss": true,
                 "story_before": "⚠️ تحذير عاجل: قائد كتيبة العدو يقود هجوماً مضاداً! قواته مدرعة بشكل ثقيل. هذه معركة مصيرية!",
                 "story_after": "🏆 مذيع: انتصار ساحق! قائد الكتيبة مهزوم! الجنود يهتفون باسمك يا جنرال!",
                 "first_reward": {"scrap": 400, "fuel": 200, "intel": 80, "xp": 120}},

                # ─── الفصل 2: التصعيد (مراحل 6-15) ───
                {"id": 6, "name": "قاعدة الإمداد", "desc": "قاعدة إمداد رئيسية للعدو.", "icon": "🏭",
                 "enemy_power": 250, "terrain": 4, "weather": 0, "is_boss": false,
                 "story_before": "استخباراتنا حددت قاعدة إمداد رئيسية. تدميرها سيشل حركة العدو في المنطقة.",
                 "story_after": "مذيع: قاعدة الإمداد مدمرة! العدو يتراجع.",
                 "first_reward": {"scrap": 280, "fuel": 100, "intel": 50, "xp": 80}},
                {"id": 7, "name": "هجوم الفجر", "desc": "هجوم صباحي مفاجئ على مواقع العدو.", "icon": "🌅",
                 "enemy_power": 300, "terrain": 0, "weather": 0, "is_boss": false,
                 "story_before": "سننفذ هجوماً مفاجئاً عند الفجر. وحدة المشاة ستتقدم أولاً.",
                 "story_after": "مذيع: هجوم الفجر نجح بتخطيط مثالي! خسائرنا في الحد الأدنى.",
                 "first_reward": {"scrap": 320, "fuel": 120, "intel": 55, "xp": 90}},
                {"id": 8, "name": "ممر الجبال", "desc": "ممر جبلي ضيق وخطير.", "icon": "⛰️",
                 "enemy_power": 350, "terrain": 2, "weather": 2, "is_boss": false,
                 "story_before": "الممر الجبلي هو الطريق الأقصر لكنه محفوف بالمخاطر. عاصفة رملية تهدد الرؤية.",
                 "story_after": "مذيع: رغم العاصفة، اخترقنا الممر! الجنود أبطال حقيقيون.",
                 "first_reward": {"scrap": 380, "fuel": 140, "intel": 60, "xp": 100}},
                {"id": 9, "name": "ساحة المعركة", "desc": "معركة واسعة في السهول المفتوحة.", "icon": "⚔️",
                 "enemy_power": 400, "terrain": 0, "weather": 1, "is_boss": false,
                 "story_before": "العدو يجمع قواته في السهول. هذه ستكون معركة كبيرة. المطر سيؤثر على الحركة.",
                 "story_after": "مذيع: المعركة الكبرى انتهت لصالحنا! العدو يفقد سيطرته على السهول.",
                 "first_reward": {"scrap": 420, "fuel": 160, "intel": 70, "xp": 115}},
                {"id": 10, "name": "العميد الحديدي", "desc": "⚡ BOSS — عميد العدو المحصّن بأسطول مدرعات.", "icon": "🛡️",
                 "enemy_power": 600, "terrain": 3, "weather": 0, "is_boss": true,
                 "story_before": "⚠️ إنذار أحمر: العميد الحديدي يقود هجوماً مضاداً بـ 200 مركبة مدرعة! جهزوا كل القوات!",
                 "story_after": "🏆 مذيع: العميد الحديدي يتراجع مهزوماً! جيشنا لا يُقهر!",
                 "first_reward": {"scrap": 700, "fuel": 350, "intel": 150, "xp": 200}},

                # ─── الفصل 3: الهجوم الكبير (مراحل 11-20) ───
                {"id": 11, "name": "نفق التهريب", "desc": "شبكة أنفاق يستخدمها العدو للتهريب.", "icon": "🕳️",
                 "enemy_power": 450, "terrain": 4, "weather": 3, "is_boss": false,
                 "story_before": "مخابراتنا اكتشفت شبكة أنفاق تحت الأرض. ضباب كثيف يغطي المنطقة.",
                 "story_after": "مذيع: الأنفاق محكمة السيطرة. فقد العدو خط تهريبه السري.",
                 "first_reward": {"scrap": 460, "fuel": 180, "intel": 80, "xp": 130}},
                {"id": 12, "name": "المطار العسكري", "desc": "السيطرة على مطار العدو.", "icon": "✈️",
                 "enemy_power": 500, "terrain": 0, "weather": 0, "is_boss": false,
                 "story_before": "مطار حيوي يستخدمه العدو للقصف الجوي. السيطرة عليه ستمنحنا تفوقاً جوياً.",
                 "story_after": "مذيع: المطار تحت سيطرتنا! سلاح الجو الآن في صفنا!",
                 "first_reward": {"scrap": 500, "fuel": 200, "intel": 90, "xp": 145}},
                {"id": 13, "name": "الشاطئ المحصّن", "desc": "هجوم برمائي على دفاعات العدو الساحلية.", "icon": "🌊",
                 "enemy_power": 550, "terrain": 0, "weather": 1, "is_boss": false,
                 "story_before": "عملية إنزال بحري! العدو حصّن الشاطئ بالألغام والخنادق.",
                 "story_after": "مذيع: رأس الجسر مؤمن! القوات تنزل بكفاءة.",
                 "first_reward": {"scrap": 550, "fuel": 220, "intel": 100, "xp": 160}},
                {"id": 14, "name": "البوابة الشمالية", "desc": "بوابة المدينة المحصنة.", "icon": "🏰",
                 "enemy_power": 600, "terrain": 4, "weather": 4, "is_boss": false,
                 "story_before": "بوابة المدينة الشمالية محمية بأسوار سميكة. الثلوج تزيد صعوبة المهمة.",
                 "story_after": "مذيع: البوابة مفتوحة! المدينة ستسقط قريباً.",
                 "first_reward": {"scrap": 600, "fuel": 250, "intel": 110, "xp": 175}},
                {"id": 15, "name": "اللواء الصاروخي", "desc": "⚡ BOSS — لواء العدو بترسانة صواريخ.", "icon": "🚀",
                 "enemy_power": 900, "terrain": 0, "weather": 5, "is_boss": true,
                 "story_before": "⚠️ خطر شديد: لواء صاروخي يهدد بتدمير everything! هجوم ليلي ضروري لإيقافهم!",
                 "story_after": "🏆 مذيع: ترسانة الصواريخ دمرت! اللواء ينهار! نحن نقترب من النصر النهائي!",
                 "first_reward": {"scrap": 1000, "fuel": 500, "intel": 200, "xp": 300}},

                # ─── الفصل 4: الحرب الشاملة (مراحل 16-25) ───
                {"id": 16, "name": "مصنع الذخيرة", "desc": "مصنع ضخم لإنتاج الأسلحة.", "icon": "💣",
                 "enemy_power": 650, "terrain": 3, "weather": 2, "is_boss": false,
                 "story_before": "مصنع الذخيرة يُمد العدو بكل ما يحتاج. تدميره سيحدث فارقاً كبيراً.",
                 "story_after": "مذيع: المصنع مدمر! إنتاج العدو من الأسلحة توقف.",
                 "first_reward": {"scrap": 650, "fuel": 280, "intel": 120, "xp": 190}},
                {"id": 17, "name": "القافلة الذهبية", "desc": "قافلة إمداد محملة بالموارد.", "icon": "💰",
                 "enemy_power": 600, "terrain": 0, "weather": 0, "is_boss": false,
                 "story_before": "قافلة ذهبية! اعتراضها سيمنحنا موارد ضخمة.",
                 "story_after": "مذيع: القافلة غنمت! الموارد تتدفق إلى مخازننا!",
                 "first_reward": {"scrap": 800, "fuel": 300, "intel": 130, "xp": 200}},
                {"id": 18, "name": "مقر الاستخبارات", "desc": "مقر استخبارات العدو السري.", "icon": "🕵️",
                 "enemy_power": 700, "terrain": 4, "weather": 3, "is_boss": false,
                 "story_before": "اختراق مقر الاستخبارات سيمنحنا معلومات حيوية عن خطط العدو.",
                 "story_after": "مذيع: وثائق سرية عثر عليها! خطة العدو الكبرى مكشوفة الآن.",
                 "first_reward": {"scrap": 700, "fuel": 320, "intel": 200, "xp": 220}},
                {"id": 19, "name": "السد الاستراتيجي", "desc": "سد يتحكم بمنطقة واسعة.", "icon": "🌊",
                 "enemy_power": 750, "terrain": 2, "weather": 1, "is_boss": false,
                 "story_before": "السيطرة على السد ستقطع إمدادات المياه عن قواعد العدو.",
                 "story_after": "مذيع: السد تحت سيطرتنا! العدو يعاني من نقص المياه.",
                 "first_reward": {"scrap": 750, "fuel": 340, "intel": 140, "xp": 240}},
                {"id": 20, "name": "الجنرال الظل", "desc": "⚡ BOSS — القائد الأعلى للعدو.", "icon": "👤",
                 "enemy_power": 1200, "terrain": 0, "weather": 0, "is_boss": true,
                 "story_before": "⚠️ المعركة الحاسمة! الجنرال الظل يقود جيش العدو بنفسه! هذه هي المعركة التي ستحدد مصير الحرب!",
                 "story_after": "🏆 مذيع: الجنرال الظل مهزوم! جيشه ينهار! النصر النهائي يقترب!",
                 "first_reward": {"scrap": 1500, "fuel": 700, "intel": 300, "xp": 500}},

                # ─── الفصل 5: النصر النهائي (مراحل 21-30) ───
                {"id": 21, "name": "الهجوم الأخير", "desc": "الهجوم النهائي على معاقل العدو.", "icon": "🔥",
                 "enemy_power": 800, "terrain": 0, "weather": 0, "is_boss": false,
                 "story_before": "هذا هو الهجوم الأخير! كل ما لدينا سنضعه في هذه المعركة.",
                 "story_after": "مذيع: بداية نهاية العدو! قواتهم تتشتت!",
                 "first_reward": {"scrap": 800, "fuel": 400, "intel": 160, "xp": 260}},
                {"id": 22, "name": "القصر الرئاسي", "desc": "اقتحام القصر الرئاسي.", "icon": "🏛️",
                 "enemy_power": 850, "terrain": 4, "weather": 0, "is_boss": false,
                 "story_before": "القصر الرئاسي هو آخر معقل للعدو. الحرس الرئاسي يحميه بشراسة.",
                 "story_after": "مذيع: القصر محاصر! زعيم العدو محاصر داخله!",
                 "first_reward": {"scrap": 900, "fuel": 450, "intel": 180, "xp": 280}},
                {"id": 23, "name": "غرفة القيادة", "desc": "اقتحام غرفة القيادة المركزية.", "icon": "📡",
                 "enemy_power": 900, "terrain": 4, "weather": 3, "is_boss": false,
                 "story_before": "غرفة القيادة محمية بأنظمة متقدمة. الاختراق يتطلب دقة عالية.",
                 "story_after": "مذيع: غرفة القيادة تحت سيطرتنا! كل أنظمة العدو معطلة!",
                 "first_reward": {"scrap": 950, "fuel": 480, "intel": 200, "xp": 300}},
                {"id": 24, "name": "المطار الأخير", "desc": "المطار الاستراتيجي الأخير.", "icon": "🛬",
                 "enemy_power": 950, "terrain": 0, "weather": 4, "is_boss": false,
                 "story_before": "المطار الأخير للعدو. السيطرة عليه تعني السيطرة الكاملة على الأجواء.",
                 "story_after": "مذيع: الأجواء آمنة تماماً! لا طائرة معادية في السماء!",
                 "first_reward": {"scrap": 1000, "fuel": 500, "intel": 220, "xp": 320}},
                {"id": 25, "name": "القائد الأعلى", "desc": "⚡ BOSS FINAL — القائد الأعلى للعدو.", "icon": "👑",
                 "enemy_power": 1500, "terrain": 0, "weather": 0, "is_boss": true,
                 "story_before": "⚠️ المعركة الأخيرة! القائد الأعلى للعدو يجمع كل ما تبقى من قواته! انتصروا وينتهي كل شيء!",
                 "story_after": "🏆🏆🏆 مذيع: انتصار ساحق! الحرب انتهت! النصر لجيوشنا! السلام يعود أخيراً! أنت بطل التحرير يا جنرال!",
                 "first_reward": {"scrap": 3000, "fuel": 1500, "intel": 500, "xp": 1000}},
        ]

func get_campaign_stage(idx: int) -> Dictionary:
        if idx >= 0 and idx < campaign_stages.size():
                return campaign_stages[idx]
        return {}

func is_campaign_stage_completed(idx: int) -> bool:
        return idx < current_campaign_stage

func is_campaign_stage_unlocked(idx: int) -> bool:
        return idx <= current_campaign_stage

func get_campaign_stage_stars(idx: int) -> int:
        return campaign_stages[idx].get("stars_earned", 0) if idx >= 0 and idx < campaign_stages.size() else 0

func get_total_campaign_stars() -> int:
        var total := 0
        for s in campaign_stages:
                total += s.get("stars_earned", 0)
        return total

func start_campaign_battle(stage_idx: int) -> bool:
        if not is_campaign_stage_unlocked(stage_idx):
                return false
        var stage: Dictionary = campaign_stages[stage_idx]
        if stage.is_empty():
                return false
        if get_deployed_count() == 0:
                return false
        battle_is_campaign = true
        battle_campaign_stage_id = stage_idx
        # تطبيق تضاريس وطقس المرحلة
        selected_terrain = stage.get("terrain", 0)
        current_weather = stage.get("weather", 0)
        return start_battle(stage["enemy_power"], stage["name"])

func complete_campaign_stage(won: bool, stars: int = 0) -> void:
        if not battle_is_campaign or battle_campaign_stage_id < 0:
                return
        var idx: int = battle_campaign_stage_id
        if won and idx >= current_campaign_stage:
                current_campaign_stage = idx + 1
                var stage: Dictionary = campaign_stages[idx]
                # مكافأة أول مرة
                if not stage.get("first_completed", false):
                        var reward: Dictionary = stage.get("first_reward", {})
                        scrap += reward.get("scrap", 0)
                        fuel += reward.get("fuel", 0)
                        intel += reward.get("intel", 0)
                        add_xp(reward.get("xp", 0), "campaign")
                        stage["first_completed"] = true
                # حفظ النجوم (أعلى نتيجة)
                var old_stars: int = stage.get("stars_earned", 0)
                if stars > old_stars:
                        stage["stars_earned"] = stars
                # مكافأة متكررة (50% من مكافأة أول مرة)
                if stage.get("first_completed", false):
                        var reward: Dictionary = stage.get("first_reward", {})
                        scrap += reward.get("scrap", 0) / 2
                        fuel += reward.get("fuel", 0) / 2
                        intel += reward.get("intel", 0) / 2
                        add_xp(reward.get("xp", 0) / 2, "campaign")
                campaign_stage_completed.emit(idx, stars)
                campaign_updated.emit()
        battle_is_campaign = false
        battle_campaign_stage_id = -1

func calculate_battle_stars() -> int:
        if not battle_is_campaign or battle_campaign_stage_id < 0:
                return 0
        var data: Dictionary = battle_data
        var player_hp_pct: float = data["player_current_hp"] / float(data["player_power"])
        var elapsed: float = data.get("elapsed", 999.0)
        var stars := 0
        # نجمة واحدة: الفوز
        stars = 1
        # نجمتان: HP فوق 50%
        if player_hp_pct >= 0.5:
                stars = 2
        # ثلاث نجوم: HP فوق 80% + أقل من 30 ثانية
        if player_hp_pct >= 0.8 and elapsed < 30.0:
                stars = 3
        return stars

# ═══════════════════════════════════════════════════
# نظام سلسلة القيادة
# ═══════════════════════════════════════════════════

var officers: Array[Dictionary] = []

func _init_officers() -> void:
        officers = [
                {"id": "inf_commander", "name": "قائد المشاة", "icon": "🎖️", "desc": "+15% هجوم المشاة",
                 "troop_type": 0, "level": 0, "max_level": 10, "active": false,
                 "cost": 200, "effect_type": "attack", "effect_troop": 0, "effect_per_level": 0.15},
                {"id": "armor_commander", "name": "قائد المدرعات", "icon": "🛡️", "desc": "+15% دفاع المدرعات",
                 "troop_type": 1, "level": 0, "max_level": 10, "active": false,
                 "cost": 300, "effect_type": "defense", "effect_troop": 1, "effect_per_level": 0.15},
                {"id": "aviation_commander", "name": "الطيار المتمرس", "icon": "✈️", "desc": "+15% ضرر الطيران",
                 "troop_type": 2, "level": 0, "max_level": 10, "active": false,
                 "cost": 400, "effect_type": "attack", "effect_troop": 2, "effect_per_level": 0.15},
                {"id": "strategist", "name": "الاستراتيجي", "icon": "🧠", "desc": "+10% كل القوات",
                 "troop_type": -1, "level": 0, "max_level": 10, "active": false,
                 "cost": 500, "effect_type": "all_attack", "effect_troop": -1, "effect_per_level": 0.10},
        ]

func hire_officer(officer_id: String) -> bool:
        for o in officers:
                if o["id"] == officer_id:
                        var cost: int = o["cost"]
                        if scrap >= cost and not o["active"]:
                                scrap -= cost
                                o["active"] = true
                                o["level"] = 1
                                officers_changed.emit()
                                check_achievements()
                                return true
        return false

func upgrade_officer(officer_id: String) -> bool:
        for o in officers:
                if o["id"] == officer_id and o["active"]:
                        if o["level"] >= o["max_level"]:
                                return false
                        var cost: int = int(o["cost"] * pow(1.3, o["level"]))
                        if scrap >= cost:
                                scrap -= cost
                                o["level"] += 1
                                officers_changed.emit()
                                check_achievements()
                                return true
        return false

func get_officer_bonus(troop_type: int, stat: String) -> float:
        var bonus := 0.0
        for o in officers:
                if not o["active"]:
                        continue
                if o["troop_type"] == troop_type or o["troop_type"] == -1:
                        if o["effect_type"] == stat and (stat != "all_attack" or o["troop_type"] == -1):
                                bonus += o["effect_per_level"] * o["level"]
                        elif o["effect_type"] == "all_attack" and stat == "attack":
                                bonus += o["effect_per_level"] * o["level"]
        return bonus

func get_officer_active_count() -> int:
        var c := 0
        for o in officers:
                if o["active"]:
                        c += 1
        return c

# ═══════════════════════════════════════════════════
# نظام التحصينات
# ═══════════════════════════════════════════════════

var fortifications: Array[Dictionary] = []

func _init_fortifications() -> void:
        fortifications = []

func get_fortification_cost(fort_type: String, level: int = 1) -> int:
        var costs := {
                "mines": 100, "barricades": 150, "watchtower": 200, "supply_base": 250, "hospital": 300
        }
        var base: int = costs.get(fort_type, 200)
        return int(base * pow(1.2, level))

func build_fortification(sector_id: String, fort_type: String) -> bool:
        if scrap < get_fortification_cost(fort_type):
                return false
        # تحقق أن القطاع محرر
        for s in world_sectors:
                if s["id"] == sector_id and s["status"] == SectorStatus.CLEARED:
                        var cost: int = get_fortification_cost(fort_type)
                        scrap -= cost
                        # تحقق عدد التحصينات (حد أقصى 2 لكل قطاع)
                        var current_count: int = 0
                        for f in fortifications:
                                if f["sector_id"] == sector_id:
                                        current_count += 1
                        if current_count >= 2:
                                scrap += cost
                                return false
                        fortifications.append({
                                "id": "%s_%s_%d" % [sector_id, fort_type, current_count],
                                "sector_id": sector_id, "type": fort_type, "level": 1,
                        })
                        fortifications_changed.emit()
                        check_achievements()
                        return true
        return false

func upgrade_fortification(fort_id: String) -> bool:
        for f in fortifications:
                if f["id"] == fort_id:
                        var cost: int = get_fortification_cost(f["type"], f["level"] + 1)
                        if scrap >= cost:
                                scrap -= cost
                                f["level"] += 1
                                fortifications_changed.emit()
                                return true
        return false

func get_sector_defense_bonus(sector_id: String) -> float:
        var bonus := 0.0
        for f in fortifications:
                if f["sector_id"] == sector_id:
                        match f["type"]:
                                "mines": bonus += 0.10 * f["level"]  # ضرر أولي للعدو
                                "barricades": bonus += 0.08 * f["level"]  # دفاع إضافي
                                "watchtower": bonus += 0.05 * f["level"]  # استطلاع مجاني
                                "supply_base": bonus += 0.0  # إنتاج موارد
                                "hospital": bonus += 0.12 * f["level"]  # تقليل الخسائر
        return bonus

func get_sector_fort_count(sector_id: String) -> int:
        var c := 0
        for f in fortifications:
                if f["sector_id"] == sector_id:
                        c += 1
        return c

func get_fort_production(sector_id: String) -> Dictionary:
        var prod := {"scrap": 0.0, "fuel": 0.0, "intel": 0.0}
        for f in fortifications:
                if f["sector_id"] == sector_id and f["type"] == "supply_base":
                        var level: int = f["level"]
                        prod["scrap"] = 1.5 * level
                        prod["fuel"] = 0.8 * level
                        prod["intel"] = 0.3 * level
        return prod

func get_hospital_loss_reduction(sector_id: String) -> float:
        for f in fortifications:
                if f["sector_id"] == sector_id and f["type"] == "hospital":
                        return 0.12 * f["level"]
        return 0.0

# ═══════════════════════════════════════════════════
# نظام المهمات
# ═══════════════════════════════════════════════════

var daily_missions: Array[Dictionary] = []
var weekly_missions: Array[Dictionary] = []
var last_daily_refresh: int = 0
var last_weekly_refresh: int = 0

func _init_missions() -> void:
        _generate_daily_missions()
        _generate_weekly_missions()

func _generate_daily_missions() -> void:
        daily_missions = []
        var templates := [
                {"type": "battles", "count": 3, "reward_scrap": 80, "reward_fuel": 40, "reward_xp": 25,
                 "desc": "أكسب %d معركة", "icon": "⚔️"},
                {"type": "recruit", "count": 20, "reward_scrap": 60, "reward_fuel": 30, "reward_xp": 20,
                 "desc": "جنّد %d جندي", "icon": "🔫"},
                {"type": "scout", "count": 2, "reward_scrap": 40, "reward_fuel": 20, "reward_xp": 30,
                 "desc": "استطلع %d قطاع", "icon": "🔍"},
                {"type": "upgrade", "count": 1, "reward_scrap": 50, "reward_fuel": 25, "reward_xp": 35,
                 "desc": "رقّي منشأة %d مرة", "icon": "⬆️"},
        ]
        # اختر 3 عشوائياً
        var shuffled := templates.duplicate()
        shuffled.shuffle()
        for i in range(3):
                var t: Dictionary = shuffled[i]
                daily_missions.append({
                        "id": "daily_%d" % i, "type": t["type"], "desc": t["desc"] % t["count"],
                        "target": t["count"], "progress": 0, "icon": t["icon"],
                        "reward_scrap": t["reward_scrap"], "reward_fuel": t["reward_fuel"], "reward_xp": t["reward_xp"],
                        "completed": false, "claimed": false,
                })

func _generate_weekly_missions() -> void:
        weekly_missions = []
        var templates := [
                {"desc": "حرر 10 قطاعات", "type": "clear_sectors", "target": 10, "progress": 0,
                 "reward_scrap": 500, "reward_fuel": 250, "reward_xp": 200, "icon": "🗺️"},
                {"desc": "وصل مستوى %d", "type": "reach_level", "target": 5, "progress": 0,
                 "reward_scrap": 600, "reward_fuel": 300, "reward_xp": 250, "icon": "⭐"},
                {"desc": "أكمل 15 معركة", "type": "total_battles", "target": 15, "progress": 0,
                 "reward_scrap": 700, "reward_fuel": 350, "reward_xp": 300, "icon": "⚔️"},
        ]
        for t in templates:
                weekly_missions.append({
                        "id": "weekly_%d" % weekly_missions.size(), "type": t["type"], "desc": t["desc"],
                        "target": t["target"], "progress": t.get("progress", 0),
                        "reward_scrap": t["reward_scrap"], "reward_fuel": t["reward_fuel"], "reward_xp": t["reward_xp"],
                        "icon": t["icon"], "completed": false, "claimed": false,
                })

func check_mission_progress() -> void:
        # فحص المهام اليومية
        for m in daily_missions:
                if m["completed"]:
                        continue
                var progress := 0
                match m["type"]:
                        "battles": progress = _battle_count_since_refresh
                        "recruit": progress = _recruit_count_since_refresh
                        "scout": progress = _scout_count_since_refresh
                        "upgrade": progress = _upgrade_count_since_refresh
                m["progress"] = progress
                if progress >= m["target"]:
                        m["completed"] = true
        # فحص المهام الأسبوعية
        for m in weekly_missions:
                if m["completed"]:
                        continue
                var progress := 0
                match m["type"]:
                        "clear_sectors":
                                var cleared := 0
                                for s in world_sectors:
                                        if s["status"] == SectorStatus.CLEARED:
                                                cleared += 1
                                progress = cleared
                        "reach_level":
                                progress = player_level
                        "total_battles":
                                progress = _battle_count_since_refresh
                m["progress"] = progress
                if progress >= m["target"]:
                        m["completed"] = true
        missions_updated.emit()

func claim_mission(mission_id: String) -> bool:
        var mission: Dictionary = {}
        for m in daily_missions:
                if m["id"] == mission_id:
                        mission = m; break
        if mission.is_empty():
                for m in weekly_missions:
                        if m["id"] == mission_id:
                                mission = m; break
        if mission.is_empty() or mission["claimed"] or not mission["completed"]:
                return false
        mission["claimed"] = true
        scrap += mission["reward_scrap"]
        fuel += mission["reward_fuel"]
        add_xp(mission["reward_xp"], "mission")
        missions_updated.emit()
        return true

var _battle_count_since_refresh: int = 0
var _recruit_count_since_refresh: int = 0
var _scout_count_since_refresh: int = 0
var _upgrade_count_since_refresh: int = 0

func track_battle() -> void:
        _battle_count_since_refresh += 1
        check_mission_progress()

func track_recruit() -> void:
        _recruit_count_since_refresh += 1
        check_mission_progress()

func track_scout() -> void:
        _scout_count_since_refresh += 1
        check_mission_progress()

func track_upgrade() -> void:
        _upgrade_count_since_refresh += 1
        check_mission_progress()

func refresh_daily_missions() -> void:
        _battle_count_since_refresh = 0
        _recruit_count_since_refresh = 0
        _scout_count_since_refresh = 0
        _upgrade_count_since_refresh = 0
        _generate_daily_missions()
        last_daily_refresh = Time.get_unix_time_from_system()
        missions_updated.emit()

func refresh_weekly_missions() -> void:
        _battle_count_since_refresh = 0
        _generate_weekly_missions()
        last_weekly_refresh = Time.get_unix_time_from_system()
        missions_updated.emit()

func check_mission_refresh() -> void:
        var now: int = Time.get_unix_time_from_system()
        # تحديث يومي كل 8 ساعات
        if now - last_daily_refresh > 28800:
                refresh_daily_missions()
        # تحديث أسبوعي كل 3 أيام
        if now - last_weekly_refresh > 259200:
                refresh_weekly_missions()

# ═══════════════════════════════════════════════════
# نظام الأحداث العشوائية
# ═══════════════════════════════════════════════════

var event_cooldown: float = 0.0
const EVENT_INTERVAL: float = 120.0  # كل دقيقتين
var _pending_events: Array[Dictionary] = []

func _init_events() -> void:
        _pending_events = []

func update_events(delta: float) -> void:
        event_cooldown += delta
        if event_cooldown >= EVENT_INTERVAL:
                event_cooldown = 0.0
                _generate_random_event()

func _generate_random_event() -> void:
        var positive_events := [
                {"name": "شحنة إمداد!", "icon": "📦", "desc": "شحنة إمداد وجدت طريقنا! موارد مجانية!",
                 "effect_type": "resources", "scrap": 150, "fuel": 80, "intel": 30},
                {"name": "متحول عسكري!", "icon": "🎖️", "desc": "وحدة عسكرية انشقّت وجنود مجانيون!",
                        "effect_type": "troops", "troop_type": 0, "count": 5},
                {"name": "مخابئ!", "icon": "📋", "desc": "مخابراتنا اعترضت وثائق سرية!",
                        "effect_type": "resources", "scrap": 50, "fuel": 25, "intel": 100},
                {"name": "ترميم المعنويات!", "icon": "💪", "desc": "خطاب تحفيزي رفع الروح!",
                        "effect_type": "morale", "amount": 15},
                {"name": "جائزة من الأهل!", "icon": "🎁", "desc": "الأهل أهدوا موارد لدعم الجيش!",
                        "effect_type": "resources", "scrap": 100, "fuel": 50, "intel": 50},
        ]
        var negative_events := [
                {"name": "تمرد!", "icon": "⚠️", "desc": "تمرد في صفوف الجنود! المعنويات انخفضت.",
                        "effect_type": "morale", "amount": -15},
                {"name": "أعطال مفاجئ!", "icon": "💣", "desc": "انفجار في مستودعات! فقدنا بعض الموارد.",
                        "effect_type": "resources", "scrap": -80, "fuel": -40, "intel": -20},
                {"name": "وباء!", "icon": "🦠", "desc": "وباء أصاب بعض الجنود! فعاليتهم انخفضت مؤقتاً.",
                        "effect_type": "morale", "amount": -10},
        ]
        var all_events := positive_events + negative_events
        # 70% إيجابية، 30% سلبية
        var event: Dictionary
        if randf() < 0.7:
                event = positive_events[randi() % positive_events.size()]
        else:
                event = negative_events[randi() % negative_events.size()]
        event["time"] = Time.get_unix_time_from_system()
        _apply_event(event)
        random_event_occurred.emit(event)

func _apply_event(event: Dictionary) -> void:
        match event.get("effect_type", ""):
                "resources":
                        scrap += event.get("scrap", 0)
                        fuel += event.get("fuel", 0)
                        intel += event.get("intel", 0)
                "morale":
                        player_morale = clampf(player_morale + event.get("amount", 0), 0.0, 100.0)
                "troops":
                        var ttype: int = event.get("troop_type", 0)
                        var count: int = event.get("count", 0)
                        for c in companies:
                                if c["type"] == ttype and c["squads"].size() > 0:
                                        for squad in c["squads"]:
                                                if squad["size"] < 10:
                                                        var add: int = mini(count, 10 - squad["size"])
                                                        squad["size"] += add
                                                        count -= add
                                                        if count <= 0:
                                                                break
                                        troops_changed.emit()
                                        if count <= 0:
                                                break
        _pending_events.append(event)

# ═══════════════════════════════════════════════════
# نظام الطقس الديناميكي
# ═══════════════════════════════════════════════════

var weather_cycle_timer: float = 0.0
const WEATHER_CYCLE_INTERVAL: float = 90.0  # تغيير كل 90 ثانية
var weather_transition_progress: float = 0.0  # 0-1 للتأثير التدريجي
var weather_notification_shown: bool = true

func update_weather_cycle(delta: float) -> void:
        weather_cycle_timer += delta
        if weather_cycle_timer >= WEATHER_CYCLE_INTERVAL:
                weather_cycle_timer = 0.0
                _cycle_weather()

func _cycle_weather() -> void:
        # لا نغير الطقس أثناء المعركة
        if battle_active:
                return
        var old_weather: int = current_weather
        # الطقس الجديد عشوائي لكن ليس نفس القديم
        var new_weather: int = current_weather
        while new_weather == current_weather:
                new_weather = randi() % 6
        current_weather = new_weather
        weather_changed.emit(current_weather)

func get_weather_forecast() -> String:
        var remaining: float = WEATHER_CYCLE_INTERVAL - weather_cycle_timer
        var secs: int = int(remaining)
        return "التغيير خلال: %dث" % secs

func force_weather(weather_idx: int) -> void:
        if weather_idx >= 0 and weather_idx < 6:
                current_weather = weather_idx
                weather_cycle_timer = 0.0
                weather_changed.emit(current_weather)

# ═══════════════════════════════════════════════════
# نظام قوافل الإمداد
# ═══════════════════════════════════════════════════

var active_convoys: Array[Dictionary] = []
var completed_convoys_count: int = 0

func _init_convoys() -> void:
        active_convoys = []

func get_available_convoy_targets() -> Array:
        var targets := []
        for s in world_sectors:
                if s["status"] == SectorStatus.CLEARED and s.get("has_supply_base", false):
                        targets.append(s)
        return targets

func launch_convoy(scrap_amount: int, fuel_amount: int, intel_amount: int) -> bool:
        if active_convoys.size() >= 3:
                return false
        var total_cost_fuel: int = 20
        if fuel < total_cost_fuel:
                return false
        if scrap_amount + fuel_amount + intel_amount <= 0:
                return false
        fuel -= total_cost_fuel
        var convoy_time: float = 30.0 + float(scrap_amount + fuel_amount + intel_amount) * 0.05
        active_convoys.append({
                "id": "convoy_%d" % Time.get_ticks_msec(),
                "scrap": scrap_amount, "fuel_carry": fuel_amount, "intel": intel_amount,
                "time_total": convoy_time, "time_remaining": convoy_time,
                "raided": false,
        })
        convoys_updated.emit()
        check_achievements()
        return true

func update_convoys(delta: float) -> void:
        for i in range(active_convoys.size() - 1, -1, -1):
                var c: Dictionary = active_convoys[i]
                c["time_remaining"] -= delta
                if c["time_remaining"] <= 0:
                        # 90% نجاح، 10% هجوم
                        if randf() < 0.1:
                                c["raided"] = true
                                var lost_pct: float = 0.3 + randf() * 0.4
                                c["scrap"] = int(float(c["scrap"]) * (1.0 - lost_pct))
                                c["fuel_carry"] = int(float(c["fuel_carry"]) * (1.0 - lost_pct))
                                c["intel"] = int(float(c["intel"]) * (1.0 - lost_pct))
                        scrap += c["scrap"]
                        fuel += c["fuel_carry"]
                        intel += c["intel"]
                        completed_convoys_count += 1
                        active_convoys.remove_at(i)
                        convoys_updated.emit()
                        check_achievements()

func get_active_convoy_count() -> int:
        return active_convoys.size()

# ═══════════════════════════════════════════════════
# نظام ترقية القوات
# ═══════════════════════════════════════════════════

var troop_upgrades: Dictionary = {}

func _init_troop_upgrades() -> void:
        troop_upgrades = {
                0: {"level": 0, "max_level": 5, "bonus_attack": 0.0, "bonus_defense": 0.0,
                    "name": "ترقية المشاة", "icon": "🔫", "desc": "+10% هجوم +5% دفاع/مستوى"},
                1: {"level": 0, "max_level": 5, "bonus_attack": 0.0, "bonus_defense": 0.0,
                    "name": "ترقية المدرعات", "icon": "🛡️", "desc": "+8% هجوم +12% دفاع/مستوى"},
                2: {"level": 0, "max_level": 5, "bonus_attack": 0.0, "bonus_defense": 0.0,
                    "name": "ترقية الطيران", "icon": "✈️", "desc": "+12% هجوم +3% دفاع/مستوى"},
        }

func get_troop_upgrade_cost(troop_type: int) -> int:
        var info: Dictionary = troop_upgrades.get(troop_type, {})
        var lvl: int = info.get("level", 0)
        return int(150 * pow(1.5, lvl))

func upgrade_troops(troop_type: int) -> bool:
        if troop_type not in troop_upgrades:
                return false
        var info: Dictionary = troop_upgrades[troop_type]
        if info["level"] >= info["max_level"]:
                return false
        var cost: int = get_troop_upgrade_cost(troop_type)
        if scrap < cost:
                return false
        scrap -= cost
        info["level"] += 1
        match troop_type:
                0:  # المشاة: +10% هجوم، +5% دفاع
                        info["bonus_attack"] += 0.10
                        info["bonus_defense"] += 0.05
                1:  # المدرعات: +8% هجوم، +12% دفاع
                        info["bonus_attack"] += 0.08
                        info["bonus_defense"] += 0.12
                2:  # الطيران: +12% هجوم، +3% دفاع
                        info["bonus_attack"] += 0.12
                        info["bonus_defense"] += 0.03
        troop_upgrades_changed.emit()
        return true

func get_troop_upgrade_bonus(troop_type: int) -> Dictionary:
        var info: Dictionary = troop_upgrades.get(troop_type, {})
        return {"attack": info.get("bonus_attack", 0.0), "defense": info.get("bonus_defense", 0.0)}

# ═══════════════════════════════════════════════════
# الموارد
# ═══════════════════════════════════════════════════
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
        # تطبيق بونص الإنتاج من المستوى + التكنولوجيا
        var prod_mult: float = 1.0 + level_bonus_production
        return base * level * prod_mult

func upgrade_building(building_id: String) -> bool:
        for b in buildings:
                if b["id"] == building_id:
                        var cost: int = get_building_upgrade_cost(b)
                        if scrap >= cost:
                                scrap -= cost
                                b["level"] = b["level"] + 1
                                buildings_changed.emit()
                                track_upgrade()
                                check_achievements()
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
                                track_recruit()
                                check_achievements()
                                return available
        return 0

func get_total_troops_by_type(troop_type: int) -> int:
        var total := 0
        for c in companies:
                if c["type"] == troop_type:
                        total += get_company_troop_count(c)
        return total

# ─── نشر القوات للمعركة ───
var deployment: Array = []

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
        var already_deployed: int = 0
        for w in deployment:
                for s in w:
                        if s["type"] == troop_type:
                                already_deployed += s["count"]
        var can_deploy: int = available - already_deployed
        if can_deploy < 5:
                return
        var current: Dictionary = deployment[wave][slot]
        if current["type"] == troop_type:
                var add: int = mini(5, can_deploy)
                if add > 0:
                        deployment[wave][slot]["count"] += add
        elif current["type"] == -1:
                deployment[wave][slot] = {"type": troop_type, "count": mini(5, can_deploy)}

func remove_from_slot(wave: int, slot: int) -> void:
        if wave >= deployment.size() or slot >= deployment[wave].size():
                return
        deployment[wave][slot] = {"type": -1, "count": 0}

func clear_deployment() -> void:
        _init_deployment()

func get_deployed_power() -> int:
        var total_power := 0
        for wave_idx in range(deployment.size()):
                var wave_mult := 1.5 if wave_idx > 0 else 1.0
                for slot in deployment[wave_idx]:
                        if slot["type"] < 0:
                                continue
                        var stats: Dictionary = troop_stats[slot["type"]]
                        var base_power: float = float(stats["attack"] * slot["count"])
                        var terrain_mult: float = terrain_defense.get(selected_terrain, 1.0)
                        var weather_data: Dictionary = weather_attack_mult.get(current_weather, weather_attack_mult[Weather.CLEAR])
                        var troop_key: String = ["infantry", "armor", "aviation"][slot["type"]]
                        var weather_mult: float = 1.0 if _tech_weather_immune else weather_data.get(troop_key, 1.0)
                        var morale_mult: float = get_morale_mult()
                        var tech_mult: float = 1.0 + _tech_attack_bonus
                        # تطبيق بونصات المستوى
                        var level_mult: float = 1.0 + level_bonus_attack
                        # تطبيق بونصات الضباط
                        var officer_atk: float = get_officer_bonus(slot["type"], "attack") + get_officer_bonus(slot["type"], "all_attack")
                        # بونص ترقية القوات
                        var upgrade_bonus: Dictionary = get_troop_upgrade_bonus(slot["type"])
                        var upgrade_atk_mult: float = 1.0 + upgrade_bonus["attack"]
                        total_power += int(base_power * upgrade_atk_mult * officer_atk * terrain_mult * wave_mult * weather_mult * morale_mult * tech_mult * level_mult)
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
var battle_target_sector_id: String = ""

func start_battle(enemy_power: int, sector_name: String, sector_id: String = "") -> bool:
        if get_deployed_count() == 0:
                return false
        battle_active = true
        battle_target_sector_id = sector_id
        var player_power := get_deployed_power()
        var deployed_count := get_deployed_count()
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
                "deployed_count": deployed_count,
                "fort_defense_mult": 1.0,
        }
        # مكافأة التحصينات للقطاع
        if sector_id != "":
                var fort_bonus: float = get_sector_defense_bonus(sector_id)
                if fort_bonus > 0:
                        battle_data["fort_defense_mult"] = 1.0 - fort_bonus
                        battle_data["log"].append("🏗️ تحصينات القطاع: -%d%% ضرر العدو!" % int(fort_bonus * 100))
        battle_started.emit()
        return true

func update_battle(delta: float) -> void:
        if not battle_active:
                return
        battle_data["elapsed"] += delta

        var player_dps: float = battle_data["player_power"] * 0.1
        var enemy_dps: float = battle_data["enemy_power"] * 0.08

        var morale_mult: float = get_morale_mult()
        player_dps *= morale_mult

        var tech_atk_mult: float = 1.0 + _tech_attack_bonus
        player_dps *= tech_atk_mult
        var tech_def_mult: float = 1.0 + _tech_defense_bonus + level_bonus_defense
        enemy_dps /= tech_def_mult

        # مكافأة التحصينات (ألغام + متاريس تقلل ضرر العدو)
        var fort_defense_mult: float = battle_data.get("fort_defense_mult", 1.0)
        enemy_dps *= fort_defense_mult

        if battle_data["tactics_active"].get("smoke", false):
                enemy_dps *= 0.3
        if battle_data["tactics_active"].get("air_support", false):
                player_dps *= 1.5

        battle_data["enemy_current_hp"] -= player_dps * delta
        battle_data["player_current_hp"] -= enemy_dps * delta

        for tactic in battle_data["tactics_cooldowns"]:
                if battle_data["tactics_cooldowns"][tactic] > 0:
                        battle_data["tactics_cooldowns"][tactic] -= delta
        for tactic in battle_data["tactics_active"].duplicate():
                if battle_data["tactics_active"][tactic] > 0:
                        battle_data["tactics_active"][tactic] -= delta
                        if battle_data["tactics_active"][tactic] <= 0:
                                battle_data["tactics_active"].erase(tactic)
                                battle_data["log"].append("⏹️ انتهى تأثير " + tactic)

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
                        battle_data["log"].append("🏳️ انسحاب!")
                        end_battle(false)
                        return true
        return true

func end_battle(won: bool) -> void:
        battle_active = false
        var deployed_count: int = battle_data.get("deployed_count", 0)
        var loot := {"scrap": 0, "fuel": 0, "intel": 0, "troops_lost": 0, "xp_gained": 0, "stars": 0}

        if won:
                total_battles_won += 1
                consecutive_wins += 1
                var base: int = battle_data["enemy_power"]
                loot["scrap"] = base * 2
                loot["fuel"] = base
                loot["intel"] = int(base * 0.5)
                scrap += loot["scrap"]
                fuel += loot["fuel"]
                intel += loot["intel"]
                total_scrap_earned += loot["scrap"]
                total_fuel_earned += loot["fuel"]
                total_intel_earned += loot["intel"]
                battle_data["log"].append("🏆 نصر! غنائم: %d خردة, %d وقود, %d معلومات" % [loot["scrap"], loot["fuel"], loot["intel"]])

                if battle_target_sector_id != "":
                        clear_sector(battle_target_sector_id)
                        battle_data["log"].append("🗺️ تم تطهير القطاع!")

                var win_loss_rate: float = 0.10 + randf() * 0.10
                # تقليل الخسائر بفضل المستشفيات
                if battle_target_sector_id != "":
                        var hosp_reduction: float = get_hospital_loss_reduction(battle_target_sector_id)
                        win_loss_rate *= (1.0 - hosp_reduction)
                loot["troops_lost"] = _apply_battle_losses(deployed_count, win_loss_rate)
                if loot["troops_lost"] > 0:
                        battle_data["log"].append("☠️ خسائر: %d جندي" % loot["troops_lost"])

                player_morale = mini(100.0, player_morale + 5.0)
                # XP من المعركة
                loot["xp_gained"] = add_xp(base, "battle")
        else:
                total_battles_lost += 1
                consecutive_wins = 0
                battle_data["log"].append("💔 هزيمة...")
                var loss_loss_rate: float = 0.30 + randf() * 0.20
                loot["troops_lost"] = _apply_battle_losses(deployed_count, loss_loss_rate)
                if loot["troops_lost"] > 0:
                        battle_data["log"].append("☠️ خسائر فادحة: %d جندي" % loot["troops_lost"])
                player_morale = maxi(0.0, player_morale - 10.0)
                # XP صغير حتى عند الهزيمة
                loot["xp_gained"] = add_xp(int(battle_data["enemy_power"] * 0.2), "battle")

        # الحملات
        if battle_is_campaign:
                loot["stars"] = calculate_battle_stars() if won else 0
                complete_campaign_stage(won, loot["stars"])

        battle_target_sector_id = ""
        clear_deployment()
        battle_ended.emit(won, loot)
        track_battle()
        check_achievements()
        save_game()

func _apply_battle_losses(total_deployed: int, loss_rate: float) -> int:
        if total_deployed <= 0:
                return 0
        var total_lost := 0
        for c in companies:
                for squad in c["squads"]:
                        if squad["size"] <= 0:
                                continue
                        var squad_loss: int = int(float(squad["size"]) * loss_rate)
                        if randf() < 0.3 and squad_loss < squad["size"]:
                                squad_loss += 1
                        squad_loss = mini(squad_loss, squad["size"])
                        squad["size"] -= squad_loss
                        total_lost += squad_loss
        troops_changed.emit()
        return total_lost

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
                        var is_explored: bool = (row == 3 and col == 0)
                        var power: int = 50 + (row + col) * 30 + randi() % 40
                        var loot_val: int = power / 2
                        world_sectors.append({
                                "id": "s_%d_%d" % [row, col], "row": row, "col": col,
                                "name": sector_names[idx] if idx < sector_names.size() else "قطاع %d" % idx,
                                "status": SectorStatus.EXPLORED if is_explored else SectorStatus.UNEXPLORED,
                                "enemy_power": power,
                                "loot": {"scrap": loot_val, "fuel": loot_val / 2, "intel": loot_val / 4},
                                "terrain": randi() % 5,
                        })
                        idx += 1

func scout_sector(sector_id: String) -> bool:
        var cost: int = 15 - _tech_scout_discount
        if intel < cost:
                return false
        for s in world_sectors:
                if s["id"] == sector_id and s["status"] == SectorStatus.UNEXPLORED:
                        intel -= cost
                        s["status"] = SectorStatus.EXPLORED
                        add_xp(10, "scout")
                        map_updated.emit()
                        track_scout()
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
                 "desc": "+50% هجوم", "cost_scrap": 1200, "cost_intel": 400,
                 "time": 120.0, "prereqs": ["t2_1", "t2_2"], "effect": "ballistic_50"},
                {"id": "t3_2", "name": "شبكة دفاعية", "icon": "🏰", "tier": 3,
                 "desc": "+40% دفاع", "cost_scrap": 1000, "cost_intel": 350,
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
                                recalculate_tech_bonuses()
                                add_xp(50, "research")
                                research_in_progress = ""
                                research_progress = 0.0
                                check_achievements()
                                save_game()
                        return

var _tech_attack_bonus: float = 0.0
var _tech_defense_bonus: float = 0.0
var _tech_scout_discount: int = 0
var _tech_weather_immune: bool = false

func recalculate_tech_bonuses() -> void:
        _tech_attack_bonus = 0.0
        _tech_defense_bonus = 0.0
        _tech_scout_discount = 0
        _tech_weather_immune = false
        for tech_id in completed_techs:
                match tech_id:
                        "t1_1": _tech_attack_bonus += 0.15
                        "t1_2": _tech_defense_bonus += 0.15
                        "t1_3": _tech_scout_discount = 8
                        "t2_1": _tech_attack_bonus += 0.25
                        "t2_2": _tech_defense_bonus += 0.25
                        "t2_3": _tech_weather_immune = true
                        "t3_1": _tech_attack_bonus += 0.50
                        "t3_2": _tech_defense_bonus += 0.40

func get_tech_info_text() -> String:
        var parts: PackedStringArray = []
        if _tech_attack_bonus > 0:
                parts.append("⚔️+%d%%" % int(_tech_attack_bonus * 100))
        if _tech_defense_bonus > 0:
                parts.append("🛡️+%d%%" % int(_tech_defense_bonus * 100))
        if _tech_weather_immune:
                parts.append("🌤️ مناعة")
        return " ".join(parts)

# ─── الروح المعنوية ───
var player_morale: float = 70.0

func get_morale_mult() -> float:
        return 0.5 + (player_morale / 100.0) * 0.5

# ─── Idle ───
var idle_timer: float = 0.0

func _idle_tick(delta: float) -> void:
        idle_timer += delta
        if idle_timer >= 1.0:
                idle_timer -= 1.0
                var prod: Dictionary = get_total_production_per_second()
                scrap += int(prod["scrap"])
                fuel += int(prod["fuel"])
                intel += int(prod["intel"])
                # إنتاج قواعد الإمداد في القطاعات المحررة
                for s in world_sectors:
                        if s["status"] == SectorStatus.CLEARED:
                                var fort_prod: Dictionary = get_fort_production(s["id"])
                                scrap += int(fort_prod["scrap"])
                                fuel += int(fort_prod["fuel"])
                                intel += int(fort_prod["intel"])

# ═══════════════════════════════════════════════════
# نظام الإنجازات
# ═══════════════════════════════════════════════════
var achievements: Array[Dictionary] = []
var total_battles_won: int = 0
var total_battles_lost: int = 0
var consecutive_wins: int = 0

func _init_achievements() -> void:
        achievements = [
                # ─── قتال (6) ───
                {"id": "first_blood", "name": "الدم الأول", "icon": "🗡️", "desc": "فُز بأول معركة", "category": "combat",
                 "reward": {"scrap": 100, "fuel": 50, "xp": 30}, "completed": false, "claimed": false},
                {"id": "veteran", "name": "المحارب المخضرم", "icon": "⚔️", "desc": "فُز بـ 10 معارك", "category": "combat",
                 "reward": {"scrap": 300, "fuel": 150, "xp": 100}, "completed": false, "claimed": false},
                {"id": "warlord", "name": "سيد الحرب", "icon": "💀", "desc": "فُز بـ 50 معارك", "category": "combat",
                 "reward": {"scrap": 1000, "fuel": 500, "xp": 300}, "completed": false, "claimed": false},
                {"id": "boss_slayer", "name": "قاتل الزعماء", "icon": "👹", "desc": "هزم أول Boss", "category": "combat",
                 "reward": {"scrap": 500, "fuel": 250, "xp": 150}, "completed": false, "claimed": false},
                {"id": "undefeated", "name": "لا يُقهر", "icon": "🏆", "desc": "فُز بـ 5 معارك متتالية", "category": "combat",
                 "reward": {"scrap": 400, "fuel": 200, "xp": 120}, "completed": false, "claimed": false},
                {"id": "perfect_battle", "name": "معركة مثالية", "icon": "⭐", "desc": "احصل على 3 نجوم في أي مرحلة حملة", "category": "combat",
                 "reward": {"scrap": 600, "fuel": 300, "xp": 200}, "completed": false, "claimed": false},
                # ─── اقتصاد (5) ───
                {"id": "scrap_hoarder", "name": "جامع الخردة", "icon": "⚙️", "desc": "اجمع 5000 خردة", "category": "economy",
                 "reward": {"scrap": 500, "fuel": 200, "xp": 100}, "completed": false, "claimed": false},
                {"id": "fuel_reserve", "name": "احتياطي الوقود", "icon": "⛽", "desc": "اجمع 3000 وقود", "category": "economy",
                 "reward": {"scrap": 200, "fuel": 500, "xp": 100}, "completed": false, "claimed": false},
                {"id": "intel_master", "name": "سيد الاستخبارات", "icon": "📋", "desc": "اجمع 1500 معلومات", "category": "economy",
                 "reward": {"scrap": 300, "fuel": 300, "xp": 150}, "completed": false, "claimed": false},
                {"id": "builder", "name": "المهندس", "icon": "🏗️", "desc": "رقِّ أي منشأة 5 مرات", "category": "economy",
                 "reward": {"scrap": 400, "fuel": 200, "xp": 120}, "completed": false, "claimed": false},
                {"id": "convoy_master", "name": "سيد القوافل", "icon": "🚛", "desc": "أكمل 10 قوافل", "category": "economy",
                 "reward": {"scrap": 500, "fuel": 300, "xp": 150}, "completed": false, "claimed": false},
                # ─── حملات (5) ───
                {"id": "campaign_start", "name": "بداية الرحلة", "icon": "📖", "desc": "أكمل المرحلة 1 من الحملة", "category": "campaign",
                 "reward": {"scrap": 200, "fuel": 100, "xp": 50}, "completed": false, "claimed": false},
                {"id": "chapter1_done", "name": "نهاية الفصل الأول", "icon": "📕", "desc": "أكمل المرحلة 5 من الحملة", "category": "campaign",
                 "reward": {"scrap": 400, "fuel": 200, "xp": 150}, "completed": false, "claimed": false},
                {"id": "chapter2_done", "name": "نهاية الفصل الثاني", "icon": "📗", "desc": "أكمل المرحلة 10 من الحملة", "category": "campaign",
                 "reward": {"scrap": 600, "fuel": 300, "xp": 200}, "completed": false, "claimed": false},
                {"id": "chapter3_done", "name": "نهاية الفصل الثالث", "icon": "📘", "desc": "أكمل المرحلة 15 من الحملة", "category": "campaign",
                 "reward": {"scrap": 800, "fuel": 400, "xp": 300}, "completed": false, "claimed": false},
                {"id": "conqueror", "name": "الفاتح", "icon": "👑", "desc": "أكمل كل 25 مرحلة حملة", "category": "campaign",
                 "reward": {"scrap": 2000, "fuel": 1000, "xp": 500}, "completed": false, "claimed": false},
                # ─── عسكري (4) ───
                {"id": "army_100", "name": "جيش المئة", "icon": "🎖️", "desc": "اجمع 100 جندي", "category": "military",
                 "reward": {"scrap": 300, "fuel": 150, "xp": 100}, "completed": false, "claimed": false},
                {"id": "all_officers", "name": "طاقم كامل", "icon": "🪖", "desc": "عيّن كل الـ 4 ضباط", "category": "military",
                 "reward": {"scrap": 500, "fuel": 250, "xp": 150}, "completed": false, "claimed": false},
                {"id": "max_officer", "name": "قائد متمرس", "icon": "🏅", "desc": "رقِّ أي ضابط للمستوى 10", "category": "military",
                 "reward": {"scrap": 800, "fuel": 400, "xp": 250}, "completed": false, "claimed": false},
                {"id": "fort_builder", "name": "بناة التحصينات", "icon": "🏰", "desc": "ابنِ 5 تحصينات", "category": "military",
                 "reward": {"scrap": 400, "fuel": 200, "xp": 120}, "completed": false, "claimed": false},
                # ─── اجتماعي (4) ───
                {"id": "first_convoy", "name": "أول قافلة", "icon": "🚚", "desc": "أطلق أول قافلة إمداد", "category": "social",
                 "reward": {"scrap": 100, "fuel": 50, "xp": 30}, "completed": false, "claimed": false},
                {"id": "first_fort", "name": "أول تحصين", "icon": "🏗️", "desc": "ابنِ أول تحصين", "category": "social",
                 "reward": {"scrap": 100, "fuel": 50, "xp": 30}, "completed": false, "claimed": false},
                {"id": "first_officer", "name": "أول ضابط", "icon": "🎖️", "desc": "عيّن أول ضابط", "category": "social",
                 "reward": {"scrap": 100, "fuel": 50, "xp": 30}, "completed": false, "claimed": false},
                {"id": "first_research", "name": "أول بحث", "icon": "🔬", "desc": "أكمل أول بحث علمي", "category": "social",
                 "reward": {"scrap": 100, "fuel": 50, "xp": 30}, "completed": false, "claimed": false},
        ]

func check_achievements() -> void:
        for a in achievements:
                if a["completed"]:
                        continue
                var met := false
                match a["id"]:
                        "first_blood":
                                met = total_battles_won >= 1
                        "veteran":
                                met = total_battles_won >= 10
                        "warlord":
                                met = total_battles_won >= 50
                        "boss_slayer":
                                met = _has_beaten_boss()
                        "undefeated":
                                met = consecutive_wins >= 5
                        "perfect_battle":
                                met = _has_3_star_stage()
                        "scrap_hoarder":
                                met = scrap >= 5000
                        "fuel_reserve":
                                met = fuel >= 3000
                        "intel_master":
                                met = intel >= 1500
                        "builder":
                                met = _max_building_level() >= 6
                        "convoy_master":
                                met = completed_convoys_count >= 10
                        "campaign_start":
                                met = current_campaign_stage >= 1
                        "chapter1_done":
                                met = current_campaign_stage >= 5
                        "chapter2_done":
                                met = current_campaign_stage >= 10
                        "chapter3_done":
                                met = current_campaign_stage >= 15
                        "conqueror":
                                met = current_campaign_stage >= 25
                        "army_100":
                                met = _get_total_troops() >= 100
                        "all_officers":
                                met = get_officer_active_count() >= 4
                        "max_officer":
                                met = _has_max_level_officer()
                        "fort_builder":
                                met = fortifications.size() >= 5
                        "first_convoy":
                                met = completed_convoys_count >= 1
                        "first_fort":
                                met = fortifications.size() >= 1
                        "first_officer":
                                met = get_officer_active_count() >= 1
                        "first_research":
                                met = completed_techs.size() >= 1
                if met:
                        a["completed"] = true
                        achievement_unlocked.emit(a["id"])
                        achievements_changed.emit()

func claim_achievement(achievement_id: String) -> bool:
        for a in achievements:
                if a["id"] == achievement_id and a["completed"] and not a["claimed"]:
                        a["claimed"] = true
                        var r: Dictionary = a["reward"]
                        scrap += r.get("scrap", 0)
                        fuel += r.get("fuel", 0)
                        add_xp(r.get("xp", 0), "achievement")
                        achievements_changed.emit()
                        return true
        return false

func _has_beaten_boss() -> bool:
        for s in campaign_stages:
                if s.get("is_boss", false) and s.get("first_completed", false):
                        return true
        return false

func _has_3_star_stage() -> bool:
        for s in campaign_stages:
                if s.get("stars_earned", 0) >= 3:
                        return true
        return false

func _max_building_level() -> int:
        var max_lvl := 0
        for b in buildings:
                if b["level"] > max_lvl:
                        max_lvl = b["level"]
        return max_lvl

func _get_total_troops() -> int:
        var total := 0
        for c in companies:
                total += get_company_troop_count(c)
        return total

func _has_max_level_officer() -> bool:
        for o in officers:
                if o["active"] and o["level"] >= o["max_level"]:
                        return true
        return false

# ═══════════════════════════════════════════════════
# نظام الإعدادات والإحصائيات
# ═══════════════════════════════════════════════════
var settings: Dictionary = {"sound_enabled": true, "notifications_enabled": true, "auto_save_enabled": true}
var total_scrap_earned: int = 0
var total_fuel_earned: int = 0
var total_intel_earned: int = 0
var total_play_time: float = 0.0
var total_xp_earned: int = 0

func reset_game() -> void:
        if FileAccess.file_exists(SAVE_PATH):
                DirAccess.remove_absolute(SAVE_PATH)
        scrap = 500
        fuel = 300
        intel = 100
        player_level = 1
        player_xp = 0
        level_bonus_attack = 0.0
        level_bonus_defense = 0.0
        level_bonus_production = 0.0
        level_skill_points = 0
        player_morale = 70.0
        total_battles_won = 0
        total_battles_lost = 0
        consecutive_wins = 0
        total_scrap_earned = 0
        total_fuel_earned = 0
        total_intel_earned = 0
        total_play_time = 0.0
        total_xp_earned = 0
        current_campaign_stage = 0
        battle_is_campaign = false
        battle_campaign_stage_id = -1
        completed_convoys_count = 0
        completed_techs = []
        research_in_progress = ""
        research_progress = 0.0
        tutorial_step = 0
        tutorial_completed = false
        show_tutorial = true
        settings = {"sound_enabled": true, "notifications_enabled": true, "auto_save_enabled": true}
        _init_buildings()
        _init_companies()
        _init_deployment()
        _init_world_map()
        _init_tech_tree()
        _init_campaigns()
        _init_officers()
        _init_fortifications()
        _init_missions()
        _init_events()
        _init_convoys()
        _init_troop_upgrades()
        _init_achievements()
        recalculate_tech_bonuses()
        settings_changed.emit()

# ═══════════════════════════════════════════════════
# نظام التعليمات
# ═══════════════════════════════════════════════════
var tutorial_step: int = 0
var tutorial_completed: bool = false
var show_tutorial: bool = true

var tutorial_texts: Array[String] = [
        "",
        "مرحباً يا جنرال! أنت قائد القوات المسلحة. هدفك تحرير المناطق من سيطرة العدو.",
        "⚙️ الخردة و ⛽ الوقود و 📋 المعلومات — هذه مواردك الأساسية. المنشآت تنتجها تلقائياً.",
        "اختار القوات وانشرها في الموجات. المشاة رخيصة، المدرعات متوازنة، والطيران قوي لكن مكلف.",
        "⚡ اضغط 'هجوم' لبدء المعركة. استخدم التكتيكات: دخان لتقليل ضرر العدو، دعم جوي لزيادة ضررك.",
        "🗺️ استكشف الخريطة لتحرير القطاعات. كل قطاع يمنحك موارد وXP.",
        "📖 الحملات تقدمك في القصة مع مراحل صعبة وBosses.",
        "🎖️ عيّن ضباطاً في الثكنات لتحسين قدرات قواتك.",
        "أنت جاهز! ابدأ بتحرير أول قطاع من الخريطة. حظاً موفقاً يا جنرال!",
]

func advance_tutorial() -> void:
        tutorial_step += 1
        if tutorial_step >= tutorial_texts.size():
                tutorial_completed = true
                tutorial_step = 0
                show_tutorial = false
        tutorial_step_changed.emit(tutorial_step)

func is_tutorial_done() -> bool:
        return tutorial_completed or tutorial_step == 0

# ─── الحفظ والتحميل ───
const SAVE_PATH := "user://generals_fist_save.json"

func save_game() -> void:
        # حفظ حالة الحملات
        var campaign_save: Array = []
        for s in campaign_stages:
                campaign_save.append({
                        "id": s["id"], "stars_earned": s.get("stars_earned", 0),
                        "first_completed": s.get("first_completed", false),
                })
        var data := {
                "scrap": scrap, "fuel": fuel, "intel": intel,
                "buildings": buildings, "companies": companies,
                "deployment": deployment, "world_sectors": world_sectors,
                "selected_terrain": selected_terrain, "current_weather": current_weather,
                "player_morale": player_morale, "completed_techs": completed_techs,
                "last_online_time": Time.get_unix_time_from_system(),
                # نظام المستوى
                "player_level": player_level, "player_xp": player_xp,
                "level_bonus_attack": level_bonus_attack,
                "level_bonus_defense": level_bonus_defense,
                "level_bonus_production": level_bonus_production,
                "level_skill_points": level_skill_points,
                # نظام الحملات
                "current_campaign_stage": current_campaign_stage,
                "campaign_save": campaign_save,
                # أنظمة L2
                "officers": officers, "fortifications": fortifications,
                "daily_missions": daily_missions, "weekly_missions": weekly_missions,
                "last_daily_refresh": last_daily_refresh, "last_weekly_refresh": last_weekly_refresh,
                # أنظمة L3
                "troop_upgrades": troop_upgrades, "active_convoys": active_convoys,
                "completed_convoys_count": completed_convoys_count,
                # أنظمة L4
                "achievements": achievements, "settings": settings,
                "total_battles_won": total_battles_won,
                "total_battles_lost": total_battles_lost,
                "consecutive_wins": consecutive_wins,
                "total_scrap_earned": total_scrap_earned,
                "total_fuel_earned": total_fuel_earned,
                "total_intel_earned": total_intel_earned,
                "total_play_time": total_play_time,
                "total_xp_earned": total_xp_earned,
                "tutorial_step": tutorial_step,
                "tutorial_completed": tutorial_completed,
                "show_tutorial": show_tutorial,
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
        scrap = data.get("scrap", 500)
        fuel = data.get("fuel", 300)
        intel = data.get("intel", 100)
        if data.has("buildings"):
                buildings.assign(data["buildings"])
        if data.has("companies"):
                companies.assign(data["companies"])
        if data.has("deployment"):
                deployment = data["deployment"]
        if data.has("world_sectors"):
                world_sectors.assign(data["world_sectors"])
        selected_terrain = data.get("selected_terrain", Terrain.PLAINS)
        current_weather = data.get("current_weather", Weather.CLEAR)
        player_morale = data.get("player_morale", 70.0)
        if data.has("completed_techs"): completed_techs.assign(data["completed_techs"])
        last_online_time = data.get("last_online_time", 0)
        # استعادة المستوى
        player_level = data.get("player_level", 1)
        player_xp = data.get("player_xp", 0)
        level_bonus_attack = data.get("level_bonus_attack", 0.0)
        level_bonus_defense = data.get("level_bonus_defense", 0.0)
        level_bonus_production = data.get("level_bonus_production", 0.0)
        level_skill_points = data.get("level_skill_points", 0)
        # استعادة الحملات
        current_campaign_stage = data.get("current_campaign_stage", 0)
        var campaign_save: Array = data.get("campaign_save", [])
        for cs in campaign_save:
                for s in campaign_stages:
                        if s["id"] == cs.get("id", -1):
                                s["stars_earned"] = cs.get("stars_earned", 0)
                                s["first_completed"] = cs.get("first_completed", false)
                                break
        recalculate_tech_bonuses()
        # استعادة أنظمة L2
        if data.has("officers"): officers.assign(data["officers"])
        if data.has("fortifications"): fortifications.assign(data["fortifications"])
        if data.has("daily_missions"): daily_missions.assign(data["daily_missions"])
        if data.has("weekly_missions"): weekly_missions.assign(data["weekly_missions"])
        last_daily_refresh = data.get("last_daily_refresh", 0)
        last_weekly_refresh = data.get("last_weekly_refresh", 0)
        # استعادة أنظمة L3
        if data.has("troop_upgrades"): troop_upgrades = data["troop_upgrades"]
        if data.has("active_convoys"): active_convoys.assign(data["active_convoys"])
        completed_convoys_count = data.get("completed_convoys_count", 0)
        # استعادة أنظمة L4
        if data.has("achievements"): achievements.assign(data["achievements"])
        if data.has("settings"): settings = data["settings"]
        total_battles_won = data.get("total_battles_won", 0)
        total_battles_lost = data.get("total_battles_lost", 0)
        consecutive_wins = data.get("consecutive_wins", 0)
        total_scrap_earned = data.get("total_scrap_earned", 0)
        total_fuel_earned = data.get("total_fuel_earned", 0)
        total_intel_earned = data.get("total_intel_earned", 0)
        total_play_time = data.get("total_play_time", 0.0)
        total_xp_earned = data.get("total_xp_earned", 0)
        tutorial_step = data.get("tutorial_step", 0)
        tutorial_completed = data.get("tutorial_completed", false)
        show_tutorial = data.get("show_tutorial", true)
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

# ─── حفظ تلقائي ───
var _auto_save_timer: float = 0.0
const AUTO_SAVE_INTERVAL: float = 60.0

# ─── التهيئة ───
func _ready() -> void:
        _init_buildings()
        _init_companies()
        _init_deployment()
        _init_world_map()
        _init_tech_tree()
        _init_campaigns()
        _init_officers()
        _init_fortifications()
        _init_missions()
        _init_events()
        _init_convoys()
        _init_troop_upgrades()
        _init_achievements()
        if not load_game():
                print("[GameManager] بداية لعبة جديدة")
        check_mission_refresh()
        recalculate_tech_bonuses()

func _notification(what: int) -> void:
        if what == NOTIFICATION_WM_GO_BACK_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
                save_game()

var _achievement_check_timer: float = 0.0

func _process(delta: float) -> void:
        total_play_time += delta
        _idle_tick(delta)
        update_events(delta)
        update_research(delta)
        update_weather_cycle(delta)
        update_convoys(delta)
        if battle_active:
                update_battle(delta)
        _auto_save_timer += delta
        if _auto_save_timer >= AUTO_SAVE_INTERVAL:
                _auto_save_timer = 0.0
                save_game()
        # فحص الإنجازات المبنية على الموارد كل 5 ثواني
        _achievement_check_timer += delta
        if _achievement_check_timer >= 5.0:
                _achievement_check_timer = 0.0
                check_achievements()
