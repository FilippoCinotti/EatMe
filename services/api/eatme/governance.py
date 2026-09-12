"""Independent editorial review, traceable evidence and strongly matched recalls."""
import os
from urllib.parse import urlsplit

from .auth import now
from .catalog import ALLERGENS
from .errors import DomainError
from .storage import decode, encode
from .validation import choice, integer, new_id, text, valid_date, valid_uuid

KINDS = {'food', 'recipe', 'diet', 'evidence', 'recall', 'expiry', 'alias'}


class GovernanceService:
    def _admin(self, tx, user_id, roles=None):
        self._profile(tx, user_id)
        row = tx.one('SELECT role FROM admin_roles WHERE user_id=?', (user_id,))
        role = row['role'] if row else ('superadmin' if user_id in os.getenv('ADMIN_USER_IDS', '').split(',') else None)
        if not role or (roles and role not in roles):
            raise DomainError('forbidden', 403)
        return role

    def admin_content(self, user_id):
        with self.db.transaction() as tx:
            role = self._admin(tx, user_id)
            items = tx.all('SELECT * FROM governed_content ORDER BY updated_at DESC LIMIT 500') if role != 'support' else []
            return {'role': role, 'items': [{**r, 'data': decode(r['data'])} for r in items], 'reports': tx.all('SELECT id,kind,subject_id,message,status,created_at FROM data_reports ORDER BY created_at DESC LIMIT 100'), 'flags': tx.all('SELECT * FROM feature_flags'), 'audit': tx.all('SELECT id,actor_id,action,subject_id,created_at FROM audit_events ORDER BY created_at DESC LIMIT 100') if role in {'admin', 'superadmin'} else []}

    def admin_action(self, user_id, data, key):
        with self.db.transaction() as tx:
            role = self._admin(tx, user_id)
            def action():
                command, stamp = data.get('action'), now()
                identifier = data.get('id') or new_id()
                if command == 'role':
                    self._admin(tx, user_id, {'superadmin'})
                    target = valid_uuid(data.get('user_id'))
                    if target == user_id:
                        raise DomainError('cannot_change_own_role', 409)
                    self._profile(tx, target)
                    assigned = choice(data.get('role'), {'support', 'editor', 'reviewer', 'admin', 'superadmin', 'none'})
                    if assigned == 'none':
                        tx.execute('DELETE FROM admin_roles WHERE user_id=?', (target,))
                    else:
                        tx.execute('INSERT INTO admin_roles VALUES (?,?,?) ON CONFLICT(user_id) DO UPDATE SET role=excluded.role,updated_at=excluded.updated_at', (target, assigned, stamp))
                elif command == 'flag':
                    self._admin(tx, user_id, {'admin', 'superadmin'})
                    name = choice(data.get('name'), {'ai_scan', 'ai_recipe', 'receipt_scan', 'barcode_scan', 'subscriptions'})
                    if type(data.get('enabled')) is not bool:
                        raise DomainError('invalid_flag', 422)
                    tx.execute('INSERT INTO feature_flags VALUES (?,?,?) ON CONFLICT(name) DO UPDATE SET enabled=excluded.enabled,updated_at=excluded.updated_at', (name, int(data['enabled']), stamp))
                elif command == 'resolve_report':
                    status = choice(data.get('status'), {'OPEN', 'INVESTIGATING', 'RESOLVED', 'REJECTED'})
                    tx.execute('UPDATE data_reports SET status=?,updated_at=? WHERE id=?', (status, stamp, valid_uuid(identifier)))
                elif command == 'draft':
                    self._admin(tx, user_id, {'editor', 'reviewer', 'admin', 'superadmin'})
                    kind, subject = choice(data.get('kind'), KINDS), valid_uuid(data.get('subject_id') or new_id())
                    value = data.get('data')
                    if not isinstance(value, dict) or len(encode(value)) > 100000:
                        raise DomainError('invalid_content', 422)
                    if tx.postgres:
                        tx.execute('SELECT pg_advisory_xact_lock(hashtextextended(?,0))', ('content:' + kind + subject,))
                    revision = tx.one('SELECT COALESCE(MAX(revision),0) AS n FROM governed_content WHERE kind=? AND subject_id=?', (kind, subject))['n'] + 1
                    tx.execute('INSERT INTO governed_content VALUES (?,?,?,?,?,?,?,?,?,?,?)', (identifier, kind, subject, revision, 'DRAFT', encode(value), user_id, None, None, stamp, stamp))
                elif command in {'submit', 'publish', 'deprecate'}:
                    row = tx.one('SELECT * FROM governed_content WHERE id=?' + (' FOR UPDATE' if tx.postgres else ''), (valid_uuid(identifier),))
                    if not row:
                        raise DomainError('content_not_found', 404)
                    if data.get('expected_status') != row['status']:
                        raise DomainError('stale_content', 409)
                    if command == 'submit':
                        self._admin(tx, user_id, {'editor', 'reviewer', 'admin', 'superadmin'})
                        if row['status'] != 'DRAFT':
                            raise DomainError('invalid_review_transition', 409)
                        self._validate_publication(tx, row)
                        status = 'IN_REVIEW'
                    elif command == 'publish':
                        self._admin(tx, user_id, {'reviewer', 'admin', 'superadmin'})
                        if row['status'] != 'IN_REVIEW' or row['created_by'] == user_id:
                            raise DomainError('independent_review_required', 409)
                        if tx.postgres:
                            tx.execute('SELECT pg_advisory_xact_lock(hashtextextended(?,0))', ('content:' + row['kind'] + row['subject_id'],))
                        latest = tx.one("SELECT MAX(revision) AS revision FROM governed_content WHERE kind=? AND subject_id=? AND status='PUBLISHED'", (row['kind'], row['subject_id']))
                        if latest['revision'] is not None and latest['revision'] >= row['revision']:
                            raise DomainError('newer_revision_published', 409)
                        self._validate_publication(tx, row)
                        self._publish(tx, row)
                        tx.execute("UPDATE governed_content SET status='DEPRECATED',updated_at=? WHERE kind=? AND subject_id=? AND status='PUBLISHED'", (stamp, row['kind'], row['subject_id']))
                        status = 'PUBLISHED'
                    else:
                        self._admin(tx, user_id, {'reviewer', 'admin', 'superadmin'})
                        if row['status'] != 'PUBLISHED':
                            raise DomainError('invalid_review_transition', 409)
                        if row['kind'] == 'diet':
                            tx.execute("UPDATE diet_versions SET status='DEPRECATED' WHERE diet_id=?", (row['subject_id'],))
                        status = 'DEPRECATED'
                    changed = tx.execute('UPDATE governed_content SET status=?,reviewed_by=?,reviewed_at=?,updated_at=? WHERE id=? AND status=?', (status, user_id if command == 'publish' else row['reviewed_by'], stamp if command == 'publish' else row['reviewed_at'], stamp, identifier, row['status']))
                    if changed.rowcount != 1:
                        raise DomainError('stale_content', 409)
                else:
                    raise DomainError('invalid_action', 422)
                tx.execute('INSERT INTO audit_events VALUES (?,?,?,?,?,?)', (new_id(), user_id, command, identifier, stamp, encode({'role': role, 'kind': data.get('kind')})))
                return {'id': identifier, 'updated': True}
            return self._once(tx, user_id, key, 'admin', data, action)

    def _validate_publication(self, tx, row):
        value, kind = decode(row['data']), row['kind']
        if kind == 'food':
            for lang in ('en', 'it'):
                text(value.get('name', {}).get(lang), maximum=160)
            choice(value.get('unit'), {'g', 'ml', 'pcs'})
            text(value.get('group'), maximum=60)
            choice(value.get('ingredient_status'), {'known', 'unknown'})
            for field in ('allergens', 'may_contain'):
                if not isinstance(value.get(field), list) or any(a not in ALLERGENS for a in value[field]):
                    raise DomainError('invalid_allergen', 422)
            if value.get('intolerances', []) not in ([], ['lactose']):
                raise DomainError('invalid_intolerance', 422)
            if value.get('nutrition'):
                nutrition = value['nutrition']
                choice(nutrition.get('basis'), {'100g', '100ml'})
                self._https(nutrition.get('source_url'))
                if not isinstance(nutrition.get('values'), dict):
                    raise DomainError('invalid_nutrition', 422)
                from .validation import decimal
                units = {'energy': 'kcal', 'energy_kj': 'kJ', 'protein': 'g', 'carbohydrates': 'g', 'fat': 'g', 'saturated_fat': 'g', 'sugars': 'g', 'fiber': 'g', 'salt': 'g', 'sodium': 'mg'}
                for name, nutrient in nutrition['values'].items():
                    if name not in units or not isinstance(nutrient, dict) or nutrient.get('unit') != units[name]:
                        raise DomainError('invalid_nutrition', 422)
                    decimal(nutrient.get('value'), maximum=100000)
                if not nutrition['values']:
                    raise DomainError('invalid_nutrition', 422)
        elif kind == 'recipe':
            self._validate_recipe(value, self._catalog(tx)[0])
        elif kind == 'diet':
            text(value.get('slug'), maximum=80)
            if type(value.get('medical')) is not bool:
                raise DomainError('invalid_diet', 422)
            for lang in ('en', 'it'):
                text(value.get('name', {}).get(lang), maximum=120)
            if not valid_date(value.get('effective_from')) or not valid_date(value.get('review_date')):
                raise DomainError('review_date_required', 422)
            if value.get('effective_until') and valid_date(value['effective_until']) <= value['effective_from']:
                raise DomainError('invalid_effective_dates', 422)
            refs = value.get('evidence_references')
            if not isinstance(refs, list) or not refs:
                raise DomainError('approved_evidence_required', 422)
            for ref in refs:
                evidence = tx.one("SELECT data FROM governed_content WHERE subject_id=? AND kind='evidence' AND status='PUBLISHED'", (valid_uuid(ref),))
                if not evidence or decode(evidence['data']).get('review_due', '') < self.today({'timezone': 'UTC'}).isoformat():
                    raise DomainError('approved_evidence_required', 422)
            rules = value.get('rules')
            if not isinstance(rules, list) or len(rules) > 100:
                raise DomainError('invalid_rules', 422)
            for rule in rules:
                choice(rule.get('type'), {'ALLOW', 'EXCLUDE', 'PREFER'})
                if type(rule.get('hard_constraint')) is not bool:
                    raise DomainError('invalid_rules', 422)
                for food_id in rule.get('food_ids', []):
                    if not tx.one('SELECT 1 FROM foods WHERE id=?', (valid_uuid(food_id),)):
                        raise DomainError('unknown_ingredient', 422)
            if value['medical']:
                for field in ('clinical_limitations', 'reviewer_qualification', 'context'):
                    text(value.get(field), maximum=4000)
        elif kind == 'evidence':
            for field in ('title', 'publisher', 'claim', 'jurisdiction'):
                text(value.get(field), maximum=4000)
            choice(value.get('strength'), {'guideline', 'systematic_review', 'trial', 'observational', 'expert_opinion'})
            if not valid_date(value.get('published_date')) or not valid_date(value.get('review_due')):
                raise DomainError('invalid_date', 422)
            if value['published_date'] > self.today({'timezone': 'UTC'}).isoformat() or value['review_due'] < self.today({'timezone': 'UTC'}).isoformat():
                raise DomainError('evidence_review_expired', 422)
            self._https(value.get('url'))
        elif kind == 'recall':
            from .providers import barcode
            barcode(value.get('barcode'))
            text(value.get('lot'), maximum=100)
            text(value.get('reason'), maximum=2000)
            self._https(value.get('url'))
            if not valid_date(value.get('published_date')):
                raise DomainError('invalid_date', 422)
        elif kind == 'expiry':
            integer(value.get('days'), minimum=0, maximum=3650)
            choice(value.get('location'), {'fridge', 'freezer', 'pantry'})
            self._https(value.get('source_url'))
            valid_uuid(value.get('food_id'))
        elif kind == 'alias':
            text(value.get('alias'), maximum=120)
            choice(value.get('locale'), {'en', 'it'})
            if not tx.one('SELECT 1 FROM foods WHERE id=?', (valid_uuid(value.get('food_id')),)):
                raise DomainError('food_not_found', 404)

    def _https(self, url):
        value = text(url, maximum=2000)
        parsed = urlsplit(value)
        if parsed.scheme != 'https' or not parsed.hostname or parsed.username or parsed.password:
            raise DomainError('invalid_source_url', 422)

    def _publish(self, tx, row):
        value, kind, identifier = decode(row['data']), row['kind'], row['subject_id']
        if kind in {'food', 'recipe'}:
            value.update(id=identifier, is_demo=False, provenance='reviewed-catalog')
            table = 'foods' if kind == 'food' else 'recipes'
            if kind == 'recipe':
                value = {**self._validate_recipe(value, self._catalog(tx)[0]), 'id': identifier, 'is_demo': False}
            tx.execute(f'INSERT INTO {table} VALUES (?,?) ON CONFLICT(id) DO UPDATE SET data=excluded.data', (identifier, encode(value)))
        elif kind == 'diet':
            value.update(id=identifier, status='PUBLISHED', is_demo=False)
            tx.execute('INSERT INTO diet_definitions VALUES (?,?,?) ON CONFLICT(id) DO UPDATE SET slug=excluded.slug,data=excluded.data', (identifier, value['slug'], encode(value)))
            version = tx.one('SELECT COALESCE(MAX(version),0) AS n FROM diet_versions WHERE diet_id=?', (identifier,))['n'] + 1
            tx.execute('INSERT INTO diet_versions VALUES (?,?,?,?,?,?,?)', (new_id(), identifier, version, 'PUBLISHED', value['effective_from'], value.get('effective_until'), encode(value['rules'])))
        elif kind == 'alias':
            tx.execute('INSERT INTO food_aliases VALUES (?,?,?,?) ON CONFLICT(alias,locale,food_id) DO UPDATE SET source=excluded.source', (value['alias'].casefold(), value['locale'], value['food_id'], row['id']))

    def evidence(self, user_id, query=''):
        self._household(user_id)
        query = text(query, maximum=120, empty=True).casefold()
        with self.db.transaction() as tx:
            today = self.today(self._profile(tx, user_id)['settings']).isoformat()
            items = [{**decode(r['data']), 'id': r['subject_id'], 'revision': r['revision']} for r in tx.all("SELECT * FROM governed_content WHERE kind='evidence' AND status='PUBLISHED'")]
            items = [v for v in items if v['review_due'] >= today and (not query or query in encode(v).casefold())]
            return {'items': items[:30], 'answer_status': 'approved_sources' if items else 'insufficient_approved_evidence', 'generated_answer': None}

    def recalls(self, user_id):
        home = self._household(user_id)
        with self.db.transaction() as tx:
            recalls = [decode(r['data']) for r in tx.all("SELECT data FROM governed_content WHERE kind='recall' AND status='PUBLISHED'")]
            items = []
            for row in tx.all('SELECT b.id,m.data FROM inventory_batches b JOIN inventory_metadata m ON m.batch_id=b.id WHERE b.household_id=? AND b.quantity_milli>0', (home,)):
                metadata = decode(row['data'])
                for recall in recalls:
                    if metadata.get('barcode') == recall['barcode'] and metadata.get('lot') == recall['lot']:
                        items.append({'batch_id': row['id'], 'recall': recall, 'match': 'barcode_and_lot'})
            return {'items': items}

    def report(self, user_id, data, key):
        with self.db.transaction() as tx:
            self._profile(tx, user_id)
            def save():
                identifier, stamp = new_id(), now()
                tx.execute('INSERT INTO data_reports VALUES (?,?,?,?,?,?,?,?)', (identifier, user_id, choice(data.get('kind'), KINDS | {'app', 'product'}), text(data.get('subject_id'), maximum=100), text(data.get('message'), maximum=2000), 'OPEN', stamp, stamp))
                return {'id': identifier}
            return self._once(tx, user_id, key, 'report', data, save)
