-- ==============================================================================
-- Emergency Reports Table
-- ==============================================================================
-- Database untuk menyimpan laporan emergency dari WhatsApp bot

CREATE TABLE IF NOT EXISTS emergency_reports (
    id SERIAL PRIMARY KEY,
    sender VARCHAR(255) NOT NULL,
    sender_name VARCHAR(255) DEFAULT 'Unknown',
    chat_id VARCHAR(255) NOT NULL,
    is_group BOOLEAN DEFAULT FALSE,
    message_text TEXT NOT NULL,
    disaster_type VARCHAR(50) NOT NULL,
    severity INTEGER DEFAULT 1 CHECK (severity >= 1 AND severity <= 5),
    status VARCHAR(20) DEFAULT 'pending',
    location_lat DECIMAL(10, 8),
    location_lng DECIMAL(11, 8),
    location_address TEXT,
    media_urls TEXT[],
    assigned_to VARCHAR(255),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMP
);

-- Index untuk query performance
CREATE INDEX IF NOT EXISTS idx_emergency_reports_status ON emergency_reports(status);
CREATE INDEX IF NOT EXISTS idx_emergency_reports_disaster_type ON emergency_reports(disaster_type);
CREATE INDEX IF NOT EXISTS idx_emergency_reports_created_at ON emergency_reports(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_emergency_reports_severity ON emergency_reports(severity DESC);

-- Trigger untuk auto-update updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_emergency_reports_updated_at
    BEFORE UPDATE ON emergency_reports
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Comments untuk dokumentasi
COMMENT ON TABLE emergency_reports IS 'Laporan emergency dari WhatsApp bot';
COMMENT ON COLUMN emergency_reports.sender IS 'WhatsApp JID pengirim';
COMMENT ON COLUMN emergency_reports.sender_name IS 'Nama pengirim dari WhatsApp';
COMMENT ON COLUMN emergency_reports.disaster_type IS 'Jenis bencana: flood, earthquake, fire, landslide, tsunami, other';
COMMENT ON COLUMN emergency_reports.severity IS 'Tingkat keparahan 1-5';
COMMENT ON COLUMN emergency_reports.status IS 'Status: pending, verified, in_progress, resolved, rejected';
