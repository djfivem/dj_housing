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
        water = { amount = 150, intervalHours = 72, label = 'Water Bill' },
        electricity = { amount = 220, intervalHours = 72, label = 'Electricity Bill' },
    },
    -- percentOfValueBps is basis points of purchase price (10 = 0.10%).
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
        -- none uses the built-in plate/model store. event/export delegates and does not invent a garage API.
        system = 'none',
        event = nil,
        exportResource = nil,
        exportName = nil,
    },
    dispatch = {
        -- none | ps-dispatch | custom
        -- ps-dispatch is invoked on the officer client because CustomAlert is a client export.
        system = 'none',
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
