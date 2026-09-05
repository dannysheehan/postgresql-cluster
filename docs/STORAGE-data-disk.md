# PostgreSQL data disk (LVM + XFS)

Use the **second disk** (`sdb`) for PGDATA only. Keep the OS on `sda`. Do **not** put live database files on Synology NFS.

Run on **both** `pg-node-1` and `pg-node-2` **before** `playbooks/site.yml`.

## Layout

```text
sda  → OS (/, /boot)
sdb  → sdb1 (GPT, LVM) → PV → VG pgdata → LV pgdata → xfs → /var/lib/postgresql
```

PGDG creates `/var/lib/postgresql/16/main` on that mount when Ansible runs.

| Choice | Why |
| --- | --- |
| **XFS** | Common for Postgres; grow online with `xfs_growfs` |
| **LVM** | Extend VG/LV after you grow the VMDK in ESXi |
| **noatime** | Fewer metadata writes on a database volume |
| **fstab pass `0`** | Data volume — skip boot fsck (root stays `1`) |

## Ansible (preferred)

```bash
uv run ansible-playbook -i inventory/hosts.yml playbooks/prepare_data_disk.yml
uv run ansible-playbook -i inventory/hosts.yml playbooks/site.yml
```

## Manual setup (as root on each node)

```bash
DISK=/dev/sdb
PART=${DISK}1
VG=pgdata
LV=pgdata
MOUNT=/var/lib/postgresql
LV_PATH=/dev/${VG}/${LV}

parted -s "${DISK}" mklabel gpt
parted -s "${DISK}" mkpart postgresql-data xfs 1MiB 100%
parted -s "${DISK}" set 1 lvm on
partprobe "${DISK}"
sleep 2

pvcreate "${PART}"
vgcreate "${VG}" "${PART}"
lvcreate -l 100%FREE -n "${LV}" "${VG}"

mkfs.xfs -L pgdata "${LV_PATH}"

mkdir -p "${MOUNT}"
UUID=$(blkid -s UUID -o value "${LV_PATH}")
grep -q "${UUID}" /etc/fstab || \
  echo "UUID=${UUID} ${MOUNT} xfs noatime,nodiratime 0 0" >> /etc/fstab

mount -a
lsblk -f "${DISK}"
vgs
lvs
df -h "${MOUNT}"
```

After PostgreSQL is installed:

```bash
chown postgres:postgres /var/lib/postgresql
chmod 750 /var/lib/postgresql
```

## Grow disk after ESXi VMDK expansion

1. Increase virtual disk size in ESXi (both nodes, same workflow).
2. On the VM:

```bash
# rescan (if needed)
echo 1 | sudo tee /sys/class/block/sdb/device/rescan

# grow partition (install cloud-guest-utils if growpart missing)
sudo growpart /dev/sdb 1

# extend LVM and XFS
sudo pvresize /dev/sdb1
sudo lvextend -l +100%FREE /dev/pgdata/pgdata
sudo xfs_growfs /var/lib/postgresql

df -h /var/lib/postgresql
```

## Already on ext4 (plain partition)?

If you mounted `sdb` as ext4 **before** this change and **PostgreSQL is not deployed yet**:

```bash
sudo umount /var/lib/postgresql
sudo wipefs -a /dev/sdb1
sudo wipefs -a /dev/sdb
# remove old UUID line from /etc/fstab
```

Then re-run `prepare_data_disk.yml`.

If PostgreSQL **already has data** on ext4, do not wipe — plan a migration (dump/restore or new node + rebuild standby).

## Verify

```bash
findmnt /var/lib/postgresql
lsblk -f /dev/sdb
vgs pgdata
lvs pgdata
df -h /var/lib/postgresql
# After site.yml:
sudo -u postgres psql -c 'SHOW data_directory;'
```

Expected: XFS on `/dev/mapper/pgdata-pgdata` (or `/dev/pgdata/pgdata`), data directory under `/var/lib/postgresql/16/main`.
