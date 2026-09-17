"""Dinner events, capability-link invitations and group Diet-Fit."""
from __future__ import annotations

import hashlib
import os
import secrets
from datetime import datetime, timedelta, timezone
from urllib.parse import quote
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from .auth import now
from .catalog import ALLERGENS, INTOLERANCES, SENSITIVITIES
from .engine import active_rules, batch_usable, compatibility, quantity, requirements
from .errors import DomainError
from .storage import decode, encode
from .validation import integer, new_id, text, valid_uuid


EATING_STYLES = {
    "omnivore",
    "balanced",
    "mediterranean",
    "vegetarian",
    "vegan",
    "pescatarian",
    "flexitarian",
    "plant-forward",
    "gluten-free",
}


def _utc(value: str, *, code: str = "invalid_start_time") -> datetime:
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
        if parsed.tzinfo is None:
            raise ValueError
        return parsed.astimezone(timezone.utc)
    except (AttributeError, TypeError, ValueError):
        raise DomainError(code, 422) from None


def _token_hash(token: str) -> str:
    if not isinstance(token, str) or not 32 <= len(token) <= 512:
        raise DomainError("invitation_unavailable", 404)
    return hashlib.sha256(token.encode()).hexdigest()


class DinnerService:
    def guest_rate_limit(self, scope: str, limit: int) -> None:
        window = int(datetime.now(timezone.utc).timestamp() // 60)
        key = hashlib.sha256(scope.encode()).hexdigest()
        with self.db.transaction() as tx:
            lock = " FOR UPDATE" if tx.postgres else ""
            row = tx.one(
                "SELECT window_start,requests FROM rate_limit_windows WHERE key_hash=?" + lock,
                (key,),
            )
            if not row or row["window_start"] != window:
                tx.execute(
                    "INSERT INTO rate_limit_windows VALUES (?,?,1) "
                    "ON CONFLICT(key_hash) DO UPDATE SET window_start=excluded.window_start,requests=1",
                    (key, window),
                )
            elif row["requests"] >= limit:
                raise DomainError("rate_limited", 429)
            else:
                tx.execute(
                    "UPDATE rate_limit_windows SET requests=requests+1 WHERE key_hash=?",
                    (key,),
                )
            if secrets.randbelow(100) == 0:
                tx.execute("DELETE FROM rate_limit_windows WHERE window_start<?", (window - 2,))

    def _invite_expiry(self, starts_at: str) -> str:
        try:
            hours = int(os.getenv("GUEST_INVITE_EXPIRY_HOURS_AFTER_EVENT", "24"))
        except ValueError:
            hours = 24
        hours = min(max(hours, 0), 720)
        return (_utc(starts_at) + timedelta(hours=hours)).isoformat()

    def _retention_cutoff(self) -> str:
        try:
            days = int(os.getenv("GUEST_TEMP_DATA_RETENTION_DAYS", "7"))
        except ValueError:
            days = 7
        days = min(max(days, 1), 90)
        return (datetime.now(timezone.utc) - timedelta(days=days)).isoformat()

    def _clean_temporary_guests(self, tx) -> None:
        tx.execute(
            "DELETE FROM dinner_participants WHERE kind='temporary_guest' AND dinner_id IN "
            "(SELECT id FROM dinners WHERE starts_at<?)",
            (self._retention_cutoff(),),
        )

    def cleanup_dinner_guests(self) -> int:
        with self.db.transaction() as tx:
            before = tx.one(
                "SELECT COUNT(*) AS n FROM dinner_participants WHERE kind='temporary_guest' "
                "AND dinner_id IN (SELECT id FROM dinners WHERE starts_at<?)",
                (self._retention_cutoff(),),
            )["n"]
            self._clean_temporary_guests(tx)
            return before

    def _dinner(self, tx, user_id: str, dinner_id: str) -> dict:
        row = tx.one(
            "SELECT * FROM dinners WHERE id=? AND household_id IN "
            "(SELECT household_id FROM household_members WHERE user_id=?)",
            (valid_uuid(dinner_id), user_id),
        )
        if not row:
            raise DomainError("dinner_not_found", 404)
        return row

    def _host_dinner(self, tx, user_id: str, dinner_id: str) -> dict:
        row = self._dinner(tx, user_id, dinner_id)
        if row["host_user_id"] != user_id:
            raise DomainError("forbidden", 403)
        return row

    def _public_invite(self, tx, token: str) -> dict:
        self._clean_temporary_guests(tx)
        row = tx.one(
            "SELECT i.*,d.title,d.starts_at,d.timezone,d.location,d.status AS dinner_status,"
            "d.household_id,d.host_user_id,p.kind,p.display_name,p.status AS participant_status,"
            "p.saved_guest_id,h.name AS host_name,r.data AS response_data,r.remembered_guest_id "
            "FROM dinner_invitations i JOIN dinners d ON d.id=i.dinner_id "
            "JOIN dinner_participants p ON p.id=i.participant_id "
            "JOIN profiles h ON h.user_id=d.host_user_id "
            "LEFT JOIN dinner_guest_responses r ON r.invitation_id=i.id WHERE i.token_hash=?",
            (_token_hash(token),),
        )
        if (
            not row
            or row["revoked_at"]
            or row["dinner_status"] != "planned"
            or _utc(row["expires_at"], code="invitation_unavailable") <= datetime.now(timezone.utc)
        ):
            raise DomainError("invitation_unavailable", 404)
        return row

    def _participant_view(self, row: dict, *, include_response: bool = False) -> dict:
        result = {
            "id": row["id"],
            "kind": row["kind"],
            "display_name": row["display_name"],
            "status": row["status"],
            "user_id": row.get("user_id"),
            "saved_guest_id": row.get("saved_guest_id"),
        }
        if include_response and row.get("response_data"):
            value = decode(row["response_data"])
            result["response"] = {
                "rsvp": value["rsvp"],
                "eating_style": value.get("eating_style"),
                "allergies": value["settings"].get("allergies", []),
                "intolerances": value["settings"].get("intolerances", []),
                "sensitivities": value["settings"].get("sensitivities", []),
                "avoidances": value["settings"].get("never_suggest", []),
                "note": value.get("note", ""),
                "remember_me": value.get("remember_me", False),
            }
        return result

    def _event_view(self, tx, user_id: str, row: dict, *, detail: bool = True) -> dict:
        data = decode(row["data"])
        result = {
            "id": row["id"],
            "title": row["title"],
            "starts_at": row["starts_at"],
            "timezone": row["timezone"],
            "location": row["location"],
            "status": row["status"],
            "version": row["version"],
            "host_user_id": row["host_user_id"],
            "menu": data.get("menu", []),
            "extra_portions": data.get("extra_portions", 0),
            "timeline": data.get("timeline", []),
            "meal_memory": data.get("meal_memory", False),
        }
        if not detail:
            return result
        participants = tx.all(
            "SELECT p.id,p.kind,p.user_id,p.saved_guest_id,p.display_name,p.status,r.data AS response_data "
            "FROM dinner_participants p LEFT JOIN dinner_invitations i ON i.participant_id=p.id "
            "LEFT JOIN dinner_guest_responses r ON r.invitation_id=i.id "
            "WHERE p.dinner_id=? ORDER BY p.created_at,p.id",
            (row["id"],),
        )
        invitations = tx.all(
            "SELECT i.id,i.participant_id,i.expires_at,i.revoked_at,i.rotated_at,i.created_at "
            "FROM dinner_invitations i WHERE i.dinner_id=? ORDER BY i.created_at",
            (row["id"],),
        )
        result["participants"] = [
            self._participant_view(item, include_response=row["host_user_id"] == user_id)
            for item in participants
        ]
        result["invitations"] = invitations
        result["servings"] = self._servings(participants, data.get("extra_portions", 0))
        result["diet_fit"] = self._menu_fit(tx, user_id, row, participants, result["menu"])
        return result

    @staticmethod
    def _servings(participants: list[dict], extra: int) -> int:
        attending = sum(
            item["status"] in {"host", "accepted", "responded"}
            for item in participants
        )
        return max(1, attending + extra)

    def dinners(self, user_id: str) -> dict:
        home = self._household(user_id)
        with self.db.transaction(home) as tx:
            self._clean_temporary_guests(tx)
            rows = tx.all(
                "SELECT DISTINCT d.* FROM dinners d LEFT JOIN dinner_participants p ON p.dinner_id=d.id "
                "WHERE d.household_id=? AND (d.host_user_id=? OR p.user_id=?) "
                "ORDER BY d.starts_at DESC LIMIT 100",
                (home, user_id, user_id),
            )
            return {"items": [self._event_view(tx, user_id, row, detail=False) for row in rows]}

    def dinner_saved_guests(self, user_id: str) -> dict:
        home = self._household(user_id)
        with self.db.transaction() as tx:
            return {
                "items": tx.all(
                    "SELECT id,display_name,consented_at,updated_at FROM dinner_saved_guests "
                    "WHERE household_id=? ORDER BY display_name,id",
                    (home,),
                )
            }

    def dinner(self, user_id: str, dinner_id: str) -> dict:
        with self.db.transaction() as tx:
            row = self._dinner(tx, user_id, dinner_id)
            return self._event_view(tx, user_id, row)

    def _validate_event(self, data: dict, existing: dict | None = None) -> dict:
        title = text(data.get("title", existing["title"] if existing else None), maximum=120)
        starts = _utc(data.get("starts_at", existing["starts_at"] if existing else None)).isoformat()
        timezone_name = data.get("timezone", existing["timezone"] if existing else "UTC")
        try:
            ZoneInfo(timezone_name)
        except (ZoneInfoNotFoundError, TypeError, ValueError):
            raise DomainError("invalid_timezone", 422) from None
        location = data.get("location", existing["location"] if existing else None)
        if location is not None:
            location = text(location, maximum=160, empty=True) or None
        return {"title": title, "starts_at": starts, "timezone": timezone_name, "location": location}

    def dinner_action(self, user_id: str, data: dict, key: str) -> dict:
        home = self._household(user_id, write=True)
        with self.db.transaction(home) as tx:
            def change():
                self._member(tx, user_id, home, write=True)
                action = data.get("action")
                if action == "create":
                    values = self._validate_event(data)
                    identifier, participant_id, stamp = new_id(), new_id(), now()
                    profile = self._profile(tx, user_id)
                    event_data = {"menu": [], "extra_portions": 0, "timeline": [], "meal_memory": False}
                    tx.execute(
                        "INSERT INTO dinners VALUES (?,?,?,?,?,?,?,?,?,?,?,?)",
                        (
                            identifier,
                            home,
                            user_id,
                            values["title"],
                            values["starts_at"],
                            values["timezone"],
                            values["location"],
                            "planned",
                            encode(event_data),
                            1,
                            stamp,
                            stamp,
                        ),
                    )
                    tx.execute(
                        "INSERT INTO dinner_participants VALUES (?,?,?,?,?,?,?,?,?)",
                        (participant_id, identifier, "host", user_id, None, profile["name"], "host", stamp, stamp),
                    )
                    return self._event_view(tx, user_id, tx.one("SELECT * FROM dinners WHERE id=?", (identifier,)))

                dinner = self._host_dinner(tx, user_id, data.get("id"))
                if dinner["version"] != data.get("expected_version"):
                    raise DomainError("stale_dinner", 409)
                if action == "delete":
                    tx.execute("DELETE FROM dinners WHERE id=?", (dinner["id"],))
                    return {"deleted": True}
                if action == "update":
                    values = self._validate_event(data, dinner)
                    tx.execute(
                        "UPDATE dinners SET title=?,starts_at=?,timezone=?,location=?,version=version+1,updated_at=? WHERE id=?",
                        (
                            values["title"],
                            values["starts_at"],
                            values["timezone"],
                            values["location"],
                            now(),
                            dinner["id"],
                        ),
                    )
                    tx.execute(
                        "UPDATE dinner_invitations SET expires_at=? WHERE dinner_id=? AND revoked_at IS NULL",
                        (self._invite_expiry(values["starts_at"]), dinner["id"]),
                    )
                elif action in {"cancel", "complete"}:
                    status = "cancelled" if action == "cancel" else "completed"
                    event_data = decode(dinner["data"])
                    if action == "complete":
                        remember = data.get("meal_memory", False)
                        if type(remember) is not bool:
                            raise DomainError("invalid_meal_memory", 422)
                        event_data["meal_memory"] = remember
                        if remember:
                            participants = tx.all(
                                "SELECT status FROM dinner_participants WHERE dinner_id=?",
                                (dinner["id"],),
                            )
                            memory = {
                                "title": dinner["title"],
                                "starts_at": dinner["starts_at"],
                                "menu": event_data.get("menu", []),
                                "servings": self._servings(participants, event_data.get("extra_portions", 0)),
                            }
                            tx.execute(
                                "INSERT INTO dinner_memories VALUES (?,?,?,?,?) "
                                "ON CONFLICT(dinner_id) DO UPDATE SET data=excluded.data",
                                (new_id(), dinner["id"], home, encode(memory), now()),
                            )
                    tx.execute(
                        "UPDATE dinners SET status=?,data=?,version=version+1,updated_at=? WHERE id=?",
                        (status, encode(event_data), now(), dinner["id"]),
                    )
                    tx.execute(
                        "UPDATE dinner_invitations SET revoked_at=COALESCE(revoked_at,?) WHERE dinner_id=?",
                        (now(), dinner["id"]),
                    )
                elif action == "add_participant":
                    self._add_participant(tx, user_id, dinner, data)
                    tx.execute(
                        "UPDATE dinners SET version=version+1,updated_at=? WHERE id=?",
                        (now(), dinner["id"]),
                    )
                elif action == "remove_participant":
                    participant = tx.one(
                        "SELECT * FROM dinner_participants WHERE id=? AND dinner_id=?",
                        (valid_uuid(data.get("participant_id")), dinner["id"]),
                    )
                    if not participant or participant["kind"] == "host":
                        raise DomainError("participant_not_found", 404)
                    tx.execute("DELETE FROM dinner_participants WHERE id=?", (participant["id"],))
                    tx.execute(
                        "UPDATE dinners SET version=version+1,updated_at=? WHERE id=?",
                        (now(), dinner["id"]),
                    )
                elif action == "update_participant":
                    participant = tx.one(
                        "SELECT * FROM dinner_participants WHERE id=? AND dinner_id=?",
                        (valid_uuid(data.get("participant_id")), dinner["id"]),
                    )
                    if not participant or participant["kind"] in {"host", "household_member"}:
                        raise DomainError("participant_not_found", 404)
                    display_name = text(data.get("display_name"), maximum=80)
                    tx.execute(
                        "UPDATE dinner_participants SET display_name=?,updated_at=? WHERE id=?",
                        (display_name, now(), participant["id"]),
                    )
                    if participant["saved_guest_id"]:
                        tx.execute(
                            "UPDATE dinner_saved_guests SET display_name=?,updated_at=? WHERE id=?",
                            (display_name, now(), participant["saved_guest_id"]),
                        )
                    tx.execute(
                        "UPDATE dinners SET version=version+1,updated_at=? WHERE id=?",
                        (now(), dinner["id"]),
                    )
                elif action == "set_menu":
                    self._set_menu(tx, user_id, dinner, data)
                elif action == "generate_shopping":
                    self.require_capability(user_id, "canUseGeneratedShopping")
                    self._generate_dinner_shopping(tx, user_id, dinner)
                elif action == "generate_timeline":
                    self._generate_timeline(tx, dinner)
                else:
                    raise DomainError("invalid_action", 422)
                updated = tx.one("SELECT * FROM dinners WHERE id=?", (dinner["id"],))
                return self._event_view(tx, user_id, updated)

            return self._once(tx, user_id, key, "dinner", data, change)

    def _add_participant(self, tx, user_id: str, dinner: dict, data: dict) -> dict:
        if tx.one("SELECT COUNT(*) AS n FROM dinner_participants WHERE dinner_id=?", (dinner["id"],))["n"] >= 40:
            raise DomainError("dinner_full", 409)
        kind = data.get("kind", "temporary_guest")
        if kind not in {"household_member", "saved_guest", "temporary_guest"}:
            raise DomainError("invalid_participant_kind", 422)
        participant_id, stamp = new_id(), now()
        linked_user, saved_guest, status = None, None, "invited"
        if kind == "household_member":
            linked_user = valid_uuid(data.get("user_id"))
            member = self._member(tx, linked_user, dinner["household_id"])
            profile = self._profile(tx, linked_user)
            display_name, status = profile["name"], "accepted"
            if tx.one(
                "SELECT 1 FROM dinner_participants WHERE dinner_id=? AND user_id=?",
                (dinner["id"], linked_user),
            ):
                raise DomainError("participant_exists", 409)
            if member["role"] == "viewer":
                status = "accepted"
        elif kind == "saved_guest":
            saved_guest = tx.one(
                "SELECT * FROM dinner_saved_guests WHERE id=? AND household_id=?",
                (valid_uuid(data.get("saved_guest_id")), dinner["household_id"]),
            )
            if not saved_guest:
                raise DomainError("saved_guest_not_found", 404)
            display_name, saved_guest = saved_guest["display_name"], saved_guest["id"]
        else:
            display_name = text(data.get("display_name"), maximum=80)
        tx.execute(
            "INSERT INTO dinner_participants VALUES (?,?,?,?,?,?,?,?,?)",
            (
                participant_id,
                dinner["id"],
                kind,
                linked_user,
                saved_guest,
                display_name,
                status,
                stamp,
                stamp,
            ),
        )
        return {"participant_id": participant_id}

    def dinner_invite_action(self, user_id: str, dinner_id: str, data: dict, key: str) -> dict:
        home = self._household(user_id, write=True)
        with self.db.transaction(home) as tx:
            def change():
                dinner = self._host_dinner(tx, user_id, dinner_id)
                participant = tx.one(
                    "SELECT * FROM dinner_participants WHERE id=? AND dinner_id=?",
                    (valid_uuid(data.get("participant_id")), dinner["id"]),
                )
                if not participant or participant["kind"] in {"host", "household_member"}:
                    raise DomainError("participant_not_found", 404)
                action = data.get("action", "create")
                existing = tx.one(
                    "SELECT * FROM dinner_invitations WHERE participant_id=?",
                    (participant["id"],),
                )
                if action == "revoke":
                    if not existing:
                        raise DomainError("invitation_not_found", 404)
                    tx.execute(
                        "UPDATE dinner_invitations SET revoked_at=? WHERE id=?",
                        (now(), existing["id"]),
                    )
                    return {"revoked": True}
                if action not in {"create", "rotate"}:
                    raise DomainError("invalid_action", 422)
                if action == "create" and existing and not existing["revoked_at"]:
                    raise DomainError("invitation_exists", 409)
                token, stamp = secrets.token_urlsafe(32), now()
                invitation_id = existing["id"] if existing else new_id()
                expiry = self._invite_expiry(dinner["starts_at"])
                if existing:
                    tx.execute(
                        "UPDATE dinner_invitations SET token_hash=?,expires_at=?,revoked_at=NULL,rotated_at=? WHERE id=?",
                        (_token_hash(token), expiry, stamp, invitation_id),
                    )
                    tx.execute("DELETE FROM dinner_guest_responses WHERE invitation_id=?", (invitation_id,))
                else:
                    tx.execute(
                        "INSERT INTO dinner_invitations VALUES (?,?,?,?,?,?,?,?)",
                        (invitation_id, dinner["id"], participant["id"], _token_hash(token), expiry, None, None, stamp),
                    )
                tx.execute(
                    "UPDATE dinner_participants SET status='invited',updated_at=? WHERE id=?",
                    (stamp, participant["id"]),
                )
                base = os.getenv("GUEST_APP_URL", "http://localhost:3000").rstrip("/")
                return {
                    "id": invitation_id,
                    "participant_id": participant["id"],
                    "token": token,
                    "url": base + "/invite/" + quote(token, safe=""),
                    "expires_at": expiry,
                }

            return self._once(tx, user_id, key, "dinner_invite", data, change)

    def public_guest_invite(self, token: str) -> dict:
        with self.db.transaction() as tx:
            row = self._public_invite(tx, token)
            response = decode(row["response_data"]) if row["response_data"] else None
            foods = [
                {
                    "id": item["id"],
                    "slug": item.get("slug"),
                    "name": item.get("name", {}),
                }
                for item in (decode(record["data"]) for record in tx.all("SELECT data FROM foods ORDER BY id"))
                if item.get("ingredient_status") == "known"
            ]
            return {
                "event": {
                    "title": row["title"],
                    "starts_at": row["starts_at"],
                    "timezone": row["timezone"],
                    "location": row["location"],
                    "host_name": row["host_name"],
                },
                "guest": {"display_name": row["display_name"], "status": row["participant_status"]},
                "response": response,
                "questionnaire": {
                    "eating_styles": sorted(EATING_STYLES),
                    "allergies": ALLERGENS,
                    "intolerances": INTOLERANCES,
                    "sensitivities": SENSITIVITIES,
                    "avoidances": foods,
                    "note_max_length": 500,
                },
                "expires_at": row["expires_at"],
            }

    def _guest_settings(self, tx, data: dict) -> dict:
        rsvp = data.get("rsvp")
        if rsvp not in {"accepted", "declined"}:
            raise DomainError("invalid_rsvp", 422)
        style = data.get("eating_style")
        if style is not None and style not in EATING_STYLES:
            raise DomainError("invalid_eating_style", 422)
        values = {}
        for field, allowed in (
            ("allergies", set(ALLERGENS)),
            ("intolerances", set(INTOLERANCES)),
            ("sensitivities", set(SENSITIVITIES)),
        ):
            selected = data.get(field, [])
            if (
                not isinstance(selected, list)
                or len(selected) > len(allowed)
                or any(not isinstance(item, str) or item not in allowed for item in selected)
            ):
                raise DomainError("invalid_" + field, 422)
            values[field] = sorted(set(selected))
        avoidances = data.get("avoidances", [])
        if (
            not isinstance(avoidances, list)
            or len(avoidances) > 50
            or any(not isinstance(item, str) for item in avoidances)
        ):
            raise DomainError("invalid_avoidances", 422)
        avoidances = sorted(set(valid_uuid(item) for item in avoidances))
        if avoidances:
            placeholders = ",".join("?" for _ in avoidances)
            found = tx.one(
                f"SELECT COUNT(*) AS n FROM foods WHERE id IN ({placeholders})",
                tuple(avoidances),
            )["n"]
            if found != len(avoidances):
                raise DomainError("invalid_avoidances", 422)
        diets = []
        if style:
            definition = tx.one("SELECT id FROM diet_definitions WHERE slug=?", (style,))
            if not definition:
                raise DomainError("invalid_eating_style", 422)
            diets = [{"diet_id": definition["id"], "strictness": "standard"}]
        note = text(data.get("note", ""), maximum=500, empty=True)
        remember = data.get("remember_me", False)
        if type(remember) is not bool:
            raise DomainError("invalid_remember_choice", 422)
        return {
            "rsvp": rsvp,
            "eating_style": style,
            "settings": {
                "diets": diets,
                "allergies": values["allergies"],
                "intolerances": values["intolerances"],
                "sensitivities": values["sensitivities"],
                "never_suggest": avoidances,
                "unknown_ingredient_policy": "strict",
                "trace_policy": "block",
                "medical_awareness": [],
                "ethical_preferences": [],
            },
            "note": note,
            "remember_me": remember,
        }

    def public_guest_respond(self, token: str, data: dict) -> dict:
        with self.db.transaction() as tx:
            invite = self._public_invite(tx, token)
            value = self._guest_settings(tx, data)
            stamp = now()
            existing = tx.one(
                "SELECT * FROM dinner_guest_responses WHERE invitation_id=?",
                (invite["id"],),
            )
            remembered_id = existing["remembered_guest_id"] if existing else None
            if value["remember_me"] and invite["kind"] == "temporary_guest" and not remembered_id:
                remembered_id = new_id()
                tx.execute(
                    "INSERT INTO dinner_saved_guests VALUES (?,?,?,?,?,?,?)",
                    (
                        remembered_id,
                        invite["household_id"],
                        invite["display_name"],
                        encode(value["settings"]),
                        stamp,
                        stamp,
                        stamp,
                    ),
                )
                tx.execute(
                    "UPDATE dinner_participants SET kind='saved_guest',saved_guest_id=?,updated_at=? WHERE id=?",
                    (remembered_id, stamp, invite["participant_id"]),
                )
            elif remembered_id:
                if value["remember_me"]:
                    tx.execute(
                        "UPDATE dinner_saved_guests SET data=?,updated_at=? WHERE id=?",
                        (encode(value["settings"]), stamp, remembered_id),
                    )
                else:
                    tx.execute(
                        "UPDATE dinner_participants SET kind='temporary_guest',saved_guest_id=NULL,updated_at=? WHERE id=?",
                        (stamp, invite["participant_id"]),
                    )
                    tx.execute("DELETE FROM dinner_saved_guests WHERE id=?", (remembered_id,))
                    remembered_id = None
            tx.execute(
                "INSERT INTO dinner_guest_responses VALUES (?,?,?,?,?) "
                "ON CONFLICT(invitation_id) DO UPDATE SET data=excluded.data,"
                "remembered_guest_id=excluded.remembered_guest_id,updated_at=excluded.updated_at",
                (invite["id"], encode(value), remembered_id, existing["submitted_at"] if existing else stamp, stamp),
            )
            status = "declined" if value["rsvp"] == "declined" else "responded"
            tx.execute(
                "UPDATE dinner_participants SET status=?,updated_at=? WHERE id=?",
                (status, stamp, invite["participant_id"]),
            )
            return {"saved": True, "status": status, "remembered": bool(remembered_id)}

    def public_guest_delete_response(self, token: str) -> dict:
        with self.db.transaction() as tx:
            invite = self._public_invite(tx, token)
            response = tx.one(
                "SELECT remembered_guest_id FROM dinner_guest_responses WHERE invitation_id=?",
                (invite["id"],),
            )
            if response and response["remembered_guest_id"]:
                tx.execute(
                    "UPDATE dinner_participants SET kind='temporary_guest',saved_guest_id=NULL WHERE id=?",
                    (invite["participant_id"],),
                )
                tx.execute(
                    "DELETE FROM dinner_saved_guests WHERE id=?",
                    (response["remembered_guest_id"],),
                )
            tx.execute("DELETE FROM dinner_guest_responses WHERE invitation_id=?", (invite["id"],))
            tx.execute(
                "UPDATE dinner_participants SET status='invited',updated_at=? WHERE id=?",
                (now(), invite["participant_id"]),
            )
            return {"deleted": True}

    def _participant_profile(self, tx, dinner: dict, participant: dict) -> dict | None:
        if participant["status"] == "declined":
            return None
        if participant["kind"] in {"host", "household_member"}:
            if participant["kind"] == "household_member":
                consent = tx.one(
                    "SELECT share_constraints FROM member_permissions WHERE household_id=? AND user_id=?",
                    (dinner["household_id"], participant["user_id"]),
                )
                if not consent or not consent["share_constraints"]:
                    return {}
            return self._profile(tx, participant["user_id"])["settings"]
        if participant["kind"] == "saved_guest" and participant["saved_guest_id"]:
            saved = tx.one(
                "SELECT data FROM dinner_saved_guests WHERE id=? AND household_id=?",
                (participant["saved_guest_id"], dinner["household_id"]),
            )
            return decode(saved["data"]) if saved else {}
        response = tx.one(
            "SELECT r.data FROM dinner_guest_responses r JOIN dinner_invitations i ON i.id=r.invitation_id "
            "WHERE i.participant_id=?",
            (participant["id"],),
        )
        return decode(response["data"])["settings"] if response else {}

    def _menu_fit(self, tx, user_id: str, dinner: dict, participants: list[dict], menu: list[str]) -> list[dict]:
        if not menu:
            return []
        foods, recipes, _, versions = self._catalog(tx, user_id)
        recipes_by_id = {recipe["id"]: recipe for recipe in recipes}
        event_day = _utc(dinner["starts_at"]).date()
        results = []
        for recipe_id in menu:
            recipe = recipes_by_id.get(recipe_id)
            if not recipe:
                results.append({"recipe_id": recipe_id, "status": "not_compatible", "issues": ["recipe_unavailable"]})
                continue
            blocked, unanswered, warnings = [], [], []
            for participant in participants:
                settings = self._participant_profile(tx, dinner, participant)
                if settings is None:
                    continue
                if not settings:
                    unanswered.append(participant["id"])
                    continue
                rules, _ = active_rules(settings.get("diets", []), versions, event_day)
                assessment = compatibility(
                    [item["food_id"] for item in recipe["ingredients"]],
                    foods,
                    settings,
                    rules,
                )
                if assessment["reasons"]:
                    blocked.append(
                        {
                            "participant_id": participant["id"],
                            "reason_codes": sorted({reason["code"] for reason in assessment["reasons"]}),
                        }
                    )
                elif assessment["warnings"]:
                    warnings.append(participant["id"])
            if blocked:
                status = "not_compatible"
            elif unanswered:
                status = "review_required"
            elif warnings:
                status = "works_with_notes"
            else:
                status = "works_for_everyone"
            results.append(
                {
                    "recipe_id": recipe_id,
                    "status": status,
                    "blocked": blocked,
                    "unanswered_participant_ids": unanswered,
                    "warning_participant_ids": warnings,
                }
            )
        return results

    def _set_menu(self, tx, user_id: str, dinner: dict, data: dict) -> None:
        menu = data.get("recipe_ids", [])
        if (
            not isinstance(menu, list)
            or len(menu) > 12
            or len(menu) != len(set(menu))
            or any(not isinstance(item, str) for item in menu)
        ):
            raise DomainError("invalid_menu", 422)
        menu = [valid_uuid(item) for item in menu]
        recipes = {recipe["id"] for recipe in self._catalog(tx, user_id)[1]}
        if any(item not in recipes for item in menu):
            raise DomainError("recipe_not_found", 404)
        extra = integer(data.get("extra_portions", 0), minimum=0, maximum=20)
        value = decode(dinner["data"])
        value.update(menu=menu, extra_portions=extra)
        tx.execute(
            "UPDATE dinners SET data=?,version=version+1,updated_at=? WHERE id=?",
            (encode(value), now(), dinner["id"]),
        )

    def _generate_dinner_shopping(self, tx, user_id: str, dinner: dict) -> None:
        value = decode(dinner["data"])
        participants = tx.all(
            "SELECT id,kind,user_id,saved_guest_id,display_name,status FROM dinner_participants WHERE dinner_id=?",
            (dinner["id"],),
        )
        servings = self._servings(participants, value.get("extra_portions", 0))
        foods, recipes, _, _ = self._catalog(tx, user_id)
        recipes = {recipe["id"]: recipe for recipe in recipes}
        totals = {}
        for recipe_id in value.get("menu", []):
            recipe = recipes.get(recipe_id)
            if not recipe:
                raise DomainError("recipe_not_found", 404)
            for food_id, amount in requirements(recipe, servings).items():
                totals[food_id] = totals.get(food_id, 0) + amount
        today = self.today(self._profile(tx, user_id)["settings"])
        for batch in self._inventory(tx, dinner["household_id"]):
            if batch_usable(batch, today) and batch["food_id"] in totals:
                totals[batch["food_id"]] = max(0, totals[batch["food_id"]] - batch["quantity_milli"])
        source = "dinner:" + dinner["id"]
        tx.execute(
            "DELETE FROM shopping_items WHERE household_id=? AND source_key=?",
            (dinner["household_id"], source),
        )
        for food_id, amount in totals.items():
            if amount:
                food = foods[food_id]
                self._shopping_insert(
                    tx,
                    user_id,
                    dinner["household_id"],
                    food_id,
                    food["name"]["en"],
                    amount,
                    food["unit"],
                    food.get("group", "other"),
                    source,
                )

    def _generate_timeline(self, tx, dinner: dict) -> None:
        value = decode(dinner["data"])
        recipes = {
            recipe["id"]: recipe
            for recipe in self._catalog(tx, dinner["host_user_id"])[1]
        }
        starts = _utc(dinner["starts_at"])
        timeline = []
        for recipe_id in value.get("menu", []):
            recipe = recipes.get(recipe_id)
            if not recipe:
                continue
            begin = starts - timedelta(minutes=recipe["minutes"])
            timeline.append(
                {
                    "recipe_id": recipe_id,
                    "start_at": begin.isoformat(),
                    "serve_at": starts.isoformat(),
                    "minutes": recipe["minutes"],
                }
            )
        timeline.sort(key=lambda item: (item["start_at"], item["recipe_id"]))
        value["timeline"] = timeline
        tx.execute(
            "UPDATE dinners SET data=?,version=version+1,updated_at=? WHERE id=?",
            (encode(value), now(), dinner["id"]),
        )

    def dinner_adaptive_servings(self, user_id: str, dinner_id: str) -> dict:
        with self.db.transaction() as tx:
            dinner = self._dinner(tx, user_id, dinner_id)
            value = decode(dinner["data"])
            participants = tx.all(
                "SELECT id,kind,user_id,saved_guest_id,display_name,status FROM dinner_participants WHERE dinner_id=?",
                (dinner["id"],),
            )
            servings = self._servings(participants, value.get("extra_portions", 0))
            recipes = {recipe["id"]: recipe for recipe in self._catalog(tx, user_id)[1]}
            scaled = []
            for recipe_id in value.get("menu", []):
                recipe = recipes.get(recipe_id)
                if recipe:
                    scaled.append(
                        {
                            "recipe_id": recipe_id,
                            "servings": servings,
                            "ingredients": [
                                {"food_id": food_id, "quantity": quantity(amount)}
                                for food_id, amount in requirements(recipe, servings).items()
                            ],
                        }
                    )
            return {"servings": servings, "recipes": scaled}
