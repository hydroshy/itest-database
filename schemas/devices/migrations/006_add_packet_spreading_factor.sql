-- Backend persists in devices.device_packets.
-- Do not alter existing column types: compatibility views depend on them.
ALTER TABLE devices.device_packets
  ADD COLUMN IF NOT EXISTS sf INTEGER,
  ADD COLUMN IF NOT EXISTS dev_eui VARCHAR(100);
ALTER TABLE devices.device_packets
  ALTER COLUMN device_id DROP NOT NULL;

COMMENT ON COLUMN devices.device_packets.sf IS 'LoRa spreading factor as an integer; NULL when not provided';
