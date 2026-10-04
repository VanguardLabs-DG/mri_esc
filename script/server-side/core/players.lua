-- =============================================================
--  mri_esc — Player Tracking & Core Server Logic
-- =============================================================

local playersCache = { count = 0, timestamp = 0 }

--- Gets the count of online players, with a 5-second cache
--- @return number
local registerCallback = (vanguard and vanguard.callback and vanguard.callback.register) or lib.callback.register
registerCallback('mri_esc:server:getPlayersOnline', function()
    local now = os.time()
    if now - playersCache.timestamp > 5 then
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
            TriggerClientEvent('mri_esc:client:resPlayersOnline', source, #GetPlayers())
        end)
    end
end

-- =============================================================
--  mri_esc — Custom Crosshair NetEvent
-- =============================================================
local function sanitizeCrosshairData(input)
    if type(input) ~= 'table' then return nil end
    local cor = tostring(input.cor or "#00ffcc"):lower()
    if not cor:match("^#[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]$") then
        cor = "#00ffcc"
    end

    local function clamp(val, minVal, maxVal, defaultVal)
        val = tonumber(val)
        if not val or val ~= val or math.abs(val) == math.huge then return defaultVal end
        return math.max(minVal, math.min(maxVal, math.floor(val)))
    end

    return {
        ativo = input.ativo == true,
        dot = input.dot == true,
        tamanho = clamp(input.tamanho, 0, 50, 10),
        gap = clamp(input.gap, 0, 20, 5),
        espessura = clamp(input.espessura, 1, 10, 2),
        outline = clamp(input.outline, 0, 5, 1),
        opacidade = clamp(input.opacidade, 0, 100, 100),
        cor = cor
    }
end

if not _G.mri_esc_saveMira_registered then
    _G.mri_esc_saveMira_registered = true
    if vanguard and vanguard.registerServerEvent then
        vanguard.registerServerEvent('mri_esc:server:saveMira', {
            rateLimit = 1000,
            validateArgs = { 'table' }
        }, function(source, miraData)
            local cleanData = sanitizeCrosshairData(miraData)
            if not cleanData then return end
            local player = exports.qbx_core:GetPlayer(source)
            if not player then return end
            player.Functions.SetMetaData('custom_crosshair', cleanData)
        end)
    else
        RegisterNetEvent('mri_esc:server:saveMira', function(miraData)
            local src = source
            local cleanData = sanitizeCrosshairData(miraData)
            if not cleanData then return end
            local player = exports.qbx_core:GetPlayer(src)
            if not player then return end
            player.Functions.SetMetaData('custom_crosshair', cleanData)
        end)
    end
end

