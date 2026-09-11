"""Identity-provider token lifecycle; credentials never enter application exports."""
import os
from datetime import datetime, timedelta, timezone
from urllib.parse import urlencode

from .errors import DomainError
from .intelligence import PrivateMedia
from .providers import https_request, json_request
from .storage import decode, encode
from .validation import choice, text, valid_uuid


def supabase_user(user_id):
    key = os.getenv('SUPABASE_SERVICE_ROLE_KEY')
    if not key:
        raise DomainError('identity_management_not_configured', 503)
    return json_request(os.environ['SUPABASE_URL'].rstrip('/') + '/auth/v1/admin/users/' + valid_uuid(user_id), headers={'Authorization': 'Bearer ' + key, 'apikey': key}, redirects=0)


def apple_secret(client_id):
    secret = os.getenv('APPLE_CLIENT_SECRET')
    if secret and client_id == os.getenv('APPLE_CLIENT_ID'):
        return secret
    if not all(os.getenv(v) for v in ('APPLE_PRIVATE_KEY', 'APPLE_KEY_ID', 'APPLE_TEAM_ID', 'APPLE_CLIENT_ID')):
        raise DomainError('apple_lifecycle_not_configured', 503)
    import jwt
    stamp = datetime.now(timezone.utc)
    return jwt.encode({'iss': os.environ['APPLE_TEAM_ID'], 'iat': stamp, 'exp': stamp + timedelta(minutes=10), 'aud': 'https://appleid.apple.com', 'sub': client_id}, os.environ['APPLE_PRIVATE_KEY'], algorithm='ES256', headers={'kid': os.environ['APPLE_KEY_ID']})


def store_apple_authorization(db, user_id, authorization_code, platform='ios'):
    choice(platform, {'ios', 'android'})
    client_id = os.getenv('APPLE_ANDROID_CLIENT_ID' if platform == 'android' else 'APPLE_CLIENT_ID', '')
    if not client_id:
        raise DomainError('apple_lifecycle_not_configured', 503)
    code = text(authorization_code, maximum=4096)
    account = supabase_user(user_id)
    identities = account.get('identities', [])
    subjects = {i.get('identity_data', {}).get('sub') for i in identities if i.get('provider') == 'apple'}
    if not subjects:
        raise DomainError('apple_identity_required', 403)
    payload = urlencode({'client_id': client_id, 'client_secret': apple_secret(client_id), 'code': code, 'grant_type': 'authorization_code'})
    token = json_request('https://appleid.apple.com/auth/token', method='POST', body=payload.encode(), headers={'Content-Type': 'application/x-www-form-urlencoded'}, redirects=0)
    import jwt
    try:
        jwks = jwt.PyJWKClient('https://appleid.apple.com/auth/keys')
        signing = jwks.get_signing_key_from_jwt(token['id_token'])
        claims = jwt.decode(token['id_token'], signing.key, algorithms=['RS256'], audience=client_id, issuer='https://appleid.apple.com')
        if claims['sub'] not in subjects:
            raise DomainError('apple_identity_mismatch', 403)
        refresh = text(token['refresh_token'], maximum=8192)
    except (jwt.PyJWTError, KeyError):
        raise DomainError('invalid_apple_authorization', 422) from None
    encrypted = PrivateMedia().cipher.encrypt(encode({'token': refresh, 'client_id': client_id}).encode()).decode()
    with db.transaction() as tx:
        tx.execute('INSERT INTO identity_tokens VALUES (?,?,?) ON CONFLICT(user_id,provider) DO UPDATE SET ciphertext=excluded.ciphertext', (user_id, 'apple', encrypted))
    return {'registered': True}


def revoke_apple_if_linked(db, user_id, *, preflight=False):
    try:
        account = supabase_user(user_id)
    except DomainError as error:
        if error.code == 'provider_not_found':
            return
        raise
    if not any(i.get('provider') == 'apple' for i in account.get('identities', [])):
        return
    with db.transaction() as tx:
        row = tx.one("SELECT ciphertext FROM identity_tokens WHERE user_id=? AND provider='apple'", (user_id,))
    if not row:
        raise DomainError('apple_reauthentication_required', 409)
    token = PrivateMedia().cipher.decrypt(row['ciphertext'].encode()).decode()
    token = decode(token)
    secret = apple_secret(token['client_id'])
    if preflight:
        return
    payload = urlencode({'client_id': token['client_id'], 'client_secret': secret, 'token': token['token'], 'token_type_hint': 'refresh_token'})
    https_request('https://appleid.apple.com/auth/revoke', method='POST', body=payload.encode(), headers={'Content-Type': 'application/x-www-form-urlencoded'}, redirects=0)
