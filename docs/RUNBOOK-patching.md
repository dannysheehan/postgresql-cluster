# Runbook: rolling OS / minor PostgreSQL patches

## Planned switchover (preferred)

With healthy replication:

```bash
ansible-playbook -i inventory/hosts.yml playbooks/switchover.yml
```

This promotes the standby, rebuilds the former primary as standby, then reminds you to swap inventory labels.

## Manual rolling patch flow

1. Patch **standby** only (`apt upgrade`, reboot if needed).
2. Confirm replication resumed: `SELECT * FROM pg_stat_replication;` on primary.
3. Run `playbooks/switchover.yml` (or promote + reinit).
4. Swap inventory labels.
5. Patch the new standby (former primary).
6. Confirm replication and VIP.

## Minor PostgreSQL package upgrade

On the **standby** first:

```bash
sudo apt-get update
sudo apt-get install --only-upgrade postgresql-16 postgresql-client-16
sudo systemctl restart postgresql@16-main
```

Switchover, then upgrade the other node the same way.

## Notes

- Pause application maintenance windows if you need zero write errors during promote (brief disconnect).
- Always take `playbooks/backup_full.yml` before risky upgrades.
- Major-version upgrades (`pg_upgrade`) are out of scope of these playbooks; use a dedicated change window.
