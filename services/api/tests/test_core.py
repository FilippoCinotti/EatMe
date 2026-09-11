import concurrent.futures
import os
import tempfile
import unittest
from datetime import date
from unittest.mock import patch

from eatme.auth import DevelopmentAuth
from eatme.catalog import identifier, seed_catalog
from eatme.engine import active_rules, amount_milli, compatibility, quantity
from eatme.errors import DomainError
from eatme.service import HEALTH_CONSENT, Service, new_id
from eatme.storage import Database, decode, encode
from eatme.transport import Router


class EatMeCase(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.db = Database(self.temp.name+"/eatme.db")
        self.db.migrate_local()
        seed_catalog(self.db)
        self.service = Service(self.db,clock=lambda:date(2026,9,10))
        self.user = new_id()
        self.profile = dict(name="Alex",adult_confirmed=True,household_size=2,diets=[
            dict(diet_id=identifier("diet","mediterranean"),strictness="standard")])
        self.service.save_profile(self.user,self.profile,new_id())

    def add(self,slug,amount,**kwargs):
        return self.service.add_inventory(self.user,dict(food_id=identifier("food",slug),quantity=str(amount),**kwargs),new_id())

    def prepare_bowl(self):
        self.add("tomato",300)
        self.add("chickpea",300)
        self.add("olive-oil",20)
        return self.service.cooking_preview(self.user,dict(recipe_id=identifier("recipe","sunny-bowl"),servings=2))

    def confirmation(self,plan):
        return dict(recipe_id=plan["recipe_id"],servings=plan["servings"],profile_version=plan["profile_version"],
                    diet_rules_version=plan["diet_rules_version"],batch_versions={a["batch_id"]:a["version"] for a in plan["allocations"]})

    def update_profile(self,**changes):
        current = self.service.get_profile(self.user)
        data = {**self.profile,"expected_version":current["version"],**changes}
        return self.service.save_profile(self.user,data,new_id())

    def assertCode(self,code,fn):
        with self.assertRaises(DomainError) as raised:
            fn()
        self.assertEqual(raised.exception.code,code)

    def test_quantities_are_exact_and_reject_invalid_input(self):
        self.assertEqual(amount_milli("0.001"),1)
        self.assertEqual(quantity(100010),"100.01")
        for invalid in ["NaN","Infinity","-1","0","0.0001",True,None,"1000001"]:
            self.assertCode("invalid_quantity",lambda:amount_milli(invalid))

    def test_health_data_requires_versioned_consent(self):
        self.assertCode("health_consent_required",lambda:self.update_profile(allergies=["peanut"]))
        self.update_profile(allergies=["peanut"],health_consent_version=HEALTH_CONSENT)
        self.assertEqual(self.service.get_profile(self.user)["settings"]["allergies"],["peanut"])

    def test_published_reviewed_rad_requires_consent_and_uses_database_rules(self):
        from eatme.service import MEDICAL_CONSENT
        rad_id = identifier("diet","rad")
        with self.db.transaction() as tx:
            record = decode(tx.one("SELECT data FROM diet_definitions WHERE id=?",(rad_id,))["data"])
            record.update(status="PUBLISHED",review_date="2026-09-01",evidence_references=["synthetic-test-only.invalid"])
            tx.execute("UPDATE diet_definitions SET data=? WHERE id=?",(encode(record),rad_id))
            tx.execute("INSERT INTO diet_versions VALUES (?,?,?,?,?,?,?)",(new_id(),rad_id,1,"PUBLISHED","2026-09-01",None,
                encode([dict(type="EXCLUDE",food_ids=[identifier("food","tomato")],hard_constraint=True)])))
        assignment = [dict(diet_id=rad_id,strictness="flexible")]
        self.assertCode("medical_consent_required",lambda:self.update_profile(diets=assignment))
        self.update_profile(diets=assignment,medical_consent_version=MEDICAL_CONSENT)
        self.assertTrue(next(d for d in self.service.catalog()["diets"] if d["id"]==rad_id)["selectable"])
        self.assertEqual(self.service.food_compatibility(self.user,identifier("food","tomato"))["assessment"]["status"],"not_compatible")

    def test_withdrawal_clears_health_data(self):
        self.update_profile(allergies=["peanut"],health_consent_version=HEALTH_CONSENT)
        self.update_profile(allergies=[])
        export = self.service.export(self.user)
        self.assertEqual(export["profile"]["settings"]["allergies"],[])
        self.assertTrue(all(c["withdrawn_at"] for c in export["consents"]))

    def test_unpublished_rad_not_selectable(self):
        rad = next(d for d in self.service.catalog()["diets"] if d["slug"]=="rad")
        self.assertFalse(rad["selectable"])
        self.assertEqual(rad["status"],"REQUIRES_REVIEW")
        self.assertCode("diet_rules_unavailable",lambda:self.update_profile(diets=[dict(diet_id=rad["id"],strictness="flexible")]))

    def test_allergy_rejected_before_ranking_and_deep_link_cooking(self):
        self.update_profile(allergies=["milk"],health_consent_version=HEALTH_CONSENT)
        self.add("feta",1000,expiry_date="2026-09-10",expiry_kind="use_by")
        recs = self.service.recommendations(self.user,"use_soon")
        self.assertNotIn(identifier("recipe","tomato-feta"),[r["recipe"]["id"] for r in recs["items"]])
        self.assertCode("recipe_not_compatible",lambda:self.service.cooking_preview(self.user,dict(recipe_id=identifier("recipe","tomato-feta"),servings=2)))

    def test_peanut_unknown_and_cross_contamination_are_not_compatible(self):
        foods = {f["id"]:f for f in self.service.catalog()["foods"]}
        profile = {"allergies":["peanut"],"intolerances":[]}
        peanut = identifier("food","peanut")
        for candidate in [peanut,new_id()]:
            self.assertEqual(compatibility([candidate],foods,profile,[])["status"],"not_compatible")
        tomato = identifier("food","tomato")
        foods[tomato]["may_contain"] = ["peanut"]
        self.assertEqual(compatibility([tomato],foods,profile,[])["reasons"][0]["code"],"may_contain_allergen")

    def test_flexible_diet_never_weakens_hard_rule(self):
        foods = {f["id"]:f for f in self.service.catalog()["foods"]}
        rule = dict(type="EXCLUDE",groups=["dairy"],hard_constraint=True,strictness="flexible",diet_id=new_id())
        result = compatibility([identifier("food","feta")],foods,{"allergies":[],"intolerances":[]},[rule])
        self.assertEqual(result["status"],"not_compatible")

    def test_flexible_lifestyle_is_a_warning(self):
        self.update_profile(diets=[dict(diet_id=identifier("diet","vegan"),strictness="flexible")])
        recipe = self.service.recipe(self.user,identifier("recipe","tomato-feta"))
        self.assertTrue(recipe["compatibility"]["warnings"])
        self.assertEqual(recipe["compatibility"]["status"],"no_known_conflict")

    def test_intolerance_and_allergy_are_separate(self):
        self.update_profile(intolerances=["lactose"],health_consent_version=HEALTH_CONSENT)
        assessment = self.service.food_compatibility(self.user,identifier("food","feta"))["assessment"]
        self.assertEqual(assessment["reasons"][0]["code"],"intolerance_conflict")

    def test_multiple_diets_compute_intersection(self):
        self.update_profile(diets=[dict(diet_id=identifier("diet",s),strictness="strict") for s in ["vegan","mediterranean"]])
        result = self.service.recommendations(self.user)
        self.assertNotIn(identifier("recipe","tomato-feta"),[r["recipe"]["id"] for r in result["items"]])

    def test_deprecated_version_fails_closed(self):
        with self.db.transaction() as tx:
            tx.execute("UPDATE diet_versions SET status='DEPRECATED' WHERE diet_id=?",(identifier("diet","mediterranean"),))
        self.assertCode("diet_rules_unavailable",lambda:self.service.recommendations(self.user))

    def test_future_rules_cannot_apply(self):
        assignments = [dict(diet_id="d",strictness="strict")]
        version = dict(diet_id="d",version=1,status="PUBLISHED",effective_from="2027-01-01",effective_until=None,rules=[])
        self.assertCode("diet_rules_unavailable",lambda:active_rules(assignments,[version],date(2026,9,10)))

    def test_distinct_batches_keep_their_own_dates(self):
        self.add("tomato",100,expiry_date="2026-09-12",expiry_kind="best_before")
        self.add("tomato",100,expiry_date="2026-09-18",expiry_kind="best_before")
        items = self.service.inventory(self.user)["items"]
        self.assertEqual(len(items),2)
        self.assertNotEqual(items[0]["expiry_date"],items[1]["expiry_date"])

    def test_expired_use_by_cannot_increase_availability(self):
        self.add("tomato",1000,expiry_date="2026-09-09",expiry_kind="use_by")
        plan = self.service.cooking_preview(self.user,dict(recipe_id=identifier("recipe","sunny-bowl"),servings=2))
        self.assertEqual(next(i for i in plan["ingredients"] if i["food_id"]==identifier("food","tomato"))["available"],"0")

    def test_best_before_is_distinct_from_use_by(self):
        self.add("tomato",300,expiry_date="2026-09-09",expiry_kind="best_before")
        self.assertTrue(self.service.inventory(self.user)["items"][0]["usable"])

    def test_date_requires_explicit_semantics(self):
        self.assertCode("expiry_type_required",lambda:self.add("tomato",100,expiry_date="2026-10-10"))

    def test_first_expiring_batch_is_consumed_first(self):
        early = self.add("tomato",100,expiry_date="2026-09-11",expiry_kind="use_by")
        self.add("tomato",500,expiry_date="2026-09-20",expiry_kind="use_by")
        plan = self.service.cooking_preview(self.user,dict(recipe_id=identifier("recipe","sunny-bowl"),servings=2))
        tomato = [a for a in plan["allocations"] if a["food_id"]==identifier("food","tomato")]
        self.assertEqual(tomato[0]["batch_id"],early["id"])
        self.assertEqual(tomato[0]["quantity"],"100")

    def test_no_shopping_is_strict_and_quantity_aware(self):
        self.assertEqual(self.service.recommendations(self.user,"no_shopping")["items"],[])
        self.prepare_bowl()
        recs = self.service.recommendations(self.user,"no_shopping")["items"]
        self.assertEqual(len(recs),1)
        self.assertEqual(recs[0]["available_count"],recs[0]["ingredient_count"])

    def test_explanations_match_recorded_scores(self):
        self.prepare_bowl()
        result = self.service.recommendations(self.user)
        for row in result["items"]:
            self.assertEqual(row["explanations"]["available"],row["available_count"])
        with self.db.transaction() as tx:
            trace = decode(tx.one("SELECT data FROM recommendation_traces WHERE id=?",(result["trace_id"],))["data"])
        self.assertTrue(trace["inventory_snapshot"])
        self.assertEqual(trace["diet_rules_version"],result["diet_rules_version"])

    def test_cooking_is_atomic_and_can_store_leftovers(self):
        plan = self.prepare_bowl()
        result = self.service.cooking_confirm(self.user,{**self.confirmation(plan),"leftover_servings":1},new_id())
        self.assertEqual(result["leftover_servings"],1)
        remaining = self.service.inventory(self.user)["items"]
        self.assertEqual(len(remaining),1)
        self.assertEqual(remaining[0]["quantity"],"100")
        self.assertIsNone(self.service.leftovers(self.user)["items"][0]["user_use_date"])

    def test_confirmation_retry_cannot_double_consume(self):
        data = self.confirmation(self.prepare_bowl())
        key = new_id()
        first = self.service.cooking_confirm(self.user,data,key)
        self.assertEqual(first,self.service.cooking_confirm(self.user,data,key))
        with self.db.transaction() as tx:
            self.assertEqual(tx.one("SELECT COUNT(*) AS n FROM cooking_sessions")["n"],1)

    def test_changed_idempotency_payload_rejected(self):
        data = dict(food_id=identifier("food","tomato"),quantity="100")
        key = new_id()
        self.service.add_inventory(self.user,data,key)
        self.assertCode("idempotency_conflict",lambda:self.service.add_inventory(self.user,{**data,"quantity":"200"},key))

    def test_stale_batch_cannot_partially_consume_recipe(self):
        plan = self.prepare_bowl()
        item = plan["allocations"][0]
        self.service.change_inventory(self.user,item["batch_id"],dict(action="consumed",quantity="1",expected_version=item["version"]),new_id())
        before = self.service.inventory(self.user)
        self.assertCode("stale_inventory",lambda:self.service.cooking_confirm(self.user,self.confirmation(plan),new_id()))
        self.assertEqual(before,self.service.inventory(self.user))

    def test_profile_change_invalidates_cooking_preview(self):
        plan = self.prepare_bowl()
        self.update_profile(name="Updated Alex")
        self.assertCode("stale_profile",lambda:self.service.cooking_confirm(self.user,self.confirmation(plan),new_id()))

    def test_concurrent_consumption_never_goes_negative(self):
        item = self.add("tomato",100)
        data = dict(action="consumed",quantity="80",expected_version=1)
        def consume():
            try:
                self.service.change_inventory(self.user,item["id"],data,new_id())
                return "ok"
            except DomainError as error:
                return error.code
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(lambda _:consume(),range(2)))
        self.assertEqual(sorted(results),["ok","stale_inventory"])
        self.assertEqual(self.service.inventory(self.user)["items"][0]["quantity"],"20")

    def test_household_authorization_prevents_cross_account_writes(self):
        item = self.add("tomato",100)
        other = new_id()
        self.service.save_profile(other,self.profile,new_id())
        self.assertEqual(self.service.inventory(other)["items"],[])
        self.assertCode("item_not_found",lambda:self.service.change_inventory(other,item["id"],dict(action="discarded",expected_version=1),new_id()))

    def test_export_and_delete_remove_private_data(self):
        self.prepare_bowl()
        self.assertTrue(self.service.export(self.user)["inventory"])
        self.service.delete_local_account(self.user)
        self.assertFalse(self.service.get_profile(self.user)["onboarded"])
        with self.db.transaction() as tx:
            for table in ["profiles","households","consents","inventory_batches","inventory_events","operations"]:
                self.assertEqual(tx.one(f"SELECT COUNT(*) AS n FROM {table}")["n"],0)

    def test_development_auth_cannot_start_in_production(self):
        with patch.dict(os.environ,{"EATME_ENV":"production"}):
            with self.assertRaises(RuntimeError):
                DevelopmentAuth(self.db)

    def test_local_auth_hashes_password_and_revokes_session(self):
        auth = DevelopmentAuth(self.db)
        session = auth.login("fictional@example.invalid","local-test-password",True)
        self.assertEqual(auth.verify(session["access_token"]),session["user_id"])
        with self.db.transaction() as tx:
            stored = tx.one("SELECT password_hash FROM dev_accounts")["password_hash"]
        self.assertNotIn("local-test-password",stored)
        auth.logout(session["access_token"])
        self.assertCode("unauthorized",lambda:auth.verify(session["access_token"]))

    def test_api_rejects_spoofed_user_id_and_protects_admin(self):
        auth = DevelopmentAuth(self.db)
        router = Router(self.service,auth)
        self.assertCode("unauthorized",lambda:router.dispatch("GET","/api/v1/inventory",{"user_id":self.user}))
        session = auth.login("transport@example.invalid","local-test-password",True)
        with patch.dict(os.environ,{"ADMIN_USER_IDS":""}):
            self.assertCode("forbidden",lambda:router.dispatch("GET","/api/v1/admin/catalog",authorization="Bearer "+session["access_token"]))

    def test_unsupported_medical_operator_fails_closed(self):
        foods = {f["id"]:f for f in self.service.catalog()["foods"]}
        rule = dict(type="TARGET_MAX",nutrient="sodium",max_value=200,hard_constraint=True,strictness="flexible",diet_id=new_id())
        result = compatibility([identifier("food","tomato")],foods,{"allergies":[],"intolerances":[]},[rule])
        self.assertEqual(result["reasons"][0]["code"],"rule_not_evaluable")


if __name__=="__main__":
    unittest.main()
