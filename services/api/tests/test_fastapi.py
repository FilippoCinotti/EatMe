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

    def test_body_limit_and_unknown_input(self):
        self.assertEqual(self.client.post('/api/v1/auth/login',content=b'x'*262145).status_code,413)
        self.assertEqual(self.client.post('/api/v1/auth/login',json={'email':'a','password':'b','user_id':'spoof'}).status_code,422)
