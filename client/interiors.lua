Housing = Housing or {}
Housing.Client = Housing.Client or {}

local shellEntity = nil
local inside = nil

local function waitForModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) and not IsModelValid(hash) then
        return nil
    end
    RequestModel(hash)
    local expires = GetGameTimer() + 8000
    while not HasModelLoaded(hash) do
        if GetGameTimer() > expires then
            return nil
        end
        Wait(10)
    end
    return hash
end

local function deleteShell()
    if shellEntity and DoesEntityExist(shellEntity) then
        DeleteEntity(shellEntity)
    end
    shellEntity = nil
end

function Housing.Client.isInside()
    return inside
end

function Housing.Client.enterInterior(data)
    DoScreenFadeOut(250)
    while not IsScreenFadedOut() do Wait(10) end
    if data.propertyType == 'ipl' then
        for index = 1, #(data.ipls or {}) do
            RequestIpl(data.ipls[index])
        end
    end
    if data.shell then
        deleteShell()
        local hash = waitForModel(data.shell.model)
        if not hash then
            DoScreenFadeIn(250)
            Housing.Client.callback('exit', {}, function() end)
            Housing.Client.notify('Shell model failed to load: ' .. tostring(data.shell.model))
            return false
        end
        local origin = data.shell.origin
        shellEntity = CreateObject(hash, origin.x, origin.y, origin.z, false, false, false)
        SetEntityHeading(shellEntity, origin.w or 0.0)
        FreezeEntityPosition(shellEntity, true)
        SetModelAsNoLongerNeeded(hash)
        local door = Housing.Util.offsetCoords(origin, data.shell.doorOffset)
        SetEntityCoords(PlayerPedId(), door.x, door.y, door.z, false, false, false, false)
        SetEntityHeading(PlayerPedId(), door.w or 0.0)
        inside = {
            propertyId = data.propertyId,
            propertyType = data.propertyType,
            exit = door,
            shell = shellEntity,
        }
    else
        local interior = data.interior
        SetEntityCoords(PlayerPedId(), interior.x, interior.y, interior.z, false, false, false, false)
        SetEntityHeading(PlayerPedId(), interior.w or 0.0)
        inside = {
            propertyId = data.propertyId,
            propertyType = data.propertyType,
            exit = interior,
        }
    end
    DoScreenFadeIn(250)
    return true
end

function Housing.Client.leaveInterior(returnCoords)
    DoScreenFadeOut(200)
    while not IsScreenFadedOut() do Wait(10) end
    deleteShell()
    if returnCoords then
        SetEntityCoords(PlayerPedId(), returnCoords.x, returnCoords.y, returnCoords.z, false, false, false, false)
        SetEntityHeading(PlayerPedId(), returnCoords.w or 0.0)
    end
    inside = nil
    DoScreenFadeIn(200)
end

function Housing.Client.forceLeave()
    deleteShell()
    inside = nil
    SetNuiFocus(false, false)
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    deleteShell()
    SetNuiFocus(false, false)
    inside = nil
end)

RegisterNetEvent('advanced_housing:forceExit', function()
    Housing.Client.forceLeave()
end)
