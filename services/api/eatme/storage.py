from __future__ import annotations

import json
import os
import sqlite3
import threading
from contextlib import contextmanager
from pathlib import Path
from typing import Iterator


class Transaction:
    def __init__(self, connection, postgres: bool):
        self.connection, self.postgres = connection, postgres

    def execute(self, sql: str, values=()):
        if self.postgres:
            sql = sql.replace("?", "%s")
        return self.connection.execute(sql, values)

    def one(self, sql: str, values=()) -> dict | None:
        row = self.execute(sql, values).fetchone()
        return dict(row) if row is not None else None

    def all(self, sql: str, values=()) -> list[dict]:
        return [dict(row) for row in self.execute(sql, values).fetchall()]


class Database:
    """Short transactions; PostgreSQL serializes each household's mutations.

    SQLite's BEGIN IMMEDIATE serializes writers for the local development adapter.
    Production schema is applied by versioned migrations, never by app startup.
    """

    def __init__(self, url: str):
        self.url = url
        self.postgres = url.startswith(("postgresql://", "postgres://"))
        self._pool = None
        self._pool_lock = threading.Lock()

    def _postgres_pool(self):
        if self._pool is None:
            with self._pool_lock:
                if self._pool is None:
                    from psycopg.rows import dict_row
                    from psycopg_pool import ConnectionPool

                    size = int(os.getenv("DATABASE_POOL_MAX_SIZE", "5"))
                    if not 1 <= size <= 10:
                        raise RuntimeError("DATABASE_POOL_MAX_SIZE must be between 1 and 10")
                    self._pool = ConnectionPool(
                        conninfo=self.url,
                        min_size=0,
                        max_size=size,
                        timeout=10,
                        kwargs={"row_factory": dict_row},
                        open=True,
                    )
        return self._pool

    def connect(self):
        if self.postgres:
            return self._postgres_pool().getconn()
        connection = sqlite3.connect(self.url, timeout=15, isolation_level=None)
        connection.row_factory = sqlite3.Row
        connection.execute("PRAGMA foreign_keys=ON")
        connection.execute("PRAGMA busy_timeout=15000")
        return connection

    @contextmanager
    def transaction(self, household_id: str | None = None) -> Iterator[Transaction]:
        connection = self.connect()
        try:
            tx = Transaction(connection, self.postgres)
            if self.postgres:
                # Psycopg starts the transaction before this first statement.
                # An explicit BEGIN here would emit a warning for every request.
                tx.execute("SET LOCAL ROLE eatme_backend")
            else:
                tx.execute("BEGIN IMMEDIATE")
            if household_id and self.postgres:
                tx.execute("SELECT id FROM households WHERE id=? FOR UPDATE", (household_id,))
            yield tx
            connection.commit()
        except Exception:
            connection.rollback()
            raise
        finally:
            if self.postgres:
                self._postgres_pool().putconn(connection)
            else:
                connection.close()

    def migrate_local(self):
        if self.postgres or os.getenv("EATME_ENV", "development") != "development":
            raise RuntimeError("Local migrations are development-only")
        schema = Path(__file__).with_name("schema.sql").read_text()
        connection = self.connect()
        try:
            connection.executescript(schema)
            connection.executescript(Path(__file__).with_name("domain.sql").read_text())
        finally:
            connection.close()


def encode(value) -> str:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def decode(value: str):
    return json.loads(value)
