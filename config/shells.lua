Housing = Housing or {}
Housing.Config = Housing.Config or {}

-- Shell models are an allow-list. The game will not spawn a model that is not listed here.
-- Offsets are community starting points for common streamed shell packs (qb-interior / K4MB1 style).
-- They are not verified against an installed shell pack in this repository. Adjust them to your assets.
-- The resource does not ship the 3D models. If the model is not streamed, entry fails cleanly.
Housing.Config.Shells = {
    shell_michael = {
        label = 'Mansion Shell',
        model = 'shell_michael',
        doorOffset = { x = -9.49, y = 5.54, z = -4.06, w = 0.0 },
    },
    shell_v16mid = {
        label = 'Vinewood House Shell',
        model = 'shell_v16mid',
        doorOffset = { x = 1.36, y = -14.23, z = -0.49, w = 0.0 },
    },
    shell_v16low = {
        label = 'Low House Shell',
        model = 'shell_v16low',
        doorOffset = { x = 4.69, y = -6.50, z = -1.65, w = 0.0 },
    },
    shell_trevor = {
        label = 'Trevor Shell',
        model = 'shell_trevor',
        doorOffset = { x = 0.17, y = -3.51, z = -0.40, w = 0.0 },
    },
    shell_trailer = {
        label = 'Trailer Shell',
        model = 'shell_trailer',
        doorOffset = { x = -1.40, y = -2.00, z = -0.20, w = 0.0 },
    },
    shell_lester = {
        label = 'Lester Shell',
        model = 'shell_lester',
        doorOffset = { x = -1.61, y = -6.02, z = -0.37, w = 0.0 },
    },
    shell_ranch = {
        label = 'Ranch Shell',
        model = 'shell_ranch',
        doorOffset = { x = -1.00, y = -5.35, z = -1.00, w = 0.0 },
    },
    shell_frankaunt = {
        label = 'Aunt Shell',
        model = 'shell_frankaunt',
        doorOffset = { x = -0.36, y = -5.89, z = -0.57, w = 0.0 },
    },
    shell_apartment = {
        label = 'Apartment Shell',
        model = 'shell_v16mid',
        doorOffset = { x = 1.36, y = -14.23, z = -0.49, w = 0.0 },
    },
}
