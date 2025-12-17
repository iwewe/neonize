-- ==============================================================================
-- Database Initialization Script
-- Emergency Response Chatbot
-- ==============================================================================

-- Create n8n database
CREATE DATABASE n8n_db;

-- Connect to emergency_db
\c emergency_db;

-- ==============================================================================
-- Emergency Reports Table
-- ==============================================================================
CREATE TABLE IF NOT EXISTS emergency_reports (
    id SERIAL PRIMARY KEY,
    report_id VARCHAR(50) UNIQUE,
    reporter_jid VARCHAR(100) NOT NULL,
    reporter_name VARCHAR(100),
    message TEXT NOT NULL,
    category VARCHAR(50),  -- BANJIR, GEMPA, KEBAKARAN, etc
    severity INT DEFAULT 1 CHECK (severity BETWEEN 1 AND 5),
    priority VARCHAR(20) DEFAULT 'MEDIUM',  -- LOW, MEDIUM, HIGH, CRITICAL
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    location_name VARCHAR(200),
    media_files TEXT[],  -- Array of file paths/URLs
    status VARCHAR(20) DEFAULT 'PENDING',  -- PENDING, VERIFIED, IN_PROGRESS, RESOLVED
    verified_by VARCHAR(100),
    verified_at TIMESTAMP,
    resolved_at TIMESTAMP,
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX idx_reports_status ON emergency_reports(status);
CREATE INDEX idx_reports_category ON emergency_reports(category);
CREATE INDEX idx_reports_severity ON emergency_reports(severity DESC);
CREATE INDEX idx_reports_created ON emergency_reports(created_at DESC);
CREATE INDEX idx_reports_reporter ON emergency_reports(reporter_jid);

-- ==============================================================================
-- Message Log Table
-- ==============================================================================
CREATE TABLE IF NOT EXISTS message_log (
    id SERIAL PRIMARY KEY,
    message_id VARCHAR(100),
    direction VARCHAR(10) CHECK (direction IN ('INCOMING', 'OUTGOING')),
    sender_jid VARCHAR(100),
    recipient_jid VARCHAR(100),
    chat_jid VARCHAR(100),
    is_group BOOLEAN DEFAULT FALSE,
    message_type VARCHAR(20),  -- text, image, video, location, document, etc
    content TEXT,
    media_url TEXT,
    caption TEXT,
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    delivered_at TIMESTAMP,
    read_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_message_log_created ON message_log(created_at DESC);
CREATE INDEX idx_message_log_sender ON message_log(sender_jid);
CREATE INDEX idx_message_log_recipient ON message_log(recipient_jid);
CREATE INDEX idx_message_log_direction ON message_log(direction);

-- ==============================================================================
-- Broadcast History Table
-- ==============================================================================
CREATE TABLE IF NOT EXISTS broadcast_history (
    id SERIAL PRIMARY KEY,
    campaign_name VARCHAR(100),
    message TEXT NOT NULL,
    recipients_count INT NOT NULL,
    sent_count INT DEFAULT 0,
    failed_count INT DEFAULT 0,
    region VARCHAR(100),
    alert_type VARCHAR(50),
    initiated_by VARCHAR(100),
    status VARCHAR(20) DEFAULT 'PENDING',  -- PENDING, IN_PROGRESS, COMPLETED, FAILED
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_broadcast_created ON broadcast_history(created_at DESC);
CREATE INDEX idx_broadcast_status ON broadcast_history(status);

-- ==============================================================================
-- Broadcast Recipients Table
-- ==============================================================================
CREATE TABLE IF NOT EXISTS broadcast_recipients (
    id SERIAL PRIMARY KEY,
    broadcast_id INT REFERENCES broadcast_history(id) ON DELETE CASCADE,
    recipient_jid VARCHAR(100) NOT NULL,
    recipient_name VARCHAR(100),
    status VARCHAR(20) DEFAULT 'PENDING',  -- PENDING, SENT, DELIVERED, READ, FAILED
    error_message TEXT,
    sent_at TIMESTAMP,
    delivered_at TIMESTAMP,
    read_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_broadcast_recipients_broadcast ON broadcast_recipients(broadcast_id);
CREATE INDEX idx_broadcast_recipients_status ON broadcast_recipients(status);

-- ==============================================================================
-- Emergency Teams Table
-- ==============================================================================
CREATE TABLE IF NOT EXISTS emergency_teams (
    id SERIAL PRIMARY KEY,
    team_id VARCHAR(50) UNIQUE NOT NULL,
    group_jid VARCHAR(100) UNIQUE,
    team_name VARCHAR(100) NOT NULL,
    mission TEXT,
    region VARCHAR(100),
    status VARCHAR(20) DEFAULT 'ACTIVE',  -- ACTIVE, STANDBY, COMPLETED, DISBANDED
    created_by VARCHAR(100),
    created_at TIMESTAMP DEFAULT NOW(),
    completed_at TIMESTAMP,
    updated_at TIMESTAMP DEFAULT NOW()
);

-- ==============================================================================
-- Team Members Table
-- ==============================================================================
CREATE TABLE IF NOT EXISTS team_members (
    id SERIAL PRIMARY KEY,
    team_id INT REFERENCES emergency_teams(id) ON DELETE CASCADE,
    member_jid VARCHAR(100) NOT NULL,
    member_name VARCHAR(100),
    role VARCHAR(50),  -- LEADER, MEDIC, LOGISTICS, COMMS, etc
    status VARCHAR(20) DEFAULT 'ACTIVE',  -- ACTIVE, INACTIVE
    joined_at TIMESTAMP DEFAULT NOW(),
    left_at TIMESTAMP
);

-- Indexes
CREATE INDEX idx_team_members_team ON team_members(team_id);
CREATE INDEX idx_team_members_jid ON team_members(member_jid);

-- ==============================================================================
-- Contacts Table
-- ==============================================================================
CREATE TABLE IF NOT EXISTS contacts (
    id SERIAL PRIMARY KEY,
    jid VARCHAR(100) UNIQUE NOT NULL,
    name VARCHAR(100),
    phone VARCHAR(20),
    is_on_whatsapp BOOLEAN DEFAULT TRUE,
    region VARCHAR(100),
    role VARCHAR(50),  -- CITIZEN, VOLUNTEER, RESPONDER, ADMIN
    is_verified BOOLEAN DEFAULT FALSE,
    notes TEXT,
    last_seen TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_contacts_jid ON contacts(jid);
CREATE INDEX idx_contacts_region ON contacts(region);
CREATE INDEX idx_contacts_role ON contacts(role);

-- ==============================================================================
-- Alert Templates Table
-- ==============================================================================
CREATE TABLE IF NOT EXISTS alert_templates (
    id SERIAL PRIMARY KEY,
    template_name VARCHAR(100) UNIQUE NOT NULL,
    alert_type VARCHAR(50) NOT NULL,
    message_template TEXT NOT NULL,
    variables TEXT[],  -- Array of variable names
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Insert default templates
INSERT INTO alert_templates (template_name, alert_type, message_template, variables) VALUES
('BANJIR_ALERT', 'BANJIR', '💧 *PERINGATAN BANJIR*

Ketinggian air: {water_level}
Lokasi: {location}

⚠️ SEGERA EVAKUASI jika air mencapai lutut.

Posko terdekat: {shelter}
Waktu: {timestamp}

#EmergencyAlert', ARRAY['water_level', 'location', 'shelter', 'timestamp']),

('GEMPA_ALERT', 'GEMPA', '🌍 *PERINGATAN GEMPA*

Magnitudo: {magnitude}
Kedalaman: {depth}
Lokasi: {location}

⚠️ WASPADA GEMPA SUSULAN

Jauhi bangunan retak.
Tetap tenang.

Waktu: {timestamp}

#EmergencyAlert', ARRAY['magnitude', 'depth', 'location', 'timestamp']);

-- ==============================================================================
-- System Events Log
-- ==============================================================================
CREATE TABLE IF NOT EXISTS system_events (
    id SERIAL PRIMARY KEY,
    event_type VARCHAR(50) NOT NULL,
    event_data JSONB,
    severity VARCHAR(20),  -- INFO, WARNING, ERROR, CRITICAL
    source VARCHAR(50),  -- NEONIZE, N8N, API, SYSTEM
    created_at TIMESTAMP DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_system_events_type ON system_events(event_type);
CREATE INDEX idx_system_events_created ON system_events(created_at DESC);
CREATE INDEX idx_system_events_severity ON system_events(severity);

-- ==============================================================================
-- Analytics & Metrics Table
-- ==============================================================================
CREATE TABLE IF NOT EXISTS metrics (
    id SERIAL PRIMARY KEY,
    metric_name VARCHAR(50) NOT NULL,
    metric_value NUMERIC,
    metric_type VARCHAR(20),  -- COUNTER, GAUGE, HISTOGRAM
    labels JSONB,  -- Additional labels/dimensions
    timestamp TIMESTAMP DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_metrics_name ON metrics(metric_name);
CREATE INDEX idx_metrics_timestamp ON metrics(timestamp DESC);

-- ==============================================================================
-- Views for Analytics
-- ==============================================================================

-- Reports Summary View
CREATE OR REPLACE VIEW reports_summary AS
SELECT
    DATE(created_at) as date,
    category,
    COUNT(*) as total_reports,
    COUNT(CASE WHEN status = 'RESOLVED' THEN 1 END) as resolved_count,
    COUNT(CASE WHEN status = 'PENDING' THEN 1 END) as pending_count,
    AVG(severity) as avg_severity,
    MAX(severity) as max_severity
FROM emergency_reports
GROUP BY DATE(created_at), category
ORDER BY date DESC, category;

-- Daily Statistics View
CREATE OR REPLACE VIEW daily_stats AS
SELECT
    DATE(created_at) as date,
    COUNT(DISTINCT reporter_jid) as unique_reporters,
    COUNT(*) as total_reports,
    COUNT(CASE WHEN severity >= 4 THEN 1 END) as high_severity_count,
    SUM(CASE WHEN status = 'RESOLVED' THEN 1 ELSE 0 END) as resolved_today
FROM emergency_reports
WHERE created_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY DATE(created_at)
ORDER BY date DESC;

-- Message Activity View
CREATE OR REPLACE VIEW message_activity AS
SELECT
    DATE(created_at) as date,
    direction,
    COUNT(*) as message_count,
    COUNT(DISTINCT sender_jid) as unique_senders,
    COUNT(DISTINCT recipient_jid) as unique_recipients
FROM message_log
WHERE created_at >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY DATE(created_at), direction
ORDER BY date DESC, direction;

-- ==============================================================================
-- Functions
-- ==============================================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers for updated_at
CREATE TRIGGER update_emergency_reports_updated_at
    BEFORE UPDATE ON emergency_reports
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_contacts_updated_at
    BEFORE UPDATE ON contacts
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_emergency_teams_updated_at
    BEFORE UPDATE ON emergency_teams
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ==============================================================================
-- Sample Data (Optional - untuk testing)
-- ==============================================================================

-- Sample contacts
INSERT INTO contacts (jid, name, phone, region, role, is_verified) VALUES
('628123456789@s.whatsapp.net', 'John Doe', '628123456789', 'Jakarta Utara', 'VOLUNTEER', TRUE),
('628987654321@s.whatsapp.net', 'Jane Smith', '628987654321', 'Jakarta Barat', 'RESPONDER', TRUE);

-- Sample alert
-- INSERT INTO emergency_reports (
--     report_id, reporter_jid, reporter_name, message, category, severity, latitude, longitude, status
-- ) VALUES (
--     'RPT20250101120000',
--     '628123456789@s.whatsapp.net',
--     'John Doe',
--     'Ada banjir di Jl. Sunter Raya setinggi 50cm',
--     'BANJIR',
--     3,
--     -6.1396,
--     106.8679,
--     'PENDING'
-- );

-- ==============================================================================
-- Permissions & Security
-- ==============================================================================

-- Grant permissions to emergency user
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO emergency;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO emergency;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO emergency;

-- ==============================================================================
-- Completion Message
-- ==============================================================================
DO $$
BEGIN
    RAISE NOTICE '✅ Database initialized successfully!';
    RAISE NOTICE 'Tables created:';
    RAISE NOTICE '  - emergency_reports';
    RAISE NOTICE '  - message_log';
    RAISE NOTICE '  - broadcast_history';
    RAISE NOTICE '  - broadcast_recipients';
    RAISE NOTICE '  - emergency_teams';
    RAISE NOTICE '  - team_members';
    RAISE NOTICE '  - contacts';
    RAISE NOTICE '  - alert_templates';
    RAISE NOTICE '  - system_events';
    RAISE NOTICE '  - metrics';
END $$;
