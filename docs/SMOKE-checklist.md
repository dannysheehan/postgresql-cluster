# Post-deploy verification checklist

## Lab (Molecule)

- [ ] `make test` passes (replication, VIP write, pgBackRest info)
- [ ] `make test-failover` passes (promote + VIP write)

## ESXi

- [ ] `ansible -i inventory/hosts.yml postgres_cluster -m ping`
- [ ] Primary: `SELECT pg_is_in_recovery();` → `f`
- [ ] Standby: `SELECT pg_is_in_recovery();` → `t`
- [ ] Primary: `SELECT * FROM pg_stat_replication;` shows standby
- [ ] VIP responds: `psql -h <VIP> -U postgres -c 'SELECT 1'`
- [ ] Keepalived: VIP address present only on writable node
- [ ] `pgbackrest --stanza=postgres-cluster info` shows a full backup
- [ ] NFS mount present when `pgbackrest_use_nfs: true` (`mount | grep pgbackrest`)
- [ ] One failover drill completed per [RUNBOOK-failover.md](RUNBOOK-failover.md)
