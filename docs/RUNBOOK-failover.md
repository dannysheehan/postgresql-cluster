# Runbook: unplanned failover

Keepalived moves the VIP only to a node that is **writable**. Promoting the standby is mandatory; the VIP alone does not promote PostgreSQL.

## 1. Confirm primary is down

```bash
ansible primary -i inventory/hosts.yml -m ping
# on standby:
sudo -u postgres psql -c 'SELECT pg_is_in_recovery();'
sudo -u postgres psql -c 'SELECT now() - pg_last_xact_replay_timestamp() AS replay_lag;'
```

Accept that any WAL not yet streamed is lost (async replication).

## 2. Fence, then promote

```bash
ansible-playbook -i inventory/hosts.yml playbooks/failover.yml
```

The playbook stops keepalived and PostgreSQL on the old primary **before** it
promotes the standby. If the old primary is unreachable it is already fenced and
the run continues; if it is reachable but cannot be stopped the run aborts
without promoting, rather than leaving two writable nodes.

Manually, keep the same order — fence first:

```bash
# on the OLD PRIMARY (skip if it is genuinely down)
sudo systemctl stop keepalived
sudo pg_ctlcluster 16 main stop

# then on the standby
sudo pg_ctlcluster 16 main promote
sudo systemctl restart keepalived
```

## 3. Confirm VIP and writes

```bash
ip -4 addr show   # VIP should appear on promoted node
psql "host=<VIP> user=postgres dbname=postgres" -c 'SELECT pg_is_in_recovery();'
# expect 'f'
```

## 4. Rebuild former primary as standby

With inventory **unchanged** (old primary still in `[primary]`, promoted node still in `[standby]`):

```bash
ansible-playbook -i inventory/hosts.yml playbooks/reinit_standby.yml
```

This wipes the old primary's data directory, so it first checks that
`groups['standby'][0]` is out of recovery and refuses to run if it is not.

Then **swap inventory labels** so the writable node is `[primary]` and the rebuilt node is `[standby]`.

## 5. Verify replication

```bash
sudo -u postgres psql -c 'SELECT * FROM pg_stat_replication;'
```
