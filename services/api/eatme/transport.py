from __future__ import annotations

import os
import re
import hashlib
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
            commit = os.getenv("RENDER_GIT_COMMIT", "")
            return {"status":"ok","version":"1.0.0","git_commit":commit[:12] or None}
        if route=="/api/v1/config" and method=="GET":
            provider = os.getenv("AI_PROVIDER", "")
            live_ready = provider == "openai" and bool(os.getenv("AI_API_KEY")) and bool(os.getenv("AI_MODEL"))
            return {"auth_mode":"development" if self.development else "supabase",
                    "vision_provider":{"mode":"live" if provider == "openai" else "development_fixture" if provider == "development" else "unavailable",
                                       "live_ready":live_ready},
                    "features":{"manual_inventory":True,"recipe_cooking":True,"healthy_food":True,
                                "ai_scan":self.service.feature_enabled("ai_scan"),"barcode_scan":self.service.feature_enabled("barcode_scan"),"receipt_scan":self.service.feature_enabled("receipt_scan"),"meal_planner":True,
                                "household_sharing":True,"account_deletion":self.development or bool(os.getenv("SUPABASE_SERVICE_ROLE_KEY"))}}
        if route in {"/api/v1/auth/register","/api/v1/auth/login"} and method=="POST":
            if not self.development:
                raise DomainError("use_supabase_auth",404)
            self.limiter.check("auth:"+client,12)
            return self.auth.login(body.get("email"),body.get("password"),route.endswith("register"))
        guest = re.fullmatch(r"/api/v1/guest/invites/([A-Za-z0-9_-]{32,512})(/response)?", route)
        if guest:
            token, response_route = guest[1], guest[2]
            digest = hashlib.sha256(token.encode()).hexdigest()
            limit = 30 if method == "GET" else 12
            self.limiter.check("guest:"+client+":"+digest, limit)
            self.service.guest_rate_limit("guest-client:"+client, 60)
            self.service.guest_rate_limit("guest-token:"+client+":"+digest, limit)
            if method == "GET" and not response_route:
                return self.service.public_guest_invite(token)
            if method == "PUT" and response_route:
                return self.service.public_guest_respond(token, body)
            if method == "DELETE" and response_route:
                return self.service.public_guest_delete_response(token)
            raise DomainError("not_found",404)
        if len(authorization)>8192 or not authorization.startswith("Bearer "):
            raise DomainError("unauthorized",401)
        token = authorization[7:]
        user_id = self.auth.verify(token)
        self.limiter.check("user:"+user_id,180)
        if route not in {"/api/v1/profile", "/api/v1/auth/logout"} or method != "DELETE":
            with self.service.db.transaction() as tx:
                deletion = tx.one("SELECT status FROM account_deletions WHERE user_id=?", (user_id,))
                if deletion and deletion["status"] in {"pending", "completed"}:
                    raise DomainError("account_deletion_pending", 409)
        if route=="/api/v1/auth/logout" and method=="POST":
            if self.development:
                self.auth.logout(token)
            return {"logged_out":True}
        reads = {"/shopping":self.service.shopping, "/plans":self.service.plans,
                 "/dinners":self.service.dinners,
                 "/dinner-guests":self.service.dinner_saved_guests,
                 "/wellbeing":self.service.wellbeing, "/households/activity":self.service.household_activity,
                 "/households":self.service.households, "/preferences":self.service.preferences,
                 "/recipes":self.service.recipes, "/jobs":self.service.jobs,
                 "/notifications":self.service.notifications, "/insights":self.service.insights,
                 "/entitlements":self.service.entitlements, "/recalls":self.service.recalls,
                 "/admin/content":self.service.admin_content}
        actions = {"/shopping":self.service.shopping_action, "/plans":self.service.plan_action,
                   "/dinners":self.service.dinner_action,
                   "/foods":self.service.food_action, "/wellbeing":self.service.wellbeing_action,
                   "/households":self.service.household_action, "/preferences":self.service.preferences,
                   "/leftovers":self.service.leftover_action, "/recipes":self.service.recipe_action,
                   "/jobs":self.service.job_action, "/notifications":self.service.notification_action,
                   "/admin/content":self.service.admin_action, "/reports":self.service.report,
                   "/inventory/metadata":self.service.inventory_metadata, "/products/stock":self.service.product_stock,
                   "/profile/avatar":self.service.profile_avatar}
        resource = route.removeprefix("/api/v1")
        if resource=="/media" and method=="POST":
            return self.service.media_upload(user_id,body)
        match = re.fullmatch(r"/api/v1/media/([a-f0-9-]{36})", route)
        if match and method=="GET":
            return self.service.media(user_id, match[1])
        match = re.fullmatch(r"/api/v1/avatars/([a-f0-9-]{36})", route)
        if match and method=="GET":
            return self.service.avatar(user_id, match[1])
        media_match = re.fullmatch(r"/media/([a-f0-9-]{36})", resource)
        if media_match and method=="GET":
            return self.service.media_preview(user_id, media_match[1])
        if resource=="/recipes/import-url" and method=="POST":
            self.limiter.check("recipe-import:"+user_id,12)
            return self.service.import_url(user_id,body)
        if resource=="/recipes/import-review" and method=="POST":
            return self.service.import_review(user_id,body)
        if resource=="/analytics" and method=="POST":
            return self.service.analytics(user_id,body)
        if resource=="/entitlements/refresh" and method=="POST":
            return self.service.entitlements(user_id,refresh=True)
        if resource=="/evidence" and method=="GET":
            return self.service.evidence(user_id,query.get("q",[""])[0])
        if resource.startswith("/products/") and method=="GET":
            self.limiter.check("product:"+user_id,12)
            return self.service.product(user_id,resource.split("/")[-1])
        if resource in reads and method=="GET":
            return reads[resource](user_id)
        if resource in actions and method=="POST":
            return actions[resource](user_id,body,operation_key)
        if route=="/api/v1/catalog" and method=="GET":
            return self.service.catalog(user_id)
        if route=="/api/v1/auth/apple-authorization" and method=="POST":
            if self.development:
                raise DomainError("use_supabase_auth",404)
            from .identity import store_apple_authorization
            return store_apple_authorization(self.service.db,user_id,body.get("authorization_code"),body.get("platform","ios"))
        if route=="/api/v1/profile":
            if method=="GET":
                return self.service.get_profile(user_id)
            if method=="PUT":
                return self.service.save_profile(user_id,body,operation_key)
            if method=="DELETE":
                if body.get("confirm") is not True:
                    raise DomainError("deletion_confirmation_required",422)
                if not self.development:
                    self.auth.verify(token,recent=True)
                return self.service.delete_account(user_id)
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
        match = re.fullmatch(r"/api/v1/dinners/([a-f0-9-]{36})", route)
        if match and method=="GET":
            return self.service.dinner(user_id, match[1])
        match = re.fullmatch(r"/api/v1/dinners/([a-f0-9-]{36})/adaptive-servings", route)
        if match and method=="GET":
            return self.service.dinner_adaptive_servings(user_id, match[1])
        match = re.fullmatch(r"/api/v1/dinners/([a-f0-9-]{36})/invitations", route)
        if match and method=="POST":
            return self.service.dinner_invite_action(user_id, match[1], body, operation_key)
        match = re.fullmatch(r"/api/v1/foods/([a-f0-9-]{36})/compatibility",route)
        if match and method=="GET":
            return self.service.food_compatibility(user_id,match[1])
        match = re.fullmatch(r"/api/v1/foods/([a-f0-9-]{36})/photo",route)
        if match and method=="GET":
            return self.service.food_photo(user_id,match[1])
        if route=="/api/v1/cooking/preview" and method=="POST":
            return self.service.cooking_preview(user_id,body)
        if route=="/api/v1/cooking/confirm" and method=="POST":
            return self.service.cooking_confirm(user_id,body,operation_key)
        if route=="/api/v1/leftovers" and method=="GET":
            return self.service.leftovers(user_id)
        if route=="/api/v1/privacy/export" and method=="GET":
            return self.service.export_all(user_id)
        if route=="/api/v1/admin/catalog" and method=="GET":
            allowed = set(filter(None,os.getenv("ADMIN_USER_IDS","").split(",")))
            if user_id not in allowed:
                raise DomainError("forbidden",403)
            return self.service.catalog(user_id)
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
