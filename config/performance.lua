Housing = Housing or {}
Housing.Config = Housing.Config or {}

Housing.Config.Performance = {
    -- Milliseconds. The client sleeps this long while far from every interaction point.
    farSleepMs = 1000,
    -- Used only while a marker is actually being drawn.
    nearSleepMs = 0,
    markerDistance = 12.0,
    interactDistance = 2.2,
    stashDistance = 2.5,
    entranceDistance = 3.0,
    rentalSweepSeconds = 60,
    billSweepSeconds = 300,
    reconcileSweepSeconds = 120,
    reservationTimeoutSeconds = 180,
    callbackTimeoutMs = 8000,
}

Housing.Config.RateLimits = {
    purchase = { burst = 3, refillPerSecond = 0.2 },
    stash = { burst = 6, refillPerSecond = 1 },
    key = { burst = 4, refillPerSecond = 0.3 },
    raid = { burst = 4, refillPerSecond = 0.2 },
    admin = { burst = 8, refillPerSecond = 1 },
    ui = { burst = 10, refillPerSecond = 2 },
    default = { burst = 8, refillPerSecond = 1 },
}
