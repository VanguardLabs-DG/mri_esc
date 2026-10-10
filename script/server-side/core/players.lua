-- =============================================================
--  mri_esc — Player Tracking & Core Server Logic
-- =============================================================

local playersCache = { count = 0, timestamp = 0 }
local isSaveMiraRegistered = false

local CROSSHAIR_LIMITS = {
    tamanho   = { min = 0, max = 50, default = 10 },
    gap       = { min = 0, max = 20, default = 5 },
    espessura = { min = 1, max = 10, default = 2 },
    outline   = { min = 0, max = 5,  default = 1 },
    opacidade = { min = 0, max = 100, default = 100 },
    defaultColor = "#00ffcc"
}

--- Gets the count of online players, with a 5-second cache
--- @return number
local registerCallback = (vanguard and vanguard.callback and vanguard.callback.register) or lib.callback.register
registerCallback('mri_esc:server:getPlayersOnline', function()
    local now = os.time()
    local ttl = (Config and Config.Timings and Config.Timings.playersCacheTtlSec) or 5
    if now - playersCache.timestamp > ttl then
        playersCache.count = #GetPlayers()
        playersCache.timestamp = now
    end
    return playersCache.count
end)

-- Legacy Support (if ox_lib not started)
if GetResourceState('ox_lib') ~= 'started' then
    if vanguard and vanguard.registerServerEvent then
        vanguard.registerServerEvent('mri_esc:server:reqPlayersOnline', {
            rateLimit = 1000
        }, function(source)
            TriggerClientEvent('mri_esc:client:resPlayersOnline', source, #GetPlayers())
        end)
    else
        RegisterNetEvent('mri_esc:server:reqPlayersOnline', function()
            local src = source
            TriggerClientEvent('mri_esc:client:resPlayersOnline', src, #GetPlayers())
        end)
    end
end

-- =============================================================
--  mri_esc — Custom Crosshair NetEvent
-- =============================================================
local function sanitizeCrosshairData(input)
    if type(input) ~= 'table' then return nil end
    local cor = tostring(input.cor or CROSSHAIR_LIMITS.defaultColor):lower()
    if not cor:match("^#[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]$") then
        cor = CROSSHAIR_LIMITS.defaultColor
    end

    local function clamp(val, limit)
        val = tonumber(val)
        if not val or val ~= val or math.abs(val) == math.huge then return limit.default end
        return math.max(limit.min, math.min(limit.max, math.floor(val)))
    end

    return {
        ativo = input.ativo == true,
        dot = input.dot == true,
        tamanho = clamp(input.tamanho, CROSSHAIR_LIMITS.tamanho),
        gap = clamp(input.gap, CROSSHAIR_LIMITS.gap),
        espessura = clamp(input.espessura, CROSSHAIR_LIMITS.espessura),
        outline = clamp(input.outline, CROSSHAIR_LIMITS.outline),
        opacidade = clamp(input.opacidade, CROSSHAIR_LIMITS.opacidade),
        cor = cor
    }
end

if not isSaveMiraRegistered then
    isSaveMiraRegistered = true
    if vanguard and vanguard.registerServerEvent then
        vanguard.registerServerEvent('mri_esc:server:saveMira', {
            rateLimit = 1000,
            validateArgs = { 'table' }
        }, function(source, miraData)
            local cleanData = sanitizeCrosshairData(miraData)
            if not cleanData then return end
            local player = exports.qbx_core:GetPlayer(source)
            if not player then return end
            pcall(function()
                player.Functions.SetMetaData('custom_crosshair', cleanData)
            end)
        end)
    else
        RegisterNetEvent('mri_esc:server:saveMira', function(miraData)
            local src = source
            local cleanData = sanitizeCrosshairData(miraData)
            if not cleanData then return end
            local player = exports.qbx_core:GetPlayer(src)
            if not player then return end
            pcall(function()
                player.Functions.SetMetaData('custom_crosshair', cleanData)
            end)
        end)
    end
end

