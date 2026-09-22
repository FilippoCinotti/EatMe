import tempfile
import unittest

from eatme.catalog import identifier, seed_catalog
from eatme.auth import DevelopmentAuth
from eatme.errors import DomainError
from eatme.service import Service, new_id
from eatme.storage import Database, decode, encode
from eatme.transport import Router


class DinnerCase(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.db = Database(self.temp.name + "/dinners.db")
        self.db.migrate_local()
        seed_catalog(self.db)
        self.app = Service(self.db)
        self.host, self.outsider = new_id(), new_id()
        self.app.save_profile(self.host, {"name": "Host", "adult_confirmed": True}, new_id())
        self.app.save_profile(self.outsider, {"name": "Other", "adult_confirmed": True}, new_id())

    def assertCode(self, code, call):
        with self.assertRaises(DomainError) as error:
            call()
        self.assertEqual(error.exception.code, code)

    def create_dinner(self):
        return self.app.dinner_action(
            self.host,
            {
                "action": "create",
                "title": "Friday dinner",
                "starts_at": "2030-09-20T19:00:00+02:00",
                "timezone": "Europe/Rome",
                "location": "Home",
            },
            new_id(),
        )

    def add_guest(self, dinner, name="Ada"):
        event = self.app.dinner_action(
            self.host,
            {
                "action": "add_participant",
                "id": dinner["id"],
                "expected_version": dinner["version"],
                "kind": "temporary_guest",
                "display_name": name,
            },
            new_id(),
        )
        return event, next(item for item in event["participants"] if item["display_name"] == name)

    def invite(self, dinner, participant, action="create"):
        return self.app.dinner_invite_action(
            self.host,
            dinner["id"],
            {"action": action, "participant_id": participant["id"]},
            new_id(),
        )

    def test_capability_token_is_hashed_rotatable_and_minimally_disclosed(self):
        dinner, participant = self.add_guest(self.create_dinner())
        invitation = self.invite(dinner, participant)
        self.assertGreaterEqual(len(invitation["token"]), 43)
        with self.db.transaction() as tx:
            stored = tx.one("SELECT token_hash FROM dinner_invitations WHERE id=?", (invitation["id"],))
        self.assertEqual(len(stored["token_hash"]), 64)
        self.assertNotEqual(stored["token_hash"], invitation["token"])

        public = self.app.public_guest_invite(invitation["token"])
        self.assertEqual(set(public), {"event", "guest", "response", "questionnaire", "expires_at"})
        self.assertEqual(public["guest"], {"display_name": "Ada", "status": "invited"})
        self.assertNotIn("participants", public["event"])
        self.assertNotIn("household_id", str(public))

        rotated = self.invite(dinner, participant, "rotate")
        self.assertCode("invitation_unavailable", lambda: self.app.public_guest_invite(invitation["token"]))
        self.assertEqual(self.app.public_guest_invite(rotated["token"])["event"]["title"], "Friday dinner")

    def test_unanswered_guest_never_works_for_everyone_and_peanut_blocks_group(self):
        dinner, participant = self.add_guest(self.create_dinner())
        invitation = self.invite(dinner, participant)
        dinner = self.app.dinner_action(
            self.host,
            {
                "action": "set_menu",
                "id": dinner["id"],
                "expected_version": dinner["version"],
                "recipe_ids": [identifier("recipe", "sunny-bowl")],
            },
            new_id(),
        )
        self.assertEqual(dinner["diet_fit"][0]["status"], "review_required")
        self.assertEqual(dinner["diet_fit"][0]["unanswered_participant_ids"], [participant["id"]])

        peanut_recipe = new_id()
        with self.db.transaction() as tx:
            tx.execute(
                "INSERT INTO recipes VALUES (?,?)",
                (
                    peanut_recipe,
                    encode(
                        {
                            "id": peanut_recipe,
                            "title": {"en": "Peanut bowl", "it": "Bowl di arachidi"},
                            "minutes": 5,
                            "servings": 2,
                            "ingredients": [
                                {"food_id": identifier("food", "peanut"), "quantity": "100"}
                            ],
                            "steps": {"en": ["Serve."], "it": ["Servi."]},
                            "is_demo": True,
                        }
                    ),
                ),
            )
        self.app.public_guest_respond(
            invitation["token"],
            {
                "rsvp": "accepted",
                "eating_style": "omnivore",
                "allergies": ["peanut"],
                "intolerances": [],
                "sensitivities": [],
                "avoidances": [],
                "remember_me": False,
            },
        )
        dinner = self.app.dinner_action(
            self.host,
            {
                "action": "set_menu",
                "id": dinner["id"],
                "expected_version": dinner["version"],
                "recipe_ids": [peanut_recipe],
            },
            new_id(),
        )
        fit = dinner["diet_fit"][0]
        self.assertEqual(fit["status"], "not_compatible")
        self.assertEqual(fit["blocked"][0]["participant_id"], participant["id"])
        self.assertEqual(fit["blocked"][0]["reason_codes"], ["contains_allergen"])
        self.assertNotIn("peanut", str(fit))

    def test_response_update_delete_remember_opt_in_and_tenant_isolation(self):
        dinner, participant = self.add_guest(self.create_dinner())
        invitation = self.invite(dinner, participant)
        first = self.app.public_guest_respond(
            invitation["token"],
            {
                "rsvp": "accepted",
                "eating_style": "vegetarian",
                "note": "<script>not executable</script>",
                "remember_me": True,
            },
        )
        self.assertTrue(first["remembered"])
        with self.db.transaction() as tx:
            self.assertEqual(tx.one("SELECT COUNT(*) AS n FROM dinner_saved_guests")["n"], 1)
            stored = decode(tx.one("SELECT data FROM dinner_guest_responses")["data"])
            self.assertEqual(stored["note"], "<script>not executable</script>")
        self.assertCode("dinner_not_found", lambda: self.app.dinner(self.outsider, dinner["id"]))

        updated = self.app.public_guest_respond(
            invitation["token"],
            {"rsvp": "accepted", "eating_style": "vegan", "remember_me": False},
        )
        self.assertFalse(updated["remembered"])
        with self.db.transaction() as tx:
            self.assertEqual(tx.one("SELECT COUNT(*) AS n FROM dinner_saved_guests")["n"], 0)
        self.assertEqual(self.app.public_guest_delete_response(invitation["token"]), {"deleted": True})
        self.assertIsNone(self.app.public_guest_invite(invitation["token"])["response"])

    def test_cancellation_revokes_public_access_and_adaptive_servings_include_extras(self):
        dinner, participant = self.add_guest(self.create_dinner())
        invitation = self.invite(dinner, participant)
        self.app.public_guest_respond(invitation["token"], {"rsvp": "accepted", "remember_me": False})
        dinner = self.app.dinner_action(
            self.host,
            {
                "action": "set_menu",
                "id": dinner["id"],
                "expected_version": dinner["version"],
                "recipe_ids": [identifier("recipe", "sunny-bowl")],
                "extra_portions": 2,
            },
            new_id(),
        )
        scaled = self.app.dinner_adaptive_servings(self.host, dinner["id"])
        self.assertEqual(scaled["servings"], 4)
        self.assertEqual(scaled["recipes"][0]["servings"], 4)
        self.app.dinner_action(
            self.host,
            {"action": "cancel", "id": dinner["id"], "expected_version": dinner["version"]},
            new_id(),
        )
        self.assertCode("invitation_unavailable", lambda: self.app.public_guest_invite(invitation["token"]))

    def test_public_transport_requires_only_the_capability_and_never_a_bearer_token(self):
        dinner, participant = self.add_guest(self.create_dinner())
        invitation = self.invite(dinner, participant)
        router = Router(self.app, DevelopmentAuth(self.db))
        path = "/api/v1/guest/invites/" + invitation["token"]
        public = router.dispatch("GET", path, client="203.0.113.8")
        self.assertEqual(public["guest"]["display_name"], "Ada")
        result = router.dispatch(
            "PUT",
            path + "/response",
            {"rsvp": "accepted", "remember_me": False},
            client="203.0.113.8",
        )
        self.assertEqual(result["status"], "responded")
        self.assertEqual(
            router.dispatch("DELETE", path + "/response", client="203.0.113.8"),
            {"deleted": True},
        )
        self.assertCode(
            "invitation_unavailable",
            lambda: router.dispatch("GET", "/api/v1/guest/invites/" + "x" * 43),
        )

    def test_public_rate_limit_is_shared_and_enforced(self):
        self.app.guest_rate_limit("guest:get:203.0.113.9", 2)
        self.app.guest_rate_limit("guest:get:203.0.113.9", 2)
        self.assertCode(
            "rate_limited",
            lambda: self.app.guest_rate_limit("guest:get:203.0.113.9", 2),
        )
        self.app.guest_rate_limit("guest:get:203.0.113.10", 2)

    def test_expired_temporary_guest_data_is_removed(self):
        dinner, participant = self.add_guest(self.create_dinner())
        invitation = self.invite(dinner, participant)
        self.app.public_guest_respond(
            invitation["token"],
            {"rsvp": "accepted", "note": "private", "remember_me": False},
        )
        with self.db.transaction() as tx:
            tx.execute(
                "UPDATE dinners SET starts_at='2000-01-01T00:00:00+00:00' WHERE id=?",
                (dinner["id"],),
            )
        self.assertEqual(self.app.cleanup_dinner_guests(), 1)
        with self.db.transaction() as tx:
            self.assertEqual(
                tx.one(
                    "SELECT COUNT(*) AS n FROM dinner_participants WHERE id=?",
                    (participant["id"],),
                )["n"],
                0,
            )
            self.assertEqual(
                tx.one(
                    "SELECT COUNT(*) AS n FROM dinner_guest_responses WHERE invitation_id=?",
                    (invitation["id"],),
                )["n"],
                0,
            )


if __name__ == "__main__":
    unittest.main()
