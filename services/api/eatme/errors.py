class DomainError(Exception):
    def __init__(self, code: str, status: int = 400, details: dict | None = None):
        self.code, self.status, self.details = code, status, details or {}
        super().__init__(code)

    def payload(self) -> dict:
        return {"error": {"code": self.code, "details": self.details}}
