from __future__ import annotations

import hashlib
import hmac
import os
import re
import secrets
from datetime import datetime, timedelta, timezone
from uuid import UUID, uuid4

from .errors import DomainError
from .storage import Database


def now() -> str:
    return datetime.now(timezone.utc).isoformat()


class DevelopmentAuth:
    """Explicit local-only credentials. Not a substitute for verified Supabase auth."""

    def __init__(self, db: Database):
        if os.getenv("EATME_ENV", "development") != "development":
            raise RuntimeError("Development auth forbidden outside development")
        self.db = db

    def login(self, email: str, password: str, register: bool = False) -> dict:
        if not isinstance(email, str) or not re.fullmatch(r"[^\s@]{1,100}@[^\s@]{1,100}\.[^\s@]{1,30}", email):
            raise DomainError("invalid_email", 422)
        if not isinstance(password, str) or not 12 <= len(password) <= 128:
            raise DomainError("password_length", 422)
        email = email.strip().lower()
        with self.db.transaction() as tx:
            account = tx.one("SELECT * FROM dev_accounts WHERE email=?", (email,))
            if register:
                if account:
                    raise DomainError("account_unavailable", 409)
                salt = secrets.token_hex(16)
                digest = hashlib.scrypt(password.encode(), salt=bytes.fromhex(salt), n=16384,r=8,p=1).hex()
                account = {"user_id":str(uuid4())}
                tx.execute("INSERT INTO dev_accounts VALUES (?,?,?)", (account["user_id"],email,f"{salt}:{digest}"))
            else:
                # Perform a hash even for unknown accounts to avoid a trivial timing distinction.
                stored = account["password_hash"] if account else f"{'0'*32}:{'0'*128}"
                salt, expected = stored.split(":")
                actual = hashlib.scrypt(password.encode(),salt=bytes.fromhex(salt),n=16384,r=8,p=1).hex()
                if not account or not hmac.compare_digest(actual, expected):
                    raise DomainError("invalid_credentials", 401)
            token = secrets.token_urlsafe(40)
            expiry = (datetime.now(timezone.utc)+timedelta(hours=12)).isoformat()
            tx.execute("DELETE FROM dev_sessions WHERE expires_at < ?", (now(),))
            tx.execute("INSERT INTO dev_sessions VALUES (?,?,?)",(hashlib.sha256(token.encode()).hexdigest(),account["user_id"],expiry))
        return {"access_token":token,"user_id":account["user_id"],"expires_at":expiry,"mode":"development"}

    def verify(self, token: str) -> str:
        if not token or len(token)>4096:
            raise DomainError("unauthorized",401)
        with self.db.transaction() as tx:
            row = tx.one("SELECT user_id FROM dev_sessions WHERE token_hash=? AND expires_at > ?",
                         (hashlib.sha256(token.encode()).hexdigest(),now()))
            if row is None:
                raise DomainError("unauthorized",401)
            return row["user_id"]

    def logout(self, token: str):
        with self.db.transaction() as tx:
            tx.execute("DELETE FROM dev_sessions WHERE token_hash=?",(hashlib.sha256(token.encode()).hexdigest(),))


class SupabaseAuth:
    def __init__(self, url: str):
        import jwt
        if not url.startswith("https://"):
            raise RuntimeError("Supabase requires HTTPS")
        self.jwt = jwt
        self.issuer = url.rstrip("/") + "/auth/v1"
        self.jwks = jwt.PyJWKClient(self.issuer + "/.well-known/jwks.json", cache_keys=True, lifespan=300)

    def verify(self, token: str, *, recent=False) -> str:
        try:
            key = self.jwks.get_signing_key_from_jwt(token)
            claims = self.jwt.decode(token,key.key,algorithms=["ES256","RS256"],audience="authenticated",
                                     issuer=self.issuer,options={"require":["exp","iat","sub","aud","iss"]})
            if claims.get("role") != "authenticated":
                raise ValueError("Wrong role")
            if recent:
                methods = claims.get("amr", [])
                recent_methods = [m for m in methods if m.get("method") in {"password", "oauth", "otp", "totp", "sso/saml"} and isinstance(m.get("timestamp"), (int,float)) and 0 <= datetime.now(timezone.utc).timestamp()-m["timestamp"] <= 300]
                if not recent_methods:
                    raise DomainError("reauthentication_required", 409)
            return str(UUID(claims["sub"]))
        except (self.jwt.PyJWTError,ValueError,KeyError):
            raise DomainError("unauthorized",401) from None
