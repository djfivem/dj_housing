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
    local jobs = payload.jobs or Housing.Config.Integrations.dispatch.jobs
    local coords = payload.coords or {}
    if system == 'ps-dispatch' and GetResourceState('ps-dispatch') == 'started' then
        pcall(function()
            exports['ps-dispatch']:CustomAlert({
                message = payload.message,
                codeName = payload.codeName,
                code = payload.code,
                priority = 2,
                coords = vector3(coords.x, coords.y, coords.z),
                jobs = jobs,
            })
        end)
    elseif system == 'cd_dispatch' and GetResourceState('cd_dispatch') == 'started' then
        pcall(function()
            TriggerServerEvent('cd_dispatch:AddNotification', {
                job_table = jobs,
                coords = vector3(coords.x, coords.y, coords.z),
                title = payload.code or '10-90',
                message = payload.message,
                flash = 0,
                unique_id = tostring(payload.propertyId or 'housing') .. ':' .. tostring(payload.codeName or 'raid'),
                sound = 1,
                blip = {
                    sprite = 40,
                    scale = 1.2,
                    colour = 1,
                    flashes = false,
                    text = payload.message or 'Housing',
                    time = 5,
                    radius = 0,
                },
            })
        end)
    elseif system == 'qs-dispatch' and GetResourceState('qs-dispatch') == 'started' then
        pcall(function()
            TriggerServerEvent('qs-dispatch:server:CreateDispatchCall', {
                job = jobs,
                callLocation = vector3(coords.x, coords.y, coords.z),
                callCode = { code = payload.code or '10-90', snippet = 'Housing' },
                message = payload.message,
                flashes = false,
                blip = {
                    sprite = 40,
                    scale = 1.2,
                    colour = 1,
                    flashes = false,
                    text = payload.message or 'Housing',
                    time = 5,
                },
            })
        end)
    end
end)

RegisterNetEvent('advanced_housing:registerQsGarage', function(list)
    if GetResourceState('qs-advancedgarages') ~= 'started' then
        return
    end
    for index = 1, #(list or {}) do
        local row = list[index]
        pcall(function()
            exports['qs-advancedgarages']:CreateGarage(row.id, {
                owner = false,
                available = true,
                type = 'vehicle',
                coords = {
                    menuCoords = { x = row.x, y = row.y, z = row.z, w = row.w },
                    spawnCoords = { x = row.x, y = row.y, z = row.z, w = row.w },
                },
                shell = false,
                price = 0,
            })
        end)
    end
end)
