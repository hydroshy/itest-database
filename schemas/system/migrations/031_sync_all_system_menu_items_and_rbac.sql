-- ==============================================================================
-- MIGRATION: 031_sync_all_system_menu_items_and_rbac.sql
-- Module: identity / rbac / menu
-- Schema: system_schema, public
-- Description: Synchronizes all 27+ system and plugin menu items into
--              system_schema.menu_items to fix FK constraint violations in
--              role_menu_permissions.
--              Registers all corresponding menu view permissions into
--              system_schema.permission, assigns canonical defaults to roles,
--              and creates unified RBAC views (v_role_menu_access, v_user_rbac_overview)
--              linking menu views with functional permissions.
-- ==============================================================================

SET search_path TO system_schema, public;

-- 1. Sync All Canonical System & Plugin Menu Items
INSERT INTO system_schema."menu_items" (
  "id", "title", "description", "route", "icon", "category", "pluginId", "tab", "order", "isActive"
) VALUES
  ('dashboard', 'Bảng điều khiển', 'Tổng quan hệ thống, trạng thái dịch vụ và phân quyền quản trị menu', '/dashboard', 'Odometer', 'system', NULL, NULL, 1, true),
  ('final-config:tool', 'Final Config Tool', 'Nạp cấu hình thiết bị tự động qua Web Serial và kiểm thử 4 công đoạn', '/plugins/final-config?tab=tool', 'Cpu', 'plugin', 'final-config', 'tool', 2, true),
  ('final-config:manager', 'Final Config Manager', 'Quản lý, tìm kiếm và tra cứu danh sách profile Final Config', '/plugins/final-config?tab=manager', 'Document', 'plugin', 'final-config', 'manager', 3, true),
  ('final-config:create', 'Tạo Final Config', 'Tạo mới cấu hình thiết bị từ Memmap Payload template', '/plugins/final-config?tab=create', 'CirclePlus', 'plugin', 'final-config', 'create', 4, true),
  ('device:manage', 'Thiết Bị (Devices)', 'Quản lý danh sách thiết bị IoT, liên kết dữ liệu Traceability (SO/WA/Item Code) và trạng thái hoạt động độc lập', '/plugins/device', 'Cpu', 'plugin', 'device', 'manage', 5, true),
  ('device-traceability:so', 'Sales Orders & Work Authorizations', 'Quản lý cây đơn hàng SO, chỉ thị xuất kho WA và danh sách thiết bị', '/plugins/device-traceability?tab=so', 'List', 'plugin', 'device-traceability', 'so', 6, true),
  ('device-traceability:devices', 'Device Traceability List', 'Tra cứu dòng đời thiết bị, lịch sử test và trạng thái hoàn thành', '/plugins/device-traceability?tab=devices', 'Search', 'plugin', 'device-traceability', 'devices', 7, true),
  ('device-traceability:final-config', 'Final Config Devices List', 'Tra cứu danh sách thiết bị đã cấu hình final config và audit log', '/plugins/device-traceability?tab=final-config', 'Checked', 'plugin', 'device-traceability', 'final-config', 8, true),
  ('memmap-payload:main', 'MEMMAP PAYLOAD', 'Quản lý bản đồ bộ nhớ (Memmap) và tải lên bảng thanh ghi thiết bị', '/plugins/memmap-payload', 'Layers', 'plugin', 'memmap-manager', 'main', 9, true),
  ('dis-manager:main', 'DIS Odoo Integration', 'Quản trị kết nối DIS API (Odoo), kiểm thử API Sandbox và đồng bộ Sales Orders vào iTest', '/plugins/dis-manager', 'Connection', 'plugin', 'dis-manager', 'main', 10, true),
  ('decoder:scripts', 'DECODER', 'Quản lý kịch bản giải mã Uplink payload thiết bị IoT, liên kết Item Code và FW Code', '/plugins/decoder?tab=list', 'Document', 'plugin', 'decoder', 'list', 11, true),
  ('lorawan-chirpstack:integration', 'CHIRPSTACK', 'Đồng bộ Gateways, Applications và Live Frames từ Network Server ChirpStack', '/plugins/lorawan-chirpstack?tab=overview', 'Connection', 'plugin', 'lorawan-chirpstack', 'overview', 12, true),
  ('lorawan-chirpstack:tenants', 'LoRaWAN Tenants', 'Quản lý tenant ChirpStack', '/plugins/lorawan-chirpstack?tab=tenants', 'User', 'plugin', 'lorawan-chirpstack', 'tenants', 13, true),
  ('lorawan-chirpstack:gateways', 'LoRaWAN Gateways', 'Quản lý gateway LoRaWAN', '/plugins/lorawan-chirpstack?tab=gateways', 'Connection', 'plugin', 'lorawan-chirpstack', 'gateways', 14, true),
  ('lorawan-chirpstack:devices', 'LoRaWAN Devices', 'Quản lý thiết bị LoRaWAN', '/plugins/lorawan-chirpstack?tab=devices', 'Cpu', 'plugin', 'lorawan-chirpstack', 'devices', 15, true),
  ('lorawan-chirpstack:telemetry', 'LoRaWAN Telemetry', 'Theo dõi uplink telemetry LoRaWAN', '/plugins/lorawan-chirpstack?tab=telemetry', 'DataLine', 'plugin', 'lorawan-chirpstack', 'telemetry', 16, true),
  ('testing:device-payload', 'DEVICE PAYLOAD', 'Giám sát trực tiếp dữ liệu thô và payload đã giải mã từ trạm testing', '/plugins/testing?tab=device-payload', 'DataLine', 'plugin', 'testing', 'device-payload', 17, true),
  ('testing:create-device-testing', 'CREATE DEVICE TESTING', 'Tạo mới phiên kiểm thử thiết bị (DUT), gắn kịch bản Flow và kích hoạt Auto Check', '/plugins/testing?tab=create-device-testing', 'CirclePlus', 'plugin', 'testing', 'create-device-testing', 18, true),
  ('testing:list-device-testing', 'LIST DEVICE TESTING', 'Danh sách các thiết bị kiểm thử được tạo ra bởi Testing Suite', '/plugins/testing?tab=list-device-testing', 'List', 'plugin', 'testing', 'list-device-testing', 19, true),
  ('testing:create-preconfig', 'CREATE PRECONFIG', 'Tạo cấu hình trước (Preconfig) cho thiết bị từ MEMMAP theo SO, WA, Item Code', '/plugins/testing?tab=create-preconfig', 'CirclePlus', 'plugin', 'testing', 'create-preconfig', 20, true),
  ('testing:list-preconfig', 'LIST PRECONFIG', 'Danh sách và tra cứu các profile Preconfig thiết bị đã tạo', '/plugins/testing?tab=list-preconfig', 'List', 'plugin', 'testing', 'list-preconfig', 21, true),
  ('testing:list-test-batch', 'LIST TEST BATCH', 'Danh sách và lịch sử các Test Batch đã thiết lập trong hệ thống', '/plugins/testing?tab=list-test-batch', 'ListFilter', 'plugin', 'testing', 'list-test-batch', 22, true),
  ('testing:list-flow-simulation', 'LIST FLOW SIMULATION', 'Quản lý danh sách kịch bản mô phỏng kiểm thử (Simulation Flow Templates)', '/plugins/testing?tab=list-flow-simulation', 'Cpu', 'plugin', 'testing', 'list-flow-simulation', 23, true),
  ('testing:list-device-simulation', 'LIST DEVICE SIMULATION', 'Quản lý danh sách thiết bị simulation độc lập', '/plugins/testing?tab=list-device-simulation', 'Radio', 'plugin', 'testing', 'list-device-simulation', 24, true),
  ('testing:so-test-batch', 'SO TEST BATCH', 'Quản lý liên kết giữa Sale Order (SO) và Test Batch', '/plugins/testing?tab=so-test-batch', 'Layers', 'plugin', 'testing', 'so-test-batch', 25, true),
  ('testing:create-test-batch', 'CREATE TEST BATCH', 'Khởi tạo cấu hình Test Batch với ITEM-CODE, LONG_FW, gán Simulation Flow tự động', '/plugins/testing?tab=create-test-batch', 'FolderPlus', 'plugin', 'testing', 'create-test-batch', 26, true),
  ('testing:device-simulation', 'CREATE SIMULATION FLOW', 'Tạo kịch bản mô phỏng kiểm thử kết hợp Auto Check: Downlink, Delay, Cửa sổ đo', '/plugins/testing?tab=device-simulation', 'Cpu', 'plugin', 'testing', 'device-simulation', 27, true),
  -- Backward-compatibility & Alias Items
  ('device-traceability:config', 'Tra Cứu Cấu Hình Cuối', 'Tra cứu và giám sát cấu hình cuối cùng của thiết bị', '/plugins/device-traceability?tab=config', 'DocumentChecked', 'plugin', 'device-traceability', 'config', 28, true),
  ('memmap-payload:manager', 'MEMMAP PAYLOAD (Manager)', 'Quản lý bản đồ bộ nhớ (Memmap) và tải lên bảng thanh ghi thiết bị', '/plugins/memmap-manager?tab=manager', 'Files', 'plugin', 'memmap-manager', 'manager', 29, true),
  ('device:devices', 'Thiết Bị (Legacy)', 'Quản lý thông tin thiết bị, serial number, network ID và truy vết nguồn gốc', '/plugins/device?tab=devices', 'Cpu', 'plugin', 'device', 'devices', 30, true),
  ('testing:gateway', 'Gateway Testing', 'Đo kiểm Gateway, kiểm tra RF/RSSI/SNR, gói tin và liên kết ChirpStack', '/plugins/testing?tab=gateway', 'Odometer', 'plugin', 'testing', 'gateway', 31, true),
  ('testing:gateway-sessions', 'Gateway Sessions', 'Tra cứu các phiên đo kiểm Gateway và dữ liệu tín hiệu RF', '/plugins/testing?tab=gateway-sessions', 'Connection', 'plugin', 'testing', 'gateway-sessions', 32, true),
  ('testing:simulation-devices', 'Simulation Devices List', 'Quản lý thiết bị mô phỏng kiểm thử độc lập', '/plugins/testing?tab=simulation-devices', 'Radio', 'plugin', 'testing', 'simulation-devices', 33, true),
  ('testing:device-auto-check', 'Device Auto Check', 'Cấu hình ngưỡng kiểm tra tự động cho kịch bản đo', '/plugins/testing?tab=device-auto-check', 'Checked', 'plugin', 'testing', 'device-auto-check', 34, true),
  ('testing:packets', 'Live Packets Monitor', 'Theo dõi luồng gói tin thô và RF metrics theo thời gian thực', '/plugins/testing?tab=packets', 'DataLine', 'plugin', 'testing', 'packets', 35, true),
  ('so-test-batch:main', 'SO Test Batch Manager', 'Liên kết đơn hàng SO và lô đo kiểm Test Batch', '/plugins/so-test-batch', 'Layers', 'plugin', 'testing', 'so-test-batch', 36, true),
  ('testing:test-batch', 'Device Test Batch', 'Thiết lập và giám sát tiến độ đo kiểm theo lô thiết bị', '/plugins/testing?tab=test-batch', 'ListFilter', 'plugin', 'testing', 'test-batch', 37, true)
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

-- 2. Register Unified Permissions for Menu Views & Functional Access
INSERT INTO system_schema."permission" ("name", "description", "module", "action")
VALUES
  -- Menu View Permissions
  ('menu:dashboard:view', 'Xem Bảng điều khiển trung tâm (Dashboard)', 'menu', 'read'),
  ('menu:final-config-tool:view', 'Truy cập Final Config Tool', 'menu', 'read'),
  ('menu:final-config-manager:view', 'Truy cập Final Config Manager', 'menu', 'read'),
  ('menu:final-config-create:view', 'Tạo Final Config mới', 'menu', 'read'),
  ('menu:device-manage:view', 'Truy cập quản lý Thiết Bị (Devices)', 'menu', 'read'),
  ('menu:device-traceability-so:view', 'Xem Đơn hàng Sales Orders & WA', 'menu', 'read'),
  ('menu:device-traceability-devices:view', 'Xem Device Traceability List', 'menu', 'read'),
  ('menu:device-traceability-final-config:view', 'Xem Final Config Devices List', 'menu', 'read'),
  ('menu:memmap-payload-main:view', 'Truy cập phân hệ MEMMAP PAYLOAD', 'menu', 'read'),
  ('menu:dis-manager-main:view', 'Truy cập phân hệ DIS Odoo Integration', 'menu', 'read'),
  ('menu:decoder-scripts:view', 'Truy cập phân hệ DECODER scripts', 'menu', 'read'),
  ('menu:lorawan-chirpstack-integration:view', 'Truy cập LoRaWAN ChirpStack Overview', 'menu', 'read'),
  ('menu:lorawan-chirpstack-tenants:view', 'Xem danh sách LoRaWAN Tenants', 'menu', 'read'),
  ('menu:lorawan-chirpstack-gateways:view', 'Xem danh sách LoRaWAN Gateways', 'menu', 'read'),
  ('menu:lorawan-chirpstack-devices:view', 'Xem danh sách LoRaWAN Devices', 'menu', 'read'),
  ('menu:lorawan-chirpstack-telemetry:view', 'Xem LoRaWAN Live Telemetry', 'menu', 'read'),
  ('menu:testing-device-payload:view', 'Xem Device Live Payload Testing', 'menu', 'read'),
  ('menu:testing-create-device-testing:view', 'Tạo mới phiên kiểm thử thiết bị', 'menu', 'read'),
  ('menu:testing-list-device-testing:view', 'Xem danh sách thiết bị kiểm thử', 'menu', 'read'),
  ('menu:testing-create-preconfig:view', 'Tạo Preconfig thiết bị từ Memmap', 'menu', 'read'),
  ('menu:testing-list-preconfig:view', 'Xem danh sách Preconfig thiết bị', 'menu', 'read'),
  ('menu:testing-list-test-batch:view', 'Xem danh sách Test Batches', 'menu', 'read'),
  ('menu:testing-list-flow-simulation:view', 'Xem danh sách Simulation Flows', 'menu', 'read'),
  ('menu:testing-list-device-simulation:view', 'Xem danh sách Simulation Devices', 'menu', 'read'),
  ('menu:testing-so-test-batch:view', 'Xem liên kết SO và Test Batch', 'menu', 'read'),
  ('menu:testing-create-test-batch:view', 'Tạo mới Test Batch', 'menu', 'read'),
  ('menu:testing-device-simulation:view', 'Tạo kịch bản Simulation Flow', 'menu', 'read'),
  -- Functional & Operational Permissions
  ('rbac:roles:manage', 'Quản lý vai trò và phân quyền hệ thống (Roles & Permissions)', 'rbac', 'manage'),
  ('rbac:users:manage', 'Gán tài khoản người dùng vào vai trò (User Role Assignment)', 'rbac', 'manage'),
  ('final-config:tool:execute', 'Thực thi nạp và test final config qua Web Serial', 'final-config', 'execute'),
  ('final-config:manager:manage', 'Quản lý, chỉnh sửa profile final config', 'final-config', 'manage'),
  ('device:manage:write', 'Thêm mới và cập nhật danh sách thiết bị IoT', 'device', 'write'),
  ('traceability:so:manage', 'Đồng bộ và quản trị đơn hàng SO/WA', 'traceability', 'manage'),
  ('memmap:profiles:manage', 'Tạo, sửa đổi và tải lên Memmap register template', 'memmap', 'manage'),
  ('decoder:scripts:manage', 'Biên soạn và cấu hình kịch bản giải mã Uplink payload', 'decoder', 'manage'),
  ('chirpstack:integration:manage', 'Quản lý kết nối và đồng bộ hạ tầng ChirpStack Network Server', 'lorawan', 'manage'),
  ('testing:suite:execute', 'Kích hoạt kịch bản kiểm thử đo sóng RF và sensor flow', 'testing', 'execute'),
  ('testing:batch:manage', 'Quản lý cấu hình lô đo kiểm Test Batch và gán kịch bản tự động', 'testing', 'manage')
ON CONFLICT ("name") DO UPDATE SET
  "description" = EXCLUDED."description",
  "module" = EXCLUDED."module",
  "action" = EXCLUDED."action";

-- 3. Assign Default Menu Permissions to Roles
-- 3a. SUPER_ADMIN / ADMIN: All menu items
INSERT INTO system_schema."role_menu_permissions" ("roleId", "roleCode", "menuItemId")
SELECT r."id", r."code", m."id"
FROM system_schema."roles" r
CROSS JOIN system_schema."menu_items" m
WHERE r."code" IN ('SUPER_ADMIN', 'ADMIN', 'admin')
ON CONFLICT ("roleId", "menuItemId") DO NOTHING;

-- 3b. SUB_ADMIN: All operational & plugin menu items
INSERT INTO system_schema."role_menu_permissions" ("roleId", "roleCode", "menuItemId")
SELECT r."id", r."code", m."id"
FROM system_schema."roles" r
CROSS JOIN system_schema."menu_items" m
WHERE r."code" IN ('SUB_ADMIN', 'sub_admin')
  AND m."id" NOT IN ('dashboard')
ON CONFLICT ("roleId", "menuItemId") DO NOTHING;

-- 3c. OPERATOR / TESTER / QA_ENGINEER: Operational test, config, traceability & monitor menus
INSERT INTO system_schema."role_menu_permissions" ("roleId", "roleCode", "menuItemId")
SELECT r."id", r."code", m."id"
FROM system_schema."roles" r
CROSS JOIN system_schema."menu_items" m
WHERE r."code" IN ('OPERATOR', 'operator', 'TESTER', 'tester', 'QA_ENGINEER', 'qa_engineer')
  AND m."id" IN (
    'dashboard',
    'final-config:tool',
    'final-config:manager',
    'device:manage',
    'device-traceability:so',
    'device-traceability:devices',
    'device-traceability:final-config',
    'decoder:scripts',
    'lorawan-chirpstack:telemetry',
    'testing:device-payload',
    'testing:create-device-testing',
    'testing:list-device-testing',
    'testing:create-preconfig',
    'testing:list-preconfig',
    'testing:list-test-batch',
    'testing:list-flow-simulation',
    'testing:list-device-simulation',
    'testing:so-test-batch',
    'testing:create-test-batch',
    'testing:device-simulation',
    'testing:gateway-sessions',
    'testing:simulation-devices',
    'testing:device-auto-check',
    'testing:packets',
    'so-test-batch:main',
    'testing:test-batch'
  )
ON CONFLICT ("roleId", "menuItemId") DO NOTHING;

-- 3d. END_USER / USER: Dashboard and Final Config Tool
INSERT INTO system_schema."role_menu_permissions" ("roleId", "roleCode", "menuItemId")
SELECT r."id", r."code", m."id"
FROM system_schema."roles" r
CROSS JOIN system_schema."menu_items" m
WHERE r."code" IN ('END_USER', 'user', 'USER')
  AND m."id" IN ('dashboard', 'final-config:tool')
ON CONFLICT ("roleId", "menuItemId") DO NOTHING;

-- 3e. Assign all permissions to SUPER_ADMIN / ADMIN
INSERT INTO system_schema."role_permissions" ("role_id", "permission_id")
SELECT r."id", p."id"
FROM system_schema."roles" r
CROSS JOIN system_schema."permission" p
WHERE r."code" IN ('SUPER_ADMIN', 'ADMIN', 'admin')
ON CONFLICT ("role_id", "permission_id") DO NOTHING;

-- 3f. Assign operational permissions to OPERATOR / TESTER
INSERT INTO system_schema."role_permissions" ("role_id", "permission_id")
SELECT r."id", p."id"
FROM system_schema."roles" r
CROSS JOIN system_schema."permission" p
WHERE r."code" IN ('OPERATOR', 'operator', 'TESTER', 'tester')
  AND (
    p."module" IN ('menu', 'testing', 'final-config', 'traceability', 'device', 'decoder')
    OR p."name" IN ('system:devices:read', 'system:devices:write')
  )
ON CONFLICT ("role_id", "permission_id") DO NOTHING;

-- 4. Create Unified RBAC Views Linking Menu Views and Permissions
-- 4a. v_role_menu_access: Matrix of role -> menu view -> granted status
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'system_schema' AND c.relname = 'v_role_menu_access' AND c.relkind = 'v'
  ) THEN
    DROP VIEW system_schema.v_role_menu_access CASCADE;
  END IF;
END $$;

CREATE OR REPLACE VIEW system_schema.v_role_menu_access AS
SELECT
  r.id AS role_id,
  r.code AS role_code,
  r.name AS role_name,
  m.id AS menu_item_id,
  m.title AS menu_title,
  m.description AS menu_description,
  m.route AS menu_route,
  m.icon AS menu_icon,
  m.category AS menu_category,
  m.plugin_id AS menu_plugin_id,
  m.tab AS menu_tab,
  m.display_order AS menu_order,
  m.is_active AS menu_is_active,
  CASE WHEN rmp.id IS NOT NULL THEN true ELSE false END AS is_granted,
  rmp.created_at AS granted_at
FROM system_schema."roles" r
CROSS JOIN system_schema."menu_items" m
LEFT JOIN system_schema."role_menu_permissions" rmp
  ON (rmp."roleId" = r.id OR UPPER(rmp."roleCode") = UPPER(r.code))
  AND rmp."menuItemId" = m.id;

-- 4b. v_user_rbac_overview: Comprehensive user overview with roles, assigned menu items, and permissions
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'system_schema' AND c.relname = 'v_user_rbac_overview' AND c.relkind = 'v'
  ) THEN
    DROP VIEW system_schema.v_user_rbac_overview CASCADE;
  END IF;
END $$;

CREATE OR REPLACE VIEW system_schema.v_user_rbac_overview AS
SELECT
  u.id AS user_id,
  u.username,
  u.email,
  u."fullName" AS full_name,
  u."userType" AS user_type,
  u."isActive" AS is_active,
  COALESCE(
    JSON_AGG(DISTINCT JSONB_BUILD_OBJECT('id', r.id, 'code', r.code, 'name', r.name))
    FILTER (WHERE r.id IS NOT NULL),
    '[]'::json
  ) AS roles,
  COALESCE(
    JSON_AGG(DISTINCT m.id)
    FILTER (WHERE m.id IS NOT NULL),
    '[]'::json
  ) AS assigned_menu_ids,
  COALESCE(
    JSON_AGG(DISTINCT p.name)
    FILTER (WHERE p.name IS NOT NULL),
    '[]'::json
  ) AS assigned_permissions,
  COUNT(DISTINCT m.id) AS total_accessible_menus,
  COUNT(DISTINCT p.id) AS total_permissions
FROM system_schema."users" u
LEFT JOIN system_schema."user_role" ur ON ur.user_id = u.id
LEFT JOIN system_schema."roles" r ON r.id = ur.role_id
LEFT JOIN system_schema."role_menu_permissions" rmp
  ON (rmp."roleId" = r.id OR UPPER(rmp."roleCode") = UPPER(r.code))
LEFT JOIN system_schema."menu_items" m ON m.id = rmp."menuItemId" AND m.is_active = true
LEFT JOIN system_schema."role_permissions" rp ON rp.role_id = r.id
LEFT JOIN system_schema."permission" p ON p.id = rp.permission_id
GROUP BY u.id, u.username, u.email, u."fullName", u."userType", u."isActive";

-- 5. Expose Views in public Schema for Microservices
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relname = 'v_role_menu_access' AND c.relkind = 'v'
  ) THEN
    DROP VIEW public.v_role_menu_access CASCADE;
  END IF;
  IF EXISTS (
    SELECT 1 FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relname = 'v_user_rbac_overview' AND c.relkind = 'v'
  ) THEN
    DROP VIEW public.v_user_rbac_overview CASCADE;
  END IF;
  IF EXISTS (
    SELECT 1 FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relname = 'system_menu_items' AND c.relkind = 'v'
  ) THEN
    DROP VIEW public.system_menu_items CASCADE;
  END IF;
  IF EXISTS (
    SELECT 1 FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relname = 'menu_items' AND c.relkind = 'v'
  ) THEN
    DROP VIEW public.menu_items CASCADE;
  END IF;
  IF EXISTS (
    SELECT 1 FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relname = 'role_menu_permissions' AND c.relkind = 'v'
  ) THEN
    DROP VIEW public.role_menu_permissions CASCADE;
  END IF;
END $$;

CREATE OR REPLACE VIEW public.v_role_menu_access AS
SELECT * FROM system_schema.v_role_menu_access;

CREATE OR REPLACE VIEW public.v_user_rbac_overview AS
SELECT * FROM system_schema.v_user_rbac_overview;

CREATE OR REPLACE VIEW public.system_menu_items AS
SELECT * FROM system_schema.menu_items;

CREATE OR REPLACE VIEW public.menu_items AS
SELECT * FROM system_schema.menu_items;

CREATE OR REPLACE VIEW public.role_menu_permissions AS
SELECT * FROM system_schema.role_menu_permissions;

-- 6. Grant Permissions to itest_system_user and itest_plugins_user
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'itest_system_user') THEN
    GRANT USAGE ON SCHEMA system_schema TO itest_system_user;
    GRANT ALL PRIVILEGES ON TABLE system_schema."menu_items" TO itest_system_user;
    GRANT ALL PRIVILEGES ON TABLE system_schema."role_menu_permissions" TO itest_system_user;
    GRANT ALL PRIVILEGES ON TABLE system_schema."permission" TO itest_system_user;
    GRANT ALL PRIVILEGES ON TABLE system_schema."role_permissions" TO itest_system_user;
    GRANT SELECT ON system_schema.v_role_menu_access TO itest_system_user;
    GRANT SELECT ON system_schema.v_user_rbac_overview TO itest_system_user;
    GRANT SELECT ON public.v_role_menu_access TO itest_system_user;
    GRANT SELECT ON public.v_user_rbac_overview TO itest_system_user;
    GRANT ALL PRIVILEGES ON TABLE public.system_menu_items TO itest_system_user;
    GRANT ALL PRIVILEGES ON TABLE public.menu_items TO itest_system_user;
    GRANT ALL PRIVILEGES ON TABLE public.role_menu_permissions TO itest_system_user;
  END IF;

  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'itest_plugins_user') THEN
    GRANT USAGE ON SCHEMA system_schema TO itest_plugins_user;
    GRANT SELECT ON TABLE system_schema."menu_items" TO itest_plugins_user;
    GRANT SELECT ON TABLE system_schema."role_menu_permissions" TO itest_plugins_user;
    GRANT SELECT ON system_schema.v_role_menu_access TO itest_plugins_user;
    GRANT SELECT ON system_schema.v_user_rbac_overview TO itest_plugins_user;
    GRANT SELECT ON public.v_role_menu_access TO itest_plugins_user;
    GRANT SELECT ON public.v_user_rbac_overview TO itest_plugins_user;
    GRANT SELECT ON public.system_menu_items TO itest_plugins_user;
    GRANT SELECT ON public.menu_items TO itest_plugins_user;
    GRANT SELECT ON public.role_menu_permissions TO itest_plugins_user;
  END IF;
END $$;
