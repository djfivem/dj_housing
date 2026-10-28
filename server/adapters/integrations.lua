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

    local dispatchConfig = config.Integrations.dispatch
    if dispatchConfig.system == 'ps-dispatch' then
        if env.getResourceState('ps-dispatch') == 'started' then
            dispatch = function(payload)
                env.triggerClient('advanced_housing:dispatch', -1, payload, 'ps-dispatch')
            end
            report.dispatch = 'ps-dispatch (client export, not executed in this environment)'
        else
            report.dispatch = 'ps-dispatch is not started'
        end
    elseif dispatchConfig.system == 'custom' and dispatchConfig.event then
        dispatch = function(payload)
            env.triggerEvent(dispatchConfig.event, payload)
        end
        report.dispatch = 'custom'
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
