Housing = Housing or {}

Housing.Resource = 'advanced_housing'

Housing.Limits = {
    maxPayloadBytes = 24576,
    maxString = 160,
    maxText = 512,
    maxReason = 400,
    maxPrice = 100000000,
    minPrice = 0,
    maxQuantity = 1000,
    maxMetadataBytes = 2048,
    maxKeysPerProperty = 25,
    maxResidents = 12,
    maxStashesPerProperty = 8,
    maxFurniturePerProperty = 40,
    maxOffset = 80.0,
    coordMin = -12000.0,
    coordMax = 12000.0,
    zMin = -800.0,
    zMax = 2500.0,
    maxIdempotency = 64,
    minIdempotency = 8,
}

Housing.Null = Housing.Null or {}
