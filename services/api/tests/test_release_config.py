"""Public build configuration must reject privileged server credentials."""
import base64
import importlib.util
import json
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location('release_config', Path(__file__).resolve().parents[3] / 'scripts/check_release_config.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class ReleaseConfigTests(unittest.TestCase):
    def config(self):
        return {'AUTH_MODE': 'supabase', 'API_URL': 'https://api.eatme.test/api/v1',
                'SUPABASE_URL': 'https://project.supabase.co',
                'SUPABASE_ANON_KEY': 'sb_publishable_configuration_test_only',
                'PRIVACY_URL': 'https://eatme.test/privacy', 'TERMS_URL': 'https://eatme.test/terms',
                'OAUTH_ENABLED': False}

    def test_valid_public_configuration(self):
        self.assertEqual(module.validate(self.config()), [])

    def test_server_secrets_and_development_endpoints_are_rejected(self):
        claims = base64.urlsafe_b64encode(json.dumps({'role': 'service_role'}).encode()).decode().rstrip('=')
        config = {**self.config(), 'SUPABASE_ANON_KEY': 'header.' + claims + '.signature',
                  'AI_API_KEY': 'secret-test-only', 'API_URL': 'http://localhost:8000/api/v1'}
        self.assertGreaterEqual(len(module.validate(config)), 3)
        self.assertNotIn('secret-test-only', '\n'.join(module.validate(config)))

    def test_social_login_requires_the_exact_registered_callback(self):
        config = {**self.config(), 'OAUTH_ENABLED': True, 'APPLE_ANDROID_CLIENT_ID': 'com.eatme.signin',
                  'APPLE_ANDROID_CALLBACK_URL': 'https://wrong.test/callback'}
        self.assertTrue(module.validate(config))
        config['APPLE_ANDROID_CALLBACK_URL'] = config['API_URL'] + '/auth/apple/callback'
        self.assertEqual(module.validate(config), [])
