"""Generate the API contract after installing services/api dependencies."""
import json
from pathlib import Path
from eatme.api import create_app

# Generating metadata must not create accounts, seed files or contact Supabase.
class ContractOnlyRouter:
    development=True

destination=Path(__file__).with_name('openapi.json')
destination.write_text(json.dumps(create_app(ContractOnlyRouter()).openapi(),indent=2)+'\n')
print(destination)
