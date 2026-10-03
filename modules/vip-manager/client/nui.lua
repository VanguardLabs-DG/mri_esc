-- =============================================================
--  mri_esc — VIP Manager Module (Client NUI Atom)
-- =============================================================

local function PushAdminList()
    CreateThread(function()
        Wait(500)
        local ok, result = pcall(function()
            return lib.callback.await('mri_esc:vip:admin:list', false)
        end)

        if not ok or not result or not result.list then
            SendNUIMessage({ action = 'updateAdminList', list = {}, stats = { total = 0, online = 0, offline = 0 } })
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

RegisterNUICallback("vipAdminRefresh", function(_, cb)
    cb({})
    PushAdminList()
end)

RegisterNUICallback("vipAdminGrant", function(data, cb)
    cb({})
    CreateThread(function()
        local ok, result = pcall(function()
            return lib.callback.await('mri_esc:vip:admin:grant', false, {
                citizenId = data.citizenId,
                tier = data.tier,
                durationDays = data.durationDays or 30
            })
        end)

        local res = (ok and result) or { success = false, error = "Erro ao processar no servidor" }
        SendNUIMessage({ action = 'adminActionResult', operation = 'grant', result = res })
        if res.success then
            Wait(500)
            PushAdminList()
        end
    end)
end)

RegisterNUICallback("vipAdminRevoke", function(data, cb)
    cb({})
    CreateThread(function()
        local ok, result = pcall(function()
            return lib.callback.await('mri_esc:vip:admin:revoke', false, {
                citizenId = data.citizenId
            })
        end)

        local res = (ok and result) or { success = false, error = "Erro ao processar no servidor" }
        SendNUIMessage({ action = 'adminActionResult', operation = 'revoke', result = res })
        if res.success then
            Wait(500)
            PushAdminList()
        end
    end)
end)

RegisterNUICallback("vipAdminExtend", function(data, cb)
    cb({})
    CreateThread(function()
        local ok, result = pcall(function()
            return lib.callback.await('mri_esc:vip:admin:extend', false, {
                citizenId = data.citizenId,
                tier      = data.tier,
                days      = data.days
            })
        end)
        local res = (ok and result) or { success = false, error = "Erro interno" }
        SendNUIMessage({ action = 'adminActionResult', operation = 'extend', result = res })
        if res.success then
            Wait(300)
            PushAdminList()
        end
    end)
end)

RegisterNUICallback("vipAdminSearch", function(data, cb)
    CreateThread(function()
        if not data.query or #data.query < 2 then cb({}); return end

        local ok, result = pcall(function()
            return lib.callback.await('mri_esc:vip:admin:search', false, {
                query = data.query
            })
        end)
        cb((ok and result) or {})
    end)
end)

RegisterNUICallback("vipAdminGetPlans", function(_, cb)
    local plans = lib.callback.await('mri_esc:admin:getPlans', false)
    cb(plans or {})
end)

RegisterNUICallback("vipAdminSavePlan", function(data, cb)
    local res = lib.callback.await('mri_esc:admin:savePlan', false, data)
    cb(res)
end)

RegisterNUICallback("vipAdminDeletePlan", function(data, cb)
    local res = lib.callback.await('mri_esc:admin:deletePlan', false, data.id)
    cb(res)
end)

RegisterNUICallback("vipAdminGetItems", function(_, cb)
    print("[vanguard_esc] NUI requested Items List")
    local items = lib.callback.await('mri_esc:admin:getItems', false)
    print("[vanguard_esc] Items received from server, sending to NUI")
    cb(items or {})
end)

RegisterNUICallback("vipAdminGetVehicles", function(_, cb)
    print("[vanguard_esc] NUI requested Vehicles List")
    local vehicles = lib.callback.await('mri_esc:admin:getVehicles', false)
    print("[vanguard_esc] Vehicles received from server, sending to NUI")
    cb(vehicles or {})
end)

RegisterNUICallback("buyVipWithGems", function(data, cb)
    CreateThread(function()
        local ok, result = pcall(function()
            return lib.callback.await('mri_esc:vip:buyWithGems', false, {
                tier = data and data.tier
            })
        end)
        cb((ok and result) or { success = false, error = "Erro ao comunicar com o servidor." })
    end)
end)

AddEventHandler('mri_esc:client:adminReady', function()
    PushAdminList()
end)
