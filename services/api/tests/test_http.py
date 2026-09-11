import json
import tempfile
import threading
import unittest
from urllib.error import HTTPError
from urllib.request import Request,urlopen

from eatme.auth import DevelopmentAuth
from eatme.catalog import identifier,seed_catalog
from eatme.local_server import create_server
from eatme.service import Service,new_id
from eatme.storage import Database
from eatme.transport import Router


class HttpTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory()
        db=Database(self.temp.name+'/http.db')
        db.migrate_local()
        seed_catalog(db)
        self.server=create_server(Router(Service(db),DevelopmentAuth(db)),port=0)
        self.thread=threading.Thread(target=self.server.serve_forever,daemon=True)
        self.thread.start()
        self.base=f'http://127.0.0.1:{self.server.server_port}/api/v1'
        self.token=''

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()
        self.temp.cleanup()

    def request(self,method,path,body=None,key=None):
        request=Request(self.base+path,data=json.dumps(body).encode() if body is not None else None,method=method,
            headers={'Content-Type':'application/json','Authorization':'Bearer '+self.token,'Idempotency-Key':key or new_id()})
        try:
            with urlopen(request,timeout=5) as response:
                self.assertEqual(response.headers['Cache-Control'],'no-store')
                return response.status,json.load(response)
        except HTTPError as error:
            return error.code,json.load(error)

    def test_complete_api_vertical_slice_and_retry(self):
        status,session=self.request('POST','/auth/register',{'email':'e2e@example.invalid','password':'test-password-long'})
        self.assertEqual(status,200)
        self.token=session['access_token']
        status,profile=self.request('PUT','/profile',{'name':'Alex','adult_confirmed':True,'household_size':2,
            'diets':[{'diet_id':identifier('diet','mediterranean'),'strictness':'standard'}],
            'allergies':['peanut'],'health_consent_version':'nutrition-profile-1'})
        self.assertEqual(status,200)
        for slug,quantity in [('tomato','300'),('chickpea','300'),('olive-oil','20')]:
            self.assertEqual(self.request('POST','/inventory',{'food_id':identifier('food',slug),'quantity':quantity})[0],200)
        status,recs=self.request('GET','/recommendations?mode=no_shopping')
        self.assertEqual(status,200)
        self.assertTrue(recs['items'])
        recipe_id=recs['items'][0]['recipe']['id']
        self.assertEqual(self.request('GET','/recipes/'+recipe_id)[0],200)
        status,plan=self.request('POST','/cooking/preview',{'recipe_id':recipe_id,'servings':2})
        self.assertEqual(status,200)
        self.assertFalse(plan['shortages'])
        payload={'recipe_id':recipe_id,'servings':2,'profile_version':plan['profile_version'],'diet_rules_version':plan['diet_rules_version'],
                 'batch_versions':{a['batch_id']:a['version'] for a in plan['allocations']},'leftover_servings':1}
        key=new_id()
        status,receipt=self.request('POST','/cooking/confirm',payload,key)
        self.assertEqual(status,200)
        self.assertEqual(self.request('POST','/cooking/confirm',payload,key)[1],receipt)
        self.assertEqual(self.request('GET','/inventory')[1]['items'][0]['quantity'],'100')
        self.assertEqual(self.request('GET','/leftovers')[1]['items'][0]['servings'],1)
        self.assertEqual(self.request('GET','/privacy/export')[0],200)
        self.assertEqual(self.request('POST','/auth/logout')[0],200)
        self.assertEqual(self.request('GET','/inventory')[0],401)

    def test_unknown_and_unauthenticated_requests(self):
        self.assertEqual(self.request('GET','/health')[0],200)
        self.assertEqual(self.request('GET','/inventory')[0],401)
        self.assertEqual(self.request('POST','/auth/register',[])[0],422)


if __name__=='__main__':
    unittest.main()
