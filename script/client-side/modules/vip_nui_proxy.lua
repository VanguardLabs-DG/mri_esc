-- =========================================================================
-- VANGUARD ESC | VIP & Admin NUI Proxy
-- Bridges CEF NUI web requests to the standalone vanguard_vip resource
-- ZERO-CHANGE guarantee for web-side (index.html, ui_store.js, components.js)
-- =========================================================================

local SafeNUICallback = (EscCore and EscCore.SafeNUICallback) or RegisterNUICallback
local MIN_SEARCH_QUERY_LEN = 2
local DEFAULT_VIP_DAYS = 30

local function GetCallbackTimeout()
    return (Config and Config.Timings and Config.Timings.callbackTimeoutMs) or 2500
end

local function PushAdminList()
    CreateThread(function()
        local cbTimeout = GetCallbackTimeout()
        local ok, result = pcall(function()
            return lib.callback.await('vanguard_vip:server:adminList', cbTimeout)
        end)

        if not ok or not result or not result.list then
            SendNUIMessage({
                action = 'updateAdminList',
                list = {},
                stats = { total = 0, online = 0, offline = 0 }
            })
            return
        end

        SendNUIMessage({
            action   = 'updateAdminList',
            list     = result.list,
            stats    = result.stats,
            allPlans = result.allPlans
        })
    end)
end

-- ─────────────────────────────────────────────────────────────
--  1. NUI ADMIN CALLBACKS
-- ─────────────────────────────────────────────────────────────

SafeNUICallback("vipAdminRefresh", function(_, cb)
    if cb then cb({}) end
    PushAdminList()
end)

SafeNUICallback("vipAdminGrant", function(data, cb)
    if cb then cb({}) end
    CreateThread(function()
        local cbTimeout = GetCallbackTimeout()
        local ok, result = pcall(function()
            return lib.callback.await('vanguard_vip:server:adminGrant', cbTimeout, {
                citizenId    = data and data.citizenId,
                tier         = data and data.tier,
                durationDays = (data and data.durationDays) or DEFAULT_VIP_DAYS
            })
        end)

        local res = (ok and result) or { success = false, error = "Erro ao comunicar com o servidor VIP." }
        SendNUIMessage({ action = 'adminActionResult', operation = 'grant', result = res })
        if res.success then
            PushAdminList()
        end
    end)
end)

SafeNUICallback("vipAdminRevoke", function(data, cb)
    if cb then cb({}) end
    CreateThread(function()
        local cbTimeout = GetCallbackTimeout()
        local ok, result = pcall(function()
            return lib.callback.await('vanguard_vip:server:adminRevoke', cbTimeout, {
                citizenId = data and data.citizenId
            })
        end)

        local res = (ok and result) or { success = false, error = "Erro ao comunicar com o servidor VIP." }
        SendNUIMessage({ action = 'adminActionResult', operation = 'revoke', result = res })
        if res.success then
            PushAdminList()
        end
    end)
end)

SafeNUICallback("vipAdminExtend", function(data, cb)
    if cb then cb({}) end
    CreateThread(function()
        local cbTimeout = GetCallbackTimeout()
        local ok, result = pcall(function()
            return lib.callback.await('vanguard_vip:server:adminExtend', cbTimeout, {
                citizenId = data and data.citizenId,
                tier      = data and data.tier,
                days      = data and data.days
            })
        end)

        local res = (ok and result) or { success = false, error = "Erro ao comunicar com o servidor VIP." }
        SendNUIMessage({ action = 'adminActionResult', operation = 'extend', result = res })
        if res.success then
            PushAdminList()
        end
    end)
end)

SafeNUICallback("vipAdminSearch", function(data, cb)
    CreateThread(function()
        if not data or not data.query or #data.query < MIN_SEARCH_QUERY_LEN then
            if cb then cb({}) end
            return
        end

        local cbTimeout = GetCallbackTimeout()
        local ok, result = pcall(function()
            return lib.callback.await('vanguard_vip:server:adminSearch', cbTimeout, {
                query = data.query
            })
        end)
        if cb then cb((ok and result) or {}) end
    end)
end)

SafeNUICallback("vipAdminGetPlans", function(_, cb)
    local cbTimeout = GetCallbackTimeout()
    local ok, plans = pcall(function()
        return lib.callback.await('vanguard_vip:server:adminGetPlans', cbTimeout)
    end)
    if cb then cb((ok and plans) or {}) end
end)

SafeNUICallback("vipAdminSavePlan", function(data, cb)
    local cbTimeout = GetCallbackTimeout()
    local ok, res = pcall(function()
        return lib.callback.await('vanguard_vip:server:adminSavePlan', cbTimeout, data)
    end)
    if cb then cb((ok and res) or { success = false, error = "Erro ao salvar plano." }) end
end)

SafeNUICallback("vipAdminDeletePlan", function(data, cb)
    local cbTimeout = GetCallbackTimeout()
    local ok, res = pcall(function()
        return lib.callback.await('vanguard_vip:server:adminDeletePlan', cbTimeout, data and data.id)
    end)
    if cb then cb((ok and res) or { success = false, error = "Erro ao excluir plano." }) end
end)

SafeNUICallback("vipAdminGetItems", function(_, cb)
    local cbTimeout = GetCallbackTimeout()
    local ok, items = pcall(function()
        return lib.callback.await('vanguard_vip:server:adminGetItems', cbTimeout)
    end)
    if cb then cb((ok and items) or {}) end
end)

SafeNUICallback("vipAdminGetVehicles", function(_, cb)
    local cbTimeout = GetCallbackTimeout()
    local ok, vehicles = pcall(function()
        return lib.callback.await('vanguard_vip:server:adminGetVehicles', cbTimeout)
    end)
    if cb then cb((ok and vehicles) or {}) end
end)

-- ─────────────────────────────────────────────────────────────
--  2. NUI SHOP CALLBACK (COMPRA COM GEMAS)
-- ─────────────────────────────────────────────────────────────

SafeNUICallback("buyVipWithGems", function(data, cb)
    CreateThread(function()
        local cbTimeout = GetCallbackTimeout()
        local ok, result = pcall(function()
            return lib.callback.await('vanguard_vip:server:buyWithGems', cbTimeout, {
                tier = data and data.tier
            })
        end)
        if cb then cb((ok and result) or { success = false, error = "Erro ao processar transação no servidor VIP." }) end
    end)
end)

AddEventHandler('mri_esc:client:adminReady', function()
    PushAdminList()
end)
