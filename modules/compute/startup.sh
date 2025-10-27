#!/bin/bash
# Startup wrapper that ensures the instance's application startup script runs from
# an attached extra persistent disk when available. If the script is executed
# from the mounted extra disk path (/mnt/extra_disk), it runs the application
# logic (install nginx, write index). Otherwise it will mount the extra disk,
# copy itself to the extra disk, register a systemd service to run from the
# extra disk on future boots, and then invoke the disk-resident script.

set -euo pipefail

EXTRA_MOUNT="/mnt/extra_disk"
DISK_SERVICE="/etc/systemd/system/extra-startup.service"

log() { echo "[startup] $(date --iso-8601=seconds) - $*"; }

# Application logic: install nginx and write index page
app_main() {
  log "Running app logic on $(pwd)"
  apt-get update -y
  apt-get install -y nginx
  systemctl enable nginx
  systemctl start nginx

  mkdir -p /var/www/html
  cat > /var/www/html/index.html <<'HTML'
<!DOCTYPE html>
<html lang="vi">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Trang Web Tĩnh Của Tôi</title>
  <style>
    /* --- Cài đặt CSS tổng thể --- */
    :root {
      --primary-color: #007bff; /* Xanh dương */
      --secondary-color: #f8f9fa; /* Xám nhạt */
      --text-color: #333;
      --light-text-color: #f1f1f1;
      --border-radius: 8px;
      --box-shadow: 0 4px 8px rgba(0, 0, 0, 0.1);
    }

    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
      margin: 0;
      padding: 0;
      line-height: 1.6;
      background-color: #fff;
      color: var(--text-color);
    }

    /* --- Container chính để căn giữa nội dung --- */
    .container {
      max-width: 1100px;
      margin: 0 auto;
      padding: 0 20px;
    }

    /* --- Phần Header và Navigation --- */
    header {
      background-color: var(--primary-color);
      color: var(--light-text-color);
      padding: 1rem 0;
      box-shadow: var(--box-shadow);
      position: sticky;
      top: 0;
      z-index: 1000;
    }

    header .container {
      display: flex;
      justify-content: space-between;
      align-items: center;
    }

    .logo {
      font-size: 1.8rem;
      font-weight: bold;
      text-decoration: none;
      color: var(--light-text-color);
    }

    nav ul {
      list-style: none;
      margin: 0;
      padding: 0;
      display: flex;
    }

    nav ul li {
      margin-left: 25px;
    }

    nav ul li a {
      color: var(--light-text-color);
      text-decoration: none;
      font-weight: 500;
      transition: color 0.3s ease;
    }

    nav ul li a:hover {
      color: #cce5ff; /* Màu xanh nhạt hơn khi hover */
    }

    /* --- Phần Hero Banner --- */
    .hero {
      background: linear-gradient(rgba(0, 0, 0, 0.5), rgba(0, 0, 0, 0.5)), url('https://placehold.co/1200x500/007BFF/FFFFFF?text=Welcome!');
      background-size: cover;
      background-position: center;
      color: white;
      text-align: center;
      padding: 100px 20px;
    }

    .hero h1 {
      font-size: 3rem;
      margin-bottom: 10px;
    }

    .hero p {
      font-size: 1.2rem;
      margin-bottom: 20px;
    }

    .cta-button {
      display: inline-block;
      background-color: var(--primary-color);
      color: white;
      padding: 12px 25px;
      border-radius: var(--border-radius);
      text-decoration: none;
      font-weight: bold;
      transition: background-color 0.3s ease, transform 0.3s ease;
    }

    .cta-button:hover {
      background-color: #0056b3; /* Màu xanh đậm hơn */
      transform: translateY(-2px);
    }

    /* --- Phần Nội dung chính --- */
    main {
      padding: 40px 0;
    }

    .section {
      margin-bottom: 40px;
      padding: 40px;
      background-color: var(--secondary-color);
      border-radius: var(--border-radius);
      box-shadow: var(--box-shadow);
    }

    .section h2 {
      text-align: center;
      margin-bottom: 30px;
      color: var(--primary-color);
    }

    /* --- Phần Footer --- */
    footer {
      background-color: #333;
      color: var(--light-text-color);
      text-align: center;
      padding: 20px 0;
    }
        
    /* --- Responsive Design cho thiết bị di động --- */
    @media (max-width: 768px) {
      header .container {
        flex-direction: column;
      }
            
      nav ul {
        margin-top: 15px;
        flex-direction: column;
        align-items: center;
      }

      nav ul li {
        margin: 10px 0;
      }
            
      .hero h1 {
        font-size: 2.2rem;
      }
    }
  </style>
</head>
<body>

  <!-- ======== HEADER ======== -->
  <header>
    <div class="container">
      <a href="#" class="logo">MyWeb</a>
      <nav>
        <ul>
          <li><a href="#home">Trang Chủ</a></li>
          <li><a href="#about">Giới Thiệu</a></li>
          <li><a href="#services">Dịch Vụ</a></li>
          <li><a href="#contact">Liên Hệ</a></li>
        </ul>
      </nav>
    </div>
  </header>

  <!-- ======== NỘI DUNG CHÍNH ======== -->
  <main>
    <!-- Phần Hero Banner -->
    <section class="hero" id="home">
      <h1>Chào Mừng Đến Với Trang Web Của Tôi</h1>
      <p>Một nơi đơn giản để chia sẻ thông tin và ý tưởng.</p>
      <a href="#about" class="cta-button">Tìm Hiểu Thêm</a>
    </section>

    <!-- Phần Giới thiệu -->
    <div class="container">
      <section id="about" class="section">
        <h2>Về Chúng Tôi</h2>
        <p>Đây là một trang web tĩnh được tạo ra hoàn toàn bằng HTML và CSS trong một file duy nhất. Mục đích là để minh họa một trang web đơn giản, sạch sẽ, và dễ dàng tùy chỉnh. Bạn có thể thay đổi bất kỳ nội dung nào trong file này để phù hợp với nhu cầu của mình.</p>
      </section>
    </div>

    <!-- Phần Dịch vụ -->
    <div class="container">
      <section id="services" class="section">
        <h2>Dịch Vụ Của Chúng Tôi</h2>
        <p>Chúng tôi cung cấp các dịch vụ tuyệt vời để giúp bạn thành công. Nội dung này chỉ là placeholder, bạn có thể thay thế bằng các dịch vụ thực tế của mình, ví dụ như:</p>
        <ul>
          <li>Thiết kế Web</li>
          <li>Tư vấn Giải pháp Công nghệ</li>
          <li>Marketing Online</li>
        </ul>
      </section>
    </div>
        
    <!-- Phần Liên hệ -->
    <div class="container">
      <section id="contact" class="section">
        <h2>Liên Hệ</h2>
        <p>Bạn có thể liên hệ với chúng tôi qua email: <strong>contact@example.com</strong></p>
      </section>
    </div>
  </main>

  <!-- ======== FOOTER ======== -->
  <footer>
    <div class="container">
      <p>&copy; <span id="year"></span> MyWeb. All Rights Reserved.</p>
    </div>
  </footer>

  <!-- ======== JAVASCRIPT ĐƠN GIẢN ======== -->
  <script>
    // Tự động cập nhật năm ở footer
    document.getElementById('year').textContent = new Date().getFullYear();
  </script>

</body>
</html>
HTML
}

# Find the root disk base name (e.g. sda)
root_src=$(findmnt -n -o SOURCE / || true)
root_base=""
if [ -n "$root_src" ]; then
  # if root is /dev/sda1 etc, get parent disk name
  if [[ "$root_src" =~ ^/dev/ ]]; then
    # try to get PKNAME via lsblk; fallback to stripping trailing digits
    root_base=$(lsblk -no PKNAME "$root_src" 2>/dev/null || true)
    if [ -z "$root_base" ]; then
      root_base=$(basename "$root_src" | sed 's/[0-9]*$//')
    fi
  fi
fi

if [[ "$0" == "$EXTRA_MOUNT"* ]]; then
  # We're running from the extra disk - do not attempt to copy again: run app
  log "Detected execution from extra disk. Running app_main"
  app_main
  exit 0
fi

# Try to find the first non-root, non-mounted disk to use as extra disk
extra_dev=""
while read -r line; do
  dev="/dev/$line"
  # skip if this is root disk
  if [ "$line" = "$root_base" ]; then
    continue
  fi
  # skip loop devices
  type=$(lsblk -no TYPE "$dev" 2>/dev/null || true)
  if [ "$type" != "disk" ]; then
    continue
  fi
  # check if any partitions or mounts exist on this disk
  mountpoints=$(lsblk -no MOUNTPOINT "$dev" 2>/dev/null || true)
  if [ -n "$mountpoints" ]; then
    # if all mountpoints are empty lines, consider unmounted; else skip
    if echo "$mountpoints" | grep -q '\S'; then
      continue
    fi
  fi
  extra_dev="$dev"
  break
done < <(lsblk -dn -o NAME)

if [ -z "$extra_dev" ]; then
  log "No extra disk found; running app on boot disk"
  app_main
  exit 0
fi

log "Found extra disk: $extra_dev"

# Create mount point and format/mount if needed
mkdir -p "$EXTRA_MOUNT"

# Determine whether device has a filesystem
if ! blkid "$extra_dev" >/dev/null 2>&1; then
  log "No filesystem found on $extra_dev - creating ext4"
  # Create a single partition-less filesystem on the whole disk
  mkfs.ext4 -F "$extra_dev"
fi

# Compute UUID and add to fstab if not present
uuid=$(blkid -s UUID -o value "$extra_dev" || true)
if [ -z "$uuid" ]; then
  log "Unable to read UUID from $extra_dev; mounting by device name"
  if ! grep -qs "$EXTRA_MOUNT" /proc/mounts; then
    mount "$extra_dev" "$EXTRA_MOUNT"
  fi
else
  if ! grep -qs "$uuid" /etc/fstab; then
    echo "UUID=$uuid $EXTRA_MOUNT ext4 defaults,nofail 0 2" >> /etc/fstab
  fi
  if ! mountpoint -q "$EXTRA_MOUNT"; then
    mount "$EXTRA_MOUNT"
  fi
fi

log "Extra disk mounted at $EXTRA_MOUNT"

# Copy this script to the extra disk and install systemd unit to run it from there
mkdir -p "$EXTRA_MOUNT/startup"
cp "$0" "$EXTRA_MOUNT/startup/startup.sh" || {
  # if $0 is not a file (metadata runner), fetch from metadata server
  curl -fsS -H "Metadata-Flavor: Google" "http://169.254.169.254/computeMetadata/v1/instance/attributes/startup-script" -o "$EXTRA_MOUNT/startup/startup.sh" || true
}
chmod +x "$EXTRA_MOUNT/startup/startup.sh" || true

cat > "$DISK_SERVICE" <<EOF
[Unit]
Description=Extra-disk startup runner
After=network.target

[Service]
Type=oneshot
ExecStart=$EXTRA_MOUNT/startup/startup.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload || true
systemctl enable --now extra-startup.service || true

log "Started disk-resident startup script via systemd"

# Optionally run the disk-resident script now (non-blocking)
nohup "$EXTRA_MOUNT/startup/startup.sh" >/var/log/extra-startup.log 2>&1 &

log "Wrapper finished"
