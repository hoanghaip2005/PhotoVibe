from typing import Any

import httpx
from psycopg import AsyncConnection, rows, sql
from psycopg.types.json import Jsonb

from ..config import Settings
from ..errors import AppError


class SupabaseRepository:
    def __init__(self, settings: Settings) -> None:
        self.settings = settings

    @property
    def _rest_url(self) -> str:
        return f"{self.settings.supabase_url.rstrip('/')}/rest/v1"

    @property
    def _headers(self) -> dict[str, str]:
        key = self.settings.supabase_service_role_key
        return {
            "apikey": key,
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
            "Prefer": "return=representation",
        }

    def _ensure_configured(self) -> None:
        if not self.settings.has_supabase:
            raise AppError(
                "SUPABASE_NOT_CONFIGURED",
                "Supabase REST keys or SUPABASE_DB_URL are missing.",
                status_code=503,
            )

    async def _connection(self) -> AsyncConnection:
        self._ensure_configured()
        if not self.settings.has_pgvector:
            raise AppError(
                "SUPABASE_DB_NOT_CONFIGURED",
                "SUPABASE_DB_URL or DATABASE_URL is missing.",
                status_code=503,
            )
        return await AsyncConnection.connect(
            self.settings.supabase_db_url,
            autocommit=True,
            row_factory=rows.dict_row,
        )

    async def insert(self, table: str, payload: dict[str, Any]) -> dict[str, Any]:
        self._ensure_configured()
        if not self.settings.has_supabase_rest:
            return await self._insert_postgres(table, payload)
        async with httpx.AsyncClient(timeout=20) as client:
            response = await client.post(
                f"{self._rest_url}/{table}",
                headers=self._headers,
                json=payload,
            )
        if response.status_code >= 400:
            raise AppError(
                "SUPABASE_INSERT_FAILED",
                f"Could not insert into {table}.",
                status_code=502,
                details=response.text[:500],
            )
        data = response.json()
        return data[0] if isinstance(data, list) and data else {}

    async def update(
        self,
        table: str,
        filters: dict[str, str],
        payload: dict[str, Any],
    ) -> list[dict[str, Any]]:
        self._ensure_configured()
        if not self.settings.has_supabase_rest:
            return await self._update_postgres(table, filters, payload)
        params = {key: f"eq.{value}" for key, value in filters.items()}
        async with httpx.AsyncClient(timeout=20) as client:
            response = await client.patch(
                f"{self._rest_url}/{table}",
                headers=self._headers,
                params=params,
                json=payload,
            )
        if response.status_code >= 400:
            raise AppError(
                "SUPABASE_UPDATE_FAILED",
                f"Could not update {table}.",
                status_code=502,
                details=response.text[:500],
            )
        return response.json()

    async def select(
        self,
        table: str,
        filters: dict[str, str] | None = None,
        limit: int = 20,
        offset: int = 0,
        order: str = "created_at.desc",
    ) -> list[dict[str, Any]]:
        self._ensure_configured()
        if not self.settings.has_supabase_rest:
            return await self._select_postgres(table, filters, limit, offset, order)
        params: dict[str, str | int] = {
            "select": "*",
            "limit": limit,
            "offset": offset,
            "order": order,
        }
        for key, value in (filters or {}).items():
            params[key] = f"eq.{value}"
        async with httpx.AsyncClient(timeout=20) as client:
            response = await client.get(
                f"{self._rest_url}/{table}",
                headers=self._headers,
                params=params,
            )
        if response.status_code >= 400:
            raise AppError(
                "SUPABASE_SELECT_FAILED",
                f"Could not select from {table}.",
                status_code=502,
                details=response.text[:500],
            )
        return response.json()

    async def maybe_user_preferences(self, user_id: str | None) -> dict[str, Any] | None:
        if not user_id or not self.settings.has_supabase:
            return None
        rows = await self.select(
            "user_music_preferences",
            filters={"user_id": user_id},
            limit=1,
        )
        return rows[0] if rows else None

    async def _insert_postgres(self, table: str, payload: dict[str, Any]) -> dict[str, Any]:
        columns = list(payload.keys())
        statement = sql.SQL(
            "insert into {table} ({columns}) values ({placeholders}) returning *"
        ).format(
            table=sql.Identifier(table),
            columns=sql.SQL(", ").join(sql.Identifier(column) for column in columns),
            placeholders=sql.SQL(", ").join(sql.Placeholder() for _ in columns),
        )
        values = [self._adapt_value(payload[column]) for column in columns]
        async with await self._connection() as connection:
            async with connection.cursor() as cursor:
                await cursor.execute(statement, values)
                row = await cursor.fetchone()
        return dict(row) if row else {}

    async def _update_postgres(
        self,
        table: str,
        filters: dict[str, str],
        payload: dict[str, Any],
    ) -> list[dict[str, Any]]:
        assignments = [
            sql.SQL("{} = {}").format(sql.Identifier(column), sql.Placeholder())
            for column in payload.keys()
        ]
        where_clauses = [
            sql.SQL("{} = {}").format(sql.Identifier(column), sql.Placeholder())
            for column in filters.keys()
        ]
        statement = sql.SQL(
            "update {table} set {assignments} where {where} returning *"
        ).format(
            table=sql.Identifier(table),
            assignments=sql.SQL(", ").join(assignments),
            where=sql.SQL(" and ").join(where_clauses),
        )
        values = [self._adapt_value(value) for value in payload.values()] + list(
            filters.values()
        )
        async with await self._connection() as connection:
            async with connection.cursor() as cursor:
                await cursor.execute(statement, values)
                rows = await cursor.fetchall()
        return [dict(row) for row in rows]

    async def _select_postgres(
        self,
        table: str,
        filters: dict[str, str] | None,
        limit: int,
        offset: int,
        order: str,
    ) -> list[dict[str, Any]]:
        values: list[Any] = []
        where = sql.SQL("")
        filter_items = list((filters or {}).items())
        if filter_items:
            where = sql.SQL(" where ") + sql.SQL(" and ").join(
                sql.SQL("{} = {}").format(sql.Identifier(column), sql.Placeholder())
                for column, _ in filter_items
            )
            values.extend(value for _, value in filter_items)
        statement = sql.SQL(
            "select * from {table}{where} {order} limit {limit} offset {offset}"
        ).format(
            table=sql.Identifier(table),
            where=where,
            order=self._order_clause(order),
            limit=sql.Placeholder(),
            offset=sql.Placeholder(),
        )
        values.extend([limit, offset])
        async with await self._connection() as connection:
            async with connection.cursor() as cursor:
                await cursor.execute(statement, values)
                rows = await cursor.fetchall()
        return [dict(row) for row in rows]

    def _order_clause(self, order: str) -> sql.Composed:
        column, _, direction = order.partition(".")
        if not column:
            column = "created_at"
        direction_sql = sql.SQL("asc") if direction.lower() == "asc" else sql.SQL("desc")
        return sql.SQL("order by {} {}").format(sql.Identifier(column), direction_sql)

    @staticmethod
    def _adapt_value(value: Any) -> Any:
        if isinstance(value, dict):
            return Jsonb(value)
        return value
