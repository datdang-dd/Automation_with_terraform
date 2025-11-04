#!/usr/bin/env bash
set -euxo pipefail
DISK_DEV="/dev/disk/by-id/google-data"
MNT="/mnt/data"

mkdir -p "$MNT"

# KỲ VỌNG snapshot có sẵn filesystem → KHÔNG mkfs!
if ! blkid "$DISK_DEV" >/dev/null 2>&1; then
  echo "ERROR: Expected filesystem on $DISK_DEV from snapshot" >&2
  exit 1
fi

mountpoint -q "$MNT" || mount "$DISK_DEV" "$MNT"
grep -q "$DISK_DEV" /etc/fstab || echo "$DISK_DEV  $MNT  ext4  defaults,nofail  0  2" >> /etc/fstab
