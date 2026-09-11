"""Dependency-free static checks; these do not replace Flutter/SQL/TypeScript builds."""
import ast
import json
import re
from pathlib import Path

root=Path(__file__).resolve().parents[1]
python_files=[*root.glob('services/**/*.py'),*root.glob('scripts/*.py')]
for source in python_files:
    ast.parse(source.read_text(),filename=str(source))
resources=root/'apps/mobile/assets/l10n'
it=json.loads((resources/'it.json').read_text())
en=json.loads((resources/'en.json').read_text())
assert set(it)==set(en),'Localization key sets differ'
for key in en:
    assert set(re.findall(r'\{([^}]+)\}',en[key]))==set(re.findall(r'\{([^}]+)\}',it[key])),key
for source in root.glob('apps/mobile/lib/**/*.dart'):
    for key in re.findall(r"\.t\('([a-z0-9_]+)'",source.read_text()):
        assert key in en or key.endswith('_'),f'Missing localization: {key}'
for source in root.rglob('*.json'):
    if not {'node_modules','.next','.dart_tool'} & set(source.parts):
        json.loads(source.read_text())
schema=(root/'services/api/eatme/schema.sql').read_text()
migration=(root/'supabase/migrations/202609100001_core.sql').read_text()
assert schema in migration,'SQLite baseline differs from PostgreSQL baseline'
assert (root/'docs/product/specification.md').is_file()
print(f'PASS: {len(python_files)} Python sources parsed; {len(en)} bilingual keys; JSON resources and baseline schema checked.')
print('Flutter, TypeScript, FastAPI and PostgreSQL require their separate runtime checks.')
