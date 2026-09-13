import tempfile
import unittest
from datetime import date
from eatme.catalog import identifier, seed_catalog
from eatme.errors import DomainError
from eatme.service import Service, new_id
from eatme.storage import Database, decode


class ReferenceFeatureTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.db = Database(temp.name + '/app.db')
        self.db.migrate_local()
        seed_catalog(self.db)
        self.day = date(2026, 9, 11)
        self.app = Service(self.db, clock=lambda: self.day)
        self.owner, self.guest = new_id(), new_id()
        for uid in (self.owner, self.guest):
            self.app.save_profile(uid, {'name':'Diner','adult_confirmed':True}, new_id())

    def create(self, user=None, **values):
        return self.app.food_action(user or self.owner, {'action':'create','name':'Homemade stock','group':'other','unit':'ml','quantity':'500', **values}, new_id())

    def assertCode(self, code, fn):
        with self.assertRaises(DomainError) as caught:
            fn()
        self.assertEqual(caught.exception.code, code)

    def test_custom_food_is_private_and_cannot_be_imported_by_unrelated_user(self):
        result = self.create()
        food_id = result['food']['id']
        self.assertEqual(result['food']['ingredient_status'], 'unknown')
        self.assertCode('food_not_found', lambda: self.app.food_compatibility(self.guest,food_id))
        self.assertCode('food_not_found', lambda: self.app.add_inventory(self.guest, {'food_id':food_id,'quantity':'100'},new_id()))
        self.assertCode('food_not_found', lambda: self.app.shopping_action(self.guest, {'action':'add','food_id':food_id,'quantity':'100'},new_id()))
        invite = self.app.household_action(self.owner, {'action':'invite','role':'viewer'},new_id())
        self.app.household_action(self.guest, {'action':'accept','token':invite['token']},new_id())
        self.assertEqual(self.app.food_compatibility(self.guest,food_id)['assessment']['status'],'not_compatible')
        self.assertCode('forbidden',lambda:self.create(self.guest))
        self.app.household_action(self.guest, {'action':'leave'},new_id())
        self.assertCode('invalid_food',lambda:self.app.food_photo(self.guest,food_id))

    def test_custom_food_validation_and_idempotency(self):
        self.assertCode('whole_units_required',lambda:self.create(unit='pcs',quantity='1.5'))
        self.assertCode('expiry_type_required',lambda:self.create(expiry_date='2026-09-12'))
        body={'action':'create','name':'Stock','group':'other','unit':'ml','quantity':'500'}
        key=new_id()
        a=self.app.food_action(self.owner,body,key)
        self.assertEqual(self.app.food_action(self.owner,body,key),a)
        self.assertEqual(len(self.app.inventory(self.owner)['items']),1)

    def test_favorites_are_personal_and_preserved_by_other_preference_edits(self):
        food=self.create()['food']['id']
        self.app.food_action(self.owner,{'action':'favorite','food_id':food,'enabled':True},new_id())
        prefs=self.app.preferences(self.owner)
        self.app.preferences(self.owner,{'expected_version':prefs['version'],'data':{'cuisines':['Italian']}},new_id())
        self.assertEqual(self.app.preferences(self.owner)['data']['favorite_foods'],[food])
        self.assertNotIn('favorite_foods', self.app.preferences(self.guest)['data'])
        prefs=self.app.preferences(self.owner)
        self.assertCode('invalid_preferences', lambda:self.app.preferences(self.owner,{'expected_version':prefs['version'],'data':{'habit_log':{'waste_less':['2026-09-11']}}},new_id()))

    def test_habit_counts_are_weekly_idempotent_and_versioned(self):
        self.app.wellbeing_action(self.owner,{'action':'target','goal':'waste_less','target':5,'expected_version':0},new_id())
        body={'action':'check_in','goal':'waste_less','completed':True,'expected_version':1}
        key=new_id()
        self.app.wellbeing_action(self.owner,body,key)
        self.app.wellbeing_action(self.owner,body,key)
        self.assertCode('stale_preferences',lambda:self.app.wellbeing_action(self.owner,body,new_id()))
        value=self.app.wellbeing(self.owner)
        self.assertEqual(value['goals'][0]['completed_days'],1)
        self.assertIsNone(value['nutrition_score'])
        self.assertEqual(self.app.wellbeing(self.guest)['goals'],[])
        self.day=date(2026,9,14)
        self.assertEqual(self.app.wellbeing(self.owner)['goals'][0]['completed_days'],0)
        self.app.wellbeing_action(self.owner,{'action':'check_in','goal':'waste_less','completed':True,'expected_version':2},new_id())
        self.app.wellbeing_action(self.owner,{'action':'check_in','goal':'waste_less','completed':False,'expected_version':3},new_id())
        self.assertEqual(self.app.wellbeing(self.owner)['goals'][0]['completed_days'],0)

    def test_external_leftovers_do_not_deduct_stock_or_inflate_cooked_meals(self):
        food=self.create()['food']['id']
        before=self.app.inventory(self.owner)
        body={'action':'create','recipe_id':identifier('recipe','sunny-bowl'),'servings':2,'prepared_at':'2026-09-10','location':'fridge','ingredients_confirmed':True}
        value=self.app.leftover_action(self.owner,body,new_id())
        self.assertEqual(before,self.app.inventory(self.owner))
        self.assertEqual(self.app.insights(self.owner)['cooked_meals'],0)
        self.app.leftover_action(self.owner,{'action':'consume','id':value['id'],'expected_version':1,'servings':1},new_id())
        self.assertEqual(self.app.leftovers(self.owner)['items'][0]['remaining'],1)
        self.assertCode('invalid_date',lambda:self.app.leftover_action(self.owner,{**body,'prepared_at':'2026-09-12'},new_id()))
        self.assertEqual(food,before['items'][0]['food_id'])

    def test_activity_is_household_scoped_and_omits_health_metadata(self):
        self.create()
        rows=self.app.household_activity(self.owner)['items']
        self.assertEqual(len(rows),1)
        self.assertNotIn('metadata',rows[0])
        self.assertNotIn('settings',rows[0])
        self.assertEqual(rows[0]['quantity'],'500')
        self.assertEqual(self.app.household_activity(self.guest)['items'],[])

    def test_invalid_primary_goal_is_domain_error(self):
        self.assertCode('invalid_goal',lambda:self.app.save_profile(new_id(),{'name':'Diner','adult_confirmed':True,'primary_goal':[]},new_id()))
