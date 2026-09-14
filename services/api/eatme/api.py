"""FastAPI HTTP adapter. Live JWT integration needs configured Supabase keys."""
from typing import Literal
from uuid import uuid4

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, RedirectResponse
from pydantic import BaseModel, ConfigDict, Field

from .errors import DomainError
from .transport import configured_router


class StrictBody(BaseModel):
    model_config = ConfigDict(extra="forbid")


class Credentials(StrictBody):
    email: str = Field(max_length=240)
    password: str = Field(min_length=12,max_length=128)


class Assignment(StrictBody):
    diet_id: str
    strictness: Literal["flexible","standard","strict"] = "standard"


class ProfileInput(StrictBody):
    name: str = Field(min_length=1,max_length=80)
    adult_confirmed: bool
    household_size: int = Field(default=1,ge=1,le=20)
    timezone: str = "Europe/Rome"
    diets: list[Assignment] = Field(default_factory=list,max_length=8)
    allergies: list[str] = Field(default_factory=list)
    intolerances: list[str] = Field(default_factory=list)
    never_suggest: list[str] = Field(default_factory=list)
    health_consent_version: str | None = None
    medical_consent_version: str | None = None
    expected_version: int | None = None


class InventoryInput(StrictBody):
    food_id: str
    quantity: str
    location: Literal["fridge","freezer","pantry"] = "fridge"
    expiry_date: str | None = None
    expiry_kind: Literal["unknown","use_by","best_before","estimated"] = "unknown"


class InventoryChange(StrictBody):
    expected_version: int
    action: Literal["consumed","discarded","corrected","moved","opened"]
    quantity: str | None = None
    location: Literal["fridge","freezer","pantry"] | None = None


class CookingInput(StrictBody):
    recipe_id: str
    servings: int = Field(ge=1,le=20)
    consumption: dict[str,str] = Field(default_factory=dict)
    participants: list[str] | None = Field(default=None,max_length=20)


class CookingConfirmation(CookingInput):
    participant_versions: dict[str,int] | None = None
    profile_version: int
    diet_rules_version: dict[str,int]
    batch_versions: dict[str,int]
    leftover_servings: int = Field(default=0,ge=0,le=20)
    leftover_use_date: str | None = None


class DeleteInput(StrictBody):
    confirm: bool


def create_app(router=None):
    import os
    router = router or configured_router()
    app = FastAPI(title="EatMe API",version="1.0.0",docs_url="/docs" if router.development else None)
    origins = list(filter(None,os.getenv("CORS_ORIGINS","http://localhost:3000").split(",")))
    app.add_middleware(CORSMiddleware,allow_origins=origins,allow_methods=["GET","POST","PUT","PATCH","DELETE"],
                       allow_headers=["Authorization","Content-Type","Idempotency-Key"])

    @app.middleware("http")
    async def headers(request:Request,call_next):
        # Header screening plus streamed size validation in the ASGI boundary.
        body = bytearray()
        async for chunk in request.stream():
            body.extend(chunk)
            if len(body)>(6_000_000 if request.url.path == "/api/v1/media" else 262144):
                return JSONResponse({"error":{"code":"payload_too_large"}},status_code=413)
        request._body = bytes(body)
        response = await call_next(request)
        response.headers["X-Request-ID"] = str(uuid4())
        response.headers["Cache-Control"] = "no-store"
        response.headers["X-Content-Type-Options"] = "nosniff"
        return response

    @app.exception_handler(DomainError)
    async def domain_error(request,error):
        return JSONResponse(error.payload(),status_code=error.status)

    def dispatch(request,body=None):
        return router.dispatch(request.method,str(request.url.path)+(f"?{request.url.query}" if request.url.query else ""),body,
            request.headers.get("Authorization",""),request.headers.get("Idempotency-Key",""),
            request.client.host if request.client else "unknown")

    @app.post("/api/v1/auth/apple/callback", include_in_schema=False)
    async def apple_callback(request: Request):
        from urllib.parse import parse_qs, urlencode
        router.limiter.check("apple-callback:" + (request.client.host if request.client else "unknown"), 30)
        raw = await request.body()
        if len(raw) > 16000 or request.headers.get("content-type", "").split(";")[0] != "application/x-www-form-urlencoded":
            raise DomainError("invalid_apple_authorization", 422)
        fields = parse_qs(raw.decode("utf-8", errors="replace"), max_num_fields=10)
        # Forward only protocol fields to a fixed application package. The client
        # validates state/nonce and Supabase verifies the signed identity token.
        allowed = {k: v[0] for k, v in fields.items() if k in {"code", "id_token", "state", "error"} and len(v) == 1}
        if not allowed.get("state"):
            raise DomainError("invalid_apple_authorization", 422)
        return RedirectResponse("intent://callback?" + urlencode(allowed) + "#Intent;package=com.filippocinotti.eatme;scheme=signinwithapple;end", status_code=303)

    # GET endpoints share a transport; OpenAPI path parameter names remain explicit.
    @app.get("/api/v1/health")
    @app.get("/api/v1/config")
    @app.get("/api/v1/catalog")
    @app.get("/api/v1/profile")
    @app.get("/api/v1/inventory")
    @app.get("/api/v1/recommendations")
    @app.get("/api/v1/leftovers")
    @app.get("/api/v1/privacy/export")
    @app.get("/api/v1/admin/catalog")
    def get_resource(request:Request):
        return dispatch(request)

    @app.get("/api/v1/recipes/{recipe_id}")
    def recipe(recipe_id:str,request:Request):
        return dispatch(request)

    @app.get("/api/v1/foods/{food_id}/compatibility")
    def food(food_id:str,request:Request):
        return dispatch(request)

    @app.post("/api/v1/auth/register")
    @app.post("/api/v1/auth/login")
    def credentials(body:Credentials,request:Request):
        return dispatch(request,body.model_dump(exclude_none=True))

    @app.post("/api/v1/auth/logout")
    def logout(request:Request):
        return dispatch(request)

    @app.put("/api/v1/profile")
    def profile(body:ProfileInput,request:Request):
        return dispatch(request,body.model_dump(exclude_none=True))

    @app.post("/api/v1/inventory")
    def inventory(body:InventoryInput,request:Request):
        return dispatch(request,body.model_dump(exclude_none=True))

    @app.patch("/api/v1/inventory/{batch_id}")
    def change_inventory(batch_id:str,body:InventoryChange,request:Request):
        return dispatch(request,body.model_dump(exclude_none=True))

    @app.post("/api/v1/cooking/preview")
    def preview(body:CookingInput,request:Request):
        return dispatch(request,body.model_dump(exclude_none=True))

    @app.post("/api/v1/cooking/confirm")
    def confirm(body:CookingConfirmation,request:Request):
        return dispatch(request,body.model_dump(exclude_none=True))

    @app.delete("/api/v1/profile")
    def delete(body:DeleteInput,request:Request):
        return dispatch(request,body.model_dump())

    # Domain commands validate action-specific fields at the shared service boundary.
    for resource in ("shopping", "plans", "households", "preferences", "leftovers", "recipes", "jobs", "notifications", "insights", "entitlements", "recalls", "evidence", "admin/content"):
        app.add_api_route("/api/v1/"+resource, get_resource, methods=["GET"], name=resource+"_list") if resource != "leftovers" else None

    def domain_command(body:dict,request:Request):
        return dispatch(request,body)

    for resource in ("shopping", "plans", "households", "preferences", "leftovers", "recipes", "jobs", "notifications", "admin/content", "reports", "inventory/metadata", "media", "recipes/import-url", "recipes/import-review", "analytics", "entitlements/refresh", "products/stock", "auth/apple-authorization"):
        app.add_api_route("/api/v1/"+resource, domain_command, methods=["POST"], name=resource+"_command")
    app.add_api_route("/api/v1/products/{code}", get_resource, methods=["GET"], name="product_lookup")
    return app
