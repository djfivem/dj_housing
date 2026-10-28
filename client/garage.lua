Housing = Housing or {}
Housing.Client = Housing.Client or {}

function Housing.Client.spawnStoredVehicle(data)
    local garage = data.garage
    if not garage then
        Housing.Client.callback('restoreVehicle', { propertyId = data.propertyId, vehicleId = data.vehicleId }, function() end)
        return
    end
    local hash = data.modelHash
    RequestModel(hash)
    local expires = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < expires do
        Wait(10)
    end
    if not HasModelLoaded(hash) then
        Housing.Client.callback('restoreVehicle', { propertyId = data.propertyId, vehicleId = data.vehicleId }, function() end)
        Housing.Client.notify('Vehicle model failed to load.')
        return
    end
    local vehicle = CreateVehicle(hash, garage.x, garage.y, garage.z, garage.w or 0.0, true, false)
    SetVehicleNumberPlateText(vehicle, data.plate or '')
    SetPedIntoVehicle(PlayerPedId(), vehicle, -1)
    SetModelAsNoLongerNeeded(hash)
end

RegisterNetEvent('advanced_housing:legacyStash', function(stashId, opts)
    TriggerServerEvent('inventory:server:OpenInventory', 'stash', stashId, {
        maxweight = opts.maxWeight,
        slots = opts.slots,
    })
    TriggerEvent('inventory:client:SetCurrentStash', stashId)
end)

RegisterNetEvent('advanced_housing:dispatch', function(payload, system)
    if system == 'ps-dispatch' and GetResourceState('ps-dispatch') == 'started' then
        pcall(function()
            exports['ps-dispatch']:CustomAlert({
                message = payload.message,
                codeName = payload.codeName,
                code = payload.code,
                priority = 2,
                coords = vector3(payload.coords.x, payload.coords.y, payload.coords.z),
                jobs = Housing.Config.Integrations.dispatch.jobs,
            })
        end)
    end
end)
