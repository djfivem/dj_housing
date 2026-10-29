Housing = Housing or {}
Housing.Client = Housing.Client or {}

local pending = {}
local sequence = 0

function Housing.Client.callback(name, payload, cb)
    sequence = sequence + 1
    local requestId = ('c%s%s'):format(GetGameTimer(), sequence)
    pending[requestId] = cb
    TriggerServerEvent('advanced_housing:request', name, requestId, payload or {})
    SetTimeout(Housing.Config.Performance.callbackTimeoutMs or 8000, function()
        local callback = pending[requestId]
        if not callback then return end
        pending[requestId] = nil
        callback({ ok = false, error = 'timeout' })
    end)
end

RegisterNetEvent('advanced_housing:response', function(requestId, result)
    local callback = pending[requestId]
    if not callback then return end
    pending[requestId] = nil
    callback(result or { ok = false, error = 'empty' })
end)

function Housing.Client.notify(message, notifyType)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(tostring(message))
    EndTextCommandThefeedPostTicker(false, false)
    if Housing.Config.Debug then
        print(('[advanced_housing] %s'):format(message))
    end
end

RegisterNetEvent('advanced_housing:notify', function(message)
    Housing.Client.notify(message)
end)
