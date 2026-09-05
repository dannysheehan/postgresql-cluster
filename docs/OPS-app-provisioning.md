# Operations: application databases and access

How to provision databases and roles for external apps (Nextcloud, Vaultwarden, Home Assistant, etc.) against this cluster.

## Rules

1. **Always write through the VIP** (`cluster_vip`, currently `192.168.1.99:5432`). Never run DDL/DML against a standby — it is read-only.
2. **One app → one database + one dedicated role.** Do not share `postgres` or one DB across apps.
3. **Least privilege.** App roles: `NOSUPERUSER`, `NOCREATEDB`, `NOCREATEROLE`. Prefer DB ownership by the app role so migrations can run as that user.
4. **Keep app provisioning out of `site.yml`.** Cluster playbooks own Postgres/HA; app playbooks own databases/users.
5. **Secrets never in git.** Use ansible-vault and/or 1Password. Every task that touches passwords must use `no_log: true`.

## Provision with Ansible

Playbook: [`playbooks/provision_app_db.yml`](../playbooks/provision_app_db.yml)  
Example vars: [`vars/apps/example.yml`](../vars/apps/example.yml)

Copy the example and fill in names (and password source):

```bash
cp vars/apps/example.yml vars/apps/nextcloud.yml
# edit app_db_name, app_db_user, extensions, password source
```

### Vault (default)

Store the app password in encrypted vault, or pass it at runtime:

```bash
# password on the CLI (shell history risk — prefer vault/1Password)
uv run ansible-playbook -i inventory/hosts.yml playbooks/provision_app_db.yml \
  -e @vars/apps/nextcloud.yml \
  -e app_db_password='...' \
  --ask-vault-pass
```

Or add to `group_vars/all/vault.yml` (encrypted):

```yaml
# example — prefer per-app items in 1Password for many apps
vault_app_passwords:
  nextcloud: "..."
```

Then in `vars/apps/nextcloud.yml`:

```yaml
app_db_password: "{{ vault_app_passwords.nextcloud }}"
```

### 1Password

Requires `op` CLI and `OP_SERVICE_ACCOUNT_TOKEN` (or an interactive `op signin`) on the control machine.

In the app vars file:

```yaml
app_secrets_backend: onepassword
app_db_password_op_item: "Nextcloud-DB"
app_db_password_op_vault: "Homelab"
app_db_password_op_field: password
```

```bash
export OP_SERVICE_ACCOUNT_TOKEN=...
uv run ansible-playbook -i inventory/hosts.yml playbooks/provision_app_db.yml \
  -e @vars/apps/nextcloud.yml \
  --ask-vault-pass
```

Admin (`postgres`) password still comes from `vault_postgresql_superuser_password`.

## What the playbook does

Against the **VIP**, as `postgres`:

1. Create/update the app role (login, password, non-superuser flags).
2. Create the database owned by that role (UTF8, `C.UTF-8` collation — matches this cluster’s initdb).
3. Grant `ALL` on the database to the role.
4. Optionally create listed extensions (e.g. `uuid-ossp`, `pg_trgm`).

Re-runs are idempotent (safe after failover while the VIP still points at a writable primary).

## Connection strings for applications

Point apps at the VIP only:

```text
postgresql://APP_USER:SECRET@192.168.1.99:5432/APP_DB?sslmode=prefer
```

Optional libpq flag so clients refuse a read-only connection after a bad failover:

```text
...?sslmode=prefer&target_session_attrs=read-write
```

Store the URL in 1Password (or the app’s secret store), not in git.

## Schema / migrations

| Model | When to use |
| --- | --- |
| **App owns schema** (default) | Homelab apps that migrate as the app user. DB `OWNER` is the app role. |
| **Separate migrator role** | Stricter setups: migrator has DDL; runtime role is DML-only. |

This playbook implements app-owned schema. Extensions that need `shared_preload_libraries` belong in cluster config, not here.

## Read traffic

The VIP is the **primary** only. There is no read pool. If an app needs replica reads, give it a separate read-only URL to the current standby IP — do not use that for writes or provisioning.

## Checklist for a new app

1. Create password in vault or 1Password.
2. Add `vars/apps/<app>.yml`.
3. Run `provision_app_db.yml` (VIP reachable, cluster healthy).
4. Deploy the app with the VIP connection string.
5. Confirm writes: `psql "host=<VIP> user=<app> dbname=<db>" -c 'SELECT 1'`.

## Komodo / FerretDB

Komodo on Postgres needs the **DocumentDB** extension (not only an app DB). See [OPS-documentdb-komodo.md](OPS-documentdb-komodo.md) and `playbooks/enable_documentdb.yml`.
