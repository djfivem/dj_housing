Housing = Housing or {}
Housing.RateLimiter = Housing.RateLimiter or {}

function Housing.RateLimiter.new(limits, clock)
    local buckets = {}
    return {
        allow = function(key, action)
            local rule = limits[action] or limits.default
            if not rule then
                return true
            end
            local now = clock()
            local slotKey = tostring(key) .. ':' .. action
            local slot = buckets[slotKey]
            if not slot then
                slot = { tokens = rule.burst, updated = now }
                buckets[slotKey] = slot
            end
            local elapsed = now - slot.updated
            if elapsed < 0 then
                elapsed = 0
            end
            slot.tokens = math.min(rule.burst, slot.tokens + (elapsed * rule.refillPerSecond))
            slot.updated = now
            if slot.tokens < 1 then
                return false
            end
            slot.tokens = slot.tokens - 1
            return true
        end,
    }
end
