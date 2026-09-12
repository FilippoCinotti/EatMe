"""Check public mobile configuration without displaying keys or making requests."""
import argparse
import base64
import json
from pathlib import Path
from urllib.parse import urlsplit

ALLOWED = {
    'AUTH_MODE', 'API_URL', 'SUPABASE_URL', 'SUPABASE_ANON_KEY',
    'OAUTH_ENABLED', 'REVENUECAT_ANDROID_KEY', 'REVENUECAT_IOS_KEY',
    'PRIVACY_URL', 'TERMS_URL', 'APPLE_ANDROID_CLIENT_ID',
    'APPLE_ANDROID_CALLBACK_URL',
}


def validate(config):
    errors = []
    if not isinstance(config, dict):
        return ['Configuration must be a JSON object.']
    if set(config) - ALLOWED:
        errors.append('Unknown fields are not allowed; keep server secrets outside mobile configuration.')
    if config.get('AUTH_MODE') != 'supabase':
        errors.append('AUTH_MODE must be supabase.')
    for name in ('API_URL', 'SUPABASE_URL', 'PRIVACY_URL', 'TERMS_URL'):
        value = config.get(name, '')
        if not isinstance(value, str):
            errors.append(f'{name} must be an HTTPS URL.')
            continue
        try:
            url = urlsplit(value)
            valid = url.scheme == 'https' and bool(url.hostname) and not url.username and not url.password and not url.fragment
            valid = valid and not any(marker in value.lower() for marker in ('your_', 'example.', 'localhost', '127.0.0.1'))
        except ValueError:
            valid = False
        if not valid:
            errors.append(f'{name} must be an operational HTTPS URL without placeholders or credentials.')
    if not str(config.get('API_URL', '')).endswith('/api/v1'):
        errors.append('API_URL must end with /api/v1.')
    key = config.get('SUPABASE_ANON_KEY', '')
    public = isinstance(key, str) and key.startswith('sb_publishable_') and len(key) > 25
    if isinstance(key, str) and key.count('.') == 2:
        try:
            payload = key.split('.')[1]
            claims = json.loads(base64.urlsafe_b64decode(payload + '=' * (-len(payload) % 4)))
            public = claims.get('role') == 'anon'
        except (ValueError, TypeError, AttributeError):
            public = False
    if not public:
        errors.append('SUPABASE_ANON_KEY must be a public publishable key or legacy anon key, never a service-role key.')
    if type(config.get('OAUTH_ENABLED')) is not bool:
        errors.append('OAUTH_ENABLED must be a boolean.')
    if config.get('OAUTH_ENABLED') is True:
        client = config.get('APPLE_ANDROID_CLIENT_ID')
        callback = config.get('APPLE_ANDROID_CALLBACK_URL')
        if not isinstance(client, str) or not client or 'YOUR_' in client:
            errors.append('Apple Android Services ID is required when social login is enabled.')
        expected = str(config.get('API_URL', '')) + '/auth/apple/callback'
        if callback != expected:
            errors.append('Apple Android callback must match the API /auth/apple/callback endpoint.')
    for name in ('REVENUECAT_ANDROID_KEY', 'REVENUECAT_IOS_KEY'):
        value = config.get(name, '')
        prefix = 'goog_' if name.endswith('ANDROID_KEY') else 'appl_'
        if not isinstance(value, str) or (value and not value.startswith(prefix)):
            errors.append(f'{name} must be an empty value or the platform public SDK key.')
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('config', type=Path)
    args = parser.parse_args()
    try:
        errors = validate(json.loads(args.config.read_text()))
    except (OSError, ValueError):
        raise SystemExit('Cannot read a valid JSON configuration.') from None
    if errors:
        raise SystemExit('\n'.join(errors))
    print('Public configuration structure passed. Verify live providers, signing and release evidence separately.')


if __name__ == '__main__':
    main()
