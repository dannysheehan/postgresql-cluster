# Operations: FerretDB DocumentDB (Komodo)

Handover aligned with the DocumentDB Enablement artifact (revised 1 Sep) — PostgreSQL 16 / Ubuntu 24.04 / VIP `192.168.1.99`.

Komodo speaks MongoDB wire protocol; FerretDB translates to SQL and needs the **DocumentDB** extension in the database it connects to (`postgres` on this cluster).

## Status

| Item | Status |
| --- | --- |
| Network `tcp/5432` from Swarm | Ready |
| PostgreSQL 16.15 | Ready |
| Role/DB `komodo_user` / `komodo` | Ready (app DB unused by FerretDB) |
| SCRAM auth | Ready |
| DocumentDB extension in `postgres` | Done |
| `documentdb_admin_role` → `komodo_user` + write probe | Done (step 6) |
| Scoped `pg_hba` for FerretDB | Done (step 7) |

## Apply / re-apply

```bash
# Full install + rolling restart + grants + verify
uv run ansible-playbook -i inventory/hosts.yml playbooks/enable_documentdb.yml

# Grants + app-user smoke test only (no restart)
uv run ansible-playbook -i inventory/hosts.yml playbooks/enable_documentdb.yml \
  --start-at-task='Configure DocumentDB extension'

# Deploy scoped pg_hba (reload) after inventory change
uv run ansible-playbook -i inventory/hosts.yml playbooks/site.yml --tags postgresql
# or re-run the postgresql role / template deploy + reload
```

Pinned package (checksum enforced when `documentdb_deb_checksum` is set):

`ubuntu24.04-postgresql-16-documentdb_0.107.0.ferretdb.2.7.0_amd64.deb`  
`sha256:c13cdcdbc18998db7ddec92d01f56b1e09fe45ce015ec51ff2e08a0f5267f723`

## postgresql.conf (steps 1–5)

```text
shared_preload_libraries = 'pg_cron,pg_documentdb_core,pg_documentdb'
cron.database_name = 'postgres'
documentdb.enableCompact = on
documentdb.enableLetAndCollationForQueryMatch = on
documentdb.enableNowSystemVariable = on
documentdb.enableSortbyIdPushDownToPrimaryKey = on
documentdb.enableSchemaValidation = on
documentdb.enableBypassDocumentValidation = on
documentdb.enableUserCrud = on
documentdb.maxUserLimit = 100
```

Then `CREATE EXTENSION documentdb CASCADE;` in **`postgres`**. Upgrade DocumentDB and FerretDB **together** (here: DocumentDB `0.107.0` ↔ FerretDB `2.7.0`).

## Step 6 — grants (non-superuser app role)

DocumentDB API functions are **not** `SECURITY DEFINER`, so callers need real table rights. Static `GRANT` lists go stale as DocumentDB creates a table per collection at runtime. Use the extension’s purpose-built role instead:

```sql
-- FerretDB startup SET (issue #4997) — separate from role membership
GRANT SET ON PARAMETER documentdb.maxUserLimit TO komodo_user;

GRANT documentdb_admin_role TO komodo_user;
GRANT USAGE ON SCHEMA documentdb_data TO komodo_user;
```

(`documentdb_admin_role` is `NOSUPERUSER` / `NOLOGIN` — keeps `komodo_user` non-superuser.)

## Step 7 — pg_hba

```text
host    postgres    komodo_user    192.168.1.0/24    scram-sha-256
```

Plus localhost **trust** for DocumentDB/pg_cron passwordless reconnects (`postgresql_local_trust_hba_entries`): `documentdb_bg_worker_role`, `postgres`, and `komodo_user` on `127.0.0.1/::1` for DB `postgres`. Without these, `drop_collection` and cron index jobs fail with `fe_sendauth: no password supplied`.

## Verification (as `komodo_user` on `postgres`)

Extension list / `SET documentdb.maxUserLimit` are necessary but **not sufficient** — they pass while writes still fail. The real test is a write:

```bash
PGPASSWORD='…' psql "postgresql://komodo_user@192.168.1.99:5432/postgres" -v ON_ERROR_STOP=1 <<'SQL'
SET documentdb.maxUserLimit TO 100;
SELECT documentdb_api.insert_one('ferretprobe','probe','{"_id":"t1","ok":true}');
SELECT documentdb_api.drop_collection('ferretprobe','probe');
SQL
```

## FerretDB connection

```text
FERRETDB_POSTGRESQL_URL=postgres://komodo_user:<password>@192.168.1.99:5432/postgres
```

Notes from the artifact:

- FerretDB targets **`postgres`**, not the separately created `komodo` database (leave/repurpose/drop that DB as you like).
- Do not put other applications in `postgres`.
- Keep the Komodo DB password distinct from other Postgres passwords in 1Password.
- FerretDB stays on the Swarm — only PostgreSQL `5432` crosses the network, not `27017`.
