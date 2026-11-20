-- ==============================================================================
-- MIGRATION: 004_add_wa_number_to_finalconfig_profile.sql
-- Module: finalconfig-manager
-- Schema: finalconfig_manager
-- Description: Adds wa_number column and index to finalconfig_manager.finalconfig_profile
-- ==============================================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'finalconfig_manager' 
      AND table_name = 'finalconfig_profile' 
      AND column_name = 'wa_number'
  ) THEN
    ALTER TABLE finalconfig_manager."finalconfig_profile" 
      ADD COLUMN "wa_number" VARCHAR(50);
  END IF;
  -- Ensure registration of migration if not present
  INSERT INTO finalconfig_manager."_migrations" ("migration_name", "batch")
  SELECT '004_add_wa_number_to_finalconfig_profile.sql', 1
  WHERE NOT EXISTS (
    SELECT 1 FROM finalconfig_manager."_migrations" 
    WHERE "migration_name" = '004_add_wa_number_to_finalconfig_profile.sql'
  );
END $$;

CREATE INDEX IF NOT EXISTS "idx_finalconfig_profile_wa"
  ON finalconfig_manager."finalconfig_profile" ("wa_number");
