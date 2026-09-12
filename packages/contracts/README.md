# API contracts

The FastAPI adapter defines HTTP routes and typed core request bodies. Action-based domain endpoints validate fields in the shared service boundary so the development and production adapters apply identical rules.

Run `python packages/contracts/export_openapi.py` in an environment with API dependencies to export the schema. Every mutation that changes domain records uses `Idempotency-Key` with a UUID and optimistic resource versions where applicable. Responses use a stable `error.code`; never infer success from a network timeout.
