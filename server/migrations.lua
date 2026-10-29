Housing = Housing or {}

function Housing.Migrations.apply()
    local sql = LoadResourceFile(GetCurrentResourceName(), 'database/migrations/001_init.sql')
    if not sql then
        return false, 'migration file missing'
    end
    local statements = {}
    for statement in sql:gmatch('[^;]+') do
        local trimmed = statement:gsub('%-%-[^\n]*', ''):gsub('^%s+', ''):gsub('%s+$', '')
        if trimmed ~= '' then
            statements[#statements + 1] = trimmed
        end
    end
    for index = 1, #statements do
        MySQL.query.await(statements[index])
    end
    local applied = MySQL.scalar.await('SELECT version FROM housing_schema_migrations WHERE version = ?', { '001' })
    if not applied then
        MySQL.insert.await('INSERT INTO housing_schema_migrations (version) VALUES (?)', { '001' })
    end

    local function columnExists(tableName, columnName)
        local found = MySQL.scalar.await([[
            SELECT COUNT(*) FROM information_schema.COLUMNS
            WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?
        ]], { tableName, columnName })
        return (tonumber(found) or 0) > 0
    end

    local function tableExists(tableName)
        local found = MySQL.scalar.await([[
            SELECT COUNT(*) FROM information_schema.TABLES
            WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?
        ]], { tableName })
        return (tonumber(found) or 0) > 0
    end

    if not columnExists('housing_properties', 'image_url') then
        MySQL.query.await('ALTER TABLE housing_properties ADD COLUMN image_url VARCHAR(512) NULL')
    end
    if not columnExists('housing_properties', 'zone_json') then
        MySQL.query.await('ALTER TABLE housing_properties ADD COLUMN zone_json JSON NULL')
    end
    if not columnExists('housing_bills', 'week_id') then
        MySQL.query.await('ALTER TABLE housing_bills ADD COLUMN week_id INT NULL')
    end
    if not tableExists('housing_utility_rates') then
        MySQL.query.await([[
            CREATE TABLE housing_utility_rates (
                week_id INT NOT NULL,
                bill_type VARCHAR(32) NOT NULL,
                amount INT NOT NULL,
                rolled_at INT NOT NULL,
                PRIMARY KEY (week_id, bill_type)
            )
        ]])
    end
    local appliedUtilities = MySQL.scalar.await('SELECT version FROM housing_schema_migrations WHERE version = ?', { '002' })
    if not appliedUtilities then
        MySQL.insert.await('INSERT INTO housing_schema_migrations (version) VALUES (?)', { '002' })
    end
    return true
end
