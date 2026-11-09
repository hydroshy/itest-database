-- ==============================================================================
-- MIGRATION: 025_cleanup_duplicate_roles_and_standardize_rbac.sql
-- Description: Standardize canonical system roles (SUPER_ADMIN, SUB_ADMIN, OPERATOR, END_USER),
--              merge user assignments and permissions from duplicate lowercase/legacy roles,
--              and purge duplicate seed/mock roles.
-- Schema: system_schema
-- Idempotency: Safe to re-run on existing PostgreSQL databases.
-- ==============================================================================

SET search_path TO system_schema, public;

-- 1. Ensure Canonical Standard Roles exist
INSERT INTO system_schema."roles" ("code", "name", "description")
VALUES
  ('SUPER_ADMIN', 'Super Admin', 'Full administrative access to all system features and plugins'),
  ('SUB_ADMIN', 'Sub-Admin', 'Delegated administrative privileges'),
  ('OPERATOR', 'Operator', 'Operational, testing and device execution access'),
  ('END_USER', 'End User', 'Standard end user with access to assigned tools')
ON CONFLICT ("code") DO UPDATE SET
  "name" = EXCLUDED."name",
  "description" = EXCLUDED."description";

-- 2. Migrate User Roles from legacy/duplicate roles to canonical roles
DO $$
DECLARE
  rec RECORD;
  v_canonical_id UUID;
BEGIN
  -- Map of legacy code -> canonical code
  FOR rec IN
    SELECT unnest(ARRAY['admin', 'sub_admin', 'operator', 'user']) AS legacy_code,
           unnest(ARRAY['SUPER_ADMIN', 'SUB_ADMIN', 'OPERATOR', 'END_USER']) AS canonical_code
  LOOP
    SELECT id INTO v_canonical_id FROM system_schema."roles" WHERE "code" = rec.canonical_code;

    IF v_canonical_id IS NOT NULL THEN
      -- Remap user_role join table
      INSERT INTO system_schema."user_role" ("user_id", "role_id")
      SELECT ur."user_id", v_canonical_id
      FROM system_schema."user_role" ur
      JOIN system_schema."roles" r ON r."id" = ur."role_id"
      WHERE r."code" = rec.legacy_code
      ON CONFLICT DO NOTHING;

      -- Remap role_permissions join table
      INSERT INTO system_schema."role_permissions" ("role_id", "permission_id")
      SELECT v_canonical_id, rp."permission_id"
      FROM system_schema."role_permissions" rp
      JOIN system_schema."roles" r ON r."id" = rp."role_id"
      WHERE r."code" = rec.legacy_code
      ON CONFLICT DO NOTHING;

      -- Remap role_menu_permissions join table (use roleId/menuItemId which carry the UNIQUE constraint)
      INSERT INTO system_schema."role_menu_permissions" ("roleId", "roleCode", "menuItemId")
      SELECT v_canonical_id, rec.canonical_code, rmp."menuItemId"
      FROM system_schema."role_menu_permissions" rmp
      JOIN system_schema."roles" r ON r."id" = rmp."roleId"
      WHERE r."code" = rec.legacy_code
      ON CONFLICT ("roleId", "menuItemId") DO NOTHING;

      DELETE FROM system_schema."role_menu_permissions" rmp
      USING system_schema."roles" r
      WHERE r."id" = rmp."roleId" AND r."code" = rec.legacy_code;
    END IF;
  END LOOP;
END $$;

-- 3. Delete legacy duplicate lowercase roles now that all relations have been migrated
DELETE FROM system_schema."roles"
WHERE "code" IN ('admin', 'sub_admin', 'operator', 'user');

-- 4. Ensure runtime privileges
GRANT ALL ON TABLE system_schema."roles" TO itest_system_user;
GRANT ALL ON TABLE system_schema."user_role" TO itest_system_user;
GRANT ALL ON TABLE system_schema."role_permissions" TO itest_system_user;
GRANT ALL ON TABLE system_schema."role_menu_permissions" TO itest_system_user;
