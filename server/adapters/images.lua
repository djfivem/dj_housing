Housing = Housing or {}
Housing.Images = Housing.Images or {}

local function decodeBody(body)
    if type(body) ~= 'string' then
        return nil
    end
    if json and json.decode then
        local ok, parsed = pcall(json.decode, body)
        if ok then
            return parsed
        end
    end
    local url = body:match('"presignedUrl"%s*:%s*"(https://[^"]+)"')
    if url then
        return { data = { presignedUrl = url } }
    end
    return nil
end

function Housing.Images.presign(ctx)
    local images = (ctx.config and ctx.config.images) or {}
    local convar = images.convar or 'housing_fivemanage_key'
    local key = ''
    if ctx.env and ctx.env.getConvar then
        key = ctx.env.getConvar(convar, '') or ''
    end
    if key == '' then
        return nil, 'image_key_missing'
    end
    if not ctx.env or not ctx.env.http then
        return nil, 'image_unavailable'
    end
    local status, body = ctx.env.http('GET', 'https://api.fivemanage.com/api/v3/file/presigned-url', {
        Authorization = key,
    })
    if status ~= 200 then
        return nil, 'image_unavailable'
    end
    local parsed = decodeBody(body)
    local url = parsed and parsed.data and parsed.data.presignedUrl
    if type(url) ~= 'string' or url:sub(1, 8) ~= 'https://' then
        return nil, 'image_unavailable'
    end
    return url
end
