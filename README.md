# PostgreSQL 2-node active/passive cluster (Ansible)

[![CI](https://github.com/dannysheehan/postgresql-cluster/actions/workflows/ci.yml/badge.svg)](https://github.com/dannysheehan/postgresql-cluster/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Ansible](https://img.shields.io/badge/ansible--core-2.16%20%E2%80%93%202.18-blue)](pyproject.toml)

Native PostgreSQL streaming replication with a Keepalived VIP, automated with
Ansible. Two nodes, one writable primary and one hot standby, with pgBackRest
backups to local disk or NFS. Failover is **operator-initiated**: the VIP only
follows a node that is already writable, so the cluster never promotes itself.

Tested locally with **Molecule + Vagrant/libvirt (KVM)** before ESXi deploy.

## What this gives you

- PostgreSQL 16 (PGDG) on Ubuntu 24.04, primary + streaming standby
- Keepalived VIP that tracks "is this node writable", not just "is it up"
- pgBackRest stanza, WAL archiving, and scheduled full backups
- Runbooks for failover, planned switchover, and rolling patches
- Playbooks to provision per-app databases and roles through the VIP
- A two-VM Molecule lab that runs without any of your real credentials

## What this is not

Not an auto-failover system. There is no consensus layer, no witness node, and
no fencing agent beyond "stop the old primary over SSH". A two-node cluster
cannot distinguish a dead peer from a partitioned one, so promotion is a
deliberate human action via `playbooks/failover.yml`. If you need automatic
failover, use Patroni or repmgr with a proper quorum.

## Quick start (lab)

Requires [uv](https://docs.astral.sh/uv/) (`curl -LsSf https://astral.sh/uv/install.sh | sh`).

```bash
make bootstrap-dev     # uv installs Python 3.12, syncs deps, Galaxy collections
make test              # full create → converge → verify → destroy
make test-failover     # promote drill
```

Interactive Vagrant lab:

```bash
make lab-up
make site-lab
make lab-down
```

## First deploy (ESXi)

0. Bootstrap VMs (once): [docs/BOOTSTRAP-hosts.md](docs/BOOTSTRAP-hosts.md) — `make bootstrap-host` (uses `-K` for sudo password)
1. Mount the data disk on both nodes — [docs/STORAGE-data-disk.md](docs/STORAGE-data-disk.md) or `playbooks/prepare_data_disk.yml`
2. Edit [inventory/group_vars/postgres_cluster.yml](inventory/group_vars/postgres_cluster.yml) for VIP, NFS, and CIDRs (not `inventory/hosts.yml` `vars:` — those lose to `group_vars/all`).
2. Copy secrets: `cp group_vars/all/vault.yml.example group_vars/all/vault.yml` and encrypt with `ansible-vault`.
3. `ansible-playbook -i inventory/hosts.yml playbooks/site.yml`

See [docs/PREREQS-esxi-synology.md](docs/PREREQS-esxi-synology.md), [docs/LAB-molecule-kvm.md](docs/LAB-molecule-kvm.md), [docs/OPS-app-provisioning.md](docs/OPS-app-provisioning.md), [docs/OPS-documentdb-komodo.md](docs/OPS-documentdb-komodo.md), and the runbooks under `docs/`.

## Layout

| Path | Purpose |
| --- | --- |
| `playbooks/prepare_data_disk.yml` | LVM + XFS data disk on `/dev/sdb` → `/var/lib/postgresql` |
| `playbooks/site.yml` | Full cluster deploy |
| `playbooks/provision_app_db.yml` | Create app DB + role via VIP |
| `playbooks/enable_documentdb.yml` | FerretDB DocumentDB extension (Komodo) |
| `playbooks/failover.yml` | Promote standby |
| `playbooks/switchover.yml` | Planned role flip + rebuild |
| `playbooks/reinit_standby.yml` | Rebuild former primary as standby |
| `playbooks/backup_full.yml` | pgBackRest full backup |
| `vars/apps/` | Per-app DB provisioning vars |
| `roles/` | common, postgresql, replication, keepalived, nfs_pgbackrest |
| `molecule/` | default + failover scenarios |

## Security

Secrets never live in this repository. `group_vars/all/vault.yml` is gitignored
and encrypted with `ansible-vault`; the Molecule lab reads its own throwaway
credentials from `molecule/lab_group_vars/` so tests never need your vault
password. See [SECURITY.md](SECURITY.md) for the threat model, the secret
inventory, and a hardening checklist before you point this at real data.

The example inventory uses RFC1918 addresses from the author's homelab. Replace
them with your own in `inventory/`.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). `make lint` and `make test` should pass
before a PR.

## License

[MIT](LICENSE)
