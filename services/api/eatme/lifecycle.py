"""Privacy lifecycle, notification preferences and server-verified entitlements."""
import os
from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo

from .auth import now
from .errors import DomainError
from .intelligence import PrivateMedia
from .providers import https_request, json_request
from .storage import decode, encode
from .validation import choice, integer, new_id, text, valid_uuid

CATEGORIES = {'expiry', 'plans', 'shopping', 'household', 'recalls'}
PLUS_ENTITLEMENTS = {'eatme_plus', 'premium'}
CAPABILITIES = {
    'canUseUnlimitedImports': False,
    'canUseAdvancedDietFit': False,
    'canUseAdvancedSubstitutions': False,
    'canUseReceiptRecognition': False,
    'canUseAdvancedPhotoRecognition': False,
    'canUseAdvancedFridgeRecognition': False,
    'canUseGeneratedShopping': False,
    'canUseSmartPlanning': False,
    'canUseHouseholdProfiles': False,
    'canUseAdvancedMealTiming': False,
    'canUsePremiumInsights': False,
    # Backward-compatible alias for clients released before Smart Planning
    # received its final product name.
    'canUseAdvancedPlanning': False,
    'canSeeSafetyWarnings': True,
    'canUseManualInventory': True,
    'canUseBasicPlanning': True,
    'canUseManualShopping': True,
}


class LifecycleService:
    @staticmethod
    def _plus_active(entitlements):
        return any(
            name in PLUS_ENTITLEMENTS and item.get('active') is True
            for name, item in entitlements.items()
            if isinstance(item, dict)
        )

    @staticmethod
    def _free_limits():
        return {
            'smart_import': int(os.getenv('FREE_SMART_IMPORT_LIMIT', '3')),
            'smart_substitution': int(os.getenv('FREE_SMART_SUBSTITUTION_LIMIT', '3')),
        }

    def _entitlement_snapshot(self, tx, user_id, entitlements):
        plus = self._plus_active(entitlements)
        limits = self._free_limits()
        rows = {
            row['capability']: row['used']
            for row in tx.all(
                "SELECT capability,used FROM usage_counters WHERE user_id=? AND period='lifetime'",
                (user_id,),
            )
        }
        capabilities = dict(CAPABILITIES)
        if plus:
            capabilities.update({name: True for name in capabilities if name.startswith('canUse')})
        return {
            'tier': 'eatme_plus' if plus else 'free',
            'capabilities': capabilities,
            'limits': {name: None if plus else limit for name, limit in limits.items()},
            'usage': {name: rows.get(name, 0) for name in limits},
            'remaining': {
                name: None if plus else max(limit - rows.get(name, 0), 0)
                for name, limit in limits.items()
            },
        }

    def check_allowance(self, user_id, capability):
        with self.db.transaction() as tx:
            row = tx.one('SELECT data FROM subscriptions WHERE user_id=?', (user_id,))
            entitlements = decode(row['data']) if row else {}
            snapshot = self._entitlement_snapshot(tx, user_id, entitlements)
            if snapshot['remaining'].get(capability) == 0:
                raise DomainError(
                    capability + '_limit_reached',
                    429,
                    {'tier': snapshot['tier'], 'limit': snapshot['limits'][capability]},
                )

    def require_capability(self, user_id, capability):
        with self.db.transaction() as tx:
            row = tx.one('SELECT data FROM subscriptions WHERE user_id=?', (user_id,))
            entitlements = decode(row['data']) if row else {}
            snapshot = self._entitlement_snapshot(tx, user_id, entitlements)
            if snapshot['capabilities'].get(capability) is not True:
                raise DomainError(
                    'eatme_plus_required',
                    403,
                    {'capability': capability, 'tier': snapshot['tier']},
                )

    def consume_allowance(self, user_id, capability):
        with self.db.transaction() as tx:
            row = tx.one('SELECT data FROM subscriptions WHERE user_id=?', (user_id,))
            entitlements = decode(row['data']) if row else {}
            if self._plus_active(entitlements):
                return
            limit = self._free_limits()[capability]
            tx.execute(
                "INSERT INTO usage_counters VALUES (?,?,'lifetime',0) ON CONFLICT DO NOTHING",
                (user_id, capability),
            )
            changed = tx.execute(
                "UPDATE usage_counters SET used=used+1 WHERE user_id=? AND capability=? AND period='lifetime' AND used<?",
                (user_id, capability, limit),
            )
            if changed.rowcount != 1:
                raise DomainError(capability + '_limit_reached', 429, {'tier': 'free', 'limit': limit})

    def feature_enabled(self, name):
        defaults = {'ai_scan': bool(os.getenv('AI_PROVIDER')), 'receipt_scan': bool(os.getenv('AI_PROVIDER')), 'ai_recipe': bool(os.getenv('AI_PROVIDER')), 'barcode_scan': bool(os.getenv('PRODUCT_CONTACT')), 'subscriptions': bool(os.getenv('REVENUECAT_SECRET_KEY'))}
        with self.db.transaction() as tx:
            row = tx.one('SELECT enabled FROM feature_flags WHERE name=?', (name,))
            return bool(row['enabled']) if row else defaults.get(name, False)

    def notifications(self, user_id):
        with self.db.transaction() as tx:
            profile = self._profile(tx, user_id)
            row = tx.one('SELECT * FROM notification_preferences WHERE user_id=?', (user_id,))
            prefs = decode(row['data']) if row else {'enabled': False, 'categories': sorted(CATEGORIES), 'quiet_start': 22, 'quiet_end': 8, 'daily_cap': 3}
            local = datetime.now(ZoneInfo(profile['settings']['timezone']))
            start, end = prefs['quiet_start'], prefs['quiet_end']
            quiet = (local.hour >= start or local.hour < end) if start > end else start <= local.hour < end
            if prefs['enabled'] and not quiet:
                candidates = []
                if 'expiry' in prefs['categories']:
                    today = self.today(profile['settings'])
                    for batch in self._inventory(tx, profile['household_id']):
                        if batch['expiry_date'] and today.isoformat() <= batch['expiry_date'] <= (today + timedelta(days=2)).isoformat():
                            candidates.append(('expiry', 'expiry:' + batch['id'] + ':' + batch['expiry_date'], {'batch_id': batch['id'], 'expiry_date': batch['expiry_date'], 'expiry_kind': batch['expiry_kind']}))
                if 'plans' in prefs['categories']:
                    for plan in tx.all('SELECT id,data FROM meal_plans WHERE user_id=? AND household_id=?', (user_id, profile['household_id'])):
                        for meal in decode(plan['data'])['meals']:
                            if meal['date'] == local.date().isoformat():
                                candidates.append(('plans', plan['id'] + ':' + meal['date'] + ':' + meal['slot'], {'recipe_id': meal['recipe_id'], 'slot': meal['slot']}))
                since = local.replace(hour=0, minute=0, second=0, microsecond=0).astimezone(timezone.utc).isoformat()
                if 'shopping' in prefs['categories']:
                    for item in tx.all('SELECT id,version FROM shopping_items WHERE household_id=? AND created_by<>? AND updated_at>=? LIMIT 10', (profile['household_id'], user_id, since)):
                        candidates.append(('shopping', 'shopping:' + item['id'] + ':' + str(item['version']), {'item_id': item['id']}))
                if 'household' in prefs['categories']:
                    for invitation in tx.all('SELECT id FROM household_invitations WHERE created_by=? AND accepted_at>=?', (user_id, since)):
                        candidates.append(('household', 'joined:' + invitation['id'], {'household_id': profile['household_id']}))
                if 'recalls' in prefs['categories']:
                    for batch in self._inventory(tx, profile['household_id']):
                        for recall in batch['recalls']:
                            candidates.insert(0, ('recalls', 'recall:' + batch['id'] + ':' + recall['published_date'], {'batch_id': batch['id'], 'url': recall['url']}))
                count = tx.one('SELECT COUNT(*) AS n FROM notification_events WHERE user_id=? AND created_at>=?', (user_id, local.replace(hour=0, minute=0, second=0, microsecond=0).astimezone(timezone.utc).isoformat()))['n']
                for category, key, value in candidates:
                    if count >= prefs['daily_cap']:
                        break
                    inserted = tx.execute('INSERT INTO notification_events VALUES (?,?,?,?,?,?,NULL) ON CONFLICT(user_id,dedup_key) DO NOTHING', (new_id(), user_id, category, key, encode(value), now()))
                    count += inserted.rowcount
            return {'preferences': prefs, 'version': row['version'] if row else 0, 'items': [{**r, 'data': decode(r['data'])} for r in tx.all('SELECT * FROM notification_events WHERE user_id=? ORDER BY created_at DESC LIMIT 50', (user_id,))]}

    def notification_action(self, user_id, data, key):
        with self.db.transaction() as tx:
            self._profile(tx, user_id)
            def save():
                if data.get('action') == 'read':
                    tx.execute('UPDATE notification_events SET read_at=? WHERE id=? AND user_id=?', (now(), valid_uuid(data.get('id')), user_id))
                    return {'read': True}
                value = data.get('preferences')
                if not isinstance(value, dict) or type(value.get('enabled')) is not bool or not isinstance(value.get('categories'), list) or any(c not in CATEGORIES for c in value['categories']):
                    raise DomainError('invalid_notification_preferences', 422)
                value = {**value, 'quiet_start': integer(value.get('quiet_start'), maximum=23), 'quiet_end': integer(value.get('quiet_end'), maximum=23), 'daily_cap': integer(value.get('daily_cap'), minimum=1, maximum=10)}
                row = tx.one('SELECT version FROM notification_preferences WHERE user_id=?', (user_id,))
                version = row['version'] if row else 0
                if data.get('expected_version') != version:
                    raise DomainError('stale_preferences', 409)
                tx.execute('INSERT INTO notification_preferences VALUES (?,?,?,?) ON CONFLICT(user_id) DO UPDATE SET data=excluded.data,version=excluded.version,updated_at=excluded.updated_at', (user_id, encode(value), version + 1, now()))
                return {'preferences': value, 'version': version + 1}
            return self._once(tx, user_id, key, 'notifications', data, save)

    def entitlements(self, user_id, refresh=False):
        self._household(user_id)
        secret = os.getenv('REVENUECAT_SECRET_KEY')
        with self.db.transaction() as tx:
            row = tx.one('SELECT * FROM subscriptions WHERE user_id=?', (user_id,))
        if secret and (refresh or not row or row['checked_at'] < (datetime.now(timezone.utc) - timedelta(minutes=15)).isoformat()):
            response = json_request('https://api.revenuecat.com/v1/subscribers/' + valid_uuid(user_id), headers={'Authorization': 'Bearer ' + secret, 'Content-Type': 'application/json'})
            verified = {}
            for name, item in response.get('subscriber', {}).get('entitlements', {}).items():
                expiry = item.get('expires_date')
                verified[name] = {'active': expiry is None or datetime.fromisoformat(expiry.replace('Z', '+00:00')) > datetime.now(timezone.utc), 'expires_at': expiry}
            with self.db.transaction() as tx:
                tx.execute('INSERT INTO subscriptions VALUES (?,?,?,?) ON CONFLICT(user_id) DO UPDATE SET data=excluded.data,checked_at=excluded.checked_at', (user_id, 'revenuecat', encode(verified), now()))
            row = {'data': encode(verified), 'checked_at': now()}
        verified = decode(row['data']) if row else {}
        with self.db.transaction() as tx:
            snapshot = self._entitlement_snapshot(tx, user_id, verified)
        return {
            'configured': bool(secret),
            'entitlements': verified,
            'checked_at': row['checked_at'] if row else None,
            **snapshot,
            'offerings_source': 'revenuecat' if secret else None,
        }

    def analytics(self, user_id, data):
        with self.db.transaction() as tx:
            prefs = tx.one('SELECT data FROM user_preferences WHERE user_id=?', (user_id,))
            if not prefs or not decode(prefs['data']).get('analytics'):
                raise DomainError('analytics_consent_required', 403)
            event = choice(data.get('event'), {'app_open', 'screen_view', 'operation_success', 'operation_failure'})
            properties = data.get('data', {})
            if not isinstance(properties, dict) or set(properties) - {'screen', 'duration_bucket', 'platform'}:
                raise DomainError('invalid_analytics', 422)
            allowed = {'screen': {'chef', 'fridge', 'healthy_food', 'profile', 'shopping', 'planner'}, 'duration_bucket': {'fast', 'medium', 'slow'}, 'platform': {'android', 'ios'}}
            for field, value in properties.items():
                choice(value, allowed[field])
            tx.execute('INSERT INTO analytics_events VALUES (?,?,?,?,?)', (new_id(), user_id, event, encode(properties), now()))
            return {'accepted': True}

    def inventory_metadata(self, user_id, data, key):
        home = self._household(user_id, write=True)
        with self.db.transaction(home) as tx:
            def save():
                self._member(tx, user_id, home, write=True)
                identifier = valid_uuid(data.get('id'))
                batch = tx.one('SELECT * FROM inventory_batches WHERE id=? AND household_id=?', (identifier, home))
                if not batch:
                    raise DomainError('batch_not_found', 404)
                if data.get('expected_version') != batch['version']:
                    raise DomainError('stale_inventory', 409)
                value = data.get('metadata', {})
                if not isinstance(value, dict) or set(value) - {'barcode', 'lot', 'purchase_date', 'cost', 'currency', 'notes', 'product_id'}:
                    raise DomainError('invalid_metadata', 422)
                from .providers import barcode
                from .validation import decimal, valid_date
                if value.get('barcode'):
                    barcode(value['barcode'])
                if value.get('purchase_date'):
                    valid_date(value['purchase_date'])
                if value.get('cost') is not None:
                    decimal(value['cost'], maximum=100000)
                    choice(value.get('currency'), {'EUR', 'USD', 'GBP', 'CHF'})
                for field in ('lot', 'notes', 'product_id'):
                    if field in value:
                        value[field] = text(value[field], maximum=500, empty=True)
                tx.execute('INSERT INTO inventory_metadata VALUES (?,?,?) ON CONFLICT(batch_id) DO UPDATE SET data=excluded.data,confirmed_at=excluded.confirmed_at', (identifier, encode(value), now()))
                expiry = valid_date(data.get('expiry_date', batch['expiry_date']))
                kind = choice(data.get('expiry_kind', batch['expiry_kind']), {'unknown', 'use_by', 'best_before', 'estimated'})
                if bool(expiry) != (kind != 'unknown'):
                    raise DomainError('expiry_type_required', 422)
                tx.execute('UPDATE inventory_batches SET expiry_date=?,expiry_kind=?,version=version+1,updated_at=? WHERE id=?', (expiry, kind, now(), identifier))
                self._event(tx, user_id, home, identifier, 'metadata_updated', 0)
                return {'id': identifier, 'version': batch['version'] + 1}
            return self._once(tx, user_id, key, 'inventory_metadata', data, save)

    def export_all(self, user_id):
        result = self.export(user_id)
        with self.db.transaction() as tx:
            for table in ('user_preferences', 'member_permissions', 'recipe_favorites', 'recipe_feedback', 'meal_plans', 'notification_preferences', 'notification_events', 'subscriptions', 'analytics_events', 'data_reports', 'usage_counters'):
                result[table] = tx.all(f'SELECT * FROM {table} WHERE user_id=?', (user_id,))
            result['processing_jobs'] = tx.all('SELECT id,kind,status,result,error_code,created_at,completed_at FROM processing_jobs WHERE user_id=?', (user_id,))
            result['private_recipes'] = [decode(r['data']) for r in tx.all("SELECT r.data FROM recipes r JOIN content_ownership o ON o.content_id=r.id AND o.kind='recipe' WHERE o.user_id=?", (user_id,))]
            result['custom_foods'] = [decode(r['data']) for r in tx.all("SELECT f.data FROM foods f JOIN content_ownership o ON o.content_id=f.id AND o.kind='food' WHERE o.user_id=?", (user_id,))]
            result['media'] = tx.all('SELECT id,kind,mime_type,size_bytes,created_at,expires_at FROM media_objects WHERE user_id=?', (user_id,))
            result['shopping'] = self.shopping(user_id)['items'] if tx.postgres else tx.all('SELECT * FROM shopping_items WHERE household_id=?', (result['profile']['household_id'],))
            result['dinners'] = [
                {**row, 'data': decode(row['data'])}
                for row in tx.all('SELECT * FROM dinners WHERE host_user_id=? ORDER BY starts_at', (user_id,))
            ]
            result['dinner_memories'] = [
                {**row, 'data': decode(row['data'])}
                for row in tx.all(
                    'SELECT m.* FROM dinner_memories m JOIN dinners d ON d.id=m.dinner_id WHERE d.host_user_id=?',
                    (user_id,),
                )
            ]
            result['format_version'] = 3
        return result

    def delete_account(self, user_id, *, retry=False):
        # Ownership is checked before external identity deletion; retry records survive profile deletion.
        if os.getenv('AUTH_MODE', 'development') == 'supabase' and not os.getenv('SUPABASE_SERVICE_ROLE_KEY'):
            raise DomainError('account_deletion_not_configured', 503)
        if not retry and os.getenv('AUTH_MODE', 'development') == 'supabase':
            from .identity import revoke_apple_if_linked
            revoke_apple_if_linked(self.db, user_id, preflight=True)
        with self.db.transaction() as tx:
            lock = ' FOR UPDATE' if tx.postgres else ''
            for home in tx.all('SELECT id FROM households WHERE owner_id=? ORDER BY id' + lock, (user_id,)):
                if tx.one('SELECT COUNT(*) AS n FROM household_members WHERE household_id=?', (home['id'],))['n'] > 1:
                    raise DomainError('ownership_transfer_required', 409)
            tx.execute("INSERT INTO account_deletions VALUES (?,'pending',?,NULL,NULL) ON CONFLICT(user_id) DO NOTHING", (user_id, now()))
        if os.getenv('AUTH_MODE', 'development') == 'supabase':
            key = os.getenv('SUPABASE_SERVICE_ROLE_KEY')
            if not key:
                raise DomainError('account_deletion_not_configured', 503)
            try:
                from .identity import revoke_apple_if_linked
                revoke_apple_if_linked(self.db,user_id)
                https_request(os.environ['SUPABASE_URL'].rstrip('/') + '/auth/v1/admin/users/' + valid_uuid(user_id), method='DELETE', headers={'Authorization': 'Bearer ' + key, 'apikey': key}, redirects=0)
            except DomainError as error:
                if error.code != 'provider_not_found':
                    with self.db.transaction() as tx:
                        tx.execute('UPDATE account_deletions SET provider_error=? WHERE user_id=?', (error.code, user_id))
                    raise
        with self.db.transaction() as tx:
            media = tx.all('SELECT storage_key FROM media_objects WHERE user_id=?', (user_id,))
            if media:
                storage = PrivateMedia()
                for item in media:
                    storage.delete(item['storage_key'])
            # Delete private catalog rows before their ownership marker can disappear.
            private = tx.all("SELECT content_id FROM content_ownership WHERE user_id=? AND kind='recipe'", (user_id,))
            tx.execute('DELETE FROM cooking_sessions WHERE user_id=?', (user_id,))
            for row in private:
                tx.execute('DELETE FROM recipes WHERE id=?', (row['content_id'],))
            private_foods = tx.all("SELECT o.content_id,o.household_id,h.owner_id,f.data FROM content_ownership o JOIN foods f ON f.id=o.content_id LEFT JOIN households h ON h.id=o.household_id WHERE o.kind='food' AND o.user_id=?", (user_id,))
            # Preserve food already shared to another household when its creator deletes their account.
            retained = set()
            for food in private_foods:
                target = {'id': food['household_id'], 'owner_id': food['owner_id']} if food['owner_id'] and food['owner_id'] != user_id else tx.one("SELECT h.id,h.owner_id FROM households h WHERE h.owner_id<>? AND (h.id IN (SELECT household_id FROM inventory_batches WHERE food_id=?) OR h.id IN (SELECT household_id FROM shopping_items WHERE food_id=?)) ORDER BY h.id LIMIT 1", (user_id, food['content_id'], food['content_id']))
                if target:
                    value = decode(food['data'])
                    value['photo_id'] = None
                    tx.execute('UPDATE foods SET data=? WHERE id=?', (encode(value), food['content_id']))
                    tx.execute("UPDATE content_ownership SET user_id=?,household_id=? WHERE kind='food' AND content_id=?", (target['owner_id'], target['id'], food['content_id']))
                    retained.add(food['content_id'])
            tx.execute('DELETE FROM households WHERE owner_id=?', (user_id,))
            for food in private_foods:
                if food['content_id'] not in retained:
                    tx.execute('DELETE FROM foods WHERE id=?', (food['content_id'],))
            tx.execute('UPDATE inventory_events SET actor_id=NULL WHERE actor_id=?', (user_id,))
            tx.execute('UPDATE shopping_items SET created_by=NULL WHERE created_by=?', (user_id,))
            tx.execute('UPDATE leftover_events SET actor_id=NULL WHERE actor_id=?', (user_id,))
            tx.execute('DELETE FROM identity_tokens WHERE user_id=?', (user_id,))
            tx.execute('UPDATE household_invitations SET accepted_by=NULL WHERE accepted_by=?', (user_id,))
            tx.execute('DELETE FROM profiles WHERE user_id=?', (user_id,))
            if not tx.postgres:
                tx.execute('DELETE FROM dev_accounts WHERE user_id=?', (user_id,))
            tx.execute("UPDATE account_deletions SET status='completed',provider_error=NULL,completed_at=? WHERE user_id=?", (now(), user_id))
        return {'deleted': True}

    def retry_account_deletions(self):
        with self.db.transaction() as tx:
            rows = tx.all("SELECT user_id FROM account_deletions WHERE status='pending' ORDER BY requested_at LIMIT 10")
        for row in rows:
            try:
                self.delete_account(row['user_id'], retry=True)
            except (DomainError, OSError):
                continue
        return len(rows)
