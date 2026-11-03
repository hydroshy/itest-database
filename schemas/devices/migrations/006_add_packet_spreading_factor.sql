-- Backend DevicePacketEntity persists in devices, not system_schema.
-- Frequency uses Hz (e.g. 923200000); legacy NUMERIC(10,3) cannot hold it.
-- Widen without rounding existing fractional values.
ALTER TABLE devices.device_packets
  ADD COLUMN IF NOT EXISTS sf INTEGER,
  ADD COLUMN IF NOT EXISTS dev_eui VARCHAR(100);
ALTER TABLE devices.device_packets
  ALTER COLUMN dev_eui TYPE VARCHAR(100),
  ALTER COLUMN device_id DROP NOT NULL;
ALTER TABLE devices.device_packets
  ALTER COLUMN frequency TYPE NUMERIC(20, 3);

COMMENT ON COLUMN devices.device_packets.sf IS 'LoRa spreading factor as an integer; NULL when not provided';
