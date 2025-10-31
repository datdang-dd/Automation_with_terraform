#!/usr/bin/env bash
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive

# ===== Vars =====
DEV="/dev/disk/by-id/google-data"     # phải khớp device_name = "data"
MNT="/mnt/data"
WWW="$MNT/www"
NGX_DEF="/etc/nginx/sites-available/default"
META="http://169.254.169.254/computeMetadata/v1/instance/attributes"

# Đọc metadata: đường dẫn ZIP: gs://<bucket>/site-vX.Y.Z.zip
APP_ARTIFACT="$(curl -fsS -H 'Metadata-Flavor: Google' "${META}/APP_ARTIFACT" || true)"
if [ -z "${APP_ARTIFACT}" ]; then
  echo "ERROR: APP_ARTIFACT is required (vd: gs://my-bucket/site-v1.0.0.zip)" >&2
  exit 1
fi

# ===== 1) Mount đĩa stateful =====
mkdir -p "${MNT}"
if ! blkid "${DEV}" >/dev/null 2>&1; then
  mkfs.ext4 -F "${DEV}"
fi
mountpoint -q "${MNT}" || mount "${DEV}" "${MNT}"
grep -qE "^[^#]*${DEV}[[:space:]]+${MNT}[[:space:]]" /etc/fstab || \
  echo "${DEV}  ${MNT}  ext4  defaults,nofail  0  2" >> /etc/fstab

# ===== 2) Cài nginx + gsutil + unzip =====
apt-get update -y
apt-get install -y nginx unzip || true
# gsutil có sẵn trên GCE (snap). Nếu chưa có thì cài nhanh qua snap.
if ! command -v gsutil >/dev/null 2>&1; then
  snap install google-cloud-cli --classic || true
fi
systemctl enable --now nginx

# ===== 3) Cấu hình Nginx root = /mnt/data/www (không symlink) =====
mkdir -p "${WWW}"
# Sửa server block mặc định: root + index nếu cần
if grep -q "root /var/www/html;" "${NGX_DEF}"; then
  sed -i "s|root /var/www/html;|root ${WWW};|" "${NGX_DEF}"
fi
if grep -qE 'index\s+index\.html index\.htm;' "${NGX_DEF}"; then
  sed -i 's/index index\.html index\.htm;/index index.html;/' "${NGX_DEF}"
fi
nginx -t && systemctl reload nginx || true

# ===== 4) Tải ZIP & bung vào /mnt/data/www =====
TMP="/tmp/site.zip"
gsutil cp "${APP_ARTIFACT}" "${TMP}"

# Xoá sạch nội dung cũ & bung file mới
rm -rf "${WWW:?}/"*
unzip -o "${TMP}" -d "${WWW}"

# Quyền/permission chuẩn cho web
chown -R www-data:www-data "${WWW}"
find "${WWW}" -type d -exec chmod 755 {} \; || true
find "${WWW}" -type f -exec chmod 644 {} \; || true

# Reload nginx
nginx -t && systemctl reload nginx || true

echo "Startup script completed: ${APP_ARTIFACT} -> ${WWW}"
