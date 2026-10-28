Housing = Housing or {}
Housing.Client = Housing.Client or {}

local spawned = {}

local function clearFurniture()
    for index = 1, #spawned do
        if DoesEntityExist(spawned[index]) then
            DeleteEntity(spawned[index])
        end
    end
    spawned = {}
end

function Housing.Client.spawnFurniture(propertyId, rows, origin)
    clearFurniture()
    for index = 1, #(rows or {}) do
        local row = rows[index]
        if row.state == 'placed' and row.offset_json and row.model then
            local hash = joaat(row.model)
            RequestModel(hash)
            local expires = GetGameTimer() + 4000
            while not HasModelLoaded(hash) and GetGameTimer() < expires do
                Wait(10)
            end
            if HasModelLoaded(hash) then
                local coords = row.offset_json
                if origin then
                    coords = Housing.Util.offsetCoords(origin, row.offset_json)
                end
                local object = CreateObject(hash, coords.x, coords.y, coords.z, false, false, false)
                SetEntityHeading(object, coords.w or 0.0)
                FreezeEntityPosition(object, true)
                spawned[#spawned + 1] = object
                SetModelAsNoLongerNeeded(hash)
            end
        end
    end
end

function Housing.Client.clearFurniture()
    clearFurniture()
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    clearFurniture()
end)
