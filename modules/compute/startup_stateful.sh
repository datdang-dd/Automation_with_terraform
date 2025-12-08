#!/usr/bin/env bash
set -euxo pipefail
DISK_DEV="/dev/disk/by-id/google-data"
MNT="/mnt/data"

mkdir -p "$MNT"

# Check if disk has filesystem (from snapshot) or needs formatting (new disk)
if ! blkid "$DISK_DEV" >/dev/null 2>&1; then
  echo "No filesystem found on $DISK_DEV, creating new ext4 filesystem..."
  mkfs.ext4 -F "$DISK_DEV"
fi

mountpoint -q "$MNT" || mount "$DISK_DEV" "$MNT"
grep -q "$DISK_DEV" /etc/fstab || echo "$DISK_DEV  $MNT  ext4  defaults,nofail  0  2" >> /etc/fstab

# ===== CÀI ĐẶT OPS AGENT (ĐỂ GỬI METRIC RAM) =====
# Thêm kho lưu trữ của Google Ops Agent
curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
sudo bash add-google-cloud-ops-agent-repo.sh --also-install
sudo systemctl start google-cloud-ops-agent

