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
    return true
end
