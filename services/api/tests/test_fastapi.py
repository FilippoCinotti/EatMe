import importlib.util
import tempfile
import unittest

from eatme.auth import DevelopmentAuth
from eatme.catalog import seed_catalog
from eatme.service import Service,new_id
from eatme.storage import Database
from eatme.transport import Router


@unittest.skipUnless(importlib.util.find_spec('fastapi') and importlib.util.find_spec('httpx'),'FastAPI/httpx not installed')
class FastAPITests(unittest.TestCase):
    def setUp(self):
        from fastapi.testclient import TestClient
        from eatme.api import create_app
        self.temp=tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        db=Database(self.temp.name+'/api.db')
        db.migrate_local()
        seed_catalog(db)
        self.client=TestClient(create_app(Router(Service(db),DevelopmentAuth(db))))
        self.addCleanup(self.client.close)

    def test_typed_boundary_and_profile_creation(self):
        result=self.client.post('/api/v1/auth/register',json={'email':'fastapi@example.invalid','password':'boundary-test-long'})
        self.assertEqual(result.status_code,200)
        token=result.json()['access_token']
        response=self.client.put('/api/v1/profile',headers={'Authorization':'Bearer '+token,'Idempotency-Key':new_id()},
            json={'name':'Alex','adult_confirmed':True})
        self.assertEqual(response.status_code,200)
        self.assertTrue(response.json()['onboarded'])
        self.assertEqual(self.client.get('/api/v1/inventory').status_code,401)

    def test_profile_boundary_accepts_the_complete_mobile_onboarding_payload(self):
        result=self.client.post('/api/v1/auth/register',json={'email':'complete@example.invalid','password':'boundary-test-long'})
        token=result.json()['access_token']
        diet_id=next(item['id'] for item in self.client.get('/api/v1/catalog',headers={'Authorization':'Bearer '+token}).json()['diets'] if not item['medical'])
        response=self.client.put('/api/v1/profile',headers={'Authorization':'Bearer '+token,'Idempotency-Key':new_id()},json={
            'name':'Alex','adult_confirmed':True,'primary_goal':'eat_better','primary_diet':diet_id,
            'household_size':2,'timezone':'Europe/Rome',
            'diets':[{'diet_id':diet_id,'strictness':'standard'}],
            'allergies':[],'intolerances':[],'sensitivities':[],'medical_awareness':[],
            'ethical_preferences':[],'trace_policy':'block',
            'meal_timing':{'mode':'standard','slots':{'breakfast':True,'lunch':True,'dinner':True,'snack':True}},
            'never_suggest':[],'unknown_ingredient_policy':'strict',
        })
        self.assertEqual(response.status_code,200,response.text)
        self.assertTrue(response.json()['onboarded'])

    def test_body_limit_and_unknown_input(self):
        self.assertEqual(self.client.post('/api/v1/auth/login',content=b'x'*262145).status_code,413)
        self.assertEqual(self.client.post('/api/v1/auth/login',json={'email':'a','password':'b','user_id':'spoof'}).status_code,422)
