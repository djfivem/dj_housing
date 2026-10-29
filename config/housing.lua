Housing = Housing or {}
Housing.Config = Housing.Config or {}

Housing.Config.Housing = {
    -- When true, structural fields from config/properties.lua refresh on start.
    -- Ownership, tenancy, status, and stash contents are never overwritten.
    syncDefinitions = true,
    saleReturnPercent = 60,
    minListingPrice = 1000,
    maxListingPercent = 300,
    defaultStashSlots = 40,
    defaultStashWeight = 100000,
    billRates = {
        property_tax = { percentOfValueBps = 10, intervalHours = 168, label = 'Property Tax' },
    },
    -- percentOfValueBps is basis points of purchase price (10 = 0.10%).
    -- Water, power, and garbage are rolled once per week for the whole city.
    -- The same amount is billed to every occupied property until the next week.
    utilities = {
        intervalHours = 168,
        types = {
            water = { label = 'Water', min = 75, max = 280 },
            electricity = { label = 'Power', min = 90, max = 360 },
            garbage = { label = 'Garbage', min = 40, max = 190 },
        },
    },
}

Housing.Config.Images = {
    -- Paste a FiveManage URL, or capture one when screenshot-basic is started.
    -- The API key stays in the server convar `housing_fivemanage_key`. Never put it in this file.
    provider = 'fivemanage',
    convar = 'housing_fivemanage_key',
    allowedHosts = { 'r2.fivemanage.com', 'fivemanage.com', 'fmapi.net' },
}

Housing.Config.Zones = {
    -- Square lot used when a property has no polygon. Replace it with zone.points from /pzcreate.
    defaultSize = 24.0,
    debug = false,
    checkMs = 750,
}

Housing.Config.Furniture = {
    { id = 'sofa_modern', label = 'Sofa', category = 'living', price = 2500, model = 'v_res_tre_sofa_s' },
    { id = 'tv_stand', label = 'TV Stand', category = 'living', price = 1200, model = 'prop_tv_cabinet_03' },
    { id = 'bed_double', label = 'Bed', category = 'bedroom', price = 2000, model = 'v_res_msonbed' },
    { id = 'dining_table', label = 'Dining Table', category = 'kitchen', price = 1800, model = 'v_res_fh_diningtable' },
    { id = 'chair_wood', label = 'Chair', category = 'kitchen', price = 450, model = 'v_res_fh_kitnstool' },
    { id = 'dresser', label = 'Dresser', category = 'bedroom', price = 1300, model = 'v_res_mddresser' },
    { id = 'plant_decor', label = 'Planter', category = 'decor', price = 350, model = 'prop_plant_int_03a' },
    { id = 'lamp_floor', label = 'Floor Lamp', category = 'decor', price = 280, model = 'v_res_d_lampa' },
}

Housing.Config.Upgrades = {
    {
        id = 'security',
        label = 'Security System',
        description = 'Raises an alarm when a raid starts.',
        price = 75000,
        effect = { alarm = true },
    },
    {
        id = 'garage_expansion',
        label = 'Custom Garage',
        description = 'Adds two garage slots.',
        price = 150000,
        effect = { garageSlots = 2 },
    },
    {
        id = 'stash_expansion',
        label = 'Yard Upgrade',
        description = 'Adds 50kg of shared stash capacity.',
        price = 100000,
        effect = { stashWeightBonus = 50000 },
    },
    {
        id = 'interior_finish',
        label = 'Interior Upgrade',
        description = 'Records a premium interior finish on the property.',
        price = 250000,
        effect = { interiorFinish = true },
    },
}

Housing.Config.Integrations = {
    doorlock = {
        -- none | ox_doorlock | custom
        system = 'none',
        custom = { resource = nil, exportName = nil },
    },
    garage = {
        -- auto registers the first started garage that has a published house API.
        -- jg-advancedgarages v3 uses registerGarage. The same id is kept so stored vehicles stay linked.
        -- builtin keeps only the plate list in this resource.
        -- qb-garages | jg-advancedgarages | qs-advancedgarages | builtin
        system = 'auto',
    },
    banking = {
        -- auto records the withdrawal in the first started banking resource.
        -- The framework still moves the money. The banking export only writes the statement.
        -- renewed | qb-banking | okokBanking | none
        system = 'auto',
    },
    dispatch = {
        -- auto | none | ps-dispatch | cd_dispatch | qs-dispatch | rcore_dispatch | lb-tablet | custom
        system = 'auto',
        -- ps-dispatch builds after version 3 may expect the job name `leo` before an alert shows a blip.
        jobs = { 'police', 'sheriff' },
    },
    mdt = {
        -- native uses housing_warrants. custom delegates reads when an export is configured.
        system = 'native',
        custom = { resource = nil, exportName = nil },
    },
    target = {
        -- auto uses ox_target, then qb-target, then key interaction.
        system = 'auto',
        distance = 2.0,
    },
}
