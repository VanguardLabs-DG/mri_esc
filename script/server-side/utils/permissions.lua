-- =============================================================
--  mri_esc — Permissions Logic
-- =============================================================

--- Verifies if a player has admin permissions via ACE, QBX, or Config
--- @param source number
--- @return boolean
function IsAdminPlayer(source)
    local srcNum = tonumber(source)
    if not srcNum then return false end
    local srcStr = tostring(srcNum)
    
    -- 1. Check ACE Permissions
    if IsPlayerAceAllowed(srcStr, "admin")
    or IsPlayerAceAllowed(srcStr, "command")
    or IsPlayerAceAllowed(srcStr, "group.admin")
    or IsPlayerAceAllowed(srcStr, "group.superadmin")
    or IsPlayerAceAllowed(srcStr, "group.god") then
        return true
    end

    -- 2. Check QBX Permissions (garantindo que o Player exista)
    if GetResourceState('qbx_core') == 'started' then
        local player = exports.qbx_core:GetPlayer(srcNum)
        if player and player.PlayerData then
            local ok, hasGroup = pcall(function()
                return exports.qbx_core:HasGroup(srcNum, 'admin') or exports.qbx_core:HasGroup(srcNum, 'god')
            end)
            if ok and hasGroup then return true end
        end
    end

    -- 3. Fallback: Config.AdminIds
    if Config and Config.AdminIds then
        for i = 0, GetNumPlayerIdentifiers(srcNum) - 1 do
            local pid = GetPlayerIdentifier(srcNum, i)
            for _, adminId in ipairs(Config.AdminIds) do
                if pid == adminId then return true end
            end
        end
    end
    
    return false
end

exports('IsAdminPlayer', IsAdminPlayer)
