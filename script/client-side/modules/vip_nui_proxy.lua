-- =========================================================================
-- VANGUARD ESC | VIP & Admin NUI Proxy
-- Bridges CEF NUI web requests to the standalone vanguard_vip resource
-- ZERO-CHANGE guarantee for web-side (index.html, ui_store.js, components.js)
-- =========================================================================

local function PushAdminList()
    CreateThread(function()
        Wait(300)
        local ok, result = pcall(function()
            return lib.callback.await('vanguard_vip:server:adminList', false)
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

RegisterNUICallback("vipAdminRefresh", function(_, cb)
    cb({})
    PushAdminList()
end)

RegisterNUICallback("vipAdminGrant", function(data, cb)
    cb({})
    CreateThread(function()
        local ok, result = pcall(function()
            return lib.callback.await('vanguard_vip:server:adminGrant', false, {
                citizenId    = data.citizenId,
                tier         = data.tier,
                durationDays = data.durationDays or 30
            })
        end)

        local res = (ok and result) or { success = false, error = "Erro ao comunicar com o servidor VIP." }
        SendNUIMessage({ action = 'adminActionResult', operation = 'grant', result = res })
        if res.success then
            Wait(400)
            PushAdminList()
        end
    end)
end)

RegisterNUICallback("vipAdminRevoke", function(data, cb)
    cb({})
    CreateThread(function()
        local ok, result = pcall(function()
            return lib.callback.await('vanguard_vip:server:adminRevoke', false, {
                citizenId = data.citizenId
            })
        end)

        local res = (ok and result) or { success = false, error = "Erro ao comunicar com o servidor VIP." }
        SendNUIMessage({ action = 'adminActionResult', operation = 'revoke', result = res })
        if res.success then
            Wait(400)
            PushAdminList()
        end
    end)
end)

RegisterNUICallback("vipAdminExtend", function(data, cb)
    cb({})
    CreateThread(function()
        local ok, result = pcall(function()
            return lib.callback.await('vanguard_vip:server:adminExtend', false, {
                citizenId = data.citizenId,
                tier      = data.tier,
                days      = data.days
            })
        end)

        local res = (ok and result) or { success = false, error = "Erro ao comunicar com o servidor VIP." }
        SendNUIMessage({ action = 'adminActionResult', operation = 'extend', result = res })
        if res.success then
            Wait(400)
            PushAdminList()
        end
    end)
end)

RegisterNUICallback("vipAdminSearch", function(data, cb)
    CreateThread(function()
        if not data.query or #data.query < 2 then cb({}); return end

        local ok, result = pcall(function()
            return lib.callback.await('vanguard_vip:server:adminSearch', false, {
                query = data.query
            })
        end)
        cb((ok and result) or {})
    end)
end)

RegisterNUICallback("vipAdminGetPlans", function(_, cb)
    local ok, plans = pcall(function()
        return lib.callback.await('vanguard_vip:server:adminGetPlans', false)
    end)
    cb((ok and plans) or {})
end)

RegisterNUICallback("vipAdminSavePlan", function(data, cb)
    local ok, res = pcall(function()
        return lib.callback.await('vanguard_vip:server:adminSavePlan', false, data)
    end)
    cb((ok and res) or { success = false, error = "Erro ao salvar plano." })
end)

RegisterNUICallback("vipAdminDeletePlan", function(data, cb)
    local ok, res = pcall(function()
        return lib.callback.await('vanguard_vip:server:adminDeletePlan', false, data.id)
    end)
    cb((ok and res) or { success = false, error = "Erro ao excluir plano." })
end)

RegisterNUICallback("vipAdminGetItems", function(_, cb)
    local ok, items = pcall(function()
        return lib.callback.await('vanguard_vip:server:adminGetItems', false)
    end)
    cb((ok and items) or {})
end)

RegisterNUICallback("vipAdminGetVehicles", function(_, cb)
    local ok, vehicles = pcall(function()
        return lib.callback.await('vanguard_vip:server:adminGetVehicles', false)
    end)
    cb((ok and vehicles) or {})
end)

-- ─────────────────────────────────────────────────────────────
--  2. NUI SHOP CALLBACK (COMPRA COM GEMAS)
-- ─────────────────────────────────────────────────────────────

RegisterNUICallback("buyVipWithGems", function(data, cb)
    CreateThread(function()
        local ok, result = pcall(function()
            return lib.callback.await('vanguard_vip:server:buyWithGems', false, {
                tier = data and data.tier
            })
        end)
        cb((ok and result) or { success = false, error = "Erro ao processar transação no servidor VIP." })
    end)
end)

AddEventHandler('mri_esc:client:adminReady', function()
    PushAdminList()
end)
