# -*- coding: utf-8 -*-
"""
慢病饮食管理 - 多病种规则引擎
- GoutEngine：嘌呤 → 红黄绿 + 每日嘌呤额度（发作期/缓解期）
- DiabetesEngine：GI/碳水 → 红黄绿 + 每日碳水额度（标准控糖/强化控糖）
- HypertensionEngine：胆固醇主进度条 + 钠定性灯/文案 + 饱和脂肪卡片（普通/强化控制）
- load_engine(disease)：工厂路由 gout / diabetes / hypertension

主链路：识别菜品 → 含量换算 → 模式匹配 → 红黄绿建议 → 每日打卡
"""
import json
import os

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

VALID_DISEASES = ("gout", "diabetes", "hypertension")
LIGHT_RANK = {"红灯": 3, "黄灯": 2, "绿灯": 1}


def _load_json(filename):
    with open(os.path.join(BASE_DIR, filename), encoding="utf-8") as f:
        return json.load(f)


class _BaseEngine:
    """规则匹配 / 映射索引共用逻辑"""

    disease = None
    rules_file = None
    food_file = None
    mapping_file = None

    def __init__(self):
        self.rules_data = _load_json(self.rules_file)
        self.food_data = _load_json(self.food_file)
        self.mapping_data = _load_json(self.mapping_file)
        self.rules = self.rules_data["rules"]
        self.foods = self.food_data["foods"]
        self.mappings = self.mapping_data["mappings"]
        self.modes = self.rules_data["meta"]["modes"]
        self._food_index = {}
        self._rule_index = {}
        self._vision_map = {}
        self._rule_by_id = {r["rule_id"]: r for r in self.rules}
        self._build_index()

    def _build_index(self):
        for food in self.foods:
            for name in [food["name"]] + food.get("alias", []):
                self._food_index[name] = food
        for rule in self.rules:
            for kw in rule.get("keywords", []):
                kw = kw.strip()
                if not kw:
                    continue
                if kw not in self._rule_index or LIGHT_RANK[rule["light"]] > LIGHT_RANK[self._rule_index[kw]["light"]]:
                    self._rule_index[kw] = rule
        for mp in self.mappings:
            self._vision_map[mp["vision_name"]] = mp

    def match_vision_mapping(self, name):
        """①视觉识别名映射表精确；映射 light 覆盖规则 light（同菜异色场景）"""
        if name not in self._vision_map:
            return None
        mp = self._vision_map[name]
        rule = None
        rid = mp.get("rule_id")
        if rid and rid in self._rule_by_id:
            # 拷贝后覆盖灯色/理由，避免改到规则库原对象
            rule = dict(self._rule_by_id[rid])
            if mp.get("light"):
                rule["light"] = mp["light"]
            if mp.get("reason"):
                rule["basis"] = mp["reason"]
        if rule is None:
            rule = {
                "light": mp["light"],
                "advice": mp.get("reason", ""),
                "basis": mp.get("reason", ""),
                "replacement": "",
                "rule_id": rid or ("MAP" + name[:6]),
            }
        return {
            "rule": rule,
            "mapped_light": mp["light"],
            "mapped_reason": mp.get("reason", ""),
            "source": "vision_mapping",
        }

    def recognize(self, dish_names):
        return [{"name": n.strip(), "weight_g": 100} for n in dish_names if n and n.strip()]

    def match_rule(self, name):
        rule, _src = self.match_rule_with_source(name)
        return rule

    def match_rule_with_source(self, name):
        """返回 (rule|None, source) source=local_map|local_keyword|None"""
        mapped = self.match_vision_mapping(name)
        if mapped:
            return mapped["rule"], "local_map"
        if name in self._rule_index:
            return self._rule_index[name], "local_keyword"
        best = None
        for kw, rule in self._rule_index.items():
            if kw and kw in name and len(kw) >= 2:
                if best is None or LIGHT_RANK[rule["light"]] > LIGHT_RANK[best["light"]]:
                    best = rule
        if best:
            return best, "local_keyword"
        return None, None

    def rule_source(self, name):
        _rule, src = self.match_rule_with_source(name)
        return src

    def _check_mode(self, mode):
        if mode not in self.modes:
            raise ValueError("mode 必须是 %s 之一（disease=%s）" % ("/".join(self.modes), self.disease))

    def _overall_light(self, results):
        """仅根据已评估灯色取最高风险；全部未评估时返回 None（禁止默认绿灯）"""
        max_light = None
        for r in results:
            light = r.get("light")
            if light in LIGHT_RANK:
                if max_light is None or LIGHT_RANK[light] > LIGHT_RANK[max_light]:
                    max_light = light
        return max_light


class GoutEngine(_BaseEngine):
    """痛风：嘌呤驱动"""

    disease = "gout"
    rules_file = "gout_rules.json"
    food_file = "food_purine.json"
    mapping_file = "vision_dish_mapping.json"

    def __init__(self):
        super().__init__()
        self.daily_limits = self.rules_data["meta"]["daily_purine_limit_mg"]

    def purine_lookup(self, name):
        food = self._food_index.get(name)
        if not food:
            return None
        return {
            "name": food["name"],
            "purine_mg": food["purine_mg"],
            "kcal": food["kcal"],
            "protein_g": food["protein_g"],
            "fat_g": food["fat_g"],
            "carb_g": food["carb_g"],
        }

    def analyze_dish(self, dish_name, weight_g=100, mode="缓解期"):
        result = {
            "dish": dish_name,
            "weight_g": weight_g,
            "purine_mg": None,
            "nutrition": None,
            "advice": None,
            "light": None,
            "reason": None,
        }
        nutr = self.purine_lookup(dish_name)
        if nutr:
            ratio = weight_g / 100.0
            result["purine_mg"] = round(nutr["purine_mg"] * ratio, 1)
            result["nutrition"] = {
                "kcal": round(nutr["kcal"] * ratio, 1),
                "protein_g": round(nutr["protein_g"] * ratio, 1),
                "fat_g": round(nutr["fat_g"] * ratio, 1),
                "carb_g": round(nutr["carb_g"] * ratio, 1),
            }
        rule, src = self.match_rule_with_source(dish_name)
        if rule:
            result["advice"] = rule["advice"]
            result["light"] = rule["light"]
            result["reason"] = rule["basis"]
            result["replacement"] = rule.get("replacement", "")
            result["rule_id"] = rule["rule_id"]
            result["rule_mode"] = rule.get("mode", "")
            result["source"] = src
        else:
            result["source"] = None
            result["light"] = None
        return result

    def analyze_meal(self, dish_names, mode="缓解期", weights=None):
        self._check_mode(mode)
        if weights is None:
            weights = [100] * len(dish_names)
        dishes = [{"name": n.strip(), "weight_g": w} for n, w in zip(dish_names, weights) if n and n.strip()]
        results = [self.analyze_dish(d["name"], d["weight_g"], mode) for d in dishes]

        total_purine = sum(r["purine_mg"] for r in results if r["purine_mg"] is not None)
        total = {"kcal": 0, "protein_g": 0, "fat_g": 0, "carb_g": 0}
        for r in results:
            if r["nutrition"]:
                for k in total:
                    total[k] += r["nutrition"][k]

        limit = self.daily_limits.get(mode, 300)
        return {
            "disease": self.disease,
            "mode": mode,
            "daily_purine_limit_mg": limit,
            "dishes": results,
            "summary": {
                "overall_light": self._overall_light(results),
                "total_purine_mg": round(total_purine, 1),
                "purine_pct_of_daily": round(min(total_purine / limit * 100, 999), 1) if limit else 0,
                "total_nutrition": {k: round(v, 1) for k, v in total.items()},
            },
        }

    def daily_summary(self, meals, mode="缓解期"):
        self._check_mode(mode)
        daily = {"purine_mg": 0.0, "kcal": 0, "protein_g": 0, "fat_g": 0, "carb_g": 0}
        for meal in meals:
            s = meal["summary"]
            daily["purine_mg"] += s.get("total_purine_mg", 0)
            t = s.get("total_nutrition", {})
            for k in ("kcal", "protein_g", "fat_g", "carb_g"):
                daily[k] += t.get(k, 0)
        limit = self.daily_limits.get(mode, 300)
        remaining = max(limit - daily["purine_mg"], 0)
        achievement = round(min(daily["purine_mg"] / limit * 100, 999), 1) if limit else 0
        return {
            "disease": self.disease,
            "mode": mode,
            "purine_limit_mg": limit,
            "intake_purine_mg": round(daily["purine_mg"], 1),
            "remaining_purine_mg": round(remaining, 1),
            "purine_achievement_pct": achievement,
            "intake_nutrition": {k: round(v, 1) for k, v in daily.items() if k != "purine_mg"},
        }


class DiabetesEngine(_BaseEngine):
    """糖尿病：GI / 碳水驱动；红灯语义=严格限量（非禁食）"""

    disease = "diabetes"
    rules_file = "diabetes_rules.json"
    food_file = "food_gi.json"
    mapping_file = "vision_dish_mapping_diabetes.json"

    def __init__(self):
        super().__init__()
        self.daily_limits = self.rules_data["meta"]["daily_carb_limit_g"]
        self.gi_grade = self.rules_data["meta"].get("gi_grade", {})
        self.light_semantics = self.rules_data["meta"].get("light_semantics", {})

    def gi_lookup(self, name):
        """按名称匹配 GI/碳水库，返回每100g（未命中返回 None）"""
        food = self._food_index.get(name)
        if not food:
            return None
        return {
            "name": food["name"],
            "gi": food.get("gi"),
            "carb_g": food["carb_g"],
            "kcal": food["kcal"],
            "protein_g": food["protein_g"],
            "fat_g": food["fat_g"],
        }

    def analyze_dish(self, dish_name, weight_g=100, mode="标准控糖"):
        result = {
            "dish": dish_name,
            "weight_g": weight_g,
            "gi": None,
            "carb_g": None,
            "nutrition": None,
            "advice": None,
            "light": None,
            "reason": None,
        }
        nutr = self.gi_lookup(dish_name)
        rule, src = self.match_rule_with_source(dish_name)
        ratio = weight_g / 100.0

        if nutr:
            result["gi"] = nutr["gi"]
            result["carb_g"] = round(nutr["carb_g"] * ratio, 1)
            result["nutrition"] = {
                "kcal": round(nutr["kcal"] * ratio, 1),
                "protein_g": round(nutr["protein_g"] * ratio, 1),
                "fat_g": round(nutr["fat_g"] * ratio, 1),
                "carb_g": round(nutr["carb_g"] * ratio, 1),
                "gi": nutr["gi"],
            }
        elif rule and rule.get("carb_g_per100g") is not None:
            # 库未命中时用规则表碳水估算
            result["carb_g"] = round(float(rule["carb_g_per100g"]) * ratio, 1)
            if rule.get("gi") is not None:
                result["gi"] = rule["gi"]

        if rule:
            if result["gi"] is None and rule.get("gi") is not None:
                result["gi"] = rule["gi"]
            result["advice"] = rule["advice"]
            result["light"] = rule["light"]
            result["reason"] = rule["basis"]
            result["replacement"] = rule.get("replacement", "")
            result["rule_id"] = rule["rule_id"]
            result["rule_mode"] = rule.get("mode", "")
            result["light_semantics"] = self.light_semantics.get(rule["light"], "")
            result["source"] = src
        else:
            result["source"] = None
            result["light"] = None
        return result

    def analyze_meal(self, dish_names, mode="标准控糖", weights=None):
        self._check_mode(mode)
        if weights is None:
            weights = [100] * len(dish_names)
        dishes = [{"name": n.strip(), "weight_g": w} for n, w in zip(dish_names, weights) if n and n.strip()]
        results = [self.analyze_dish(d["name"], d["weight_g"], mode) for d in dishes]

        total_carb = sum(r["carb_g"] for r in results if r["carb_g"] is not None)
        total = {"kcal": 0, "protein_g": 0, "fat_g": 0, "carb_g": 0}
        for r in results:
            if r["nutrition"]:
                for k in total:
                    total[k] += r["nutrition"].get(k, 0)
            elif r["carb_g"] is not None:
                total["carb_g"] += r["carb_g"]

        limit = self.daily_limits.get(mode, 180)
        return {
            "disease": self.disease,
            "mode": mode,
            "daily_carb_limit_g": limit,
            "dishes": results,
            "summary": {
                "overall_light": self._overall_light(results),
                "total_carb_g": round(total_carb, 1),
                "carb_pct_of_daily": round(min(total_carb / limit * 100, 999), 1) if limit else 0,
                "total_nutrition": {k: round(v, 1) for k, v in total.items()},
            },
        }

    def daily_summary(self, meals, mode="标准控糖"):
        self._check_mode(mode)
        daily = {"carb_g": 0.0, "kcal": 0, "protein_g": 0, "fat_g": 0}
        for meal in meals:
            s = meal["summary"]
            daily["carb_g"] += s.get("total_carb_g", 0)
            t = s.get("total_nutrition", {})
            for k in ("kcal", "protein_g", "fat_g"):
                daily[k] += t.get(k, 0)
        limit = self.daily_limits.get(mode, 180)
        remaining = max(limit - daily["carb_g"], 0)
        achievement = round(min(daily["carb_g"] / limit * 100, 999), 1) if limit else 0
        return {
            "disease": self.disease,
            "mode": mode,
            "carb_limit_g": limit,
            "intake_carb_g": round(daily["carb_g"], 1),
            "remaining_carb_g": round(remaining, 1),
            "carb_achievement_pct": achievement,
            "intake_nutrition": {k: round(v, 1) for k, v in daily.items()},
        }


class HypertensionEngine(_BaseEngine):
    """高血压/高血脂：胆固醇主累计；钠定性灯+文案；饱和脂肪进单品卡片"""

    disease = "hypertension"
    rules_file = "hypertension_rules.json"
    food_file = "food_nutrition_ht.json"
    mapping_file = "vision_dish_mapping_hypertension.json"

    def __init__(self):
        super().__init__()
        self.daily_limits = self.rules_data["meta"]["cholesterol_limit_mg"]
        self.sodium_limits = self.rules_data["meta"].get("daily_sodium_limit_mg", {})
        self.light_semantics = self.rules_data["meta"].get("light_semantics", {})

    def ht_lookup(self, name):
        """含量库：胆固醇/钠/饱和脂肪（每100g）"""
        food = self._food_index.get(name)
        if not food:
            return None
        return {
            "name": food["name"],
            "cholesterol_mg": food.get("cholesterol_mg", 0),
            "sodium_mg": food.get("sodium_mg", 0),
            "sat_fat_g": food.get("sat_fat_g", 0),
            "kcal": food.get("kcal", 0),
            "protein_g": food.get("protein_g", 0),
            "fat_g": food.get("fat_g", 0),
        }

    def analyze_dish(self, dish_name, weight_g=100, mode="普通控制"):
        result = {
            "dish": dish_name,
            "weight_g": weight_g,
            "cholesterol_mg": None,
            "sodium_mg": None,
            "sat_fat_g": None,
            "nutrition": None,
            "advice": None,
            "light": None,
            "reason": None,
        }
        nutr = self.ht_lookup(dish_name)
        rule, src = self.match_rule_with_source(dish_name)
        ratio = weight_g / 100.0

        if nutr:
            result["cholesterol_mg"] = round(float(nutr["cholesterol_mg"]) * ratio, 1)
            result["sodium_mg"] = round(float(nutr["sodium_mg"]) * ratio, 1)
            result["sat_fat_g"] = round(float(nutr["sat_fat_g"]) * ratio, 2)
            result["nutrition"] = {
                "kcal": round(float(nutr["kcal"]) * ratio, 1),
                "protein_g": round(float(nutr["protein_g"]) * ratio, 1),
                "fat_g": round(float(nutr["fat_g"]) * ratio, 1),
                "cholesterol_mg": result["cholesterol_mg"],
                "sodium_mg": result["sodium_mg"],
                "sat_fat_g": result["sat_fat_g"],
            }
        elif rule:
            # 库未命中时用规则表字段估算
            if rule.get("cholesterol_mg") is not None:
                result["cholesterol_mg"] = round(float(rule["cholesterol_mg"]) * ratio, 1)
            if rule.get("sodium_mg_per100g") is not None:
                result["sodium_mg"] = round(float(rule["sodium_mg_per100g"]) * ratio, 1)
            if rule.get("sat_fat_g") is not None:
                result["sat_fat_g"] = round(float(rule["sat_fat_g"]) * ratio, 2)

        if rule:
            result["advice"] = rule["advice"]
            result["light"] = rule["light"]
            result["reason"] = rule["basis"]
            result["replacement"] = rule.get("replacement", "")
            result["rule_id"] = rule["rule_id"]
            result["rule_mode"] = rule.get("mode", "")
            result["light_semantics"] = self.light_semantics.get(rule["light"], "")
            result["source"] = src
            # 高盐提示：红灯且规则含钠时附定性标签（不驱动主进度条）
            if rule["light"] == "红灯" and (rule.get("sodium_mg_per100g") or 0) >= 800:
                result["sodium_note"] = "高盐风险（估算值）；注意隐性盐/调味料等量交换"
        else:
            result["source"] = None
            result["light"] = None
        return result

    def analyze_meal(self, dish_names, mode="普通控制", weights=None):
        self._check_mode(mode)
        if weights is None:
            weights = [100] * len(dish_names)
        dishes = [{"name": n.strip(), "weight_g": w} for n, w in zip(dish_names, weights) if n and n.strip()]
        results = [self.analyze_dish(d["name"], d["weight_g"], mode) for d in dishes]

        total_chol = sum(r["cholesterol_mg"] for r in results if r["cholesterol_mg"] is not None)
        total_sat = sum(r["sat_fat_g"] for r in results if r["sat_fat_g"] is not None)
        total = {"kcal": 0, "protein_g": 0, "fat_g": 0}
        for r in results:
            if r["nutrition"]:
                for k in total:
                    total[k] += r["nutrition"].get(k, 0)

        limit = self.daily_limits.get(mode, 300)
        return {
            "disease": self.disease,
            "mode": mode,
            "daily_cholesterol_limit_mg": limit,
            "daily_sodium_limit_mg": self.sodium_limits.get(mode),
            "primary_metric": "cholesterol_mg",
            "dishes": results,
            "summary": {
                "overall_light": self._overall_light(results),
                "total_cholesterol_mg": round(total_chol, 1),
                "cholesterol_pct_of_daily": round(min(total_chol / limit * 100, 999), 1) if limit else 0,
                "total_sat_fat_g": round(total_sat, 2),
                "total_nutrition": {k: round(v, 1) for k, v in total.items()},
                "sodium_qualitative": True,
            },
        }

    def daily_summary(self, meals, mode="普通控制"):
        self._check_mode(mode)
        daily = {"cholesterol_mg": 0.0, "sat_fat_g": 0.0, "kcal": 0, "protein_g": 0, "fat_g": 0}
        for meal in meals:
            s = meal["summary"]
            daily["cholesterol_mg"] += s.get("total_cholesterol_mg", 0)
            daily["sat_fat_g"] += s.get("total_sat_fat_g", 0)
            t = s.get("total_nutrition", {})
            for k in ("kcal", "protein_g", "fat_g"):
                daily[k] += t.get(k, 0)
        limit = self.daily_limits.get(mode, 300)
        remaining = max(limit - daily["cholesterol_mg"], 0)
        achievement = round(min(daily["cholesterol_mg"] / limit * 100, 999), 1) if limit else 0
        return {
            "disease": self.disease,
            "mode": mode,
            "cholesterol_limit_mg": limit,
            "intake_cholesterol_mg": round(daily["cholesterol_mg"], 1),
            "remaining_cholesterol_mg": round(remaining, 1),
            "cholesterol_achievement_pct": achievement,
            "intake_sat_fat_g": round(daily["sat_fat_g"], 2),
            "sodium_limit_mg_hint": self.sodium_limits.get(mode),
            "intake_nutrition": {
                k: round(v, 1) for k, v in daily.items() if k not in ("cholesterol_mg", "sat_fat_g")
            },
        }


# ---------- 工厂 ----------
_ENGINE_CACHE = {}


def load_engine(disease="gout"):
    """多病种工厂：gout / diabetes / hypertension（带实例缓存）"""
    key = (disease or "gout").strip().lower()
    if key not in VALID_DISEASES:
        raise ValueError("disease 必须是 %s 之一" % "/".join(VALID_DISEASES))
    if key not in _ENGINE_CACHE:
        if key == "gout":
            _ENGINE_CACHE[key] = GoutEngine()
        elif key == "diabetes":
            _ENGINE_CACHE[key] = DiabetesEngine()
        else:
            _ENGINE_CACHE[key] = HypertensionEngine()
    return _ENGINE_CACHE[key]


def valid_modes(disease="gout"):
    return list(load_engine(disease).modes)


# ---------- 演示 / 回归 ----------
def _assert(cond, msg):
    if not cond:
        raise AssertionError(msg)


def run_regression():
    """痛风 + 糖尿病 + 护心 + 同菜异色 + 工厂校验"""
    # 痛风
    gout = load_engine("gout")
    meal1 = gout.analyze_meal(["卤猪肝", "红烧肉", "米饭", "炒青菜"], mode="发作期")
    _assert(meal1["summary"]["overall_light"] == "红灯", "痛风含猪肝应为红灯")
    liver = next(d for d in meal1["dishes"] if "猪肝" in d["dish"])
    _assert(liver["light"] == "红灯", "痛风卤猪肝红灯")
    day = gout.daily_summary([meal1], mode="发作期")
    _assert(day["purine_limit_mg"] == 150, "发作期嘌呤上限150")
    try:
        gout.analyze_meal(["米饭"], mode="未知")
        _assert(False, "痛风非法 mode 应抛错")
    except ValueError:
        pass

    # 糖尿病
    dia = load_engine("diabetes")
    meal_d = dia.analyze_meal(["白米饭", "猪肝", "炒青菜", "苹果"], mode="强化控糖", weights=[200, 100, 150, 150])
    rice = next(d for d in meal_d["dishes"] if d["dish"] == "白米饭")
    _assert(rice["light"] == "红灯", "糖尿病白米饭应红灯，got %s" % rice["light"])
    advice = rice.get("advice") or ""
    _assert("严格限量" in advice or "非禁食" in advice,
            "糖尿病红灯应为限量口径，got: %s" % advice)
    _assert("均禁食" not in advice, "糖尿病不得使用痛风式禁食口径")
    pig = next(d for d in meal_d["dishes"] if d["dish"] == "猪肝")
    _assert(pig["light"] == "黄灯", "糖尿病猪肝应黄灯（同菜异色），got %s" % pig["light"])
    apple = next(d for d in meal_d["dishes"] if d["dish"] == "苹果")
    _assert(apple["light"] == "绿灯", "苹果绿灯")
    _assert(meal_d["daily_carb_limit_g"] == 130, "强化控糖碳水上限130")
    _assert("total_carb_g" in meal_d["summary"], "汇总需 total_carb_g")
    day_d = dia.daily_summary([meal_d], mode="强化控糖")
    _assert(day_d["carb_limit_g"] == 130, "daily carb_limit")
    _assert(day_d["intake_carb_g"] >= 0, "intake_carb_g")

    # 护心（高血压/高血脂）
    ht = load_engine("hypertension")
    meal_h = ht.analyze_meal(["白米饭", "猪肝", "咸菜", "清炒上海青"], mode="强化控制",
                             weights=[200, 100, 50, 150])
    h_rice = next(d for d in meal_h["dishes"] if d["dish"] == "白米饭")
    h_liver = next(d for d in meal_h["dishes"] if d["dish"] == "猪肝")
    h_pickle = next(d for d in meal_h["dishes"] if d["dish"] == "咸菜")
    _assert(h_rice["light"] == "黄灯", "护心白米饭应黄灯，got %s" % h_rice["light"])
    _assert(h_liver["light"] == "红灯", "护心猪肝应红灯，got %s" % h_liver["light"])
    _assert(h_pickle["light"] == "红灯", "护心咸菜应红灯")
    _assert(meal_h["daily_cholesterol_limit_mg"] == 200, "强化控制胆固醇上限200")
    _assert("total_cholesterol_mg" in meal_h["summary"], "汇总需 total_cholesterol_mg")
    advice_h = h_liver.get("advice") or ""
    _assert("严格限量" in advice_h or "限量" in advice_h, "护心红灯应为限量口径")
    day_h = ht.daily_summary([meal_h], mode="强化控制")
    _assert(day_h["cholesterol_limit_mg"] == 200, "daily cholesterol_limit")
    _assert(day_h["intake_cholesterol_mg"] >= 0, "intake_cholesterol_mg")
    try:
        ht.analyze_meal(["苹果"], mode="发作期")
        _assert(False, "护心不可用痛风 mode")
    except ValueError:
        pass

    # 同菜异色对照（三病种）
    gout_rice = gout.analyze_dish("白米饭")
    dia_rice = dia.analyze_dish("白米饭")
    ht_rice = ht.analyze_dish("白米饭")
    _assert(gout_rice["light"] == "绿灯" and dia_rice["light"] == "红灯" and ht_rice["light"] == "黄灯",
            "白米饭异色：痛风绿/糖尿红/护心黄，got %s/%s/%s"
            % (gout_rice["light"], dia_rice["light"], ht_rice["light"]))
    gout_liver = gout.analyze_dish("猪肝")
    dia_liver = dia.analyze_dish("猪肝")
    ht_liver = ht.analyze_dish("猪肝")
    _assert(gout_liver["light"] == "红灯" and dia_liver["light"] == "黄灯" and ht_liver["light"] == "红灯",
            "猪肝异色：痛风红/糖尿黄/护心红，got %s/%s/%s"
            % (gout_liver["light"], dia_liver["light"], ht_liver["light"]))
    ht_seaweed = ht.analyze_dish("紫菜")
    _assert(ht_seaweed["light"] == "黄灯", "护心紫菜应黄灯，got %s" % ht_seaweed["light"])

    # 工厂
    _assert(load_engine("gout") is gout, "工厂应缓存实例")
    _assert(load_engine("hypertension") is ht, "护心工厂缓存")
    try:
        load_engine("xxx")
        _assert(False, "非法 disease 应抛错")
    except ValueError:
        pass
    try:
        dia.analyze_meal(["苹果"], mode="发作期")
        _assert(False, "糖尿病不可用痛风 mode")
    except ValueError:
        pass

    print("REGRESSION PASS")
    print("  gout overall:", meal1["summary"]["overall_light"],
          "purine", meal1["summary"]["total_purine_mg"], "mg")
    print("  diabetes overall:", meal_d["summary"]["overall_light"],
          "carb", meal_d["summary"]["total_carb_g"], "g /", meal_d["daily_carb_limit_g"])
    print("  hypertension overall:", meal_h["summary"]["overall_light"],
          "chol", meal_h["summary"]["total_cholesterol_mg"], "mg /", meal_h["daily_cholesterol_limit_mg"])
    print("  contrast 白米饭:", gout_rice["light"], "/", dia_rice["light"], "/", ht_rice["light"])
    print("  contrast 猪肝:", gout_liver["light"], "/", dia_liver["light"], "/", ht_liver["light"])
    return True


if __name__ == "__main__":
    run_regression()
    print("\n=== 护心样例 JSON ===")
    eng = load_engine("hypertension")
    sample = eng.analyze_meal(["白米饭", "猪肝", "清炒上海青"], mode="普通控制", weights=[150, 80, 200])
    print(json.dumps(sample, ensure_ascii=False, indent=2))
