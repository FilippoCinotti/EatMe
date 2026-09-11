"""Provider boundary for later inventory/evidence milestones. Not a running queue."""
from dataclasses import dataclass
from typing import Literal, Protocol


@dataclass(frozen=True)
class Detection:
    food_candidate_id: str | None
    display_name: str
    quantity: str | None
    unit: Literal['g','ml','pcs'] | None
    confidence: float
    provenance: Literal['vision','package_ocr','receipt']
    requires_confirmation: bool = True

    def __post_init__(self):
        if not 0<=self.confidence<=1:
            raise ValueError('Confidence outside [0,1]')
        if not self.requires_confirmation:
            raise ValueError('Unconfirmed detections cannot be committed')


class AIProvider(Protocol):
    async def analyze_food_photo(self,image:bytes) -> list[Detection]:
        ...
    async def parse_receipt(self,image:bytes) -> list[Detection]:
        ...


class ProductProvider(Protocol):
    async def lookup_barcode(self,barcode:str) -> dict | None:
        ...


class UnconfiguredAIProvider:
    async def analyze_food_photo(self,image:bytes) -> list[Detection]:
        raise RuntimeError('AI provider not configured; use manual entry')
    async def parse_receipt(self,image:bytes) -> list[Detection]:
        raise RuntimeError('Receipt provider not configured; use manual entry')
