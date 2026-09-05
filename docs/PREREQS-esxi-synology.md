# Prerequisites: ESXi + Synology

Complete these before running `playbooks/site.yml` against real hosts.

## ESXi guests

- Two Ubuntu Server **24.04** VMs with local disk for PGDATA (`/var/lib/postgresql`)
- Same L2 VLAN / subnet (required for Keepalived VIP)
- Static IPs for both nodes + one unused IP for the VIP
- SSH as a sudo-capable user from your Ansible control host
- Optional: anti-affinity / separate datastores if you care about correlated failure

Suggested sizing (homelab): 2–4 vCPU, 4–8 GB RAM, 40+ GB disk each.

## Inventory

Edit `inventory/hosts.yml`:

- `ansible_host` for each node
- `cluster_vip` / `postgresql_allowed_cidrs`
- `keepalived_interface` (often `ens192` on VMware)
- Synology NFS: `pgbackrest_nfs_server`, `pgbackrest_nfs_export`
- `pgbackrest_use_nfs: true` and `pgbackrest_repo_path: "{{ pgbackrest_nfs_mount }}"`

## Synology NFS (backups only)

**Never** put live PGDATA on NFS.

DSM → Shared Folder → NFS permissions:

- Privilege: Read/Write
- Squash: map to admin (or set anonuid/anongid)
- **anonuid / anongid:** match the `postgres` UID/GID on the Ubuntu hosts (`id postgres`)
- Security: sys
- Prefer NFSv4

Mount options applied by Ansible (defaults; Synology often needs **nfsvers=4.0**, not 4.1):

```
nfsvers=4.0,proto=tcp,hard,intr,rw,rsize=1048576,wsize=1048576,noatime,timeo=600,retrans=2,_netdev
```

Export the Synology shared folder root (e.g. `/volume1/nfs`) and put the stanza under a subdirectory (`pg_backups`). Configure in `inventory/group_vars/postgres_cluster.yml`.

## Secrets

```bash
cp group_vars/all/vault.yml.example group_vars/all/vault.yml
# edit passwords
ansible-vault encrypt group_vars/all/vault.yml
```

## First deploy

```bash
make bootstrap-dev   # once on the control host (requires uv)
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --ask-vault-pass
```

Or with uv directly:

```bash
uv sync
uv run ansible-galaxy collection install -r requirements.yml -p collections
uv run ansible-playbook -i inventory/hosts.yml playbooks/site.yml --ask-vault-pass
```

Gate on lab first: `make test && make test-failover`.
