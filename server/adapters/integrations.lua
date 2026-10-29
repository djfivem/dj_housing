Housing = Housing or {}
Housing.Integrations = Housing.Integrations or {}

function Housing.Integrations.bind(config, env)
    local report = {}
    local doorlock = function() end
    local dispatch = function() end
    local evidenceExternal = nil

    local doorConfig = config.Integrations.doorlock
    if doorConfig.system == 'ox_doorlock' then
        if env.getResourceState('ox_doorlock') == 'started' then
            doorlock = function(property, locked)
                for index = 1, #(property.doors or {}) do
                    local door = property.doors[index]
                    if door.id then
                        pcall(function()
                            env.exports.ox_doorlock:setDoorState(door.id, locked and 1 or 0)
                        end)
                    end
                end
            end
            report.doorlock = 'ox_doorlock'
        else
            report.doorlock = 'configured ox_doorlock is not started'
        end
    elseif doorConfig.system == 'custom' and doorConfig.custom.resource and doorConfig.custom.exportName then
        if env.getResourceState(doorConfig.custom.resource) == 'started' then
            doorlock = function(property, locked)
                for index = 1, #(property.doors or {}) do
                    local door = property.doors[index]
                    pcall(function()
                        env.exports[doorConfig.custom.resource][doorConfig.custom.exportName](door.id, locked)
                    end)
                end
            end
            report.doorlock = 'custom'
        else
            report.doorlock = 'custom door resource is not started'
        end
    else
        report.doorlock = 'none'
    end

    local dispatchConfig = config.Integrations.dispatch or {}
    local dispatchOrder = {
        { id = 'ps-dispatch', resource = 'ps-dispatch', side = 'client' },
        { id = 'cd_dispatch', resource = 'cd_dispatch', side = 'client' },
        { id = 'qs-dispatch', resource = 'qs-dispatch', side = 'client' },
        { id = 'rcore_dispatch', resource = 'rcore_dispatch', side = 'server' },
        { id = 'lb-tablet', resource = 'lb-tablet', side = 'server' },
    }
    local dispatchSetting = dispatchConfig.system or 'none'
    local chosenDispatch
    if dispatchSetting == 'auto' then
        for index = 1, #dispatchOrder do
            if env.getResourceState(dispatchOrder[index].resource) == 'started' then
                chosenDispatch = dispatchOrder[index]
                break
            end
        end
    elseif dispatchSetting ~= 'none' and dispatchSetting ~= 'custom' then
        for index = 1, #dispatchOrder do
            if dispatchOrder[index].id == dispatchSetting then
                chosenDispatch = dispatchOrder[index]
            end
        end
    end
    if dispatchSetting == 'custom' and dispatchConfig.event then
        dispatch = function(payload)
            env.triggerEvent(dispatchConfig.event, payload)
        end
        report.dispatch = 'custom'
    elseif chosenDispatch and env.getResourceState(chosenDispatch.resource) == 'started' then
        if chosenDispatch.side == 'client' then
            dispatch = function(payload)
                payload.jobs = dispatchConfig.jobs
                env.triggerClient('advanced_housing:dispatch', -1, payload, chosenDispatch.id)
            end
        elseif chosenDispatch.id == 'rcore_dispatch' then
            dispatch = function(payload)
                pcall(function()
                    env.triggerEvent('rcore_dispatch:server:sendAlert', {
                        code = payload.code or '10-90',
                        default_priority = 'medium',
                        coords = payload.coords,
                        job = dispatchConfig.jobs,
                        text = payload.message,
                        type = 'alerts',
                        blip_time = 5,
                        blip = {
                            sprite = 40,
                            colour = 1,
                            scale = 1.0,
                            text = payload.message or 'Housing',
                            flashes = false,
                            radius = 0,
                        },
                    })
                end)
            end
        else
            dispatch = function(payload)
                local coords = payload.coords or {}
                pcall(function()
                    env.exports['lb-tablet'].AddDispatch({
                        priority = 'medium',
                        code = payload.code or '10-90',
                        title = 'Housing',
                        description = payload.message,
                        location = {
                            label = payload.propertyId or 'Property',
                            coords = { x = coords.x, y = coords.y },
                        },
                        time = 300,
                        job = (dispatchConfig.jobs and dispatchConfig.jobs[1]) or 'police',
                    })
                end)
            end
        end
        report.dispatch = chosenDispatch.id .. ' (not executed in this environment)'
    elseif chosenDispatch then
        report.dispatch = chosenDispatch.id .. ' is not started'
    else
        report.dispatch = 'none'
    end

    local evidenceConfig = config.Evidence
    if evidenceConfig.system == 'custom' and evidenceConfig.custom.resource and evidenceConfig.custom.exportName then
        if env.getResourceState(evidenceConfig.custom.resource) == 'started' then
            evidenceExternal = function(payload)
                pcall(function()
                    env.exports[evidenceConfig.custom.resource][evidenceConfig.custom.exportName](payload)
                end)
            end
            report.evidence = 'custom'
        else
            report.evidence = 'custom evidence resource is not started; native ledger remains active'
        end
    else
        report.evidence = 'native'
    end

    report.mdt = config.Integrations.mdt.system
    report.garage = config.Integrations.garage.system
    return {
        doorlock = doorlock,
        dispatch = dispatch,
        evidenceExternal = evidenceExternal,
        report = report,
    }
end
