"""Household membership, explicit constraint sharing and profile preferences."""
import hashlib
import secrets
from datetime import datetime, timedelta, timezone

from .auth import now
from .engine import active_rules
from .errors import DomainError
from .storage import decode, encode
from .validation import choice, integer, new_id, text, valid_uuid

SHARING_CONSENT = "household-constraints-1"


class HouseholdService:
    def _member(self, tx, user_id, household_id=None, write=False, owner=False):
        profile = self._profile(tx, user_id)
        household_id = household_id or profile["household_id"]
        row = tx.one("SELECT * FROM household_members WHERE household_id=? AND user_id=?", (household_id, user_id))
        if not row or (write and row["role"] == "viewer") or (owner and row["role"] != "owner"):
            raise DomainError("forbidden", 403)
        return row

    def households(self, user_id):
        with self.db.transaction() as tx:
            profile = self._profile(tx, user_id)
            homes = tx.all("SELECT h.*,m.role,s.name FROM households h JOIN household_members m ON m.household_id=h.id LEFT JOIN household_settings s ON s.household_id=h.id WHERE m.user_id=?", (user_id,))
            members = tx.all("SELECT m.user_id,m.role,p.name,COALESCE(c.share_constraints,0) AS share_constraints FROM household_members m JOIN profiles p ON p.user_id=m.user_id LEFT JOIN member_permissions c ON c.user_id=m.user_id AND c.household_id=m.household_id WHERE m.household_id=?", (profile["household_id"],))
            owner = any(h['id'] == profile['household_id'] and h['role'] == 'owner' for h in homes)
            invitations = tx.all("SELECT id,role,expires_at FROM household_invitations WHERE household_id=? AND accepted_at IS NULL AND revoked_at IS NULL AND expires_at>? ORDER BY created_at DESC LIMIT 100", (profile['household_id'], now())) if owner else []
            return {"items": homes, "current_id": profile["household_id"], "members": members, "invitations": invitations, "consent_version": SHARING_CONSENT}

    def household_action(self, user_id, data, key):
        household_id = self._household(user_id)
        with self.db.transaction(household_id) as tx:
            def change():
                self._member(tx, user_id, household_id)
                action = data.get("action")
                if action == "invite":
                    self._member(tx, user_id, household_id, owner=True)
                    role = choice(data.get("role", "member"), {"member", "viewer"})
                    token, identifier, stamp = secrets.token_urlsafe(32), new_id(), now()
                    expires = (datetime.now(timezone.utc) + timedelta(days=7)).isoformat()
                    tx.execute("INSERT INTO household_invitations VALUES (?,?,?,?,?,?,?,?,?,?)", (identifier, household_id, user_id, hashlib.sha256(token.encode()).hexdigest(), role, expires, None, None, None, stamp))
                    return {"id": identifier, "token": token, "expires_at": expires, "role": role}
                if action == "accept":
                    token = text(data.get("token"), maximum=100)
                    invite = tx.one("SELECT * FROM household_invitations WHERE token_hash=?", (hashlib.sha256(token.encode()).hexdigest(),))
                    if not invite or invite["revoked_at"] or invite["accepted_at"] or invite["expires_at"] <= now():
                        raise DomainError("invitation_unavailable", 409)
                    target = invite["household_id"]
                    if tx.postgres:
                        tx.execute("SELECT id FROM households WHERE id=? FOR UPDATE", (target,))
                    owner = tx.one("SELECT owner_id FROM households WHERE id=?", (target,))
                    if not owner or tx.one("SELECT 1 FROM account_deletions WHERE user_id=? AND status IN ('pending','completed')", (owner["owner_id"],)):
                        raise DomainError("invitation_unavailable", 409)
                    if tx.one("SELECT COUNT(*) AS n FROM household_members WHERE household_id=?", (target,))["n"] >= 20:
                        raise DomainError("household_full", 409)
                    if tx.one("SELECT 1 FROM household_members WHERE household_id=? AND user_id=?", (target, user_id)):
                        raise DomainError("already_member", 409)
                    changed = tx.execute("UPDATE household_invitations SET accepted_by=?,accepted_at=? WHERE id=? AND accepted_at IS NULL AND revoked_at IS NULL", (user_id, now(), invite["id"]))
                    if changed.rowcount != 1:
                        raise DomainError("invitation_unavailable", 409)
                    tx.execute("INSERT INTO household_members VALUES (?,?,?)", (target, user_id, invite["role"]))
                    tx.execute("UPDATE profiles SET household_id=?,version=version+1 WHERE user_id=?", (target, user_id))
                    return {"household_id": target}
                if action == "switch":
                    target = valid_uuid(data.get("household_id"))
                    self._member(tx, user_id, target)
                    tx.execute("UPDATE profiles SET household_id=?,version=version+1 WHERE user_id=?", (target, user_id))
                    return {"household_id": target}
                if action == "share_constraints":
                    enabled = data.get("enabled")
                    if type(enabled) is not bool or (enabled and data.get("consent_version") != SHARING_CONSENT):
                        raise DomainError("sharing_consent_required", 422)
                    tx.execute("INSERT INTO member_permissions VALUES (?,?,?,?,?) ON CONFLICT(household_id,user_id) DO UPDATE SET share_constraints=excluded.share_constraints,consent_version=excluded.consent_version,updated_at=excluded.updated_at", (household_id, user_id, int(enabled), SHARING_CONSENT if enabled else None, now()))
                    tx.execute("UPDATE profiles SET version=version+1 WHERE user_id=?", (user_id,))
                    return {"share_constraints": enabled}
                if action == "leave":
                    member = self._member(tx, user_id, household_id)
                    if member["role"] == "owner":
                        raise DomainError("ownership_transfer_required", 409)
                    target = data.get("fallback_household_id")
                    if target is None:
                        fallback = tx.one("SELECT household_id FROM household_members WHERE user_id=? AND household_id<>? ORDER BY household_id LIMIT 1", (user_id, household_id))
                        if fallback:
                            target = fallback['household_id']
                        else:
                            target = new_id()
                            tx.execute("INSERT INTO households VALUES (?,?,?,?)", (target, user_id, 1, now()))
                            tx.execute("INSERT INTO household_members VALUES (?,?,?)", (target, user_id, 'owner'))
                    target = valid_uuid(target)
                    if target == household_id:
                        raise DomainError("invalid_household", 422)
                    self._member(tx, user_id, target)
                    tx.execute(
                        "DELETE FROM dinners WHERE household_id=? AND host_user_id=?",
                        (household_id, user_id),
                    )
                    tx.execute("DELETE FROM household_members WHERE household_id=? AND user_id=?", (household_id, user_id))
                    tx.execute("DELETE FROM member_permissions WHERE household_id=? AND user_id=?", (household_id, user_id))
                    tx.execute("UPDATE profiles SET household_id=?,version=version+1 WHERE user_id=?", (target, user_id))
                    return {"household_id": target}
                self._member(tx, user_id, household_id, owner=True)
                if action == "rename":
                    name = text(data.get("name"), maximum=80)
                    tx.execute("INSERT INTO household_settings VALUES (?,?,1,?) ON CONFLICT(household_id) DO UPDATE SET name=excluded.name,version=household_settings.version+1,updated_at=excluded.updated_at", (household_id, name, now()))
                elif action == "revoke":
                    tx.execute("UPDATE household_invitations SET revoked_at=? WHERE id=? AND household_id=?", (now(), valid_uuid(data.get("invitation_id")), household_id))
                elif action in {"role", "transfer"}:
                    target = valid_uuid(data.get("user_id"))
                    if target == user_id:
                        raise DomainError("invalid_member", 422)
                    self._member(tx, target, household_id)
                    if action == "transfer":
                        tx.execute("UPDATE household_members SET role='member' WHERE household_id=? AND user_id=?", (household_id, user_id))
                        tx.execute("UPDATE households SET owner_id=? WHERE id=?", (target, household_id))
                        role = "owner"
                    else:
                        role = choice(data.get("role"), {"member", "viewer"})
                    tx.execute("UPDATE household_members SET role=? WHERE household_id=? AND user_id=?", (role, household_id, target))
                else:
                    raise DomainError("invalid_action", 422)
                return {"updated": True}
            return self._once(tx, user_id, key, "household", data, change)

    def _diners(self, tx, user_id, participants, profile, versions, today):
        if participants is None:
            participants = [user_id]
        if not isinstance(participants, list) or not 1 <= len(participants) <= 20 or any(not isinstance(p,str) for p in participants) or len(set(participants)) != len(participants):
            raise DomainError("invalid_participants", 422)
        settings = {**profile["settings"], "diets": [], "allergies": [], "intolerances": [], "never_suggest": []}
        rules, rule_versions, snapshots = [], {}, {}
        for participant in sorted(participants):
            if tx.postgres:
                tx.execute("SELECT user_id FROM profiles WHERE user_id=? FOR SHARE", (participant,))
            valid_uuid(participant)
            self._member(tx, participant, profile["household_id"])
            if participant != user_id:
                permission = tx.one("SELECT share_constraints FROM member_permissions WHERE household_id=? AND user_id=?", (profile["household_id"], participant))
                if not permission or not permission["share_constraints"]:
                    raise DomainError("participant_consent_required", 409)
            diner = self._profile(tx, participant)
            diner_rules, diner_versions = active_rules(diner["settings"]["diets"], versions, today)
            rules.extend(diner_rules)
            rule_versions.update(diner_versions)
            snapshots[participant] = diner["version"]
            for field in ("allergies", "intolerances", "never_suggest"):
                settings[field] = sorted(set(settings[field]) | set(diner["settings"].get(field, [])))
        return settings, rules, rule_versions, snapshots

    def preferences(self, user_id, data=None, key=None):
        with self.db.transaction() as tx:
            self._profile(tx, user_id)
            row = tx.one("SELECT * FROM user_preferences WHERE user_id=?", (user_id,))
            if data is None:
                return {"data": decode(row["data"]) if row else {}, "version": row["version"] if row else 0}
            def save():
                if data.get("expected_version") != (row["version"] if row else 0):
                    raise DomainError("stale_preferences", 409)
                value = data.get("data", {})
                reserved = {'favorite_foods', 'habit_targets', 'habit_log'}
                if not isinstance(value, dict) or set(value) - {"goals", "cuisines", "skill", "max_minutes", "learning", "analytics", "ai_consent", "budget", "seasonal"} - reserved:
                    raise DomainError("invalid_preferences", 422)
                previous = decode(row['data']) if row else {}
                value = dict(value)
                for field in reserved:
                    if field in value and value[field] != previous.get(field):
                        raise DomainError('invalid_preferences', 422)
                    if field in previous:
                        value[field] = previous[field]
                for name in ("learning", "analytics", "ai_consent", "seasonal"):
                    if name in value and type(value[name]) is not bool:
                        raise DomainError("invalid_preferences", 422)
                if value.get('ai_consent') is False:
                    tx.execute("UPDATE processing_jobs SET status='cancelled',completed_at=?,version=version+1 WHERE user_id=? AND status IN ('queued','processing')", (now(), user_id))
                for name in ("goals", "cuisines"):
                    if name in value:
                        if not isinstance(value[name], list) or len(value[name]) > 20:
                            raise DomainError("invalid_preferences", 422)
                        value[name] = [text(v, maximum=60) for v in value[name]]
                if "max_minutes" in value:
                    integer(value["max_minutes"], minimum=5, maximum=240)
                if "skill" in value:
                    choice(value["skill"], {"beginner", "confident", "advanced"})
                if "budget" in value:
                    choice(value["budget"], {"any", "low", "medium"})
                version = (row["version"] if row else 0) + 1
                tx.execute("INSERT INTO user_preferences VALUES (?,?,?,?) ON CONFLICT(user_id) DO UPDATE SET data=excluded.data,version=excluded.version,updated_at=excluded.updated_at", (user_id, encode(value), version, now()))
                return {"data": value, "version": version}
            return self._once(tx, user_id, key, "preferences", data, save)
