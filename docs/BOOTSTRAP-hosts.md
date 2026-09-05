# Bootstrap fresh VMs for Ansible

Use this **once per node** before any cluster playbooks when sudo is not yet configured for passwordless Ansible.

The Ansible SSH/become user is always **`$USER` on this desktop** (via `lookup('env', 'USER')` in `group_vars/all/bootstrap.yml`). Create the same username on each VM during Ubuntu install.

## Prerequisites

- Same username on the VM as on this machine (`echo $USER`)
- SSH works as that user — password or key
- VM user is in the `sudo` group
- You know the **sudo password** (first run only)

## Run

```bash
cd /path/to/postgressql-cluster
uv sync

# -K = ask become (sudo) password on the VM
uv run ansible-playbook -i inventory/bootstrap.yml playbooks/bootstrap_host.yml -K
```

Or:

```bash
make bootstrap-host
```

Optional: limit to one host while testing:

```bash
uv run ansible-playbook -i inventory/bootstrap.yml playbooks/bootstrap_host.yml -K --limit pg-node-2
```

## What it does

| Step | Action |
| --- | --- |
| Packages | `python3`, `python3-apt`, `python3-psycopg2`, `sudo`, `acl`, … |
| Sudoers | `/etc/sudoers.d/90-ansible` — NOPASSWD for `$USER` |
| Verify | Runs `sudo -n id` to confirm passwordless sudo |

## Optional: separate `deploy` user

In `group_vars/all/bootstrap.yml`:

```yaml
bootstrap_create_deploy_user: true
bootstrap_deploy_user: deploy
bootstrap_deploy_authorized_key: ~/.ssh/id_ed25519.pub
```

Then override `ansible_user: deploy` in `inventory/hosts.yml` if you want a dedicated account.

## After bootstrap

```bash
# no -K needed from here on
uv run ansible -i inventory/hosts.yml postgres_cluster -m ping

uv run ansible-playbook -i inventory/hosts.yml playbooks/prepare_data_disk.yml
uv run ansible-playbook -i inventory/hosts.yml playbooks/site.yml
```

## Troubleshooting

| Problem | Fix |
| --- | --- |
| `Missing sudo password` | Add `-K` on first bootstrap run |
| `bootstrap_packages is undefined` | Ensure `inventory/group_vars/all` exists (symlink to `../../group_vars/all`) |
| `User X not found` | Create user `X` on the VM (`X` = your desktop `$USER`) |
| `NOPASSWD sudo is not working` | Check `/etc/sudoers.d/90-ansible` with `visudo -c` on the host |
| SSH fails | Ensure VM username matches desktop `$USER` |
