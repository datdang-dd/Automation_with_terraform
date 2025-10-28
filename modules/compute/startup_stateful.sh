#!/usr/bin/env bash
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive

# ===== Vars =====
DEV="/dev/disk/by-id/google-data"     # phải khớp device_name = "data"
MNT="/mnt/data"
WWW="$MNT/www"
NGX_DEF="/etc/nginx/sites-available/default"

# Đọc metadata: thư mục GCS chứa site (định dạng: gs://my-bucket/site/)
META="http://169.254.169.254/computeMetadata/v1/instance/attributes"
SITE_GCS_DIR="$(curl -fsH 'Metadata-Flavor: Google' ${META}/SITE_GCS_DIR)"

if [ -z "${SITE_GCS_DIR}" ]; then
  echo "ERROR: metadata attribute SITE_GCS_DIR (vd: gs://my-bucket/site/) is required" >&2
  exit 1
fi

# ===== 1) Mount đĩa stateful =====
mkdir -p "$MNT"
if ! blkid "$DEV" >/dev/null 2>&1; then
  mkfs.ext4 -F "$DEV"
fi
mount "$DEV" "$MNT" || true
grep -q "$DEV" /etc/fstab || echo "$DEV $MNT ext4 defaults,nofail 0 2" >> /etc/fstab

# ===== 2) Cài nginx + google-cloud-cli (để có gsutil) =====
apt-get update -y
apt-get install -y nginx google-cloud-cli
systemctl enable --now nginx

# ===== 3) Cấu hình Nginx root = /mnt/data/www (không symlink) =====
mkdir -p "$WWW"
# Sửa server block mặc định: root + index
if ! grep -q "root $WWW" "$NGX_DEF"; then
  sed -i "s|root /var/www/html;|root $WWW;|" "$NGX_DEF" || true
fi
if grep -qE 'index\s+index\.html index\.htm;' "$NGX_DEF"; then
  sed -i 's/index index\.html index\.htm;/index index.html;/' "$NGX_DEF" || true
fi
nginx -t && systemctl reload nginx || true

# Quyền cho web
chown -R www-data:www-data "$WWW"
find "$WWW" -type d -exec chmod 755 {} \; || true
find "$WWW" -type f -exec chmod 644 {} \; || true

# ===== 4) Script đồng bộ từ GCS về WWW =====
install -d -m 755 /usr/local/bin
cat >/usr/local/bin/site-sync.sh <<'SYNC'
#!/usr/bin/env bash
set -euo pipefail

WWW="/mnt/data/www"
SITE_GCS_DIR="${SITE_GCS_DIR}"
TMP_LOG="/tmp/site-sync.changed"

# Đồng bộ nội dung (thư mục) từ GCS về local
# -m: parallel; -r: recursive; -d: xoá local file không còn trên GCS
gsutil -m rsync -r -d "${SITE_GCS_DIR}" "${WWW}" | tee "${TMP_LOG}" || true

# Nếu có thay đổi, sửa quyền và reload nginx
if [ -s "${TMP_LOG}" ]; then
  chown -R www-data:www-data "${WWW}"
  find "${WWW}" -type d -exec chmod 755 {} \; || true
  find "${WWW}" -type f -exec chmod 644 {} \; || true
  systemctl reload nginx || true
fi

rm -f "${TMP_LOG}" || true
SYNC
chmod +x /usr/local/bin/site-sync.sh

# Inject biến môi trường SITE_GCS_DIR cho service
sed -i "1i SITE_GCS_DIR='${SITE_GCS_DIR}'" /usr/local/bin/site-sync.sh

# ===== 5) systemd service + timer (30s/lần, bạn có thể đổi) =====
cat >/etc/systemd/system/site-sync.service <<'UNIT'
[Unit]
Description=Sync static site from GCS to /mnt/data/www

[Service]
Type=oneshot
ExecStart=/usr/local/bin/site-sync.sh
UNIT

cat >/etc/systemd/system/site-sync.timer <<'TIMER'
[Unit]
Description=Run site-sync every 30 seconds

[Timer]
OnBootSec=15s
OnUnitActiveSec=60s
AccuracySec=5s
Unit=site-sync.service

[Install]
WantedBy=timers.target
TIMER

systemctl daemon-reload
systemctl enable --now site-sync.timer

# Lần đầu kéo site về ngay
systemctl start site-sync.service || true
