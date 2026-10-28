Housing = Housing or {}
Housing.Config = Housing.Config or {}

-- auto | esx | qbcore | qbox | standalone
-- auto refuses to start identity services when more than one framework resource is running.
Housing.Config.Framework = 'auto'

-- auto | ox_inventory | qb_inventory | lj_inventory | ps_inventory | qs_inventory | custom | none
-- auto refuses to guess when more than one supported inventory is running.
Housing.Config.Inventory = 'auto'

-- target | key | both
Housing.Config.Interaction = 'both'

-- framework | ox_lib | custom
Housing.Config.Notification = 'framework'
Housing.Config.CustomNotifyEvent = nil

Housing.Config.Locale = 'en'
Housing.Config.Debug = false

Housing.Config.OpenCommand = 'housing'
Housing.Config.AdminCommand = 'housingadmin'

-- Account name passed to the active framework adapter. Adapters map it to their native account.
Housing.Config.Account = 'bank'
