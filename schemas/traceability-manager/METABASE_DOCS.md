# Tài Liệu Hướng Dẫn Truy Vấn Metabase BI - Device Traceability

Tài liệu này cung cấp toàn bộ đặc tả dữ liệu, mô hình quan hệ, và bộ truy vấn mẫu (SQL Recipes) để phục vụ việc tích hợp và xây dựng Dashboard/Báo cáo trên **Metabase BI** cho module **Device Traceability** thuộc nền tảng `iTest`.

---

## 1. Tổng Quan Kiến Trúc & Mô Hình Dữ Liệu (Data Contract v2)

Module Traceability được thiết kế trong schema riêng biệt `traceability_manager` với 3 tầng dữ liệu chuẩn hóa linh hoạt:
1. **Tầng 1 - Đơn Bán Hàng (`traceability_so`)**: Quản lý Đơn Bán Hàng (Sale Order - SO, ví dụ `SO/2026/01855`), tên khách hàng (`customer_name`), và ghi chú hợp đồng.
2. **Tầng 2 - Lệnh Sản Xuất (`traceability_wa`)**: Quản lý Lệnh Sản Xuất (Work Authorization - WA) thuộc SO với quan hệ 1 SO -> n WA. Cú pháp bắt buộc chuẩn: `WA/xxxx/xxxxx` (ví dụ: `WA/2026/00412`).
3. **Tầng 3 - Thiết Bị Cá Thể & Kết Quả Đo Kiểm CSV (`traceability_device`)**: Đại diện cho từng thiết bị vật lý với Serial Number độc nhất (`serial_number`), DevEUI/Device Key, Item Code, SKU, HW/FW Version. Thiết bị có thể liên kết trực tiếp qua SO (`so_id`) hoặc thông qua Lệnh Sản Xuất (`wa_id`). Bảng lưu trữ đầy đủ dữ liệu đo kiểm phần cứng từ file CSV kiểm thử trạm (`WSLRW-C-RS485-01_tested.csv` format) và kết quả nạp Final Config.
4. **Tầng Phân Tích Tổng Hợp (`v_device_traceability_lifecycle`)**: View tối ưu sẵn cho Metabase, gom toàn bộ thông tin vòng đời thiết bị từ SO, WA, kết quả test phần cứng và trạng thái phiên Final Config, kèm cờ điều kiện tiên quyết `is_eligible_for_final_config` (`test_result = 'PASS'`).

```
+---------------------------------------------------+
|      traceability_manager.traceability_so         |
|---------------------------------------------------|
| * id (UUID PK)                                    |
| * so_number (VARCHAR UNIQUE)  -- SO/2026/01855    |
| * customer_name (VARCHAR)                         |
| * notes (TEXT)                                    |
+---------------------------------------------------+
       | 1                           | 1
       |                             |
       | n                           | n (hỗ trợ trực tiếp)
       v                             |
+------------------------------------+              |
|   traceability_manager.traceability_wa            |
|---------------------------------------------------|
| * id (UUID PK)                                    |
| * so_id (UUID FK -> so.id)                        |
| * wa_number (VARCHAR UNIQUE)  -- WA/xxxx/xxxxx    |
| * item_code (VARCHAR)                             |
| * planned_quantity (INTEGER)                      |
+---------------------------------------------------+
       | 0..1 (hoặc null nếu thuộc thẳng SO)
       |
       | n
       v
+---------------------------------------------------+
|     traceability_manager.traceability_device      |
|---------------------------------------------------|
| * id (UUID PK)                                    |
| * so_id (UUID FK -> so.id)                        |
| * wa_id (UUID FK -> wa.id, ON DELETE SET NULL)    |
| * serial_number (VARCHAR UNIQUE) -- LRCR26000093   |
| * device_key / dev_eui                            |
| * item_code, sku, hw_version, fw_version          |
| * test_result (PASS / FAIL / PENDING)             |
| * test_id, test_station, test_person, tested_at   |
| * test_raw_data (JSONB)                           |
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
| * status (IN_PROGRESS, COMPLETED, FAILED, ...)     |
| * current_step, total_steps, passed_steps          |
| * started_at, completed_at, error_message         |
+---------------------------------------------------+
```

---

## 2. Từ Điển Dữ Liệu (Data Dictionary)

### 2.1 Bảng `traceability_manager.traceability_so`

| Cột (Column) | Kiểu Dữ Liệu | Khóa/Ràng Buộc | Ý Nghĩa Nghiệp Vụ & Ghi Chú |
|---|---|---|---|
| `id` | `UUID` | PK, Default gen_random_uuid() | Định danh duy nhất của Đơn Bán Hàng. |
| `so_number` | `VARCHAR(50)` | NOT NULL, UNIQUE, Indexed | Mã Đơn Bán Hàng từ ERP (VD: `SO/2026/01855`). |
| `customer_name` | `VARCHAR(255)` | Nullable | Tên khách hàng hoặc tổ chức đặt hàng. |
| `notes` | `TEXT` | Nullable | Ghi chú đơn hàng. |
| `created_at` | `TIMESTAMPTZ` | NOT NULL | Thời điểm tạo bản ghi. |
| `updated_at` | `TIMESTAMPTZ` | NOT NULL | Thời điểm cập nhật cuối cùng (tự động qua Trigger). |

### 2.2 Bảng `traceability_manager.traceability_wa`

| Cột (Column) | Kiểu Dữ Liệu | Khóa/Ràng Buộc | Ý Nghĩa Nghiệp Vụ & Ghi Chú |
|---|---|---|---|
| `id` | `UUID` | PK, Default gen_random_uuid() | Định danh duy nhất của Lệnh Sản Xuất. |
| `so_id` | `UUID` | NOT NULL, FK -> `traceability_so(id)` | Khóa ngoại tới SO tương ứng (CASCADE DELETE). |
| `wa_number` | `VARCHAR(50)` | NOT NULL, Indexed | Cú pháp chuẩn `WA/xxxx/xxxxx` (VD: `WA/2026/00412`). Ràng buộc duy nhất phức hợp `(so_id, wa_number, item_code)` cho phép quản lý nhiều ITEM_CODE độc lập trong cùng một lệnh WA. |
| `item_code` | `VARCHAR(100)` | Nullable, Indexed | Mã chủng loại thành phẩm ERP (VD: `WSLRW-C-RS485-01`). |
| `planned_quantity` | `INTEGER` | NOT NULL, Default 0 | Số lượng kế hoạch của lệnh sản xuất. |
| `notes` | `TEXT` | Nullable | Ghi chú kỹ thuật của lệnh sản xuất. |
| `created_at` | `TIMESTAMPTZ` | NOT NULL | Thời điểm tạo bản ghi. |
| `updated_at` | `TIMESTAMPTZ` | NOT NULL | Thời điểm cập nhật cuối cùng. |

### 2.3 Bảng `traceability_manager.traceability_device`

| Cột (Column) | Kiểu Dữ Liệu | Khóa/Ràng Buộc | Ý Nghĩa Nghiệp Vụ & Ghi Chú (Khớp CSV `WSLRW-C-RS485-01_tested.csv`) |
|---|---|---|---|
| `id` | `UUID` | PK, Default gen_random_uuid() | Định danh duy nhất của thiết bị cá thể. |
| `so_id` | `UUID` | NOT NULL, FK -> `traceability_so(id)` | Bắt buộc liên kết với Đơn Bán Hàng. |
| `wa_id` | `UUID` | Nullable, FK -> `traceability_wa(id)` | Có thể liên kết với Lệnh Sản Xuất hoặc NULL nếu gán trực tiếp cho SO. |
| `serial_number` | `VARCHAR(100)` | NOT NULL, UNIQUE, Indexed | Mã định danh phần cứng (VD: `LRCR26000093`). |
| `device_key` | `VARCHAR(64)` | Nullable, Indexed | Device Key hex từ trạm đo kiểm phần cứng. |
| `dev_eui` | `VARCHAR(64)` | Nullable, Indexed | Chuẩn hóa DevEUI viễn thông (16 ký tự hex). |
| `item_code` | `VARCHAR(100)` | Nullable | Mã vật tư thành phẩm (VD: `WSLRW-C-RS485-01`). |
| `sku` | `VARCHAR(100)` | Nullable | SKU sản phẩm (VD: `WSLRW-MB485`). |
| `hw_version` | `VARCHAR(50)` | Nullable | Phiên bản phần cứng (VD: `2H`). |
| `fw_version` | `VARCHAR(50)` | Nullable | Phiên bản firmware nạp ở khâu đo kiểm (VD: `5F0917`). |
| `test_result` | `VARCHAR(20)` | NOT NULL, Default 'PENDING' | Kết quả đo kiểm trạm: `PASS`, `FAIL`, `PENDING`. **Điều kiện bắt buộc: Chỉ PASS mới được phép chọn để nạp Final Config**. |
| `test_id` | `VARCHAR(255)` | Nullable | Mã định danh lần chạy test từ hệ thống kiểm thử. |
| `test_station` | `VARCHAR(100)` | Nullable | Trạm kiểm tra (VD: `STATION-EN-3`). |
| `test_person` | `VARCHAR(100)` | Nullable | Người vận hành trạm kiểm thử (VD: `DO QUANG KHANH`). |
| `tested_at` | `TIMESTAMPTZ` | Nullable, Indexed | Thời gian hoàn tất bài test trạm. |
| `test_raw_data` | `JSONB` | NOT NULL, Default '{}'::jsonb | Lưu toàn bộ payload thô CSV (start_time, duration, calib, v.v.). |
| `final_config_session_id` | `UUID` | FK -> `finalconfig_execution_session(id)` | Phiên nạp cấu hình thực thi. |
| `config_status` | `VARCHAR(20)` | Default 'PENDING' | Trạng thái nạp cấu hình: `PENDING`, `CONFIGURED_PASS`, `CONFIGURED_FAIL`. |
| `status` | `VARCHAR(30)` | Default 'TESTED' | Trạng thái vòng đời (`TESTED`, `CONFIGURED`, `SHIPPED`). |

---

## 3. View Phân Tích: `v_device_traceability_lifecycle`

View này là nguồn dữ liệu chuẩn hóa chính cho Metabase, liên kết tự động giữa SO, WA, Device Test Data, và Phiên Final Config:

```sql
SELECT * FROM traceability_manager.v_device_traceability_lifecycle LIMIT 10;
```

### Các Cột Trong View:
- `device_id`: Khóa UUID thiết bị.
- `serial_number`: Số serial phần cứng.
- `device_key`, `dev_eui`: Định danh viễn thông.
- `item_code`: Mã sản phẩm (ưu tiên từ device, nếu trống lấy từ WA).
- `sku`, `hw_version`, `fw_version`: Cấu hình vật lý.
- `test_result`: Kết quả test trạm (`PASS` / `FAIL`).
- `test_id`, `test_station`, `test_person`, `tested_at`, `test_raw_data`: Chi tiết đo kiểm trạm.
- `is_eligible_for_final_config`: `BOOLEAN` (`test_result = 'PASS'`) - Điều kiện cho phép nạp Final Config.
- `so_id`, `so_number`, `customer_name`: Thông tin đơn hàng.
- `wa_id`, `wa_number`: Thông tin lệnh sản xuất.
- `final_config_session_id`, `final_config_status`, `final_config_session_status`, `final_config_passed_steps`: Kết quả Final Config.
- `overall_status`: Trạng thái tổng quát.

---

## 4. Bộ Truy Vấn Mẫu Cho Metabase (SQL Recipes)

### 4.1 Thống kê tỷ lệ đạt kiểm thử phần cứng và điều kiện Final Config theo SO
```sql
SELECT
  so_number,
  customer_name,
  COUNT(device_id) AS total_devices,
  COUNT(CASE WHEN test_result = 'PASS' THEN 1 END) AS test_passed,
  COUNT(CASE WHEN test_result = 'FAIL' THEN 1 END) AS test_failed,
  ROUND(100.0 * COUNT(CASE WHEN test_result = 'PASS' THEN 1 END) / NULLIF(COUNT(device_id), 0), 2) AS test_yield_percent,
  COUNT(CASE WHEN is_eligible_for_final_config AND final_config_status = 'CONFIGURED_PASS' THEN 1 END) AS final_config_passed
FROM traceability_manager.v_device_traceability_lifecycle
GROUP BY so_number, customer_name
ORDER BY so_number DESC;
```

### 4.2 Tiến độ thực hiện theo từng Lệnh Sản Xuất (WA) thuộc SO
```sql
SELECT
  wa.wa_number,
  so.so_number,
  wa.item_code,
  wa.planned_quantity,
  COUNT(d.id) AS tested_count,
  COUNT(CASE WHEN d.test_result = 'PASS' THEN 1 END) AS pass_count,
  ROUND(100.0 * COUNT(d.id) / NULLIF(wa.planned_quantity, 0), 1) AS progress_percent
FROM traceability_manager.traceability_wa wa
JOIN traceability_manager.traceability_so so ON wa.so_id = so.id
LEFT JOIN traceability_manager.traceability_device d ON wa.id = d.wa_id
GROUP BY wa.wa_number, so.so_number, wa.item_code, wa.planned_quantity
ORDER BY wa.wa_number DESC;
```

### 4.3 Danh sách thiết bị PASS đủ điều kiện chờ nạp Final Config
```sql
SELECT
  serial_number,
  dev_eui,
  item_code,
  sku,
  so_number,
  wa_number,
  tested_at,
  test_station,
  test_person
FROM traceability_manager.v_device_traceability_lifecycle
WHERE is_eligible_for_final_config = true
  AND (final_config_status IS NULL OR final_config_status = 'PENDING')
ORDER BY tested_at DESC;
```

---

## 5. View Metabase Mới: `v_so_summary` & `v_device_summary`

### 5.1 View `traceability_manager.v_so_summary` (Theo Dõi Tiến Độ Đơn Hàng SO/WA/Item Code)
View phân tích tổng hợp tiến độ đơn hàng theo SO, Lệnh sản xuất (WA) và Mã thành phẩm (Item Code). Phục vụ trực tiếp việc tạo Dashboard/Cards trên Metabase theo dõi:
- Số lượng kế hoạch (`planned_quantity`).
- Số lượng đã đo kiểm (`tested` / `tested_quantity`), `tested_pass_quantity`, `tested_fail_quantity`.
- Số lượng còn lại chưa test (`remaining_test`).
- Số lượng thiết bị cá thể đã nạp cấu hình thành công (`config_distinct`).
- Số lượng còn lại chưa cấu hình (`remaining_config`).
- Tiến độ phần trăm đo kiểm (`test_progress_percent`) và cấu hình (`config_progress_percent`).
- Trạng thái sản xuất (`production_status`: `PENDING`, `TESTING`, `CONFIGURING`, `COMPLETED`).

#### Truy vấn mẫu Metabase:
```sql
-- Tracking tiến độ tổng thể các đơn hàng SO
SELECT
  so_number,
  customer_name,
  wa_number,
  item_code,
  planned_quantity,
  tested,
  remaining_test,
  config_distinct,
  remaining_config,
  test_progress_percent,
  config_progress_percent,
  production_status,
  last_tested_at,
  last_configured_at
FROM traceability_manager.v_so_summary
ORDER BY so_number DESC, wa_number ASC;
```

```sql
-- Rollup theo từng SO (Tổng hợp cho Executive Dashboard)
SELECT
  so_number,
  customer_name,
  SUM(planned_quantity) AS total_planned,
  SUM(tested) AS total_tested,
  SUM(remaining_test) AS total_remaining_test,
  SUM(config_distinct) AS total_configured,
  SUM(remaining_config) AS total_remaining_config,
  ROUND(100.0 * SUM(tested) / NULLIF(SUM(planned_quantity), 0), 2) AS overall_test_yield,
  ROUND(100.0 * SUM(config_distinct) / NULLIF(SUM(planned_quantity), 0), 2) AS overall_config_yield
FROM traceability_manager.v_so_summary
GROUP BY so_number, customer_name
ORDER BY so_number DESC;
```

### 5.2 View `traceability_manager.v_device_summary` (Tra Cứu Thiết Bị Với DevEUI, AppKey, AppEUI, Serial)
View cung cấp bảng dữ liệu chi tiết cho từng thiết bị cá thể phục vụ tìm kiếm, tra cứu bảo hành, quản lý xuất kho và đối soát thiết bị viễn thông:
- `dev_eui`: Device EUI viễn thông chuẩn hóa (16 ký tự hex).
- `app_key`: Khóa mã hóa OTAA AppKey (32 ký tự hex) nạp từ Final Config hoặc đo kiểm.
- `app_eui`: AppEUI / JoinEUI lấy từ giá trị readback của Final Config (register 31 / audit readback); nếu chưa final config, fallback sang thiết bị hoặc lần đăng ký test gần nhất. Không có giá trị thì `NULL`, không điền giả toàn số 0.
- `serial_number`: Số Serial Number phần cứng duy nhất.
- `so_number`, `wa_number`, `item_code`, `hw_version`, `fw_version`. View không xuất `device_key` hoặc `sku`.
- `test_result`, `test_station`, `test_person`, `tested_at`.
- `config_status`, `config_person`, `configured_at`, `final_config_session_id`.

#### Truy vấn mẫu Metabase:
```sql
-- Tra cứu thiết bị theo Serial, DevEUI hoặc AppKey
SELECT
  serial_number,
  dev_eui,
  app_eui,
  app_key,
  item_code,
  so_number,
  wa_number,
  test_result,
  config_status,
  config_person,
  configured_at
FROM traceability_manager.v_device_summary
WHERE serial_number = {{search_serial}}
   OR dev_eui ILIKE {{search_eui}}
   OR app_key ILIKE {{search_app_key}};
```

