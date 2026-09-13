"""Household food entry, personal favorites and explicitly self-reported habits."""
import base64
from datetime import timedelta

from .auth import now
from .engine import amount_milli, quantity
from .errors import DomainError
from .intelligence import PrivateMedia
from .storage import decode, encode
from .validation import choice, integer, new_id, text, valid_date, valid_uuid

GOALS = {'eat_better', 'waste_less', 'follow_diet', 'more_vegetables', 'less_processed', 'maintain_weight'}
GROUPS = {'vegetable', 'fruit', 'legume', 'grain', 'oil', 'dairy', 'meat', 'egg', 'fish', 'nuts', 'seed', 'herb', 'other', 'honey', 'packaged'}


class ReferenceFeaturesService:
    def food_action(self, user_id, data, key):
        home = self._household(user_id, write=data.get('action') == 'create')
        with self.db.transaction(home) as tx:
            def change():
                self._member(tx, user_id, home, write=data.get('action') == 'create')
                if data.get('action') == 'favorite':
                    food_id = valid_uuid(data.get('food_id'))
                    if food_id not in self._catalog(tx, user_id)[0]:
                        raise DomainError('invalid_food', 404)
                    enabled = data.get('enabled')
                    if type(enabled) is not bool:
                        raise DomainError('invalid_favorite', 422)
                    row = tx.one('SELECT * FROM user_preferences WHERE user_id=?', (user_id,))
                    prefs = decode(row['data']) if row else {}
                    favorites = set(prefs.get('favorite_foods', []))
                    if enabled:
                        favorites.add(food_id)
                    else:
                        favorites.discard(food_id)
                    if len(favorites) > 500:
                        raise DomainError('favorite_limit', 422)
                    prefs['favorite_foods'] = sorted(favorites)
                    self._save_reference_preferences(tx, user_id, prefs, row)
                    return {'favorite': enabled, 'food_id': food_id}
                if data.get('action') != 'create':
                    raise DomainError('invalid_action', 422)
                name = text(data.get('name'), maximum=100)
                unit = choice(data.get('unit'), {'g', 'ml', 'pcs'})
                group = choice(data.get('group'), GROUPS)
                amount = amount_milli(data.get('quantity'))
                if unit == 'pcs' and amount % 1000:
                    raise DomainError('whole_units_required', 422)
                location = choice(data.get('location', 'fridge'), {'fridge', 'freezer', 'pantry'})
                expiry = valid_date(data.get('expiry_date'))
                kind = choice(data.get('expiry_kind', 'unknown'), {'unknown', 'use_by', 'best_before', 'estimated'})
                if bool(expiry) != (kind != 'unknown'):
                    raise DomainError('expiry_type_required', 422)
                notes = text(data.get('notes', ''), maximum=500, empty=True)
                if tx.one("SELECT COUNT(*) AS n FROM content_ownership WHERE household_id=? AND kind='food'", (home,))['n'] >= 500:
                    raise DomainError('custom_food_limit', 422)
                media_id = data.get('media_id')
                if media_id:
                    media = tx.one("SELECT * FROM media_objects WHERE id=? AND user_id=? AND kind='food'", (valid_uuid(media_id), user_id))
                    if not media or (media['expires_at'] and media['expires_at'] < now()):
                        raise DomainError('media_expired', 409)
                    tx.execute('UPDATE media_objects SET expires_at=NULL WHERE id=?', (media_id,))
                food_id, batch_id, stamp = new_id(), new_id(), now()
                food = {'id': food_id, 'name': {'en': name, 'it': name}, 'unit': unit, 'group': group,
                        'ingredient_status': 'unknown', 'allergens': [], 'may_contain': [], 'intolerances': [],
                        'nutrition': None, 'provenance': 'household-entry', 'is_demo': False, 'photo_id': media_id}
                tx.execute('INSERT INTO foods VALUES (?,?)', (food_id, encode(food)))
                tx.execute("INSERT INTO content_ownership VALUES ('food',?,?,?)", (food_id, user_id, home))
                tx.execute('INSERT INTO inventory_batches VALUES (?,?,?,?,?,?,?,?,?,?,?,?)', (batch_id, home, food_id, amount, location, expiry, kind, None, 'custom-manual', 1, stamp, stamp))
                tx.execute('INSERT INTO inventory_metadata VALUES (?,?,?)', (batch_id, encode({'notes': notes, 'ingredients_unreviewed': True}), stamp))
                self._event(tx, user_id, home, batch_id, 'created', amount)
                return {'food': food, 'id': batch_id, 'version': 1}
            return self._once(tx, user_id, key, 'food_action', data, change)

    def food_photo(self, user_id, food_id):
        with self.db.transaction() as tx:
            self._profile(tx, user_id)
            food = self._catalog(tx, user_id)[0].get(valid_uuid(food_id))
            if not food:
                raise DomainError('invalid_food', 404)
            media_id = food.get('photo_id')
            media = tx.one('SELECT * FROM media_objects WHERE id=?', (media_id,)) if media_id else None
            if not media or (media['expires_at'] and media['expires_at'] < now()):
                return {'base64': None}
            return {'base64': base64.b64encode(PrivateMedia().read(media['storage_key'])).decode(), 'mime_type': 'image/jpeg'}

    def _save_reference_preferences(self, tx, user_id, value, row):
        version = (row['version'] if row else 0) + 1
        if row:
            changed = tx.execute('UPDATE user_preferences SET data=?,version=?,updated_at=? WHERE user_id=? AND version=?', (encode(value), version, now(), user_id, row['version']))
            if changed.rowcount != 1:
                raise DomainError('stale_preferences', 409)
        else:
            changed = tx.execute('INSERT INTO user_preferences VALUES (?,?,?,?) ON CONFLICT DO NOTHING', (user_id, encode(value), version, now()))
            if changed.rowcount != 1:
                raise DomainError('stale_preferences', 409)
        return version

    def wellbeing(self, user_id):
        with self.db.transaction() as tx:
            profile = self._profile(tx, user_id)
            row = tx.one('SELECT * FROM user_preferences WHERE user_id=?', (user_id,))
            prefs = decode(row['data']) if row else {}
            today = self.today(profile['settings'])
            monday = today - timedelta(days=today.weekday())
            log = prefs.get('habit_log', {})
            goals = [{'id': goal, 'target': target, 'done_today': today.isoformat() in log.get(goal, []),
                      'completed_days': sum(monday.isoformat() <= day <= today.isoformat() for day in log.get(goal, []))}
                     for goal, target in prefs.get('habit_targets', {}).items()]
            return {'goals': goals, 'today': today.isoformat(), 'week_start': monday.isoformat(),
                    'version': row['version'] if row else 0, 'method': 'self_reported_days',
                    'primary_goal': profile['settings'].get('primary_goal'), 'nutrition_score': None}

    def wellbeing_action(self, user_id, data, key):
        home = self._household(user_id)
        with self.db.transaction(home) as tx:
            def change():
                profile = self._profile(tx, user_id)
                row = tx.one('SELECT * FROM user_preferences WHERE user_id=?', (user_id,))
                if data.get('expected_version') != (row['version'] if row else 0):
                    raise DomainError('stale_preferences', 409)
                prefs = decode(row['data']) if row else {}
                action = choice(data.get('action'), {'target', 'check_in', 'remove'})
                goal = choice(data.get('goal'), GOALS)
                targets, log = prefs.get('habit_targets', {}), prefs.get('habit_log', {})
                today = self.today(profile['settings'])
                if action == 'target':
                    targets[goal] = integer(data.get('target'), minimum=1, maximum=7)
                elif action == 'remove':
                    targets.pop(goal, None)
                    log.pop(goal, None)
                else:
                    if goal not in targets or type(data.get('completed')) is not bool:
                        raise DomainError('invalid_habit', 422)
                    days = set(log.get(goal, []))
                    if data['completed']:
                        days.add(today.isoformat())
                    else:
                        days.discard(today.isoformat())
                    log[goal] = sorted(day for day in days if day >= (today - timedelta(days=90)).isoformat())
                prefs.update(habit_targets=targets, habit_log=log)
                version = self._save_reference_preferences(tx, user_id, prefs, row)
                return {'updated': True, 'version': version}
            return self._once(tx, user_id, key, 'wellbeing', data, change)

    def household_activity(self, user_id):
        home = self._household(user_id)
        with self.db.transaction() as tx:
            self._member(tx, user_id, home)
            rows = tx.all('SELECT e.id,e.kind,e.delta_milli,e.created_at,e.batch_id,p.name AS actor_name,f.data AS food_data FROM inventory_events e LEFT JOIN profiles p ON p.user_id=e.actor_id LEFT JOIN inventory_batches b ON b.id=e.batch_id LEFT JOIN foods f ON f.id=b.food_id WHERE e.household_id=? ORDER BY e.created_at DESC,e.id DESC LIMIT 100', (home,))
            return {'items': [{k: v for k, v in row.items() if k not in {'food_data', 'delta_milli'}} | {
                'food_name': decode(row['food_data'])['name'] if row['food_data'] else {},
                'unit': decode(row['food_data'])['unit'] if row['food_data'] else None,
                'quantity': quantity(abs(row['delta_milli']))} for row in rows]}
