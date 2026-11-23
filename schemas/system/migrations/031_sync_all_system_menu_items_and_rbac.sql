-- ==============================================================================
-- MIGRATION: 031_sync_all_system_menu_items_and_rbac.sql
-- Module: identity / menu / rbac
-- Schema: system_schema
-- Description: Registers all missing menu items from SYSTEM_MENU_ITEMS into 
--              system_schema.menu_items and updates role_menu_permissions
--              to resolve FK violation errors completely.
-- ==============================================================================

SET search_path TO system_schema, public;

-- 1. Upsert all SYSTEM_MENU_ITEMS
INSERT INTO system_schema."menu_items" (
  "id", "title", "description", "route", "icon", "category", "pluginId", "tab", "order", "isActive"
) VALUES
  ('dashboard', 'Bảng điều khiển', 'Tổng quan hệ thống, trạng thái dịch vụ và phân quyền quản trị menu', '/dashboard', 'Odometer', 'system', NULL, NULL, 1, true),
  ('final-config:tool', 'Final Config Tool', 'Nạp cấu hình thiết bị tự động qua Web Serial và kiểm thử 4 công đoạn', '/plugins/final-config?tab=tool', 'Cpu', 'plugin', 'final-config', 'tool', 2, true),
  ('final-config:manager', 'Final Config Manager', 'Quản lý, tìm kiếm và tra cứu danh sách profile Final Config', '/plugins/final-config?tab=manager', 'Document', 'plugin', 'final-config', 'manager', 3, true),
  ('final-config:create', 'Tạo Final Config', 'Tạo mới cấu hình thiết bị từ Memmap Payload template', '/plugins/final-config?tab=create', 'CirclePlus', 'plugin', 'final-config', 'create', 4, true),
  ('device:manage', 'Thiết Bị (Devices)', 'Quản lý danh sách thiết bị IoT, liên kết dữ liệu Traceability (SO/WA/Item Code)', '/plugins/device', 'Cpu', 'plugin', 'device', NULL, 5, true),
  ('device-traceability:so', 'Sales Orders & Work Authorizations', 'Quản lý cây đơn hàng SO, chỉ thị xuất kho WA và danh sách thiết bị', '/plugins/device-traceability?tab=so', 'List', 'plugin', 'device-traceability', 'so', 6, true),
  ('device-traceability:devices', 'Device Traceability List', 'Tra cứu dòng đời thiết bị, lịch sử test và trạng thái hoàn thành', '/plugins/device-traceability?tab=devices', 'Search', 'plugin', 'device-traceability', 'devices', 7, true),
  ('device-traceability:final-config', 'Final Config Devices List', 'Tra cứu danh sách thiết bị đã cấu hình final config và audit log', '/plugins/device-traceability?tab=final-config', 'Checked', 'plugin', 'device-traceability', 'final-config', 8, true),
  ('device-traceability:config', 'Tra Cứu Cấu Hình Cuối', 'Tra cứu và giám sát cấu hình cuối cùng của thiết bị', '/plugins/device-traceability?tab=config', 'DocumentChecked', 'plugin', 'device-traceability', 'config', 9, true),
  ('memmap-payload:main', 'MEMMAP PAYLOAD', 'Quản lý bản đồ bộ nhớ (Memmap) và tải lên bảng thanh ghi thiết bị', '/plugins/memmap-payload', 'Layers', 'plugin', 'memmap-manager', 'main', 10, true),
  ('memmap-payload:manager', 'MEMMAP PAYLOAD', 'Quản lý bản đồ bộ nhớ (Memmap) và tải lên bảng thanh ghi thiết bị', '/plugins/memmap-manager?tab=manager', 'Files', 'plugin', 'memmap-manager', 'manager', 10, true),
  ('dis-manager:main', 'DIS Odoo Integration', 'Quản trị kết nối DIS API (Odoo), kiểm thử API Sandbox và đồng bộ Sales Orders vào iTest', '/plugins/dis-manager', 'Connection', 'plugin', 'dis-manager', NULL, 11, true),
  ('decoder:scripts', 'DECODER', 'Quản lý kịch bản giải mã Uplink payload thiết bị IoT, liên kết Item Code và FW Code', '/plugins/decoder?tab=list', 'Document', 'plugin', 'decoder', 'list', 12, true),
  ('lorawan-chirpstack:integration', 'CHIRPSTACK', 'Đồng bộ Gateways, Applications và Live Frames từ Network Server ChirpStack', '/plugins/lorawan-chirpstack?tab=overview', 'Connection', 'plugin', 'lorawan-chirpstack', 'overview', 13, true),
  ('lorawan-chirpstack:tenants', 'LoRaWAN Tenants', 'Quản lý tenant ChirpStack', '/plugins/lorawan-chirpstack?tab=tenants', 'User', 'plugin', 'lorawan-chirpstack', 'tenants', 14, true),
  ('lorawan-chirpstack:gateways', 'LoRaWAN Gateways', 'Quản lý gateway LoRaWAN', '/plugins/lorawan-chirpstack?tab=gateways', 'Connection', 'plugin', 'lorawan-chirpstack', 'gateways', 15, true),
  ('lorawan-chirpstack:devices', 'LoRaWAN Devices', 'Quản lý thiết bị LoRaWAN', '/plugins/lorawan-chirpstack?tab=devices', 'Cpu', 'plugin', 'lorawan-chirpstack', 'devices', 16, true),
  ('lorawan-chirpstack:telemetry', 'LoRaWAN Telemetry', 'Theo dõi uplink telemetry LoRaWAN', '/plugins/lorawan-chirpstack?tab=telemetry', 'DataLine', 'plugin', 'lorawan-chirpstack', 'telemetry', 17, true),
  ('testing:device-payload', 'DEVICE PAYLOAD', 'Giám sát trực tiếp dữ liệu thô và payload đã giải mã từ trạm testing', '/plugins/testing?tab=device-payload', 'DataLine', 'plugin', 'testing', 'device-payload', 18, true),
  ('testing:list-device-testing', 'LIST DEVICE TESTING', 'Danh sách các thiết bị kiểm thử được tạo ra bởi Testing Suite', '/plugins/testing?tab=list-device-testing', 'List', 'plugin', 'testing', 'list-device-testing', 19, true),
  ('testing:create-preconfig', 'CREATE PRECONFIG', 'Tạo cấu hình trước (Preconfig) cho thiết bị từ MEMMAP theo SO, WA, Item Code', '/plugins/testing?tab=create-preconfig', 'CirclePlus', 'plugin', 'testing', 'create-preconfig', 20, true),
  ('testing:list-preconfig', 'LIST PRECONFIG', 'Danh sách và tra cứu các profile Preconfig thiết bị đã tạo', '/plugins/testing?tab=list-preconfig', 'List', 'plugin', 'testing', 'list-preconfig', 21, true),
  ('testing:list-test-batch', 'LIST TEST BATCH', 'Danh sách và lịch sử các Test Batch đã thiết lập trong hệ thống', '/plugins/testing?tab=list-test-batch', 'ListFilter', 'plugin', 'testing', 'list-test-batch', 22, true),
  ('testing:list-flow-simulation', 'LIST FLOW SIMULATION', 'Quản lý danh sách kịch bản mô phỏng kiểm thử (Simulation Flow Templates)', '/plugins/testing?tab=list-flow-simulation', 'Cpu', 'plugin', 'testing', 'list-flow-simulation', 23, true),
  ('testing:list-device-simulation', 'LIST DEVICE SIMULATION', 'Quản lý danh sách thiết bị simulation độc lập', '/plugins/testing?tab=list-device-simulation', 'Radio', 'plugin', 'testing', 'list-device-simulation', 24, true),
  ('testing:so-test-batch', 'SO TEST BATCH', 'Quản lý liên kết giữa Sale Order (SO) và Test Batch', '/plugins/testing?tab=so-test-batch', 'Layers', 'plugin', 'testing', 'so-test-batch', 25, true),
  ('testing:create-test-batch', 'CREATE TEST BATCH', 'Khởi tạo cấu hình Test Batch với ITEM-CODE, LONG_FW, gán Simulation Flow tự động', '/plugins/testing?tab=create-test-batch', 'FolderPlus', 'plugin', 'testing', 'create-test-batch', 26, true),
  ('testing:device-simulation', 'CREATE SIMULATION FLOW', 'Tạo kịch bản mô phỏng kiểm thử kết hợp Auto Check: Downlink, Delay, Cửa sổ đo', '/plugins/testing?tab=device-simulation', 'Cpu', 'plugin', 'testing', 'device-simulation', 27, true),
  ('testing:gateway', 'Gateway Testing', 'Đo kiểm Gateway, kiểm tra RF/RSSI/SNR, gói tin và liên kết ChirpStack', '/plugins/testing?tab=gateway', 'Odometer', 'plugin', 'testing', 'gateway', 28, true),
  ('device:devices', 'Thiết Bị (Devices)', 'Quản lý thông tin thiết bị, serial number, network ID và truy vết nguồn gốc', '/plugins/device?tab=devices', 'Cpu', 'plugin', 'device', 'devices', 29, true)
ON CONFLICT ("id") DO UPDATE SET
  "title" = EXCLUDED."title",
  "description" = EXCLUDED."description",
  "route" = EXCLUDED."route",
  "icon" = EXCLUDED."icon",
  "category" = EXCLUDED."category",
  "pluginId" = EXCLUDED."pluginId",
  "tab" = EXCLUDED."tab",
  "order" = EXCLUDED."order",
  "isActive" = EXCLUDED."isActive",
  "updated_at" = CURRENT_TIMESTAMP;

-- 2. Seed permissions for Super Admin
INSERT INTO system_schema."role_menu_permissions" ("roleId", "roleCode", "menuItemId")
SELECT r."id", r."code", m."id"
FROM system_schema."roles" r
CROSS JOIN system_schema."menu_items" m
WHERE r."code" IN ('SUPER_ADMIN', 'ADMIN', 'admin')
ON CONFLICT ("roleId", "menuItemId") DO NOTHING;

-- 3. Refresh views
DROP VIEW IF EXISTS system_schema."system_menu_items" CASCADE;
CREATE OR REPLACE VIEW system_schema."system_menu_items" AS
SELECT * FROM system_schema."menu_items";

DROP VIEW IF EXISTS public."system_menu_items" CASCADE;
CREATE OR REPLACE VIEW public."system_menu_items" AS
SELECT * FROM system_schema."menu_items";

DROP VIEW IF EXISTS public."menu_items" CASCADE;
CREATE OR REPLACE VIEW public."menu_items" AS
SELECT * FROM system_schema."menu_items";
