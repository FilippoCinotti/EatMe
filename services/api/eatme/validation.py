"""Shared boundary validation for both the FastAPI and local transports."""
from datetime import date
from decimal import Decimal, InvalidOperation
from uuid import UUID, uuid4

from .errors import DomainError


def new_id() -> str:
    return str(uuid4())


def valid_uuid(value) -> str:
    try:
        return str(UUID(value))
    except (TypeError, ValueError, AttributeError):
        raise DomainError("invalid_identifier", 422) from None


def valid_date(value) -> str | None:
    if value is None or value == "":
        return None
    try:
        parsed = date.fromisoformat(value)
        if parsed.isoformat() != value:
            raise ValueError
        return value
    except (ValueError, TypeError):
        raise DomainError("invalid_date", 422) from None


def text(value, *, maximum=240, empty=False, code="invalid_text") -> str:
    if not isinstance(value, str) or len(value.strip()) > maximum or (not empty and not value.strip()):
        raise DomainError(code, 422)
    return value.strip()


def integer(value, minimum=0, maximum=100, code="invalid_number") -> int:
    if type(value) is not int or not minimum <= value <= maximum:
        raise DomainError(code, 422)
    return value


def choice(value, options, code="invalid_option"):
    if not isinstance(value, str) or value not in options:
        raise DomainError(code, 422)
    return value


def decimal(value, *, maximum=1_000_000, zero=True) -> Decimal:
    try:
        if isinstance(value, bool):
            raise InvalidOperation
        number = Decimal(str(value))
        if not number.is_finite() or number < 0 or number > maximum or (not zero and not number):
            raise InvalidOperation
        return number
    except (InvalidOperation, ValueError, TypeError):
        raise DomainError("invalid_number", 422) from None
