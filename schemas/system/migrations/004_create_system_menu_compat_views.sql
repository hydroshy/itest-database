-- ==============================================================================
-- MIGRATION: 004_create_system_menu_compat_views.sql
-- Description: Provide compatibility views and schema bridges for MenuService
--              and RBAC:
--              1. public.system_menu_items -> system_schema.menu_items
--              2. public.menu_items -> system_schema.menu_items
--              3. public.role_menu_permissions -> system_schema.role_menu_permissions
--              4. system_schema.system_menu_items -> system_schema.menu_items
--              5. Auto-sync trigger for role_code -> roleId in role_menu_permissions
--              6. Grant runtime permissions to itest_system_user
-- Schema: system_schema, public
-- Idempotency: Safe to re-run on existing PostgreSQL volumes.
-- ==============================================================================

-- 1. Relax NOT NULL on roleId in system_schema.role_menu_permissions if present
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'system_schema' 
      AND table_name = 'role_menu_permissions' 
      AND column_name = 'roleId' 
      AND is_nullable = 'NO'
  ) THEN
    ALTER TABLE system_schema."role_menu_permissions" ALTER COLUMN "roleId" DROP NOT NULL;
  END IF;
END $$;

-- 2. Enhanced Trigger function for role_menu_permissions to resolve roleId from role_code
CREATE OR REPLACE FUNCTION system_schema.sync_role_menu_permissions_columns()
RETURNS TRIGGER AS $$
DECLARE
  v_role_id UUID;
BEGIN
  -- Sync roleCode <-> role_code
  IF NEW."roleCode" IS NOT NULL AND NEW."role_code" IS NULL THEN
    NEW."role_code" := NEW."roleCode";
  ELSIF NEW."role_code" IS NOT NULL AND NEW."roleCode" IS NULL THEN
    NEW."roleCode" := NEW."role_code";
  END IF;

  -- Auto-lookup roleId if only role_code / roleCode provided
  IF NEW."roleId" IS NULL AND (NEW."role_code" IS NOT NULL OR NEW."roleCode" IS NOT NULL) THEN
    SELECT id INTO v_role_id FROM system_schema."roles" 
    WHERE UPPER("code") = UPPER(COALESCE(NEW."role_code", NEW."roleCode")) 
    LIMIT 1;
    
    IF v_role_id IS NOT NULL THEN
      NEW."roleId" := v_role_id;
      NEW."role_id" := v_role_id;
    END IF;
  ELSIF NEW."roleId" IS NOT NULL AND NEW."role_id" IS NULL THEN
    NEW."role_id" := NEW."roleId";
  ELSIF NEW."role_id" IS NOT NULL AND NEW."roleId" IS NULL THEN
    NEW."roleId" := NEW."role_id";
  END IF;

  -- Sync menuItemId <-> menu_item_id
  IF NEW."menuItemId" IS NOT NULL AND NEW."menu_item_id" IS NULL THEN
    NEW."menu_item_id" := NEW."menuItemId";
  ELSIF NEW."menu_item_id" IS NOT NULL AND NEW."menuItemId" IS NULL THEN
    NEW."menuItemId" := NEW."menu_item_id";
  END IF;

  -- Timestamps
  NEW."created_at" := COALESCE(NEW."createdAt", NEW."created_at", now());
  NEW."createdAt" := NEW."created_at";

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Reattach trigger
DROP TRIGGER IF EXISTS trg_sync_role_menu_permissions ON system_schema."role_menu_permissions";
CREATE TRIGGER trg_sync_role_menu_permissions
BEFORE INSERT OR UPDATE ON system_schema."role_menu_permissions"
FOR EACH ROW
EXECUTE FUNCTION system_schema.sync_role_menu_permissions_columns();

-- 3. Compatibility Views in system_schema
CREATE OR REPLACE VIEW system_schema."system_menu_items" AS
SELECT * FROM system_schema."menu_items";

-- 4. Compatibility Views in public schema
CREATE OR REPLACE VIEW public."system_menu_items" AS
SELECT * FROM system_schema."menu_items";

CREATE OR REPLACE VIEW public."menu_items" AS
SELECT * FROM system_schema."menu_items";

CREATE OR REPLACE VIEW public."role_menu_permissions" AS
SELECT * FROM system_schema."role_menu_permissions";

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'system_schema' AND table_name = 'roles') THEN
    EXECUTE 'CREATE OR REPLACE VIEW public."roles" AS SELECT * FROM system_schema."roles";';
  END IF;
END $$;

-- 5. Grant Permissions to itest_system_user and itest_plugins_user
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'itest_system_user') THEN
    GRANT USAGE ON SCHEMA system_schema TO itest_system_user;
    GRANT USAGE ON SCHEMA public TO itest_system_user;

    GRANT ALL PRIVILEGES ON TABLE system_schema."menu_items" TO itest_system_user;
    GRANT ALL PRIVILEGES ON TABLE system_schema."role_menu_permissions" TO itest_system_user;
    GRANT ALL PRIVILEGES ON TABLE system_schema."system_menu_items" TO itest_system_user;

    GRANT ALL PRIVILEGES ON TABLE public."system_menu_items" TO itest_system_user;
    GRANT ALL PRIVILEGES ON TABLE public."menu_items" TO itest_system_user;
    GRANT ALL PRIVILEGES ON TABLE public."role_menu_permissions" TO itest_system_user;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'roles') THEN
      GRANT ALL PRIVILEGES ON TABLE public."roles" TO itest_system_user;
    END IF;

    ALTER ROLE itest_system_user SET search_path TO system_schema, plugins_schema, ops_schema, traceability_manager, public;
  END IF;

  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'itest_plugins_user') THEN
    GRANT USAGE ON SCHEMA system_schema TO itest_plugins_user;
    GRANT USAGE ON SCHEMA public TO itest_plugins_user;
    GRANT SELECT ON TABLE system_schema."menu_items" TO itest_plugins_user;
    GRANT SELECT ON TABLE system_schema."system_menu_items" TO itest_plugins_user;
    GRANT SELECT ON TABLE public."system_menu_items" TO itest_plugins_user;
    GRANT SELECT ON TABLE public."menu_items" TO itest_plugins_user;
  END IF;
END $$;
