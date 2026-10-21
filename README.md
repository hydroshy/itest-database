# ITEST PLATFORM - DATABASE DEPLOYMENT & MULTI-SCHEMA MANAGEMENT

Hệ thống cơ sở dữ liệu tập trung thế hệ mới của nền tảng **ITEST Platform**, triển khai trên nền tảng **PostgreSQL 17 Alpine** với kiến trúc phân lập multi-schema và phân quyền truy cập tối thiểu (least-privilege) độc lập cho từng phân hệ:
- **`system_schema`**: Lõi Micro-kernel Core Backbone (`itest-system`) - Quản lý RBAC, User, Audit log, Device Registry.
- **`plugins_schema`**: Hệ sinh thái IoT Plugins độc lập (`itest-plugins`) - Quản lý cấu hình plugin, channel truyền thông, time-series telemetry và command execution logs.
- **`lorawan_chirpstack`**: Phân hệ chuyên biệt cho ChirpStack LoRaWAN Plugin - Quản lý connection profile, API token, credentials và tham chiếu tenant cho `network_servers`.
- **`ops_schema`**: Trạm vận hành, giám sát và cảnh báo thời gian thực (`itest-ops-agent`) - Quản lý danh sách targets giám sát đa database, telemetry metrics và audit actions.

---

## 1. Cấu trúc thư mục

```text
itest-database/
├── .env.example                # Cấu hình mẫu môi trường PostgreSQL & ports
├── docker-compose.yml          # Triển khai PostgreSQL 17 Alpine, persistent volume, healthcheck
├── package.json                # Quản lý script và thư viện migration Node.js (pg, dotenv)
├── init-scripts/               # Tự động thực thi khi container khởi tạo lần đầu
│   └── 01-init-databases.sql   # Khởi tạo 3 schemas, 3 dedicated users, phân quyền least-privilege
├── schemas/                    # Quản lý DDL và migration tuần tự theo từng source
│   ├── system/                 # Schemas & data seed cho itest-system (Core)
│   │   └── schema.sql
│   ├── plugins/                # Schemas cho itest-plugins
│   │   └── schema.sql
│   └── ops-agent/              # Schemas cho itest-ops-agent
│       └── schema.sql
└── scripts/                    # Bộ công cụ CLI migration độc lập theo phân hệ
    ├── migrate.js              # Migration engine tự động ghi nhận bảng __itest_migrations_history
    ├── migrate.bat             # Kịch bản chạy nhanh trên Windows (UTF-8, CRLF)
    └── migrate.sh              # Kịch bản chạy trên Linux / macOS / CI-CD
```

---

## 2. Thông tin kết nối & Phân quyền User

| Phân hệ / User | Mật khẩu mặc định | Schema phụ trách | Quyền hạn trên hệ thống |
| :--- | :--- | :--- | :--- |
| **`itest_admin`** (Superuser) | `itest_secure_password_2026` | Toàn quyền (`public`, tất cả schema) | Quản trị DB, chạy migration |
| **`itest_system_user`** | `system_secret_2026` | `system_schema` | Toàn quyền trên Core schema |
| **`itest_plugins_user`** | `plugins_secret_2026` | `plugins_schema` | Toàn quyền Plugins schema; Chỉ đọc (`SELECT`) trên `system_schema` |
| **`itest_ops_user`** | `ops_secret_2026` | `ops_schema` | Toàn quyền Ops schema; Đọc `system_schema` và `plugins_schema` để giám sát |

---

## 3. Hướng dẫn khởi động & Triển khai Docker

### Bước 1: Chuẩn bị file cấu hình môi trường
```bash
cp .env.example .env
```

### Bước 2: Khởi động PostgreSQL 17 Container
```bash
docker compose up -d
```
Container sẽ tự động chạy script `init-scripts/01-init-databases.sql` tạo sẵn schemas và users.

### Bước 3: Kiểm tra trạng thái container
```bash
docker compose ps
```

---

## 4. Công cụ CLI Migration theo từng source

Để cập nhật schema độc lập theo từng phân hệ mà không làm ảnh hưởng phân hệ khác:

### Chạy toàn bộ migration:
```bash
# Windows
scripts\migrate.bat

# Linux / Mac / CLI Node.js
node scripts/migrate.js --source=all
```

### Cập nhật riêng lẻ từng phân hệ:
```bash
# Chỉ cập nhật itest-system (Core)
scripts\migrate.bat system
node scripts/migrate.js --source=system

# Chỉ cập nhật itest-plugins
scripts\migrate.bat plugins
node scripts/migrate.js --source=plugins

# Chỉ cập nhật itest-ops-agent
scripts\migrate.bat ops-agent
node scripts/migrate.js --source=ops-agent
```

### Kiểm tra trạng thái schema và lịch sử migration:
```bash
scripts\migrate.bat status
node scripts/migrate.js --status
```

---

## 5. Tích hợp với `itest-ops-agent`

`itest-ops-agent` hỗ trợ cơ chế giám sát đa database. Khi triển khai `itest-database`, thêm cấu hình giám sát trực tiếp qua UI hoặc biến môi trường của `ops-agent`:
- **Host**: `itest-database` (trong Docker network `itest-network`) hoặc `127.0.0.1` (từ host).
- **Port**: `5432`
- **Database**: `itest_platform`
- **User**: `itest_ops_user`
- **Password**: `ops_secret_2026`
