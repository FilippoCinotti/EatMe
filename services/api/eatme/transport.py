from __future__ import annotations

import os
import re
import threading
import time
from collections import OrderedDict
from urllib.parse import parse_qs, urlsplit

from .auth import DevelopmentAuth, SupabaseAuth
from .errors import DomainError
from .service import Service
from .storage import Database


class RateLimiter:
    """Bounded local limiter; use a shared gateway limiter for production replicas."""
    def __init__(self):
        self.entries = OrderedDict()
        self.lock = threading.Lock()

    def check(self, key: str, limit: int = 120):
        current = time.monotonic()
        with self.lock:
            start,count = self.entries.get(key,(current,0))
            if current-start > 60:
                start,count = current,0
            self.entries[key] = (start,count+1)
            self.entries.move_to_end(key)
            if len(self.entries)>10000:
                self.entries.popitem(last=False)
            if count >= limit:
                raise DomainError("rate_limited",429)


class Router:
    def __init__(self, service: Service, auth):
        self.service,self.auth = service,auth
        self.development = isinstance(auth,DevelopmentAuth)
        self.limiter = RateLimiter()

    def dispatch(self,method,path,body=None,authorization="",operation_key="",client="local"):
        split = urlsplit(path)
        route = split.path.rstrip("/")
        body = {} if body is None else body
        if not isinstance(body,dict):
            raise DomainError("invalid_json_body",422)
        query = parse_qs(split.query)
        self.limiter.check(client,180)
        if route=="/api/v1/health" and method=="GET":
            return {"status":"ok","version":"0.1.0"}
        if route=="/api/v1/config" and method=="GET":
            return {"auth_mode":"development" if self.development else "supabase",
                    "features":{"manual_inventory":True,"recipe_cooking":True,"healthy_food":True,
                                "ai_scan":False,"barcode_scan":False,"receipt_scan":False,"meal_planner":False,
                                "household_sharing":False,"account_deletion":self.development}}
        if route in {"/api/v1/auth/register","/api/v1/auth/login"} and method=="POST":
            if not self.development:
                raise DomainError("use_supabase_auth",404)
            self.limiter.check("auth:"+client,12)
            return self.auth.login(body.get("email"),body.get("password"),route.endswith("register"))
        if len(authorization)>8192 or not authorization.startswith("Bearer "):
            raise DomainError("unauthorized",401)
        token = authorization[7:]
        user_id = self.auth.verify(token)
        self.limiter.check("user:"+user_id,180)
        if route=="/api/v1/auth/logout" and method=="POST":
            if self.development:
                self.auth.logout(token)
            return {"logged_out":True}
        if route=="/api/v1/catalog" and method=="GET":
            return self.service.catalog()
        if route=="/api/v1/profile":
            if method=="GET":
                return self.service.get_profile(user_id)
            if method=="PUT":
                return self.service.save_profile(user_id,body,operation_key)
            if method=="DELETE":
                if body.get("confirm") is not True:
                    raise DomainError("deletion_confirmation_required",422)
                return self.service.delete_local_account(user_id)
        if route=="/api/v1/inventory":
            if method=="GET":
                return self.service.inventory(user_id)
            if method=="POST":
                return self.service.add_inventory(user_id,body,operation_key)
        match = re.fullmatch(r"/api/v1/inventory/([a-f0-9-]{36})",route)
        if match and method=="PATCH":
            return self.service.change_inventory(user_id,match[1],body,operation_key)
        if route=="/api/v1/recommendations" and method=="GET":
            return self.service.recommendations(user_id,query.get("mode",["for_you"])[0],query.get("food_id",[None])[0])
        match = re.fullmatch(r"/api/v1/recipes/([a-f0-9-]{36})",route)
        if match and method=="GET":
            return self.service.recipe(user_id,match[1])
        match = re.fullmatch(r"/api/v1/foods/([a-f0-9-]{36})/compatibility",route)
        if match and method=="GET":
            return self.service.food_compatibility(user_id,match[1])
        if route=="/api/v1/cooking/preview" and method=="POST":
            return self.service.cooking_preview(user_id,body)
        if route=="/api/v1/cooking/confirm" and method=="POST":
            return self.service.cooking_confirm(user_id,body,operation_key)
        if route=="/api/v1/leftovers" and method=="GET":
            return self.service.leftovers(user_id)
        if route=="/api/v1/privacy/export" and method=="GET":
            return self.service.export(user_id)
        if route=="/api/v1/admin/catalog" and method=="GET":
            allowed = set(filter(None,os.getenv("ADMIN_USER_IDS","").split(",")))
            if user_id not in allowed:
                raise DomainError("forbidden",403)
            return self.service.catalog()
        raise DomainError("not_found",404)


def configured_router() -> Router:
    from .catalog import seed_catalog
    from .engine import DEFAULT_WEIGHTS
    from .storage import decode
    environment = os.getenv("EATME_ENV","development")
    if environment not in {"development","staging","production"}:
        raise RuntimeError("Invalid EATME_ENV")
    db = Database(os.getenv("DATABASE_URL","eatme-dev.sqlite3"))
    mode = os.getenv("AUTH_MODE","development" if environment=="development" else "supabase")
    if environment!="development" and (mode!="supabase" or not db.postgres):
        raise RuntimeError("Non-development requires Supabase auth and PostgreSQL")
    if mode=="development":
        db.migrate_local()
        seed_catalog(db)
        auth = DevelopmentAuth(db)
    elif mode=="supabase":
        auth = SupabaseAuth(os.environ["SUPABASE_URL"])
    else:
        raise RuntimeError("Unsupported AUTH_MODE")
    weights = decode(os.getenv("RANKING_WEIGHTS_JSON","null")) or DEFAULT_WEIGHTS
    for profile in weights.values():
        if set(profile)!={"availability","expiry","diet","speed"} or any(type(v) not in {int,float} or not 0<=v<=1 for v in profile.values()) or abs(sum(profile.values())-1)>0.0001:
            raise RuntimeError("Invalid ranking weights")
    return Router(Service(db,weights=weights),auth)
