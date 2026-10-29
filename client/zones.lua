Housing = Housing or {}
Housing.Client = Housing.Client or {}

local polygons = {}
local announced = {}

local function destroyPolygons()
    for index = 1, #polygons do
        local zone = polygons[index]
        if zone and zone.destroy then
            zone:destroy()
        end
    end
    polygons = {}
end

local function square(entrance)
    local size = (Housing.Config.Zones and Housing.Config.Zones.defaultSize) or 24.0
    local half = size / 2
    return {
        vector2(entrance.x - half, entrance.y - half),
        vector2(entrance.x + half, entrance.y - half),
        vector2(entrance.x + half, entrance.y + half),
        vector2(entrance.x - half, entrance.y + half),
    }, entrance.z - 8.0, entrance.z + 12.0
end

function Housing.Client.setZones(list)
    destroyPolygons()
    if PolyZone == nil then
        return
    end
    local checkMs = (Housing.Config.Zones and Housing.Config.Zones.checkMs) or 750
    local debug = Housing.Config.Zones and Housing.Config.Zones.debug == true
    for index = 1, #(list or {}) do
        local property = list[index]
        if property.entrance and property.enabled ~= false then
            local points, minZ, maxZ
            if property.zone and type(property.zone.points) == 'table' and #property.zone.points >= 3 then
                points = {}
                for pointIndex = 1, #property.zone.points do
                    local point = property.zone.points[pointIndex]
                    points[pointIndex] = vector2(point.x, point.y)
                end
                minZ = property.zone.minZ
                maxZ = property.zone.maxZ
            else
                points, minZ, maxZ = square(property.entrance)
            end
            local zone = PolyZone:Create(points, {
                name = 'housing_' .. property.id,
                minZ = minZ,
                maxZ = maxZ,
                debugPoly = debug,
            })
            local propertyId = property.id
            local label = property.label
            zone:onPlayerInOut(function(inside)
                if inside then
                    if not announced[propertyId] then
                        announced[propertyId] = true
                        Housing.Client.notify(label)
                    end
                else
                    announced[propertyId] = nil
                end
            end, checkMs)
            polygons[#polygons + 1] = zone
        end
    end
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then
        return
    end
    destroyPolygons()
end)
