#!/usr/bin/env bash
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive

DEV="/dev/disk/by-id/google-data"   # khớp device_name = "data"
MNT="/mnt/data"
WWW="$MNT/www"
LINK="/var/www/html"

# Mount đĩa stateful
mkdir -p "$MNT"
if ! blkid "$DEV" >/dev/null 2>&1; then
  mkfs.ext4 -F "$DEV"
fi
mount "$DEV" "$MNT" || true
grep -q "$DEV" /etc/fstab || echo "$DEV $MNT ext4 defaults,nofail 0 2" >> /etc/fstab

# Cài nginx + unzip
apt-get update -y
apt-get install -y nginx unzip
systemctl enable --now nginx

# Lấy metadata artifact
META="http://169.254.169.254/computeMetadata/v1/instance/attributes"
APP_ARTIFACT="$(curl -fsH 'Metadata-Flavor: Google' ${META}/APP_ARTIFACT)"
APP_SHA256="$(curl -fsH 'Metadata-Flavor: Google' ${META}/APP_SHA256 || true)"

# Tải artifact về ổ stateful
mkdir -p "$WWW"
TMP="$MNT/site.zip"
gsutil cp "${APP_ARTIFACT}" "${TMP}"

# (tuỳ chọn) Verify checksum
if [ -n "${APP_SHA256}" ]; then
  echo "${APP_SHA256}  ${TMP}" | sha256sum -c -
fi

# Bung site vào ổ stateful
rm -rf "${WWW:?}/*"
unzip -o "${TMP}" -d "${WWW}"
chown -R www-data:www-data "${WWW}"

# Trỏ document root sang ổ stateful
if [ -d "$LINK" ] && [ ! -L "$LINK" ]; then
  rm -rf "$LINK"
fi
ln -sfn "$WWW" "$LINK"

systemctl restart nginx
