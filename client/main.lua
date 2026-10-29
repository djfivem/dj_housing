Housing = Housing or {}
Housing.Client = Housing.Client or {}

CreateThread(function()
    Wait(1000)
    Housing.Client.callback('dashboard', {}, function(result)
        if result and result.ok then
            Housing.Client.setProperties(result.data.properties)
            TriggerServerEvent('advanced_housing:requestGarages')
        end
    end)
end)
