# Contributing

## Setup

```bash
make bootstrap-dev     # uv installs Python 3.12, syncs deps, Galaxy collections
```

## Before opening a PR

```bash
make lint              # ansible-lint
make test              # full Molecule run: create → converge → verify → destroy
make test-failover     # promote drill
```

`make test` needs KVM/libvirt, Vagrant with `vagrant-libvirt`, and roughly 6 GB
of free RAM for two guests. It does **not** need your vault password — the lab
scenarios read `molecule/lab_group_vars/`.

CI runs lint and syntax checks only; the VM scenarios are local-only.

## Ground rules

- **Never commit a real credential.** See [SECURITY.md](SECURITY.md).
- Any task touching a password sets `no_log: true`.
- Destructive playbooks (`reinit_standby.yml`, `prepare_data_disk.yml`) must
  keep their pre-flight guards. If you add a destructive step, add a guard.
- Changes to `roles/` or `playbooks/` need a passing `make test`; changes to
  failover paths need `make test-failover` too.
