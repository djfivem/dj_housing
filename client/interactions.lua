Housing = Housing or {}
Housing.Client = Housing.Client or {}

local points = {}
local zones = {}

local function distanceTo(coords, point)
    local dx = coords.x - point.x
    local dy = coords.y - point.y
    local dz = coords.z - point.z
    return math.sqrt((dx * dx) + (dy * dy) + (dz * dz))
end

local function addTarget(point)
    if GetResourceState('ox_target') == 'started' then
        local id = exports.ox_target:addSphereZone({
            coords = vector3(point.x, point.y, point.z),
            radius = Housing.Config.Integrations.target.distance,
            options = {
                {
                    name = 'housing_' .. point.id,
                    label = point.label,
                    onSelect = function()
                        Housing.Client.openUi('home')
                        SendNUIMessage({ action = 'select', propertyId = point.id })
                    end,
                },
            },
        })
        zones[#zones + 1] = { system = 'ox_target', id = id }
        return
    end
    if GetResourceState('qb-target') == 'started' then
        local name = 'housing_' .. point.id
        exports['qb-target']:AddCircleZone(name, vector3(point.x, point.y, point.z), Housing.Config.Integrations.target.distance, {
            name = name,
            useZ = true,
        }, {
            options = {
                {
                    label = point.label,
                    action = function()
                        Housing.Client.openUi('home')
                        SendNUIMessage({ action = 'select', propertyId = point.id })
                    end,
                },
            },
            distance = 2.0,
        })
        zones[#zones + 1] = { system = 'qb-target', id = name }
    end
end

function Housing.Client.setProperties(list)
    points = {}
    for index = 1, #(list or {}) do
        local property = list[index]
        if property.entrance and property.enabled ~= false then
            points[#points + 1] = {
                id = property.id,
                label = property.label,
                x = property.entrance.x,
                y = property.entrance.y,
                z = property.entrance.z,
            }
            if Housing.Config.Interaction ~= 'key' then
                addTarget(points[#points])
            end
            local blip = AddBlipForCoord(property.entrance.x, property.entrance.y, property.entrance.z)
            SetBlipSprite(blip, 40)
            SetBlipColour(blip, property.role and 2 or 47)
            SetBlipScale(blip, 0.75)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(property.label)
            EndTextCommandSetBlipName(blip)
        end
    end
end

CreateThread(function()
    while true do
        local sleep = Housing.Config.Performance.farSleepMs or 1000
        local coords = GetEntityCoords(PlayerPedId())
        local inside = Housing.Client.isInside()
        if inside and inside.exit then
            local dist = distanceTo(coords, inside.exit)
            if dist < (Housing.Config.Performance.markerDistance or 12.0) then
                sleep = Housing.Config.Performance.nearSleepMs or 0
                DrawMarker(1, inside.exit.x, inside.exit.y, inside.exit.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.8, 0.8, 0.4, 255, 122, 26, 160, false, false, 2, false, nil, nil, false)
                if dist < (Housing.Config.Performance.interactDistance or 2.2) and IsControlJustReleased(0, 38) then
                    Housing.Client.callback('exit', {}, function(result)
                        if result and result.ok then
                            Housing.Client.clearFurniture()
                            Housing.Client.leaveInterior(result.data.returnCoords)
                        end
                    end)
                end
            end
        elseif Housing.Config.Interaction ~= 'target' then
            for index = 1, #points do
                local point = points[index]
                local dist = distanceTo(coords, point)
                if dist < (Housing.Config.Performance.markerDistance or 12.0) then
                    sleep = Housing.Config.Performance.nearSleepMs or 0
                    DrawMarker(1, point.x, point.y, point.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.9, 0.9, 0.45, 255, 122, 26, 140, false, false, 2, false, nil, nil, false)
                    if dist < (Housing.Config.Performance.interactDistance or 2.2) and IsControlJustReleased(0, 38) then
                        Housing.Client.openUi('home')
                        SendNUIMessage({ action = 'select', propertyId = point.id })
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for index = 1, #zones do
        local zone = zones[index]
        if zone.system == 'ox_target' then
            pcall(function() exports.ox_target:removeZone(zone.id) end)
        elseif zone.system == 'qb-target' then
            pcall(function() exports['qb-target']:RemoveZone(zone.id) end)
        end
    end
end)
