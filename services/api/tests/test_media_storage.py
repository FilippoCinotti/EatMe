import os
import tempfile
import unittest
from unittest.mock import patch

from cryptography.fernet import Fernet

from eatme.errors import DomainError
from eatme.intelligence import PrivateMedia


class PrivateMediaTests(unittest.TestCase):
    def test_filesystem_adapter_encrypts_at_rest(self):
        with tempfile.TemporaryDirectory() as directory, patch.dict(
            os.environ,
            {
                "EATME_ENV": "production",
                "MEDIA_STORAGE_BACKEND": "filesystem",
                "MEDIA_DIRECTORY": directory,
                "MEDIA_ENCRYPTION_KEY": Fernet.generate_key().decode(),
            },
            clear=False,
        ):
            storage = PrivateMedia()
            identifier = "11111111-1111-4111-8111-111111111111"
            storage.write(identifier, b"private image")
            with open(f"{directory}/{identifier}", "rb") as encrypted_file:
                self.assertNotIn(b"private image", encrypted_file.read())
            self.assertEqual(storage.read(identifier), b"private image")
            storage.delete(identifier)
            with self.assertRaises(DomainError) as missing:
                storage.read(identifier)
            self.assertEqual(missing.exception.code, "media_expired")

    def test_supabase_adapter_uses_server_key_and_encrypted_payload(self):
        key = Fernet.generate_key().decode()
        calls = []

        def fake_request(url, **kwargs):
            calls.append((url, kwargs))
            if kwargs.get("method") == "POST":
                self.assertNotIn(b"private image", kwargs["body"])
                return b"{}"
            if kwargs.get("method") == "DELETE":
                return b"{}"
            return calls[0][1]["body"]

        with patch.dict(
            os.environ,
            {
                "EATME_ENV": "production",
                "MEDIA_STORAGE_BACKEND": "supabase",
                "SUPABASE_URL": "https://project.supabase.co",
                "SUPABASE_SERVICE_ROLE_KEY": "server-only",
                "SUPABASE_MEDIA_BUCKET": "eatme-private-media",
                "MEDIA_ENCRYPTION_KEY": key,
            },
            clear=False,
        ), patch("eatme.intelligence.https_request", side_effect=fake_request):
            storage = PrivateMedia()
            identifier = "22222222-2222-4222-8222-222222222222"
            storage.write(identifier, b"private image")
            self.assertEqual(storage.read(identifier), b"private image")
            storage.delete(identifier)
        self.assertEqual(calls[0][1]["headers"]["apikey"], "server-only")
        self.assertNotIn("server-only", calls[0][0])
        self.assertTrue(calls[0][0].endswith("/eatme-private-media/" + identifier))

    def test_supabase_backend_requires_server_configuration(self):
        with patch.dict(
            os.environ,
            {"EATME_ENV": "production", "MEDIA_STORAGE_BACKEND": "supabase"},
            clear=True,
        ), self.assertRaises(DomainError) as error:
            PrivateMedia()
        self.assertEqual(error.exception.code, "media_storage_not_configured")


if __name__ == "__main__":
    unittest.main()
