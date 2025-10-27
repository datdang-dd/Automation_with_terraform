#!/usr/bin/env bash
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive

# --- Tham số khớp với instance template & MIG ---
DEV="/dev/disk/by-id/google-data"   # phải khớp device_name = "data"
MNT="/mnt/data"
WWW="$MNT/www"
LINK="/var/www/html"

log(){ echo "[startup] $(date -Is) $*"; }

# 1) Mount đĩa stateful (tạo FS nếu mới)
log "Mount stateful disk to $MNT"
mkdir -p "$MNT"
if ! blkid "$DEV" >/dev/null 2>&1; then
  log "No filesystem on $DEV -> mkfs.ext4"
  mkfs.ext4 -F "$DEV"
fi
mount "$DEV" "$MNT" || true
grep -qE "^[^#]*\s+$MNT\s+" /etc/fstab || echo "$DEV $MNT ext4 defaults,nofail 0 2" >> /etc/fstab

# 2) Cài nginx (idempotent)
log "Install & enable nginx"
apt-get update -y
apt-get install -y nginx
systemctl enable nginx

# 3) Seed nội dung web lên đĩa stateful (chỉ lần đầu)
log "Seed web content (if empty) -> $WWW"
mkdir -p "$WWW"
if [ -z "$(ls -A "$WWW" 2>/dev/null)" ]; then
  cat > "$WWW/index.html" <<'HTML'
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
      <h1>Chào Mừng Đến Với Trang Web </h1>
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
fi

# 4) Trỏ docroot của nginx về thư mục trên đĩa stateful (symlink an toàn)
log "Point nginx docroot to $WWW via symlink $LINK"
if [ -d "$LINK" ] && [ ! -L "$LINK" ]; then
  rm -rf "$LINK"
fi
ln -sfn "$WWW" "$LINK"

# 5) Khởi động/restart nginx để áp dụng
systemctl restart nginx
log "Startup completed"
