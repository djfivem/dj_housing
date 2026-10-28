-- Version 001. Statements mirror database/schema.sql and use IF NOT EXISTS.
-- The runner records the version only after every statement succeeds.

CREATE TABLE IF NOT EXISTS housing_schema_migrations (
    version VARCHAR(32) NOT NULL PRIMARY KEY,
    applied_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS housing_properties (
    id VARCHAR(64) NOT NULL PRIMARY KEY,
    label VARCHAR(80) NOT NULL,
    description VARCHAR(512) NOT NULL DEFAULT '',
    property_type VARCHAR(16) NOT NULL,
    purchase_price INT NOT NULL,
    rental_price INT NOT NULL DEFAULT 0,
    rental_period_hours INT NOT NULL DEFAULT 0,
    entrance_json JSON NOT NULL,
    interior_json JSON NOT NULL,
    shell_model VARCHAR(64) NULL,
    shell_options_json JSON NULL,
    ipls_json JSON NULL,
    image_key VARCHAR(32) NOT NULL DEFAULT 'default',
    bedrooms INT NOT NULL DEFAULT 1,
    bathrooms INT NOT NULL DEFAULT 1,
    garages INT NOT NULL DEFAULT 0,
    garage_json JSON NULL,
    doors_json JSON NULL,
    features_json JSON NULL,
    status VARCHAR(16) NOT NULL DEFAULT 'available',
    reservation_token VARCHAR(64) NULL,
    listed TINYINT NOT NULL DEFAULT 0,
    listing_price INT NULL,
    enabled TINYINT NOT NULL DEFAULT 1,
    created_at INT NOT NULL,
    updated_at INT NOT NULL,
    INDEX idx_housing_properties_status (status),
    INDEX idx_housing_properties_listed (listed)
);

CREATE TABLE IF NOT EXISTS housing_stashes (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    property_id VARCHAR(64) NOT NULL,
    stash_key VARCHAR(64) NOT NULL,
    label VARCHAR(80) NOT NULL,
    stash_type VARCHAR(16) NOT NULL,
    access_level VARCHAR(16) NOT NULL,
    slots INT NOT NULL,
    max_weight INT NOT NULL,
    UNIQUE KEY uq_housing_stash (property_id, stash_key),
    INDEX idx_housing_stash_property (property_id)
);

CREATE TABLE IF NOT EXISTS housing_ownership (
    property_id VARCHAR(64) NOT NULL PRIMARY KEY,
    framework VARCHAR(16) NOT NULL,
    character_id VARCHAR(80) NOT NULL,
    display_name VARCHAR(64) NULL,
    purchased_at INT NOT NULL,
    purchase_price INT NOT NULL,
    acquisition VARCHAR(16) NOT NULL,
    shell_model VARCHAR(64) NULL,
    INDEX idx_housing_owner (framework, character_id)
);

CREATE TABLE IF NOT EXISTS housing_tenancies (
    id VARCHAR(64) NOT NULL PRIMARY KEY,
    property_id VARCHAR(64) NOT NULL,
    framework VARCHAR(16) NOT NULL,
    character_id VARCHAR(80) NOT NULL,
    display_name VARCHAR(64) NULL,
    started_at INT NOT NULL,
    expires_at INT NOT NULL,
    price_paid INT NOT NULL,
    status VARCHAR(16) NOT NULL,
    INDEX idx_housing_tenancy_property (property_id, status),
    INDEX idx_housing_tenancy_expiry (status, expires_at),
    INDEX idx_housing_tenant (framework, character_id)
);

CREATE TABLE IF NOT EXISTS housing_access (
    property_id VARCHAR(64) NOT NULL,
    framework VARCHAR(16) NOT NULL,
    character_id VARCHAR(80) NOT NULL,
    display_name VARCHAR(64) NULL,
    role VARCHAR(16) NOT NULL,
    granted_by VARCHAR(80) NULL,
    granted_at INT NOT NULL,
    expires_at INT NULL,
    revoked_at INT NULL,
    revoked_by VARCHAR(80) NULL,
    PRIMARY KEY (property_id, framework, character_id),
    INDEX idx_housing_access_character (framework, character_id)
);

CREATE TABLE IF NOT EXISTS housing_keys (
    id VARCHAR(64) NOT NULL PRIMARY KEY,
    property_id VARCHAR(64) NOT NULL,
    holder_framework VARCHAR(16) NOT NULL,
    holder_character_id VARCHAR(80) NOT NULL,
    issued_by VARCHAR(80) NULL,
    access_level VARCHAR(16) NOT NULL,
    state VARCHAR(16) NOT NULL,
    issued_at INT NOT NULL,
    expires_at INT NULL,
    revoked_at INT NULL,
    revoked_by VARCHAR(80) NULL,
    inventory_state VARCHAR(24) NOT NULL,
    INDEX idx_housing_keys_property (property_id),
    INDEX idx_housing_keys_holder (holder_framework, holder_character_id)
);

CREATE TABLE IF NOT EXISTS housing_transactions (
    id VARCHAR(64) NOT NULL PRIMARY KEY,
    property_id VARCHAR(64) NOT NULL,
    framework VARCHAR(16) NOT NULL,
    actor_character_id VARCHAR(80) NOT NULL,
    tx_type VARCHAR(32) NOT NULL,
    amount INT NOT NULL,
    account_name VARCHAR(16) NOT NULL,
    status VARCHAR(24) NOT NULL,
    money_state VARCHAR(24) NOT NULL,
    grant_state VARCHAR(24) NOT NULL,
    reservation_token VARCHAR(64) NULL,
    error_code VARCHAR(64) NULL,
    detail_json JSON NULL,
    created_at INT NOT NULL,
    updated_at INT NOT NULL,
    INDEX idx_housing_tx_property (property_id),
    INDEX idx_housing_tx_status (status, money_state),
    INDEX idx_housing_tx_actor (framework, actor_character_id)
);

CREATE TABLE IF NOT EXISTS housing_payouts (
    id VARCHAR(64) NOT NULL PRIMARY KEY,
    framework VARCHAR(16) NOT NULL,
    character_id VARCHAR(80) NOT NULL,
    amount INT NOT NULL,
    account_name VARCHAR(16) NOT NULL,
    reason_text VARCHAR(128) NOT NULL,
    status VARCHAR(16) NOT NULL,
    property_id VARCHAR(64) NULL,
    created_at INT NOT NULL,
    paid_at INT NULL,
    INDEX idx_housing_payout_owner (framework, character_id, status)
);

CREATE TABLE IF NOT EXISTS housing_balances (
    framework VARCHAR(16) NOT NULL,
    character_id VARCHAR(80) NOT NULL,
    account_name VARCHAR(16) NOT NULL,
    balance INT NOT NULL,
    PRIMARY KEY (framework, character_id, account_name)
);

CREATE TABLE IF NOT EXISTS housing_bills (
    id VARCHAR(64) NOT NULL PRIMARY KEY,
    property_id VARCHAR(64) NOT NULL,
    bill_type VARCHAR(32) NOT NULL,
    label VARCHAR(80) NOT NULL,
    amount INT NOT NULL,
    status VARCHAR(16) NOT NULL,
    due_at INT NOT NULL,
    paid_at INT NULL,
    paid_by VARCHAR(80) NULL,
    INDEX idx_housing_bills_property (property_id, status)
);

CREATE TABLE IF NOT EXISTS housing_furniture (
    id VARCHAR(64) NOT NULL PRIMARY KEY,
    property_id VARCHAR(64) NOT NULL,
    catalog_id VARCHAR(64) NOT NULL,
    model VARCHAR(64) NOT NULL,
    label VARCHAR(80) NOT NULL,
    state VARCHAR(16) NOT NULL,
    offset_json JSON NULL,
    created_at INT NOT NULL,
    INDEX idx_housing_furniture_property (property_id)
);

CREATE TABLE IF NOT EXISTS housing_upgrades (
    property_id VARCHAR(64) NOT NULL,
    upgrade_id VARCHAR(64) NOT NULL,
    purchased_at INT NOT NULL,
    purchased_by VARCHAR(80) NULL,
    PRIMARY KEY (property_id, upgrade_id)
);

CREATE TABLE IF NOT EXISTS housing_vehicles (
    id VARCHAR(64) NOT NULL PRIMARY KEY,
    property_id VARCHAR(64) NOT NULL,
    framework VARCHAR(16) NOT NULL,
    character_id VARCHAR(80) NOT NULL,
    plate VARCHAR(16) NOT NULL,
    model_hash INT NOT NULL,
    state VARCHAR(16) NOT NULL,
    stored_at INT NOT NULL,
    INDEX idx_housing_vehicles_property (property_id, state)
);

CREATE TABLE IF NOT EXISTS housing_warrants (
    id VARCHAR(64) NOT NULL PRIMARY KEY,
    property_id VARCHAR(64) NOT NULL,
    requester_framework VARCHAR(16) NOT NULL,
    requester_character_id VARCHAR(80) NOT NULL,
    requester_name VARCHAR(64) NULL,
    approver_character_id VARCHAR(80) NULL,
    approver_name VARCHAR(64) NULL,
    reason_text VARCHAR(400) NOT NULL,
    case_reference VARCHAR(64) NULL,
    scope_json JSON NOT NULL,
    allow_seizure TINYINT NOT NULL DEFAULT 0,
    status VARCHAR(16) NOT NULL,
    emergency TINYINT NOT NULL DEFAULT 0,
    issued_at INT NOT NULL,
    expires_at INT NOT NULL,
    decided_at INT NULL,
    revoked_at INT NULL,
    INDEX idx_housing_warrants_property (property_id, status)
);

CREATE TABLE IF NOT EXISTS housing_raids (
    id VARCHAR(64) NOT NULL PRIMARY KEY,
    property_id VARCHAR(64) NOT NULL,
    warrant_id VARCHAR(64) NULL,
    lead_framework VARCHAR(16) NOT NULL,
    lead_character_id VARCHAR(80) NOT NULL,
    lead_name VARCHAR(64) NULL,
    officers_json JSON NOT NULL,
    state VARCHAR(16) NOT NULL,
    emergency TINYINT NOT NULL DEFAULT 0,
    allow_seizure TINYINT NOT NULL DEFAULT 0,
    scope_json JSON NOT NULL,
    started_at INT NULL,
    ended_at INT NULL,
    created_at INT NOT NULL,
    INDEX idx_housing_raids_property (property_id, state)
);

CREATE TABLE IF NOT EXISTS housing_evidence (
    id VARCHAR(64) NOT NULL PRIMARY KEY,
    property_id VARCHAR(64) NOT NULL,
    stash_key VARCHAR(64) NOT NULL,
    raid_id VARCHAR(64) NOT NULL,
    warrant_id VARCHAR(64) NULL,
    officer_framework VARCHAR(16) NOT NULL,
    officer_character_id VARCHAR(80) NOT NULL,
    officer_name VARCHAR(64) NULL,
    item_name VARCHAR(48) NOT NULL,
    quantity INT NOT NULL,
    metadata_json JSON NULL,
    case_reference VARCHAR(64) NULL,
    status VARCHAR(16) NOT NULL,
    created_at INT NOT NULL,
    updated_at INT NOT NULL,
    INDEX idx_housing_evidence_property (property_id),
    INDEX idx_housing_evidence_raid (raid_id)
);

CREATE TABLE IF NOT EXISTS housing_evidence_transfers (
    id VARCHAR(64) NOT NULL PRIMARY KEY,
    evidence_id VARCHAR(64) NOT NULL,
    from_status VARCHAR(16) NOT NULL,
    to_status VARCHAR(16) NOT NULL,
    actor_character_id VARCHAR(80) NOT NULL,
    note_text VARCHAR(200) NULL,
    created_at INT NOT NULL,
    INDEX idx_housing_evidence_transfer (evidence_id)
);

CREATE TABLE IF NOT EXISTS housing_audit (
    id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    category VARCHAR(32) NOT NULL,
    action_name VARCHAR(48) NOT NULL,
    framework VARCHAR(16) NULL,
    actor_character_id VARCHAR(80) NULL,
    property_id VARCHAR(64) NULL,
    target_id VARCHAR(80) NULL,
    detail_json JSON NULL,
    created_at INT NOT NULL,
    INDEX idx_housing_audit_property (property_id, created_at),
    INDEX idx_housing_audit_actor (framework, actor_character_id)
);
