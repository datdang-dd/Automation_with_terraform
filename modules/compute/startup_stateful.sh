#!/usr/bin/env bash
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive

# ===== Thông tin ổ đĩa =====
DISK_DEV="/dev/disk/by-id/google-data"   # device_name = "data"
MNT="/mnt/data"
WWW="$MNT/www"
NGX_DEF="/etc/nginx/sites-available/default"

# ===== 1) Mount đĩa ngoài =====
mkdir -p "$MNT"
if [ -e "$DISK_DEV" ]; then
  # Nếu chưa format, tạo ext4
  if ! blkid "$DISK_DEV" >/dev/null 2>&1; then
    mkfs.ext4 -F "$DISK_DEV"
  fi

  # Mount vào /mnt/data (idempotent)
  mountpoint -q "$MNT" || mount "$DISK_DEV" "$MNT"
  grep -q "$DISK_DEV" /etc/fstab || echo "$DISK_DEV  $MNT  ext4  defaults,nofail  0  2" >> /etc/fstab
else
  echo "ERROR: Disk $DISK_DEV not found" >&2
  exit 1
fi

# ===== 2) Cài nginx =====
apt-get update -y
apt-get install -y nginx
systemctl enable --now nginx

# ===== 3) Cấu hình root của Nginx trỏ về ổ đĩa ngoài =====
mkdir -p "$WWW"
chown -R www-data:www-data "$MNT"
chmod -R 755 "$MNT"

# Sửa cấu hình nginx
if grep -q "root /var/www/html;" "$NGX_DEF"; then
  sed -i "s|root /var/www/html;|root $WWW;|" "$NGX_DEF"
fi

# Tạo file index mặc định
echo "<h1>Hello from $(hostname)</h1><p>Root: $WWW</p>" > "$WWW/index.html"

nginx -t && systemctl reload nginx || true

echo "✅ Nginx is installed and serving content from $WWW"
