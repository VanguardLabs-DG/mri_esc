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
if not _G.mri_esc_saveMira_registered then
    _G.mri_esc_saveMira_registered = true
    if vanguard and vanguard.registerServerEvent then
        vanguard.registerServerEvent('mri_esc:server:saveMira', {
            rateLimit = 1000,
            validateArgs = { 'table' }
        }, function(source, miraData)
            local player = exports.qbx_core:GetPlayer(source)
            if not player then return end
            player.Functions.SetMetaData('custom_crosshair', miraData)
        end)
    else
        RegisterNetEvent('mri_esc:server:saveMira', function(miraData)
            local src = source
            if type(miraData) ~= 'table' then return end
            local player = exports.qbx_core:GetPlayer(src)
            if not player then return end
            player.Functions.SetMetaData('custom_crosshair', miraData)
        end)
    end
end

