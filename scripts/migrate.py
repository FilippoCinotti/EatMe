"""Apply immutable versioned PostgreSQL migrations with an owner credential."""
import hashlib
import os
from pathlib import Path

import psycopg

root = Path(__file__).resolve().parents[1]
with psycopg.connect(os.environ['MIGRATION_DATABASE_URL'],autocommit=True) as connection:
    connection.execute('CREATE TABLE IF NOT EXISTS eatme_migrations(name TEXT PRIMARY KEY,sha256 TEXT NOT NULL)')
    connection.execute('SELECT pg_advisory_lock(918731)')
    try:
        for file in sorted((root/'supabase/migrations').glob('*.sql')):
            source=file.read_text()
            checksum=hashlib.sha256(source.encode()).hexdigest()
            row=connection.execute('SELECT sha256 FROM eatme_migrations WHERE name=%s',(file.name,)).fetchone()
            if row:
                if row[0]!=checksum:
                    raise RuntimeError(f'Applied migration changed: {file.name}')
                continue
            # Transaction wrappers in the source also support direct psql application.
            source=source.replace('BEGIN;','',1)
            position=source.rfind('COMMIT;')
            source=source[:position]+source[position+len('COMMIT;'):] if position>=0 else source
            with connection.transaction():
                connection.execute(source)
                connection.execute('INSERT INTO eatme_migrations VALUES(%s,%s)',(file.name,checksum))
            print('Applied',file.name)
    finally:
        connection.execute('SELECT pg_advisory_unlock(918731)')
