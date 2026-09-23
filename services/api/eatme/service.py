from __future__ import annotations

import hashlib
from datetime import date, datetime
from uuid import UUID, uuid4
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from .lifecycle import LifecycleService
from .intelligence import IntelligenceService
from .governance import GovernanceService
from .content import ContentService
from .households import HouseholdService
from .planning import PlanningService
from .dinners import DinnerService
from .reference_features import ReferenceFeaturesService, GOALS
from .auth import now
from .catalog import ALLERGENS, ETHICAL_PREFERENCES, INTOLERANCES, MEDICAL_AWARENESS, SENSITIVITIES
from .engine import active_rules, amount_milli, batch_usable, compatibility, quantity, rank, requirements
from .errors import DomainError
from .storage import Database, Transaction, decode, encode

HEALTH_CONSENT = "nutrition-profile-1"
MEDICAL_CONSENT = "medical-nutrition-1"


def new_id() -> str:
    return str(uuid4())


def valid_uuid(value: str) -> str:
    try:
        return str(UUID(value))
    except (TypeError,ValueError,AttributeError):
        raise DomainError("invalid_identifier",422) from None


def valid_date(value) -> str | None:
    if value is None or value == "":
        return None
    try:
        parsed = date.fromisoformat(value)
        if parsed.isoformat() != value:
            raise ValueError
        return value
    except (ValueError,TypeError):
        raise DomainError("invalid_date",422) from None


class Service(
    ReferenceFeaturesService,
    HouseholdService,
    PlanningService,
    DinnerService,
    ContentService,
    GovernanceService,
    IntelligenceService,
    LifecycleService,
):
    def __init__(self, db: Database, *, clock=None, weights=None):
        self.db, self.clock, self.weights = db, clock, weights

    def today(self, settings: dict) -> date:
        return self.clock() if self.clock else datetime.now(ZoneInfo(settings["timezone"])).date()

    def _profile(self, tx: Transaction, user_id: str) -> dict:
        deletion = tx.one("SELECT status FROM account_deletions WHERE user_id=?", (user_id,))
        if deletion and deletion["status"] in {"pending", "completed"}:
            raise DomainError("account_deletion_pending", 409)
        row = tx.one("SELECT * FROM profiles WHERE user_id=?",(user_id,))
        if not row:
            raise DomainError("onboarding_required",409)
        row["settings"] = decode(row["settings"])
        row["settings"].setdefault("unknown_ingredient_policy", "strict")
        row["settings"].setdefault("sensitivities", [])
        row["settings"].setdefault("medical_awareness", [])
        row["settings"].setdefault("ethical_preferences", [])
        row["settings"].setdefault("trace_policy", "block")
        row["settings"].setdefault("meal_timing", {"mode": "standard"})
        return row

    def _household(self, user_id: str, write: bool = False) -> str:
        with self.db.transaction() as tx:
            profile = self._profile(tx,user_id)
            member = tx.one("SELECT role FROM household_members WHERE household_id=? AND user_id=?",(profile["household_id"],user_id))
            if not member or (write and member["role"] == "viewer"):
                raise DomainError("forbidden",403)
            return profile["household_id"]

    def _catalog(self, tx, user_id=None):
        foods = {r["id"]:decode(r["data"]) for r in tx.all("SELECT f.* FROM foods f LEFT JOIN content_ownership o ON o.content_id=f.id AND o.kind='food' WHERE o.content_id IS NULL OR o.user_id=? OR o.household_id IN (SELECT household_id FROM household_members WHERE user_id=?)", (user_id,user_id))}
        recipes = [decode(r["data"]) for r in tx.all("SELECT r.* FROM recipes r LEFT JOIN content_ownership o ON o.content_id=r.id AND o.kind='recipe' WHERE o.content_id IS NULL OR o.user_id=?", (user_id,))]
        recipes = [recipe for recipe in recipes if not recipe.get("archived")]
        diets = [decode(r["data"]) for r in tx.all("SELECT * FROM diet_definitions")]
        versions = [{**v,"rules":decode(v["rules"])} for v in tx.all("SELECT * FROM diet_versions")]
        retired = tx.all("SELECT DISTINCT g.kind,g.subject_id FROM governed_content g WHERE g.status='DEPRECATED' AND NOT EXISTS (SELECT 1 FROM governed_content p WHERE p.kind=g.kind AND p.subject_id=g.subject_id AND p.status='PUBLISHED')")
        for row in retired:
            if row['kind'] == 'food' and row['subject_id'] in foods:
                foods[row['subject_id']].update(ingredient_status='unknown', retired=True)
            if row['kind'] == 'recipe':
                recipes = [r for r in recipes if r['id'] != row['subject_id']]
        today = self.today({'timezone': 'UTC'}).isoformat()
        current_evidence = {r['subject_id'] for r in tx.all("SELECT subject_id,data FROM governed_content WHERE kind='evidence' AND status='PUBLISHED'") if decode(r['data']).get('review_due', '') >= today}
        unavailable = {d['id'] for d in diets if not d.get('is_demo', False) and (not d.get('evidence_references') or not set(d['evidence_references']) <= current_evidence)}
        for version in versions:
            if version['diet_id'] in unavailable:
                version['status'] = 'REVIEW_REQUIRED'
        return foods,recipes,diets,versions

    def catalog(self, user_id=None) -> dict:
        with self.db.transaction() as tx:
            foods,_,diets,versions = self._catalog(tx,user_id)
            current = self.clock() if self.clock else date.today()
            for diet in diets:
                diet["selectable"] = any(v["diet_id"]==diet["id"] and v["status"]=="PUBLISHED" and
                    v["effective_from"]<=current.isoformat() and (not v["effective_until"] or current.isoformat()<v["effective_until"])
                    for v in versions)
            return {"foods":list(foods.values()),"diets":diets,"allergens":ALLERGENS,
                    "intolerances":INTOLERANCES,"sensitivities":SENSITIVITIES,
                    "medical_awareness":MEDICAL_AWARENESS,"ethical_preferences":ETHICAL_PREFERENCES,
                    "meal_timing":{"modes":["standard","custom","time_restricted"],
                                   "presets":["12:12","14:10","16:8","18:6"]},
                    "health_consent_version":HEALTH_CONSENT,
                    "medical_consent_version":MEDICAL_CONSENT,
                    "unknown_ingredient_policies":["strict","review"],
                    "is_demo":any(f.get("is_demo",False) for f in foods.values())}

    def get_profile(self, user_id: str):
        with self.db.transaction() as tx:
            deletion = tx.one("SELECT status FROM account_deletions WHERE user_id=?", (user_id,))
            if deletion and deletion["status"] in {"pending", "completed"}:
                raise DomainError("account_deletion_pending", 409)
            row = tx.one("SELECT * FROM profiles WHERE user_id=?",(user_id,))
            if not row:
                return {"onboarded":False}
            row["settings"] = decode(row["settings"])
            row["settings"].setdefault("unknown_ingredient_policy", "strict")
            row["settings"].setdefault("sensitivities", [])
            row["settings"].setdefault("medical_awareness", [])
            row["settings"].setdefault("ethical_preferences", [])
            row["settings"].setdefault("trace_policy", "block")
            row["settings"].setdefault("meal_timing", {"mode": "standard"})
            row["household_size"] = tx.one("SELECT size FROM households WHERE id=?",(row["household_id"],))["size"]
            return {"onboarded":True,**row}

    def profile_avatar(self, user_id: str, data: dict, key: str):
        with self.db.transaction() as tx:
            def save():
                profile = self._profile(tx, user_id)
                expected = data.get("expected_version")
                if expected != profile["version"]:
                    raise DomainError("stale_profile", 409)
                media_id = data.get("media_id")
                if media_id is not None:
                    media_id = valid_uuid(media_id)
                    media = tx.one(
                        "SELECT id FROM media_objects WHERE id=? AND user_id=? AND kind='avatar'",
                        (media_id, user_id),
                    )
                    if not media:
                        raise DomainError("invalid_avatar", 422)
                settings = profile["settings"]
                if media_id is None:
                    settings.pop("avatar_media_id", None)
                else:
                    settings["avatar_media_id"] = media_id
                changed = tx.execute(
                    "UPDATE profiles SET settings=?,version=version+1 WHERE user_id=? AND version=?",
                    (encode(settings), user_id, profile["version"]),
                )
                if changed.rowcount != 1:
                    raise DomainError("stale_profile", 409)
                return {"avatar_media_id": media_id, "version": profile["version"] + 1}
            return self._once(tx, user_id, key, "profile_avatar", data, save)

    def _once(self, tx, user_id, key, name, body, action):
        key = valid_uuid(key)
        if tx.postgres:
            tx.execute("SELECT pg_advisory_xact_lock(hashtextextended(?,0))",(user_id+":"+key,))
        fingerprint = hashlib.sha256(encode({"action":name,"body":body}).encode()).hexdigest()
        existing = tx.one("SELECT * FROM operations WHERE user_id=? AND operation_key=?",(user_id,key))
        if existing:
            if existing["request_hash"] != fingerprint:
                raise DomainError("idempotency_conflict",409)
            return decode(existing["response"])
        result = action()
        tx.execute("INSERT INTO operations VALUES (?,?,?,?,?)",(user_id,key,fingerprint,encode(result),now()))
        return result

    def save_profile(self, user_id: str, data: dict, key: str):
        name = data.get("name","")
        if not isinstance(name,str) or not 1 <= len(name.strip()) <= 80 or data.get("adult_confirmed") is not True:
            raise DomainError("invalid_profile",422)
        size = data.get("household_size",1)
        if type(size) is not int or not 1 <= size <= 20:
            raise DomainError("invalid_household_size",422)
        timezone = data.get("timezone","Europe/Rome")
        try:
            ZoneInfo(timezone)
        except (ZoneInfoNotFoundError,TypeError,ValueError):
            raise DomainError("invalid_timezone",422) from None
        allergies, intolerances = data.get("allergies",[]),data.get("intolerances",[])
        sensitivities = data.get("sensitivities", [])
        medical_awareness = data.get("medical_awareness", [])
        ethical_preferences = data.get("ethical_preferences", [])
        if not isinstance(allergies,list) or any(not isinstance(v,str) or v not in ALLERGENS for v in allergies):
            raise DomainError("invalid_allergen",422)
        if not isinstance(intolerances,list) or any(v not in INTOLERANCES for v in intolerances):
            raise DomainError("invalid_intolerance",422)
        if not isinstance(sensitivities, list) or any(v not in SENSITIVITIES for v in sensitivities):
            raise DomainError("invalid_sensitivity", 422)
        if not isinstance(medical_awareness, list) or any(v not in MEDICAL_AWARENESS for v in medical_awareness):
            raise DomainError("invalid_medical_awareness", 422)
        if not isinstance(ethical_preferences, list) or any(v not in ETHICAL_PREFERENCES for v in ethical_preferences):
            raise DomainError("invalid_ethical_preference", 422)
        if (allergies or intolerances or sensitivities) and data.get("health_consent_version") != HEALTH_CONSENT:
            raise DomainError("health_consent_required",422)
        trace_policy = data.get("trace_policy", "block")
        if trace_policy not in {"ignore", "review", "block"}:
            raise DomainError("invalid_trace_policy", 422)
        meal_timing = data.get("meal_timing", {"mode": "standard"})
        if not isinstance(meal_timing, dict) or meal_timing.get("mode") not in {"standard", "custom", "time_restricted"}:
            raise DomainError("invalid_meal_timing", 422)
        if meal_timing["mode"] != "standard":
            for field in ("start", "end"):
                value = meal_timing.get(field)
                try:
                    hour, minute = [int(part) for part in value.split(":")]
                except (AttributeError, ValueError, TypeError):
                    raise DomainError("invalid_meal_timing", 422) from None
                if not 0 <= hour <= 23 or not 0 <= minute <= 59 or value != f"{hour:02d}:{minute:02d}":
                    raise DomainError("invalid_meal_timing", 422)
            preset = meal_timing.get("preset", "custom")
            if preset not in {"12:12", "14:10", "16:8", "18:6", "custom"}:
                raise DomainError("invalid_meal_timing", 422)
            slots = meal_timing.get(
                "slots",
                {"breakfast": True, "lunch": True, "dinner": True, "snack": True},
            )
            if (
                not isinstance(slots, dict)
                or set(slots) != {"breakfast", "lunch", "dinner", "snack"}
                or any(type(value) is not bool for value in slots.values())
                or not any(slots.values())
            ):
                raise DomainError("invalid_meal_timing", 422)
            meal_timing = {**meal_timing, "preset": preset, "slots": slots}
        else:
            slots = meal_timing.get(
                "slots",
                {"breakfast": True, "lunch": True, "dinner": True, "snack": True},
            )
            if (
                not isinstance(slots, dict)
                or set(slots) != {"breakfast", "lunch", "dinner", "snack"}
                or any(type(value) is not bool for value in slots.values())
                or not any(slots.values())
            ):
                raise DomainError("invalid_meal_timing", 422)
            meal_timing = {"mode": "standard", "slots": slots}
        assignments = data.get("diets",[])
        if not isinstance(assignments,list) or len(assignments)>8:
            raise DomainError("invalid_diet",422)
        for assignment in assignments:
            if not isinstance(assignment,dict) or assignment.get("strictness") not in {"flexible","standard","strict"}:
                raise DomainError("invalid_diet",422)
            valid_uuid(assignment.get("diet_id"))
        if len({a["diet_id"] for a in assignments}) != len(assignments):
            raise DomainError("duplicate_diet",422)
        unknown_policy = data.get("unknown_ingredient_policy", "strict")
        if unknown_policy not in {"strict", "review"}:
            raise DomainError("invalid_unknown_ingredient_policy", 422)
        primary_goal = data.get('primary_goal')
        if primary_goal is not None and (not isinstance(primary_goal, str) or primary_goal not in GOALS):
            raise DomainError('invalid_goal', 422)
        primary_diet = data.get('primary_diet')
        if primary_diet is not None and (not isinstance(primary_diet, str) or primary_diet not in {a['diet_id'] for a in assignments}):
            raise DomainError('invalid_diet', 422)
        with self.db.transaction() as tx:
            def save():
                if tx.one("SELECT 1 FROM account_deletions WHERE user_id=? AND status IN ('pending','completed')", (user_id,)):
                    raise DomainError("account_deletion_pending", 409)
                foods,_,diets,versions = self._catalog(tx)
                active_rules(assignments,versions,self.today({"timezone":timezone}))
                chosen = {a["diet_id"] for a in assignments}
                medical = [d for d in diets if d["id"] in chosen and d["medical"]]
                if medical or medical_awareness:
                    if data.get("medical_consent_version") != MEDICAL_CONSENT:
                        raise DomainError("medical_consent_required",422)
                never = data.get("never_suggest",[])
                if not isinstance(never,list) or any(f not in foods for f in never):
                    raise DomainError("invalid_food",422)
                existing = tx.one("SELECT * FROM profiles WHERE user_id=?",(user_id,))
                previous_settings = decode(existing["settings"]) if existing else {}
                avatar_id = data.get("avatar_id") if "avatar_id" in data else previous_settings.get("avatar_id")
                if avatar_id is not None:
                    avatar_id = valid_uuid(avatar_id)
                    avatar = tx.one(
                        "SELECT 1 FROM media_objects WHERE id=? AND user_id=? AND kind='avatar'",
                        (avatar_id, user_id),
                    )
                    if not avatar:
                        raise DomainError("invalid_avatar", 422)
                settings = {"diets":assignments,"allergies":sorted(set(allergies)),"intolerances":sorted(set(intolerances)),
                            "sensitivities":sorted(set(sensitivities)),"medical_awareness":sorted(set(medical_awareness)),
                            "ethical_preferences":sorted(set(ethical_preferences)),"trace_policy":trace_policy,
                            "meal_timing":meal_timing,
                            "never_suggest":never,"timezone":timezone,"adult_confirmed":True,
                            "primary_goal":primary_goal,"primary_diet":primary_diet,
                            "unknown_ingredient_policy":unknown_policy}
                if avatar_id is not None:
                    settings["avatar_id"] = avatar_id
                stamp = now()
                if existing:
                    if data.get("expected_version") != existing["version"]:
                        raise DomainError("stale_profile",409)
                    household_id = existing["household_id"]
                    changed = tx.execute("UPDATE profiles SET name=?,settings=?,version=version+1 WHERE user_id=? AND version=?",
                               (name.strip(),encode(settings),user_id,existing["version"]))
                    if changed.rowcount != 1:
                        raise DomainError("stale_profile",409)
                    tx.execute("UPDATE households SET size=? WHERE id=? AND owner_id=?",(size,household_id,user_id))
                    version = existing["version"]+1
                else:
                    household_id = new_id()
                    tx.execute("INSERT INTO households VALUES (?,?,?,?)",(household_id,user_id,size,stamp))
                    tx.execute("INSERT INTO profiles VALUES (?,?,?,?,?,?)",(user_id,name.strip(),household_id,encode(settings),1,stamp))
                    tx.execute("INSERT INTO household_members VALUES (?,?,?)",(household_id,user_id,"owner"))
                    version = 1
                # Withdrawal is explicit: removing all health fields withdraws the previous consent.
                tx.execute("UPDATE consents SET withdrawn_at=? WHERE user_id=? AND withdrawn_at IS NULL",(stamp,user_id))
                if allergies or intolerances or sensitivities:
                    tx.execute("INSERT INTO consents VALUES (?,?,?,?,?,?)",(new_id(),user_id,"health_profile",HEALTH_CONSENT,stamp,None))
                if medical or medical_awareness:
                    tx.execute("INSERT INTO consents VALUES (?,?,?,?,?,?)",(new_id(),user_id,"medical_nutrition",MEDICAL_CONSENT,stamp,None))
                return {"user_id":user_id,"household_id":household_id,"version":version,"onboarded":True}
            return self._once(tx,user_id,key,"profile",data,save)

    def _inventory(self, tx, household_id):
        rows = tx.all("SELECT b.*,m.data AS metadata FROM inventory_batches b LEFT JOIN inventory_metadata m ON m.batch_id=b.id WHERE household_id=? AND quantity_milli>0 ORDER BY CASE WHEN expiry_date IS NULL THEN 1 ELSE 0 END,expiry_date,created_at,id",(household_id,))
        recalls = [decode(r['data']) for r in tx.all("SELECT data FROM governed_content WHERE kind='recall' AND status='PUBLISHED'")]
        for row in rows:
            row['metadata'] = decode(row['metadata']) if row['metadata'] else {}
            row['recalls'] = [r for r in recalls if row['metadata'].get('barcode') == r['barcode'] and row['metadata'].get('lot') == r['lot']]
        return rows

    def inventory(self,user_id):
        household_id = self._household(user_id)
        with self.db.transaction() as tx:
            foods,_,_,_ = self._catalog(tx,user_id)
            settings = self._profile(tx,user_id)["settings"]
            return {"items":[{**b,"quantity":quantity(b["quantity_milli"]),"food":foods[b["food_id"]],
                              "usable":batch_usable(b,self.today(settings))} for b in self._inventory(tx,household_id)]}

    def _event(self,tx,user_id,household_id,batch_id,kind,delta,metadata=None):
        tx.execute("INSERT INTO inventory_events VALUES (?,?,?,?,?,?,?,?)",
                   (new_id(),household_id,batch_id,user_id,kind,delta,now(),encode(metadata or {})))

    def add_inventory(self,user_id,data,key):
        household_id = self._household(user_id,write=True)
        amount = amount_milli(data.get("quantity"))
        location = data.get("location","fridge")
        expiry = valid_date(data.get("expiry_date"))
        kind = data.get("expiry_kind","unknown")
        if location not in {"fridge","freezer","pantry"} or kind not in {"unknown","use_by","best_before","estimated"}:
            raise DomainError("invalid_inventory",422)
        if bool(expiry) != (kind != "unknown"):
            raise DomainError("expiry_type_required",422)
        with self.db.transaction(household_id) as tx:
            def add():
                self._member(tx,user_id,household_id,write=True)
                food = self._catalog(tx, user_id)[0].get(valid_uuid(data.get("food_id")))
                if not food:
                    raise DomainError("food_not_found",404)
                if food["unit"]=="pcs" and amount%1000:
                    raise DomainError("whole_units_required",422)
                batch_id, stamp = new_id(),now()
                tx.execute("INSERT INTO inventory_batches VALUES (?,?,?,?,?,?,?,?,?,?,?,?)",
                           (batch_id,household_id,data["food_id"],amount,location,expiry,kind,None,"manual",1,stamp,stamp))
                self._event(tx,user_id,household_id,batch_id,"created",amount)
                return {"id":batch_id,"version":1,"quantity":quantity(amount)}
            return self._once(tx,user_id,key,"add_inventory",data,add)

    def change_inventory(self,user_id,batch_id,data,key):
        household_id = self._household(user_id,write=True)
        with self.db.transaction(household_id) as tx:
            def change():
                self._member(tx,user_id,household_id,write=True)
                batch = tx.one("SELECT * FROM inventory_batches WHERE id=? AND household_id=?",(batch_id,household_id))
                if not batch:
                    raise DomainError("item_not_found",404)
                if data.get("expected_version") != batch["version"]:
                    raise DomainError("stale_inventory",409)
                action = data.get("action")
                amount, location, opened = batch["quantity_milli"],batch["location"],batch["opened_at"]
                if action == 'consumed':
                    current = next((b for b in self._inventory(tx, household_id) if b['id'] == batch_id), batch)
                    if not batch_usable(current, self.today(self._profile(tx, user_id)['settings'])):
                        raise DomainError('batch_not_usable', 409)
                if action in {"consumed","discarded"}:
                    amount -= amount_milli(data.get("quantity",quantity(amount)))
                    if amount < 0:
                        raise DomainError("insufficient_inventory",409)
                elif action == "corrected":
                    amount = amount_milli(data.get("quantity"),zero=True)
                elif action == "moved":
                    location = data.get("location")
                    if location not in {"fridge","freezer","pantry"}:
                        raise DomainError("invalid_location",422)
                elif action == "opened":
                    opened = now()
                else:
                    raise DomainError("invalid_action",422)
                tx.execute("UPDATE inventory_batches SET quantity_milli=?,location=?,opened_at=?,version=version+1,updated_at=? WHERE id=?",
                           (amount,location,opened,now(),batch_id))
                self._event(tx,user_id,household_id,batch_id,action,amount-batch["quantity_milli"])
                return {"id":batch_id,"version":batch["version"]+1,"quantity":quantity(amount)}
            return self._once(tx,user_id,key,"change_inventory:"+batch_id,data,change)

    def _context(self,tx,user_id):
        profile = self._profile(tx,user_id)
        foods,recipes,_,versions = self._catalog(tx,user_id)
        today = self.today(profile["settings"])
        rules,rule_versions = active_rules(profile["settings"]["diets"],versions,today)
        return profile,foods,recipes,rules,rule_versions,today

    def recommendations(self,user_id,mode="for_you",food_id=None):
        household_id = self._household(user_id)
        with self.db.transaction() as tx:
            profile,foods,recipes,rules,versions,today = self._context(tx,user_id)
            size = tx.one("SELECT size FROM households WHERE id=?",(household_id,))["size"]
            inventory = self._inventory(tx,household_id)
            # Barcode/imported products remain separate food entities because their
            # package quantity and safety metadata are not interchangeable with a
            # canonical ingredient.  A reviewed food_products.food_id mapping may,
            # however, be used as a semantic inventory match for recommendation
            # ranking (never for quantity-aware cooking allocation).
            product_mappings = {
                row["id"]: row["food_id"]
                for row in tx.all("SELECT id,food_id FROM food_products WHERE food_id IS NOT NULL")
            }
            for batch in inventory:
                metadata = batch.get("metadata", {})
                product_id = metadata.get("product_id")
                canonical_food_id = metadata.get("canonical_food_id") or product_mappings.get(product_id)
                if canonical_food_id in foods:
                    batch["canonical_food_id"] = canonical_food_id
            if food_id:
                recipes = [r for r in recipes if food_id in {i["food_id"] for i in r["ingredients"]}]
            prefs_row = tx.one("SELECT data FROM user_preferences WHERE user_id=?",(user_id,))
            preferences = decode(prefs_row["data"]) if prefs_row else {}
            relax_soft = mode == "guilty_pleasure"
            if preferences.get("max_minutes") and not relax_soft:
                recipes = [r for r in recipes if r["minutes"] <= preferences["max_minutes"]]
            skill = {'beginner': 0, 'confident': 1, 'advanced': 2}
            if preferences.get('skill'):
                recipes = [r for r in recipes if skill.get(r.get('difficulty', 'beginner'), 0) <= skill[preferences['skill']]]
            ranked,rejected = rank(recipes,foods,inventory,profile["settings"],rules,today,mode,size,self.weights)
            feedback = {r["recipe_id"]:r["rating"] for r in tx.all("SELECT recipe_id,rating FROM recipe_feedback WHERE user_id=?",(user_id,))} if preferences.get("learning") else {}
            cuisines = {c.casefold() for c in preferences.get("cuisines",[])}
            for item in ranked:
                item["preference_adjustment"] = 0 if relax_soft else (.05 * feedback.get(item["recipe"]["id"],0) + (.03 if item["recipe"].get("cuisine","").casefold() in cuisines else 0))
                if not relax_soft and preferences.get('budget') in {'low', 'medium'}:
                    item['preference_adjustment'] += item['component_scores']['availability'] * (.06 if preferences['budget'] == 'low' else .03)
                seasonal = [foods[i['food_id']] for i in item['recipe']['ingredients'] if foods[i['food_id']].get('season_months')]
                if not relax_soft and preferences.get('seasonal') and seasonal:
                    item['preference_adjustment'] += .03 * sum(today.month in f['season_months'] for f in seasonal) / len(seasonal)
                item["score"] = round(item["score"]+item["preference_adjustment"],6)
                item["soft_preferences_relaxed"] = relax_soft
            if any(item['preference_adjustment'] for item in ranked):
                ranked.sort(key=lambda item:(-item["score"],item["recipe"]["id"]))
                diverse, repeated, seen = [], [], set()
                for item in ranked:
                    primary = item['recipe']['ingredients'][0]['food_id']
                    (repeated if primary in seen else diverse).append(item)
                    seen.add(primary)
                ranked = diverse + repeated
            trace_id = new_id()
            snapshot = [{"id":b["id"],"version":b["version"],"quantity_milli":b["quantity_milli"],
                         "expiry_date":b["expiry_date"],"expiry_kind":b["expiry_kind"]} for b in inventory]
            trace = {"mode":mode,"diet_rules_version":versions,"profile_version":profile["version"],
                     "inventory_snapshot":snapshot,"ranked":ranked,"rejected":rejected,"servings":size}
            tx.execute("INSERT INTO recommendation_traces VALUES (?,?,?,?,?)",(trace_id,user_id,household_id,encode(trace),now()))
            return {"trace_id":trace_id,"items":ranked[:4],"servings":size,"diet_rules_version":versions,
                    "preference_context":{"mode":mode,"soft_preferences_relaxed":relax_soft,
                                          "hard_restrictions_active":True},
                    "profile_context":{"diet_ids":[a["diet_id"] for a in profile["settings"]["diets"]],
                                       "primary_diet":profile["settings"].get("primary_diet"),
                                       "allergy_count":len(profile["settings"].get("allergies", [])),
                                       "intolerance_count":len(profile["settings"].get("intolerances", [])),
                                       "exclusion_count":len(profile["settings"].get("never_suggest", [])),
                                       "unknown_ingredient_policy":profile["settings"].get("unknown_ingredient_policy", "strict")},
                    "is_demo":any(f.get("is_demo",False) for f in foods.values())}

    def recipe(self,user_id,recipe_id):
        self._household(user_id)
        with self.db.transaction() as tx:
            profile,foods,recipes,rules,versions,_ = self._context(tx,user_id)
            recipe = next((r for r in recipes if r["id"]==recipe_id),None)
            if not recipe:
                raise DomainError("recipe_not_found",404)
            validation = compatibility([i["food_id"] for i in recipe["ingredients"]],foods,profile["settings"],rules)
            return {**recipe,"favorite":bool(tx.one("SELECT 1 FROM recipe_favorites WHERE user_id=? AND recipe_id=?",(user_id,recipe_id))),"compatibility":validation,"diet_rules_version":versions,"nutrition":self.recipe_nutrition(recipe,foods,recipe["servings"])}

    def food_compatibility(self,user_id,food_id):
        self._household(user_id)
        with self.db.transaction() as tx:
            profile,foods,_,rules,versions,_ = self._context(tx,user_id)
            if food_id not in foods:
                raise DomainError("food_not_found",404)
            return {"food":foods[food_id],"assessment":compatibility([food_id],foods,profile["settings"],rules),
                    "diet_rules_version":versions,"nutrition":foods[food_id].get("nutrition"),
                    "evidence":[decode(row['data']) for row in tx.all("SELECT data FROM governed_content WHERE kind='evidence' AND status='PUBLISHED'")
                                if food_id in decode(row['data']).get('food_ids', []) and decode(row['data'])['review_due'] >= self.today(profile['settings']).isoformat()]}

    def _preview(self,tx,user_id,data):
        profile,foods,recipes,rules,versions,today = self._context(tx,user_id)
        self._member(tx,user_id,profile["household_id"])
        settings,rules,versions,participants = self._diners(tx,user_id,data.get("participants"),profile,self._catalog(tx,user_id)[3],today)
        recipe = next((r for r in recipes if r["id"]==data.get("recipe_id")),None)
        if not recipe:
            raise DomainError("recipe_not_found",404)
        validation = compatibility([i["food_id"] for i in recipe["ingredients"]],foods,settings,rules)
        if validation["reasons"]:
            raise DomainError("recipe_not_compatible",409,validation)
        needed = requirements(recipe,data.get("servings",recipe["servings"]))
        custom = data.get("consumption",{})
        if not isinstance(custom,dict) or any(f not in needed for f in custom):
            raise DomainError("invalid_consumption",422)
        for f,value in custom.items():
            needed[f] = amount_milli(value,zero=True)
        inventory = self._inventory(tx,profile["household_id"])
        allocations, shortages, ingredients = [],[],[]
        for f,total in needed.items():
            remaining = total
            for batch in inventory:
                if batch["food_id"]!=f or not batch_usable(batch,today):
                    continue
                used = min(remaining,batch["quantity_milli"])
                if used:
                    allocations.append({"batch_id":batch["id"],"version":batch["version"],"food_id":f,"quantity_milli":used,"quantity":quantity(used)})
                    remaining -= used
            if remaining:
                shortages.append({"food_id":f,"quantity":quantity(remaining)})
            ingredients.append({"food_id":f,"food":foods[f],"quantity":quantity(total),"available":quantity(total-remaining)})
        return {"recipe_id":recipe["id"],"servings":data.get("servings",recipe["servings"]),"ingredients":ingredients,"nutrition":self.recipe_nutrition(recipe,foods,data.get("servings",recipe["servings"])),
                "allocations":allocations,"shortages":shortages,"profile_version":profile["version"],"diet_rules_version":versions,"participant_versions":participants}

    def cooking_preview(self,user_id,data):
        household_id = self._household(user_id)
        with self.db.transaction(household_id) as tx:
            return self._preview(tx,user_id,data)

    def cooking_confirm(self,user_id,data,key):
        household_id = self._household(user_id,write=True)
        with self.db.transaction(household_id) as tx:
            def confirm():
                self._member(tx,user_id,household_id,write=True)
                plan = self._preview(tx,user_id,data)
                if data.get("profile_version") != plan["profile_version"] or data.get("diet_rules_version") != plan["diet_rules_version"]:
                    raise DomainError("stale_profile",409)
                if data.get("participants") is not None and data.get("participant_versions") != plan["participant_versions"]:
                    raise DomainError("stale_participants",409)
                versions = {a["batch_id"]:a["version"] for a in plan["allocations"]}
                if data.get("batch_versions") != versions:
                    raise DomainError("stale_inventory",409)
                if plan["shortages"]:
                    raise DomainError("insufficient_inventory",409,{"shortages":plan["shortages"]})
                left = data.get("leftover_servings",0)
                if type(left) is not int or not 0 <= left <= plan["servings"]:
                    raise DomainError("invalid_leftovers",422)
                use_date = valid_date(data.get("leftover_use_date"))
                cooking_id = new_id()
                for item in plan["allocations"]:
                    changed = tx.execute("UPDATE inventory_batches SET quantity_milli=quantity_milli-?,version=version+1,updated_at=? WHERE id=? AND household_id=? AND version=? AND quantity_milli>=?",
                        (item["quantity_milli"],now(),item["batch_id"],household_id,item["version"],item["quantity_milli"]))
                    if changed.rowcount != 1:
                        raise DomainError("stale_inventory",409)
                    self._event(tx,user_id,household_id,item["batch_id"],"cooked",-item["quantity_milli"],{"cooking_id":cooking_id})
                record = {**plan,"consumption_overrides":data.get("consumption",{}),"leftover_servings":left}
                tx.execute("INSERT INTO cooking_sessions VALUES (?,?,?,?,?,?)",(cooking_id,user_id,household_id,plan["recipe_id"],encode(record),now()))
                if left:
                    tx.execute("INSERT INTO leftovers VALUES (?,?,?,?,?,?,?,?)",(new_id(),household_id,cooking_id,left,now(),"fridge",use_date,"manual"))
                return {"id":cooking_id,"consumed":plan["allocations"],"leftover_servings":left}
            return self._once(tx,user_id,key,"cooking_confirm",data,confirm)

    def leftovers(self,user_id):
        household_id = self._household(user_id)
        with self.db.transaction() as tx:
            rows = tx.all("SELECT l.*,COALESCE(s.remaining,l.servings) AS remaining,COALESCE(s.version,1) AS version,c.recipe_id,r.data AS recipe_data FROM leftovers l LEFT JOIN leftover_state s ON s.leftover_id=l.id JOIN cooking_sessions c ON c.id=l.cooking_id JOIN recipes r ON r.id=c.recipe_id WHERE l.household_id=? AND COALESCE(s.remaining,l.servings)>0 ORDER BY l.prepared_at DESC LIMIT 100",(household_id,))
            return {"items":[{**{k:v for k,v in row.items() if k!="recipe_data"},"recipe_title":decode(row["recipe_data"])["title"]} for row in rows]}

    def export(self,user_id):
        household_id = self._household(user_id)
        with self.db.transaction() as tx:
            return {"format_version":1,"exported_at":now(),"profile":self._profile(tx,user_id),
                    "inventory":self._inventory(tx,household_id),
                    "inventory_events":tx.all("SELECT * FROM inventory_events WHERE household_id=?",(household_id,)),
                    "cooking_sessions":tx.all("SELECT * FROM cooking_sessions WHERE user_id=?",(user_id,)),
                    "consents":tx.all("SELECT * FROM consents WHERE user_id=?",(user_id,)),
                    "leftovers":tx.all("SELECT * FROM leftovers WHERE household_id=?",(household_id,))}

    def delete_local_account(self,user_id):
        import os
        if self.db.postgres or os.getenv("EATME_ENV","development")!="development":
            raise DomainError("account_deletion_not_configured",503)
        household_id = self._household(user_id,write=True)
        with self.db.transaction(household_id) as tx:
            members = tx.all("SELECT user_id FROM household_members WHERE household_id=?",(household_id,))
            if len(members)!=1:
                raise DomainError("ownership_transfer_required",409)
            tx.execute("DELETE FROM households WHERE id=?",(household_id,))
            tx.execute("DELETE FROM profiles WHERE user_id=?",(user_id,))
            tx.execute("DELETE FROM dev_accounts WHERE user_id=?",(user_id,))
            return {"deleted":True}
