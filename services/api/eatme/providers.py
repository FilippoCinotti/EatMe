"""Bounded server-side adapters. Provider data is untrusted input."""
import http.client
import ipaddress
import json
import os
import socket
import ssl
from decimal import Decimal, InvalidOperation
from urllib.parse import urljoin, urlsplit

from .errors import DomainError


class PinnedHTTPS(http.client.HTTPSConnection):
    def __init__(self, hostname, address):
        super().__init__(hostname, timeout=15, context=ssl.create_default_context())
        self.address = address

    def connect(self):
        # Connect to the address that passed validation, retaining TLS hostname checks.
        sock = socket.create_connection((self.address, 443), self.timeout)
        self.sock = self._context.wrap_socket(sock, server_hostname=self.host)


def https_request(url, *, method="GET", body=None, headers=None, maximum=2_000_000, redirects=3):
    parts = urlsplit(url)
    if parts.scheme != "https" or not parts.hostname or parts.username or parts.password or parts.port not in (None, 443):
        raise DomainError("invalid_public_url", 422)
    try:
        addresses = {r[4][0] for r in socket.getaddrinfo(parts.hostname, 443, type=socket.SOCK_STREAM)}
        if not addresses or any(not ipaddress.ip_address(a).is_global for a in addresses):
            raise DomainError("invalid_public_url", 422)
        connection = PinnedHTTPS(parts.hostname, sorted(addresses)[0])
        try:
            connection.request(method, (parts.path or "/") + ("?" + parts.query if parts.query else ""), body=body, headers={"User-Agent": "EatMe/1.0", "Accept-Encoding": "identity", **(headers or {})})
            response = connection.getresponse()
            if response.status in {301, 302, 303, 307, 308}:
                if not redirects or method != "GET" or (headers and "Authorization" in headers):
                    raise DomainError("provider_redirect_rejected", 502)
                return https_request(urljoin(url, response.getheader("Location", "")), maximum=maximum, redirects=redirects-1)
            payload = response.read(maximum + 1)
            if len(payload) > maximum:
                raise DomainError("provider_response_too_large", 502)
            if response.status == 404:
                raise DomainError("provider_not_found", 404)
            if response.status == 429:
                raise DomainError("provider_rate_limited", 429)
            if not 200 <= response.status < 300:
                raise DomainError("provider_unavailable", 502)
            return payload
        finally:
            connection.close()
    except (OSError, ValueError, http.client.HTTPException):
        raise DomainError("provider_unavailable", 502) from None


def json_request(url, **kwargs):
    try:
        return json.loads(https_request(url, **kwargs))
    except (ValueError, UnicodeError):
        raise DomainError("invalid_provider_response", 502) from None


def barcode(value):
    if not isinstance(value, str) or not value.isascii() or not value.isdigit() or len(value) not in {8, 12, 13, 14}:
        raise DomainError("invalid_barcode", 422)
    check = sum(int(d) * (3 if i % 2 == 0 else 1) for i, d in enumerate(reversed(value[:-1])))
    if (10 - check % 10) % 10 != int(value[-1]):
        raise DomainError("invalid_barcode", 422)
    return value


def nutrition(product):
    source = product.get("nutriments", {})
    values = {}
    for name, field, unit in [("energy", "energy-kcal", "kcal"), ("protein", "proteins", "g"), ("carbohydrates", "carbohydrates", "g"), ("sugars", "sugars", "g"), ("fat", "fat", "g"), ("saturated_fat", "saturated-fat", "g"), ("fiber", "fiber", "g"), ("salt", "salt", "g"), ("sodium", "sodium", "g")]:
        try:
            value = Decimal(str(source.get(field + "_100g")))
            if not value.is_finite() or value < 0 or value > (1000 if unit == "kcal" else 100):
                continue
            values[name] = {"value": str(value), "unit": unit, "derived": False}
        except InvalidOperation:
            continue
    if "salt" in values and "sodium" not in values:
        values["sodium"] = {"value": str(Decimal(values["salt"]["value"]) / Decimal("2.5")), "unit": "g", "derived": True}
    return {"basis": "100ml" if product.get("nutrition_data_per") == "100ml" else "100g", "values": values, "source": "Open Food Facts", "verified": False}


class OpenFoodFacts:
    def lookup(self, code):
        code = barcode(code)
        contact = os.getenv("PRODUCT_CONTACT", "")
        if not contact:
            raise DomainError("product_provider_not_configured", 503)
        data = json_request("https://world.openfoodfacts.org/api/v3.6/product/" + code + ".json", headers={"User-Agent": "EatMe/1.0 (" + contact + ")"})
        product = data.get("product")
        if not isinstance(product, dict):
            raise DomainError("product_not_found", 404)
        return {"barcode": code, "name": str(product.get("product_name", ""))[:240], "brand": str(product.get("brands", ""))[:240], "ingredients_text": str(product.get("ingredients_text", ""))[:8000], "allergens": product.get("allergens_tags", []), "traces": product.get("traces_tags", []), "nutrition": nutrition(product), "additives": product.get("additives_tags", []), "source_url": "https://world.openfoodfacts.org/product/" + code, "attribution": "Open Food Facts contributors · ODbL", "needs_confirmation": True}
