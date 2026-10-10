-- =========================================================================
-- VANGUARD ESC | VIP Facade & Core Aggregator
-- Consumes standalone vanguard_vip and aggregates ESC Core features
-- (Discord Avatar, Custom Crosshair metadata, Admin State)
-- =========================================================================

local function GetDefaultVipDataFallback(source)
    local player = exports.qbx_core:GetPlayer(source)
    local moneyData = player and player.PlayerData and player.PlayerData.money or {}
    local charInfo  = player and player.PlayerData and player.PlayerData.charinfo or {}
    local jobInfo   = player and player.PlayerData and player.PlayerData.job or {}
    local cid       = player and player.PlayerData and player.PlayerData.citizenid or ""

    local coins = tonumber(moneyData.coin) or 0
    local gems = tonumber(moneyData.gems) or 0
    if cid and cid ~= "" and GetResourceState('casas_paulista') == 'started' and exports['casas_paulista'] and exports['casas_paulista'].GetCoins then
        pcall(function()
            local c = exports['casas_paulista']:GetCoins(cid)
            if c ~= nil then coins = tonumber(c) or 0 end
        end)
    end

    return {
        tier          = 'nenhum',
        label         = "Nenhum",
        salary        = 0,
        inventory     = 100,
        coins         = coins,
        gems          = gems,
        benefits      = {},
        interval      = 30,
        timeLeft      = 0,
        vipSince      = nil,
        vipExpires    = nil,
        daysActive    = 0,
        daysLeft      = nil,
        isExpired     = false,
        totalEarned   = 0,
        paycheckCount = 0,
        charName      = string.format("%s %s", charInfo.firstname or "", charInfo.lastname or ""),
        charJob       = jobInfo.label or 'Desempregado',
        citizenId     = cid,
        allPlans      = {}
    }
end

-- ─────────────────────────────────────────────────────────────
--  FACADE CALLBACK: mri_esc:server:getVipData
-- ─────────────────────────────────────────────────────────────
lib.callback.register('mri_esc:server:getVipData', function(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return nil end

    local vipData = nil
    if GetResourceState('vanguard_vip') == 'started' then
        local ok, data = pcall(function()
            return exports['vanguard_vip']:GetPlayerVipData(source)
        end)
        if ok and data then
            vipData = data
        end
    end

    -- Fallback gracioso se vanguard_vip estiver temporariamente indisponível
    if not vipData then
        vipData = GetDefaultVipDataFallback(source)
    else
        local cid = player.PlayerData.citizenid
        if (not vipData.coins or vipData.coins == 0) and cid and GetResourceState('casas_paulista') == 'started' and exports['casas_paulista'] and exports['casas_paulista'].GetCoins then
            pcall(function()
                local c = exports['casas_paulista']:GetCoins(cid)
                if c ~= nil then
                    vipData.coins = tonumber(c) or 0
                end
            end)
        end
        local moneyData = player.PlayerData.money or {}
        if not vipData.gems or vipData.gems == 0 then
            vipData.gems = tonumber(moneyData.gems) or 0
        end
    end

    -- 1. Obter avatar do Discord via vanguard.discord.getAvatar
    local discordAvatar = nil
    if vanguard and vanguard.discord and vanguard.discord.getAvatar then
        local ok, av = pcall(vanguard.discord.getAvatar, source)
        if ok and av and av ~= "" then
            discordAvatar = av
        end
    end
    vipData.avatar = discordAvatar

    -- 2. Obter mira customizada salva nos metadados do jogador
    local customCrosshair = (player.PlayerData and player.PlayerData.metadata) and player.PlayerData.metadata['custom_crosshair'] or nil
    vipData.mira = customCrosshair

    -- 3. Obter status administrativo explícito
    vipData.isAdmin = IsAdminPlayer(source) == true

    return vipData
end)

-- ─────────────────────────────────────────────────────────────
--  HELPERS & BACKWARD COMPATIBILITY EXPORTS
-- ─────────────────────────────────────────────────────────────

local function GrantVip(...)
    if GetResourceState('vanguard_vip') == 'started' then
        local ok, res, err = pcall(function(...)
            return exports['vanguard_vip']:GrantVip(...)
        end, ...)
        if ok then return res, err end
        return false, tostring(res)
    end
    return false, "Resource vanguard_vip não iniciado."
end

local function RevokeVip(...)
    if GetResourceState('vanguard_vip') == 'started' then
        local ok, res, err = pcall(function(...)
            return exports['vanguard_vip']:RevokeVip(...)
        end, ...)
        if ok then return res, err end
        return false, tostring(res)
    end
    return false, "Resource vanguard_vip não iniciado."
end

local function ExtendVip(...)
    if GetResourceState('vanguard_vip') == 'started' then
        local ok, res, err = pcall(function(...)
            return exports['vanguard_vip']:ExtendVip(...)
        end, ...)
        if ok then return res, err end
        return false, tostring(res)
    end
    return false, "Resource vanguard_vip não iniciado."
end

local function GetVipConfigs(...)
    if GetResourceState('vanguard_vip') == 'started' then
        local ok, res = pcall(function(...)
            return exports['vanguard_vip']:GetVipConfigs(...)
        end, ...)
        if ok and res then return res end
        return {}
    end
    return {}
end

local function SafeGetVipRecord(...)
    if GetResourceState('vanguard_vip') == 'started' then
        local ok, res = pcall(function(...)
            return exports['vanguard_vip']:SafeGetVipRecord(...)
        end, ...)
        if ok then return res end
        return nil
    end
    return nil
end

-- Retrocompatibilidade para scripts que chamem exports['vanguard_esc']:X
exports('GrantVip', function(...) return GrantVip(...) end)
exports('RevokeVip', function(...) return RevokeVip(...) end)
exports('ExtendVip', function(...) return ExtendVip(...) end)
exports('GetVipConfigs', function(...) return GetVipConfigs(...) end)
exports('SafeGetVipRecord', function(...) return SafeGetVipRecord(...) end)
