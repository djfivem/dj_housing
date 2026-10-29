Housing = Housing or {}
Housing.Client = Housing.Client or {}

local open = false

local function focus(state)
    open = state
    SetNuiFocus(state, state)
    SetNuiFocusKeepInput(false)
end

function Housing.Client.openUi(view)
    focus(true)
    SendNUIMessage({ action = 'open', view = view or 'home' })
end

function Housing.Client.closeUi()
    focus(false)
    SendNUIMessage({ action = 'close' })
end

RegisterNetEvent('advanced_housing:open', function(view)
    Housing.Client.openUi(view)
end)

RegisterCommand(Housing.Config.OpenCommand, function()
    Housing.Client.openUi('home')
end, false)

RegisterNUICallback('close', function(_, cb)
    Housing.Client.closeUi()
    cb({ ok = true })
end)

local forwarded = {
    'dashboard', 'purchase', 'rent', 'renew', 'sell', 'list', 'unlist', 'enter', 'exit',
    'payBill', 'payAll', 'buyFurniture', 'placeFurniture', 'buyUpgrade', 'storeVehicle',
    'takeVehicle', 'restoreVehicle', 'openStash', 'grantAccess', 'revokeAccess', 'issueKey',
    'revokeKey', 'transferKey', 'revokePropertyKeys', 'recoverKey', 'requestWarrant',
    'decideWarrant', 'openRaid', 'setRaidState', 'inspectStash', 'seize', 'transferEvidence',
    'adminEnable', 'adminArchive', 'adminTransfer', 'adminRepair', 'collectPayouts',
    'setPropertyImage', 'prepareImageUpload',
}

for index = 1, #forwarded do
    local name = forwarded[index]
    RegisterNUICallback(name, function(data, cb)
        Housing.Client.callback(name, data or {}, function(result)
            if name == 'enter' and result and result.ok then
                local entered = Housing.Client.enterInterior(result.data)
                if entered then
                    Housing.Client.callback('dashboard', { propertyId = result.data.propertyId }, function(dash)
                        if dash and dash.ok and result.data.shell then
                            Housing.Client.spawnFurniture(result.data.propertyId, dash.data.furniture, result.data.shell.origin)
                        elseif dash and dash.ok then
                            Housing.Client.spawnFurniture(result.data.propertyId, dash.data.furniture, nil)
                        end
                    end)
                end
            elseif name == 'exit' and result and result.ok then
                Housing.Client.clearFurniture()
                Housing.Client.leaveInterior(result.data.returnCoords)
            elseif name == 'takeVehicle' and result and result.ok then
                result.data.propertyId = data.propertyId
                Housing.Client.spawnStoredVehicle(result.data)
            end
            cb(result or { ok = false, error = 'empty' })
        end)
    end)
end

RegisterNUICallback('captureImage', function(data, cb)
    Housing.Client.callback('prepareImageUpload', data or {}, function(prepared)
        if not prepared or not prepared.ok or not prepared.data or type(prepared.data.url) ~= 'string' then
            cb(prepared or { ok = false, error = 'image_unavailable' })
            return
        end
        if GetResourceState('screenshot-basic') ~= 'started' then
            cb({ ok = false, error = 'screenshot_unavailable' })
            return
        end
        exports['screenshot-basic']:requestScreenshotUpload(prepared.data.url, 'file', function(body)
            local url = type(body) == 'string' and body:match('"url"%s*:%s*"(https://[^"]+)"') or nil
            if not url then
                cb({ ok = false, error = 'image_unavailable' })
                return
            end
            Housing.Client.callback('setPropertyImage', {
                propertyId = data and data.propertyId,
                imageUrl = url,
            }, function(saved)
                cb(saved or { ok = false, error = 'image_unavailable' })
            end)
        end)
    end)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
    open = false
end)
