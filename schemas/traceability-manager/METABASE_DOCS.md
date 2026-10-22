# Tài Liệu Hướng Dẫn Truy Vấn Metabase BI - Device Traceability

Tài liệu này cung cấp toàn bộ đặc tả dữ liệu, mô hình quan hệ, và bộ truy vấn mẫu (SQL Recipes) để phục vụ việc tích hợp và xây dựng Dashboard/Báo cáo trên **Metabase BI** cho module **Device Traceability** thuộc nền tảng `iTest`.

---

## 1. Tổng Quan Kiến Trúc & Mô Hình Dữ Liệu

Module Traceability được thiết kế trong schema riêng biệt `traceability_manager` với 2 tầng dữ liệu chuẩn hóa:
1. **Tầng 1 - Lệnh Sản Xuất ERP (`traceability_order`)**: Đại diện cho đơn hàng (`so_number`), lệnh sản xuất (`wa_number`), mã thành phẩm ERP (`item_code`), và loại kết nối (`connectivity`).
2. **Tầng 2 - Thiết Bị Cá Thể (`traceability_device`)**: Đại diện cho từng thiết bị vật lý với Serial Number độc nhất (`serial_number`), SKU, phiên bản phần cứng/firmware, thông tin định danh mạng viễn thông (LoRaWAN EUI/Key, Sigfox ID/PAC, NB-IoT IMEI), và liên kết phiên Final Config.
3. **Tầng Phân Tích Tổng Hợp (`v_device_traceability_lifecycle`)**: View tối ưu sẵn cho Metabase, gom toàn bộ thông tin vòng đời thiết bị từ ERP đến kết quả nạp cấu hình thực thi.

```
+---------------------------------------------------+
|     traceability_manager.traceability_order       |
|---------------------------------------------------|
| * id (UUID PK)                                    |
| * so_number (VARCHAR)       -- Lệnh bán hàng ERP  |
| * wa_number (VARCHAR)       -- Lệnh sản xuất ERP  |
| * item_code (VARCHAR)       -- Mã sản phẩm ERP    |
| * connectivity (VARCHAR)    -- LoRaWAN / Sigfox   |
| * total_quantity (INTEGER)  -- Số lượng kế hoạch  |
+---------------------------------------------------+
                          | 1
                          |
                          | n
+---------------------------------------------------+
|     traceability_manager.traceability_device      |
|---------------------------------------------------|
| * id (UUID PK)                                    |
| * order_id (UUID FK)                              |
| * serial_number (VARCHAR UNIQUE)                  |
| * sku (VARCHAR)                                   |
| * fw_version, hw_version, me_version              |
| * dev_eui, app_eui, app_key (LoRaWAN)             |
| * sigfox_id, sigfox_pac (Sigfox)                  |
| * config_status (PENDING / PASS / FAIL)           |
| * final_config_session_id (UUID FK)               |
+---------------------------------------------------+
                          |
                          | 0..1 (FK ON DELETE SET NULL)
                          v
+---------------------------------------------------+
| finalconfig_manager.finalconfig_execution_session |
|---------------------------------------------------|
| * id (UUID PK)                                    |
| * status (COMPLETED / FAILED / ABORTED)           |
| * passed_steps, failed_steps, total_steps         |
| * completed_at (TIMESTAMPTZ)                      |
+---------------------------------------------------+
```

---

## 2. Từ Điển Dữ Liệu (Data Dictionary)

### 2.1 Bảng `traceability_manager.traceability_order`

| Cột (Column) | Kiểu Dữ Liệu | Khóa/Ràng Buộc | Ý Nghĩa Nghiệp Vụ & Ghi Chú |
|---|---|---|---|
| `id` | `UUID` | PK, Default gen_random_uuid() | Định danh duy nhất của lệnh sản xuất. |
| `so_number` | `VARCHAR(50)` | NOT NULL, Indexed | Mã đơn hàng bán hàng từ ERP (Sales Order, VD: `SO/2026/01850`). |
| `wa_number` | `VARCHAR(50)` | NOT NULL, Indexed | Mã lệnh phân bổ/sản xuất từ xưởng (Work Authorization, VD: `WA/2026/00412`). |
| `item_code` | `VARCHAR(100)` | NOT NULL, Indexed | Mã vật tư thành phẩm ERP (VD: `WSLRW-ATH-11`). |
| `connectivity` | `VARCHAR(20)` | NOT NULL, Default 'LoRaWAN' | Giao thức truyền thông vật lý: `LoRaWAN`, `Sigfox`, `NB-IoT`, `Others`. |
| `total_quantity`| `INTEGER` | NOT NULL, Default 0 | Số lượng sản phẩm chỉ tiêu trong lệnh. |
| `notes` | `TEXT` | Nullable | Ghi chú thêm từ điều độ sản xuất hoặc quản lý đơn. |
| `created_by` | `VARCHAR(100)` | Default 'system' | Người lập hoặc hệ thống kích hoạt tạo lệnh. |
| `created_at` | `TIMESTAMPTZ` | NOT NULL | Thời điểm khởi tạo lệnh trên hệ thống iTest. |
| `updated_at` | `TIMESTAMPTZ` | NOT NULL | Thời điểm cập nhật cuối cùng (tự động qua Trigger). |

*Ràng buộc duy nhất*: `UNIQUE(so_number, wa_number, item_code)` ngăn trùng lặp lệnh sản xuất.

### 2.2 Bảng `traceability_manager.traceability_device`

| Cột (Column) | Kiểu Dữ Liệu | Khóa/Ràng Buộc | Ý Nghĩa Nghiệp Vụ & Ghi Chú |
|---|---|---|---|
| `id` | `UUID` | PK, Default gen_random_uuid() | Định danh duy nhất của thiết bị cá thể. |
| `order_id` | `UUID` | FK -> `traceability_order(id)` | Khóa ngoại liên kết tới lô/lệnh sản xuất. |
| `serial_number` | `VARCHAR(100)` | UNIQUE, NOT NULL | Số Serial vật lý dán trên vỏ/mạch (VD: `SN202610220001`). |
| `sku` | `VARCHAR(100)` | NOT NULL, Indexed | Mã SKU thương mại của sản phẩm. |
| `fw_version` | `VARCHAR(50)` | NOT NULL | Phiên bản firmware nạp trong thiết bị (khớp với Long FW). |
| `hw_version` | `VARCHAR(50)` | Nullable | Phiên bản PCBA phần cứng (VD: `HW1.2`). |
| `me_version` | `VARCHAR(50)` | Nullable | Phiên bản cơ khí/vỏ hộp (VD: `ME1.0`). |
| `dev_eui` | `VARCHAR(32)` | Nullable, Indexed | Định danh thiết bị LoRaWAN (16 ký tự hex in hoa). |
| `app_eui` | `VARCHAR(32)` | Nullable | JoinEUI / AppEUI LoRaWAN (16 ký tự hex). |
| `app_key` | `VARCHAR(64)` | Nullable | Khóa bảo mật mạng OTAA 128-bit (32 ký tự hex). |
| `sigfox_id` | `VARCHAR(16)` | Nullable, Indexed | Định danh thiết bị mạng Sigfox (8 ký tự hex). |
| `sigfox_pac` | `VARCHAR(32)` | Nullable | Mã kích hoạt/chuyển vùng thiết bị Sigfox ban đầu. |
| `telecom_credentials` | `JSONB` | Default `{}` | Chứa các thông tin mở rộng (IMEI, IMSI, BLE MAC, Private keys). |
| `final_config_session_id` | `UUID` | FK -> `finalconfig_execution_session(id)` | Liên kết tới phiên nạp cấu hình thực thi. |
| `config_status` | `VARCHAR(20)` | NOT NULL, Default 'PENDING' | Trạng thái nạp cấu hình: `PENDING`, `CONFIGURED_PASS`, `CONFIGURED_FAIL`. |
| `chirpstack_synced` | `BOOLEAN`| NOT NULL, Default FALSE | Cờ xác nhận đã đồng bộ lên ChirpStack Network Server. |
| `status` | `VARCHAR(30)` | NOT NULL, Default 'INITIAL' | Trạng thái vòng đời: `INITIAL`, `CONFIGURED`, `QA_PASSED`, `PACKED`, `SHIPPED`. |
| `created_at` | `TIMESTAMPTZ` | NOT NULL | Thời điểm ghi nhận thiết bị vào hệ thống. |
| `updated_at` | `TIMESTAMPTZ` | NOT NULL | Thời điểm cập nhật cuối cùng. |

---

## 3. Metabase BI View: `v_device_traceability_lifecycle`

View `traceability_manager.v_device_traceability_lifecycle` được tối ưu sẵn nhằm giúp người dùng Metabase **không cần viết các câu lệnh JOIN phức tạp**:

```sql
SELECT
    d.id AS device_id,
    d.serial_number,
    o.so_number,
    o.wa_number,
    o.item_code,
    o.connectivity,
    d.sku,
    d.fw_version,
    d.hw_version,
    d.me_version,
    d.dev_eui,
    d.app_eui,
    d.sigfox_id,
    d.config_status,
    d.chirpstack_synced,
    d.status AS device_status,
    d.final_config_session_id,
    fcs.status AS final_config_session_status,
    fcs.serial_number AS final_config_device_sn,
    fcs.passed_steps AS config_passed_steps,
    fcs.failed_steps AS config_failed_steps,
    fcs.total_steps AS config_total_steps,
    fcs.completed_at AS configured_at,
    d.created_at AS device_created_at,
    o.created_at AS order_created_at
FROM traceability_manager.traceability_device d
JOIN traceability_manager.traceability_order o ON d.order_id = o.id
LEFT JOIN finalconfig_manager.finalconfig_execution_session fcs ON d.final_config_session_id = fcs.id;
```

---

## 4. Tuyển Tập Truy Vấn Mẫu (Metabase SQL Recipes)

Các câu truy vấn dưới đây có thể copy trực tiếp vào Metabase Native Query Editor để tạo Card / Dashboard:

### 4.1 Báo cáo Tiến độ & Tỷ lệ Đạt (Yield / Pass Rate) theo Lệnh Sản Xuất
```sql
-- Metabase Question: Tiến độ sản xuất & Pass Rate theo SO / WA
SELECT
    o.so_number AS "Đơn Hàng (SO)",
    o.wa_number AS "Lệnh SX (WA)",
    o.item_code AS "Mã Vật Tư",
    o.connectivity AS "Kết Nối",
    o.total_quantity AS "Kế Hoạch (SL)",
    COUNT(d.id) AS "Đã Quét (SL)",
    COUNT(d.id) FILTER (WHERE d.config_status = 'CONFIGURED_PASS') AS "Pass (SL)",
    COUNT(d.id) FILTER (WHERE d.config_status = 'CONFIGURED_FAIL') AS "Fail (SL)",
    COUNT(d.id) FILTER (WHERE d.config_status = 'PENDING') AS "Chưa Cấu Hình (SL)",
    ROUND(
        (COUNT(d.id) FILTER (WHERE d.config_status = 'CONFIGURED_PASS')::NUMERIC / NULLIF(COUNT(d.id), 0)) * 100,
        2
    ) AS "Tỷ Lệ Đạt (%)",
    ROUND(
        (COUNT(d.id)::NUMERIC / NULLIF(o.total_quantity, 0)) * 100,
        2
    ) AS "Tiến Độ Hoàn Thành (%)"
FROM traceability_manager.traceability_order o
LEFT JOIN traceability_manager.traceability_device d ON o.id = d.order_id
GROUP BY o.id, o.so_number, o.wa_number, o.item_code, o.connectivity, o.total_quantity
ORDER BY o.created_at DESC;
```

### 4.2 Sản Lượng Sản Xuất Theo Ngày & Loại Kết Nối (Daily Throughput)
```sql
-- Metabase Question: Biểu đồ sản lượng theo ngày (Trend Chart)
SELECT
    DATE_TRUNC('day', d.created_at) AS "Ngày",
    o.connectivity AS "Loại Kết Nối",
    COUNT(d.id) AS "Số Lượng Thiết Bị"
FROM traceability_manager.traceability_device d
JOIN traceability_manager.traceability_order o ON d.order_id = o.id
WHERE d.created_at >= NOW() - INTERVAL '30 days'
GROUP BY 1, 2
ORDER BY 1 ASC, 2;
```

### 4.3 Truy Vết Chi Tiết Thiết Bị (Drill-Down / Single Device Lookup)
Sử dụng tham số Metabase Field Filter `{{serial_number}}`:
```sql
-- Metabase Question: Chi tiết vòng đời 1 thiết bị theo Serial
SELECT
    v.serial_number AS "Serial Number",
    v.so_number AS "Sales Order",
    v.wa_number AS "Work Order",
    v.item_code AS "Item Code",
    v.connectivity AS "Kết Nối",
    v.sku AS "SKU",
    v.fw_version AS "Firmware",
    v.hw_version AS "Hardware",
    v.me_version AS "Mechanical",
    v.dev_eui AS "DevEUI",
    v.app_eui AS "AppEUI",
    v.sigfox_id AS "Sigfox ID",
    v.config_status AS "Trạng Thái Cấu Hình",
    v.chirpstack_synced AS "Đã Sync ChirpStack",
    v.config_passed_steps AS "Số Bước Đạt",
    v.config_failed_steps AS "Số Bước Lỗi",
    v.configured_at AS "Thời Gian Cấu Hình",
    v.device_created_at AS "Ngày Tạo"
FROM traceability_manager.v_device_traceability_lifecycle v
WHERE v.serial_number = {{serial_number}};
```

### 4.4 Thống Kê Phân Bổ Firmware & Hardware Revisions
```sql
-- Metabase Question: Ma trận phiên bản FW/HW
SELECT
    d.sku AS "SKU",
    d.hw_version AS "HW Version",
    d.fw_version AS "FW Version",
    COUNT(d.id) AS "Số Lượng Xuất Xưởng"
FROM traceability_manager.traceability_device d
GROUP BY d.sku, d.hw_version, d.fw_version
ORDER BY d.sku, COUNT(d.id) DESC;
```

### 4.5 Danh Sách Thiết Bị Cần Cấp Phát Lại / Đồng Bộ Lỗi ChirpStack
```sql
-- Metabase Question: Thiết bị đã cấu hình PASS nhưng chưa sync lên ChirpStack
SELECT
    d.serial_number,
    d.sku,
    d.dev_eui,
    d.app_eui,
    o.so_number,
    o.wa_number,
    d.created_at
FROM traceability_manager.traceability_device d
JOIN traceability_manager.traceability_order o ON d.order_id = o.id
WHERE o.connectivity = 'LoRaWAN'
  AND d.config_status = 'CONFIGURED_PASS'
  AND d.chirpstack_synced = FALSE
ORDER BY d.created_at ASC;
```

---

## 5. Hướng Dẫn Cấu Hình Kết Nối Trên Metabase

1. Mở trang quản trị Metabase: `Settings` -> `Admin Settings` -> `Databases` -> `Add Database`.
2. Điền thông tin kết nối PostgreSQL:
   - **Database type**: `PostgreSQL`
   - **Name**: `iTest Production Analytics`
   - **Host**: `127.0.0.1` (hoặc hostname Docker `itest-postgres`)
   - **Port**: `5432`
   - **Database name**: `itest_db`
   - **Username**: `itest_system_user` hoặc `itest_ops_user` (đã được cấp quyền SELECT toàn diện trên schema `traceability_manager`).
   - **Password**: Theo cấu hình môi trường `.env`.
3. Trong mục **Schemas included**, chọn schema:
   - `traceability_manager`
   - `finalconfig_manager`
   - `memmap_manager`
4. Metabase sẽ tự động quét Data Schema, nhận diện các Foreign Keys và kích hoạt tính năng **X-ray** cùng tính năng tự động tạo bảng liên kết.
