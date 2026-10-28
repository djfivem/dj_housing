Housing = Housing or {}
Housing.Frameworks = Housing.Frameworks or {}

local Frameworks = Housing.Frameworks

local function call(fn)
    local ok, a, b = pcall(fn)
    if not ok then
        return nil, 'uncertain'
    end
    return a, b
end

function Frameworks.detect(config, env)
    local mode = config.Framework or 'auto'
    local function started(name)
        return env.getResourceState(name) == 'started'
    end
    if mode ~= 'auto' then
        if mode ~= 'esx' and mode ~= 'qbcore' and mode ~= 'qbox' and mode ~= 'standalone' then
            return nil, 'unknown_framework'
        end
        return mode
    end
    local found = {}
    if started('es_extended') then found[#found + 1] = 'esx' end
    if started('qb-core') then found[#found + 1] = 'qbcore' end
    if started('qbx_core') then found[#found + 1] = 'qbox' end
    if #found > 1 then
        return nil, 'ambiguous_framework', found
    end
    if #found == 1 then
        return found[1]
    end
    return 'standalone'
end

local function accountName(config, frameworkName, account)
    local map = config.Frameworks[frameworkName]
    if account == 'cash' then
        return map.cashAccount
    end
    return map.bankAccount
end

function Frameworks.esx(config, env)
    if env.getResourceState('es_extended') ~= 'started' then
        return nil, 'es_extended is not started'
    end
    local function core()
        return env.exports['es_extended']:getSharedObject()
    end
    local adapter = { name = 'esx', liveVerified = false }
    function adapter.getPlayer(source)
        local ESX = core()
        local xPlayer = ESX.GetPlayerFromId(source)
        if not xPlayer then
            return nil
        end
        local grade = xPlayer.job and xPlayer.job.grade or 0
        if type(grade) == 'table' then
            grade = grade.grade or grade.level or 0
        end
        local name = xPlayer.getName and xPlayer.getName() or 'Unknown'
        return {
            source = source,
            framework = 'esx',
            characterId = xPlayer.identifier,
            name = name,
            job = { name = xPlayer.job and xPlayer.job.name or 'unemployed', grade = grade, label = xPlayer.job and xPlayer.job.label or '' },
            group = xPlayer.getGroup and xPlayer.getGroup() or 'user',
        }
    end
    function adapter.getSourceByCharacter(framework, characterId)
        if framework ~= 'esx' then return nil end
        local ESX = core()
        if not ESX.GetPlayerFromIdentifier then return nil end
        local xPlayer = ESX.GetPlayerFromIdentifier(characterId)
        return xPlayer and xPlayer.source or nil
    end
    function adapter.getMoney(source, account)
        local ESX = core()
        local xPlayer = ESX.GetPlayerFromId(source)
        if not xPlayer then return 0 end
        local named = accountName(config, 'esx', account)
        if named == 'money' and xPlayer.getMoney then
            return xPlayer.getMoney()
        end
        local row = xPlayer.getAccount(named)
        return row and row.money or 0
    end
    function adapter.removeMoney(source, account, amount, reason)
        if amount < 0 then return false end
        local ESX = core()
        local xPlayer = ESX.GetPlayerFromId(source)
        if not xPlayer then return false end
        local named = accountName(config, 'esx', account)
        local before = adapter.getMoney(source, account)
        if before < amount then return false end
        local ok = pcall(function()
            if named == 'money' and xPlayer.removeMoney then
                xPlayer.removeMoney(amount, reason)
            else
                xPlayer.removeAccountMoney(named, amount, reason)
            end
        end)
        if not ok then return nil, 'uncertain' end
        local after = adapter.getMoney(source, account)
        return after <= (before - amount)
    end
    function adapter.addMoney(source, account, amount, reason)
        if amount < 0 then return false end
        local ESX = core()
        local xPlayer = ESX.GetPlayerFromId(source)
        if not xPlayer then return false end
        local named = accountName(config, 'esx', account)
        local before = adapter.getMoney(source, account)
        local ok = pcall(function()
            if named == 'money' and xPlayer.addMoney then
                xPlayer.addMoney(amount, reason)
            else
                xPlayer.addAccountMoney(named, amount, reason)
            end
        end)
        if not ok then return nil, 'uncertain' end
        return adapter.getMoney(source, account) >= before + amount
    end
    function adapter.notify(source, message, notifyType)
        if config.Notification == 'custom' and config.CustomNotifyEvent then
            env.triggerClient(config.CustomNotifyEvent, source, message, notifyType)
            return
        end
        if config.Notification == 'ox_lib' and env.getResourceState('ox_lib') == 'started' then
            env.triggerClient('ox_lib:notify', source, { description = message, type = notifyType or 'inform' })
            return
        end
        env.triggerClient('esx:showNotification', source, message)
    end
    function adapter.hasAdmin(source)
        if env.isAceAllowed(source, config.Permissions.adminAce) then
            return true
        end
        local player = adapter.getPlayer(source)
        return player ~= nil and config.Frameworks.esx.adminGroups[player.group] == true
    end
    return adapter
end

function Frameworks.qbcore(config, env)
    if env.getResourceState('qb-core') ~= 'started' then
        return nil, 'qb-core is not started'
    end
    local function core()
        return env.exports['qb-core']:GetCoreObject()
    end
    local adapter = { name = 'qbcore', liveVerified = false }
    local function playerOf(source)
        return core().Functions.GetPlayer(source)
    end
    function adapter.getPlayer(source)
        local player = playerOf(source)
        if not player or not player.PlayerData then return nil end
        local data = player.PlayerData
        local charinfo = data.charinfo or {}
        local grade = data.job and data.job.grade or 0
        if type(grade) == 'table' then grade = grade.level or 0 end
        return {
            source = source,
            framework = 'qbcore',
            characterId = data.citizenid,
            name = ((charinfo.firstname or '') .. ' ' .. (charinfo.lastname or '')):gsub('^%s+', ''):gsub('%s+$', ''),
            job = { name = data.job and data.job.name or 'unemployed', grade = grade, label = data.job and data.job.label or '' },
            group = 'user',
        }
    end
    function adapter.getSourceByCharacter(framework, characterId)
        if framework ~= 'qbcore' then return nil end
        local player = core().Functions.GetPlayerByCitizenId(characterId)
        return player and player.PlayerData and player.PlayerData.source or nil
    end
    function adapter.getMoney(source, account)
        local player = playerOf(source)
        if not player then return 0 end
        return player.Functions.GetMoney(accountName(config, 'qbcore', account)) or 0
    end
    function adapter.removeMoney(source, account, amount, reason)
        if amount < 0 then return false end
        local player = playerOf(source)
        if not player then return false end
        local ok, result = pcall(function()
            return player.Functions.RemoveMoney(accountName(config, 'qbcore', account), amount, reason)
        end)
        if not ok then return nil, 'uncertain' end
        return result == true
    end
    function adapter.addMoney(source, account, amount, reason)
        if amount < 0 then return false end
        local player = playerOf(source)
        if not player then return false end
        local ok, result = pcall(function()
            return player.Functions.AddMoney(accountName(config, 'qbcore', account), amount, reason)
        end)
        if not ok then return nil, 'uncertain' end
        return result == true
    end
    function adapter.notify(source, message, notifyType)
        if config.Notification == 'ox_lib' and env.getResourceState('ox_lib') == 'started' then
            env.triggerClient('ox_lib:notify', source, { description = message, type = notifyType or 'inform' })
            return
        end
        env.triggerClient('QBCore:Notify', source, message, notifyType or 'primary')
    end
    function adapter.hasAdmin(source)
        if env.isAceAllowed(source, config.Permissions.adminAce) then return true end
        local QBCore = core()
        for _, permission in ipairs(config.Frameworks.qbcore.adminPermissions) do
            local ok, allowed = pcall(function()
                return QBCore.Functions.HasPermission(source, permission)
            end)
            if ok and allowed then return true end
        end
        return false
    end
    return adapter
end

function Frameworks.qbox(config, env)
    if env.getResourceState('qbx_core') ~= 'started' then
        return nil, 'qbx_core is not started'
    end
    local adapter = { name = 'qbox', liveVerified = false }
    local function playerOf(source)
        return env.exports.qbx_core:GetPlayer(source)
    end
    function adapter.getPlayer(source)
        local player = playerOf(source)
        if not player or not player.PlayerData then return nil end
        local data = player.PlayerData
        local charinfo = data.charinfo or {}
        local grade = data.job and data.job.grade or 0
        if type(grade) == 'table' then grade = grade.level or 0 end
        return {
            source = source,
            framework = 'qbox',
            characterId = data.citizenid,
            name = ((charinfo.firstname or '') .. ' ' .. (charinfo.lastname or '')):gsub('^%s+', ''):gsub('%s+$', ''),
            job = { name = data.job and data.job.name or 'unemployed', grade = grade, label = data.job and data.job.label or '' },
            group = 'user',
        }
    end
    function adapter.getSourceByCharacter(framework, characterId)
        if framework ~= 'qbox' then return nil end
        local player = env.exports.qbx_core:GetPlayerByCitizenId(characterId)
        if not player then return nil end
        return player.PlayerData and player.PlayerData.source or nil
    end
    function adapter.getMoney(source, account)
        local ok, amount = pcall(function()
            return env.exports.qbx_core:GetMoney(source, accountName(config, 'qbox', account))
        end)
        if not ok or type(amount) ~= 'number' then return 0 end
        return amount
    end
    function adapter.removeMoney(source, account, amount, reason)
        if amount < 0 then return false end
        local ok, result = pcall(function()
            return env.exports.qbx_core:RemoveMoney(source, accountName(config, 'qbox', account), amount, reason)
        end)
        if not ok then return nil, 'uncertain' end
        return result == true
    end
    function adapter.addMoney(source, account, amount, reason)
        if amount < 0 then return false end
        local ok, result = pcall(function()
            return env.exports.qbx_core:AddMoney(source, accountName(config, 'qbox', account), amount, reason)
        end)
        if not ok then return nil, 'uncertain' end
        return result == true
    end
    function adapter.notify(source, message, notifyType)
        if config.Notification == 'ox_lib' and env.getResourceState('ox_lib') == 'started' then
            env.triggerClient('ox_lib:notify', source, { description = message, type = notifyType or 'inform' })
            return
        end
        env.triggerClient('QBCore:Notify', source, message, notifyType or 'primary')
    end
    function adapter.hasAdmin(source)
        if env.isAceAllowed(source, config.Permissions.adminAce) then return true end
        for index = 1, #config.Frameworks.qbox.adminAces do
            if env.isAceAllowed(source, config.Frameworks.qbox.adminAces[index]) then
                return true
            end
        end
        return false
    end
    return adapter
end

function Frameworks.standalone(config, env, repo)
    local adapter = { name = 'standalone', liveVerified = false }
    local function characterId(source)
        local license = env.getPlayerIdentifierByType(source, 'license')
        if not license or license == '' then
            return nil
        end
        return license
    end
    function adapter.getPlayer(source)
        local id = characterId(source)
        if not id then return nil end
        if env.getPlayerName(source) == nil then return nil end
        repo.ensureBalance('standalone', id, 'bank', config.Frameworks.standalone.startingBank or 0)
        repo.ensureBalance('standalone', id, 'cash', config.Frameworks.standalone.startingCash or 0)
        local policeGrade = nil
        if config.Frameworks.standalone.police[id] then
            policeGrade = config.Frameworks.standalone.police[id]
        end
        return {
            source = source,
            framework = 'standalone',
            characterId = id,
            name = env.getPlayerName(source) or 'Resident',
            job = { name = policeGrade and 'police' or 'unemployed', grade = policeGrade or 0, label = policeGrade and 'Police' or 'Civilian' },
            group = 'user',
        }
    end
    function adapter.getSourceByCharacter(framework, id)
        if framework ~= 'standalone' then return nil end
        return env.findSourceByIdentifier and env.findSourceByIdentifier(id) or nil
    end
    function adapter.getMoney(source, account)
        local id = characterId(source)
        if not id then return 0 end
        local named = account == 'cash' and 'cash' or 'bank'
        return repo.getBalance('standalone', id, named)
    end
    function adapter.removeMoney(source, account, amount, reason)
        if amount < 0 then return false end
        local id = characterId(source)
        if not id then return false end
        local named = account == 'cash' and 'cash' or 'bank'
        return repo.tryRemoveBalance('standalone', id, named, amount)
    end
    function adapter.addMoney(source, account, amount, reason)
        if amount < 0 then return false end
        local id = characterId(source)
        if not id then return false end
        local named = account == 'cash' and 'cash' or 'bank'
        return repo.addBalance('standalone', id, named, amount)
    end
    function adapter.notify(source, message, notifyType)
        env.triggerClient('advanced_housing:notify', source, message, notifyType)
    end
    function adapter.hasAdmin(source)
        if env.isAceAllowed(source, config.Permissions.adminAce) then return true end
        local id = characterId(source)
        return id ~= nil and config.Frameworks.standalone.admins[id] == true
    end
    return adapter
end

function Frameworks.create(config, env, repo)
    local mode, err, extra = Frameworks.detect(config, env)
    if not mode then
        return nil, err, extra
    end
    if mode == 'esx' then return Frameworks.esx(config, env) end
    if mode == 'qbcore' then return Frameworks.qbcore(config, env) end
    if mode == 'qbox' then return Frameworks.qbox(config, env) end
    return Frameworks.standalone(config, env, repo)
end
