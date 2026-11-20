-- ==============================================================================
-- MIGRATION: 029_create_preconfig_menus_and_permissions.sql
-- Module: testing / preconfig
-- Schema: system_schema
-- Description: Registers 'testing:create-preconfig' and 'testing:list-preconfig'
--              menu items, permissions, and grants for canonical roles.
-- ==============================================================================

SET search_path TO system_schema, public;

-- 1. Register Menu Items
INSERT INTO system_schema."menu_items" (
  "id", "title", "description", "route", "icon", "category", "pluginId", "tab", "order", "isActive"
) VALUES
(
  'testing:create-preconfig',
  'CREATE PRECONFIG',
  'Tạo cấu hình trước (Preconfig) cho thiết bị từ MEMMAP theo SO, WA, Item Code',
  '/plugins/testing?tab=create-preconfig',
  'CirclePlus',
  'plugin',
  'testing',
  'create-preconfig',
  25,
  true
),
(
  'testing:list-preconfig',
  'LIST PRECONFIG',
  'Danh sách và tra cứu các profile Preconfig thiết bị đã tạo',
  '/plugins/testing?tab=list-preconfig',
  'List',
  'plugin',
  'testing',
  'list-preconfig',
  26,
  true
)
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

-- 2. Register Permissions
INSERT INTO system_schema."permission" ("name", "description", "module", "action")
VALUES
  ('menu:testing-create-preconfig:view', 'Access CREATE PRECONFIG tab in LoRaWAN Testing', 'menu', 'read'),
  ('menu:testing-list-preconfig:view', 'Access LIST PRECONFIG tab in LoRaWAN Testing', 'menu', 'read'),
  ('testing:preconfig:create', 'Create device preconfig profiles', 'testing', 'create'),
  ('testing:preconfig:manage', 'Manage and view device preconfig profiles', 'testing', 'manage')
ON CONFLICT ("name") DO UPDATE SET
  "description" = EXCLUDED."description",
  "module" = EXCLUDED."module",
  "action" = EXCLUDED."action";

-- 3. Assign to Canonical Roles (SUPER_ADMIN, SUB_ADMIN, OPERATOR, END_USER)
INSERT INTO system_schema."role_menu_permissions" ("roleId", "roleCode", "menuItemId")
SELECT r."id", r."code", m."id"
FROM system_schema."roles" r
CROSS JOIN system_schema."menu_items" m
WHERE r."code" IN ('SUPER_ADMIN', 'ADMIN', 'admin')
  AND m."id" IN ('testing:create-preconfig', 'testing:list-preconfig')
ON CONFLICT ("roleId", "menuItemId") DO NOTHING;

INSERT INTO system_schema."role_menu_permissions" ("roleId", "roleCode", "menuItemId")
SELECT r."id", r."code", m."id"
FROM system_schema."roles" r
CROSS JOIN system_schema."menu_items" m
WHERE r."code" IN ('SUB_ADMIN', 'sub_admin', 'OPERATOR', 'operator', 'TESTER', 'tester', 'QA_ENGINEER', 'qa_engineer')
  AND m."id" IN ('testing:create-preconfig', 'testing:list-preconfig')
ON CONFLICT ("roleId", "menuItemId") DO NOTHING;
