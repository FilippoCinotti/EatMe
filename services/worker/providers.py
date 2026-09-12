"""Provider contracts shared by queue workers and evaluation fixtures."""
from typing import Protocol


class AIProvider(Protocol):
    def run(self, kind: str, payload: dict, foods: dict, image: bytes | None = None) -> dict:
        """Return untrusted structured candidates; the service validates them."""
        ...


class ProductProvider(Protocol):
    def lookup(self, code: str) -> dict:
        """Return source-attributed product data, never a dietary guarantee."""
        ...
