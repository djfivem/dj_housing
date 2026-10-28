Housing = Housing or {}
Housing.Config = Housing.Config or {}

local function stash(key, label, stashType, accessLevel, slots, weight)
    return {
        key = key,
        label = label,
        stashType = stashType,
        accessLevel = accessLevel,
        slots = slots,
        maxWeight = weight,
    }
end

-- Example catalogue. Coordinates are real-world GTA positions you should confirm in-game.
-- shell/apartment `interior` values are door offsets relative to the instanced shell origin.
-- mlo/ipl `interior` values are absolute interior coordinates. MLOs do not spawn a shell.
Housing.Config.Properties = {
    {
        id = 'vinewood_hills_mansion',
        label = 'Vinewood Hills Mansion',
        description = 'Modern luxury mansion with a pool, garage, and viewing deck. Perfect for anyone looking for premium living.',
        propertyType = 'shell',
        purchasePrice = 2500000,
        rentalPrice = 25000,
        rentalPeriodHours = 168,
        entrance = { x = -174.35, y = 497.88, z = 137.65, w = 191.0 },
        interior = { x = -9.49, y = 5.54, z = -4.06, w = 0.0 },
        shellModel = 'shell_michael',
        shellOptions = { 'shell_michael', 'shell_ranch' },
        image = 'mansion',
        bedrooms = 6,
        bathrooms = 6,
        garages = 4,
        garage = { x = -173.4, y = 502.6, z = 137.42, w = 10.0 },
        stashes = {
            stash('shared', 'Household Storage', 'shared', 'resident', 80, 250000),
            stash('personal', 'Personal Locker', 'personal', 'resident', 30, 80000),
            stash('restricted', 'Owner Safe', 'restricted', 'owner', 20, 50000),
        },
        features = { pool = true, view = true },
    },
    {
        id = 'del_perro_apartment',
        label = 'Del Perro Apartment',
        description = 'High-rise apartment over Del Perro. Uses a base-game online apartment IPL, not a spawned shell.',
        propertyType = 'ipl',
        purchasePrice = 330000,
        rentalPrice = 4500,
        rentalPeriodHours = 168,
        entrance = { x = -773.88, y = 312.08, z = 85.70, w = 180.0 },
        interior = { x = -786.87, y = 315.76, z = 217.64, w = 180.0 },
        ipls = { 'apa_v_mp_h_01_a' },
        image = 'apartment',
        bedrooms = 2,
        bathrooms = 1,
        garages = 1,
        garage = { x = -796.2, y = 307.4, z = 85.70, w = 180.0 },
        stashes = {
            stash('shared', 'Apartment Storage', 'shared', 'resident', 40, 100000),
            stash('personal', 'Personal Locker', 'personal', 'resident', 20, 40000),
        },
        features = { city = true },
    },
    {
        id = 'sandy_shores_trailer',
        label = 'Sandy Shores Trailer',
        description = 'Compact trailer on the east side of Sandy Shores.',
        propertyType = 'shell',
        purchasePrice = 180000,
        rentalPrice = 1800,
        rentalPeriodHours = 168,
        entrance = { x = 1975.52, y = 3818.22, z = 33.44, w = 30.0 },
        interior = { x = -1.40, y = -2.00, z = -0.20, w = 0.0 },
        shellModel = 'shell_trailer',
        image = 'trailer',
        bedrooms = 1,
        bathrooms = 1,
        garages = 1,
        garage = { x = 1972.4, y = 3822.1, z = 33.3, w = 30.0 },
        stashes = {
            stash('shared', 'Trailer Storage', 'shared', 'resident', 25, 60000),
        },
        features = { rural = true },
    },
    {
        id = 'mirror_park_house',
        label = 'Mirror Park House',
        description = 'Existing Mirror Park house MLO. Entry teleports between the configured door and interior. No shell is spawned.',
        propertyType = 'mlo',
        purchasePrice = 650000,
        rentalPrice = 7000,
        rentalPeriodHours = 168,
        entrance = { x = 1229.68, y = -725.36, z = 60.96, w = 110.0 },
        interior = { x = 1228.10, y = -724.40, z = 60.80, w = 110.0 },
        image = 'house',
        bedrooms = 3,
        bathrooms = 2,
        garages = 2,
        garage = { x = 1221.5, y = -730.2, z = 60.6, w = 110.0 },
        doors = {},
        stashes = {
            stash('shared', 'House Storage', 'shared', 'resident', 50, 150000),
            stash('personal', 'Personal Locker', 'personal', 'resident', 25, 50000),
            stash('restricted', 'Owner Safe', 'restricted', 'coowner', 15, 40000),
        },
        features = { yard = true },
    },
}
