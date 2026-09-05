# Security Policy

## Reporting a vulnerability

Please report security issues through
[GitHub private vulnerability reporting](https://github.com/dannysheehan/postgresql-cluster/security/advisories/new)
rather than opening a public issue. Expect an initial response within 7 days.

## Scope and threat model

This repository automates a **2-node active/passive PostgreSQL cluster** for a
private network. It assumes:

- Cluster nodes sit on a trusted RFC1918 segment; `postgresql_allowed_cidrs`
  is the network boundary, and PostgreSQL is not exposed to the internet.
- Replication and superuser credentials come from `ansible-vault` (or 1Password),
  never from the repository.
- Operators reach the nodes over SSH with key auth and passwordless sudo
  configured by `playbooks/bootstrap_host.yml`.

Reports that depend on exposing PostgreSQL or the VIP directly to an untrusted
network are out of scope — that is a deployment choice this repository does not
make for you.

## Secrets

No secret belongs in git. The following are the only credential-bearing paths,
and all of them are either gitignored or deliberately fake:

| Path | Status |
| --- | --- |
| `group_vars/all/vault.yml` | **gitignored** — encrypt with `ansible-vault` |
| `vars/apps/*.yml` (except `example.yml`) | **gitignored** |
| `group_vars/all/vault.yml.example` | placeholders only |
| `molecule/lab_group_vars/all/vault.yml` | throwaway lab credentials, public by design |

`molecule/lab_group_vars/all/vault.yml` exists so the Molecule lab never needs
your real vault password. Those values must never be used on a real node.

Every task handling a password sets `no_log: true`. If you add one that does
not, that is a bug worth reporting.

## Hardening checklist for real deployments

- [ ] `group_vars/all/vault.yml` encrypted, password not stored beside the repo
- [ ] `vault_keepalived_auth_pass` set to a unique value (both nodes must match)
- [ ] `postgresql_allowed_cidrs` narrowed to the smallest workable range
- [ ] `ufw_enabled: true`
- [ ] `pg_hba.conf` reviewed — the default `host all all <cidr>` rule is broad
- [ ] pgBackRest repository on storage separate from the database nodes
