# Lab: Molecule + Vagrant/libvirt (KVM)

## Host requirements

Already expected on this workstation:

- [uv](https://docs.astral.sh/uv/) (`uv --version`)
- KVM + libvirt (`virsh`, user in `libvirt` / `kvm` groups)
- Vagrant ≥ 2.4 with `vagrant-libvirt` plugin
- Box `bento/ubuntu-24.04` (cached or downloaded on first run)
- ~6 GB free RAM for two 2 GB guests

## Bootstrap

```bash
cd /path/to/postgressql-cluster
make bootstrap-dev
```

This uses **uv** to:

1. Install Python 3.12 (from `.python-version`) if needed
2. Create `.venv` and install locked deps from `pyproject.toml` / `uv.lock`
3. Install Ansible Galaxy collections into `./collections`

Prefer Makefile targets (`make test`). They export `ANSIBLE_LIBRARY` for molecule-vagrant. Equivalent manual flow:

```bash
uv sync
export ANSIBLE_LIBRARY="$(uv run python -c 'import sysconfig; print(sysconfig.get_path("purelib"))')/molecule_vagrant/modules"
export ANSIBLE_COLLECTIONS_PATH="$(pwd)/collections"
uv run molecule test -s default
```

## Commands

| Command | What it does |
| --- | --- |
| `make bootstrap-dev` | `uv python install` + `uv sync` + Galaxy collections |
| `make sync` | Refresh the uv environment / lock |
| `make test` | `uv run molecule test -s default` |
| `make converge` | Create (if needed) + apply `site.yml` |
| `make verify` | Run assertions only |
| `make destroy` | Tear down default scenario VMs |
| `make test-failover` | Build cluster, promote standby, assert VIP/writes |

## Network layout (lab)

| Host | IP |
| --- | --- |
| VIP | `192.168.56.10` |
| pg-node-1 (primary) | `192.168.56.11` (private) + libvirt NAT for SSH |
| pg-node-2 (standby) | `192.168.56.12` (private) + libvirt NAT for SSH |

Keepalived uses **unicast VRRP** on `eth1` (private_network). Backups use a **local** `/var/lib/pgbackrest` path (no Synology).

## Troubleshooting

- **Wrong keepalived interface:** on the guest run `ip -br a` and set `keepalived_interface` in `group_vars/all/main.yml`.
- **VIP never appears:** confirm `check_postgres_primary.sh` returns 0 only on the writable node; `journalctl -u keepalived -e`.
- **Basebackup auth fails:** check `/var/lib/postgresql/.pgpass` mode `0600` and `pg_hba.conf` replication lines.
- **Libvirt permission errors:** ensure your user is in `libvirt` and `qemu:///system` works (`virsh list --all`).
- **`couldn't resolve module/action 'vagrant'`:** use `make test`, or export `ANSIBLE_LIBRARY` as above.
- **uv not found:** install from https://docs.astral.sh/uv/getting-started/installation/
