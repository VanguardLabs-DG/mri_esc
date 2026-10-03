-- =============================================================
--  mri_esc — VIP Manager Module (Callbacks Organism)
-- =============================================================

lib.callback.register('mri_esc:server:getVipData', function(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return nil end

    local vipTier = player.PlayerData.metadata['vip'] or 'nenhum'
    local moneyData = player.PlayerData.money or {}
    local gems = tonumber(moneyData.gems) or 0
    local coins = tonumber(moneyData.coin) or 0
    local cid   = player.PlayerData.citizenid

    local vipConfigs = GetVipConfigs()
    local currentVipInfo = vipConfigs[vipTier] or vipConfigs['nenhum'] or { label = "Nenhum", payment = 0, inventory = 100 }
    
    local r           = SafeGetVipRecord(cid)
    local vipSince    = r and r.granted_at   or (vipTier ~= 'nenhum' and 0 or nil)
    local vipExpires  = r and r.expires_at   or nil
    local totalEarned = r and r.total_earned or 0
    local paycheckCount = r and r.paycheck_count or 0

    local daysActive = 0
    if vipSince and vipSince > 0 then
        daysActive = math.floor((os.time() - vipSince) / 86400)
    end

    local isExpired, daysLeft = false, nil
    if vipExpires and vipExpires > 0 then
        local diff = vipExpires - os.time()
        isExpired = diff <= 0
        daysLeft  = math.max(0, math.floor(diff / 86400))
    end

    local charName = string.format("%s %s",
        player.PlayerData.charinfo.firstname or "",
        player.PlayerData.charinfo.lastname  or "")

    -- Obter avatar do Discord com fallback gracioso via vanguard.discord.getAvatar
    local discordAvatar = nil
    if vanguard and vanguard.discord and vanguard.discord.getAvatar then
        local ok, av = pcall(vanguard.discord.getAvatar, source)
        if ok and av and av ~= "" then
            discordAvatar = av
        end
    end

    -- Obter dados de mira customizada salvos em metadata do jogador
    local customCrosshair = (player.PlayerData and player.PlayerData.metadata) and player.PlayerData.metadata['custom_crosshair'] or nil

    return {
        tier          = vipTier,
        label         = currentVipInfo.label    or "Nenhum",
        salary        = currentVipInfo.payment  or 0,
        inventory     = currentVipInfo.inventory or 0,
        coins         = coins,
        gems          = gems,
        benefits      = currentVipInfo.benefits or {},
        interval      = paycheckInterval,
        timeLeft      = GetSyncedTimeLeft(),
        vipSince      = vipSince,
        vipExpires    = vipExpires,
        daysActive    = daysActive,
        daysLeft      = daysLeft,
        isExpired     = isExpired,
        totalEarned   = totalEarned,
        paycheckCount = paycheckCount,
        charName      = charName,
        charJob       = player.PlayerData.job.label or 'Desempregado',
        citizenId     = cid,
        avatar        = discordAvatar,
        mira          = customCrosshair,
        isAdmin       = IsAdminPlayer(source) == true, -- Explicit boolean
        allPlans      = (function()
            local p = {}
            for id, cfg in pairs(vipConfigs) do
                if id ~= 'nenhum' then
                    p[#p+1] = {
                        id = id,
                        label = cfg.label,
                        payment = cfg.payment,
                        inventory = cfg.inventory,
                        priceGems = cfg.priceGems or 500,
                        priceReal = cfg.priceReal or "50,00",
                        badge = cfg.badge or "VIP",
                        featured = cfg.featured or false,
                        benefits = cfg.benefits,
                        rewards = cfg.rewards or {},
                        vehicle = cfg.vehicle or nil
                    }
                end
            end
            table.sort(p, function(a,b) return (tonumber(a.payment) or 0) < (tonumber(b.payment) or 0) end)
            return p
        end)()
    }
end)

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

lib.callback.register('mri_esc:vip:buyWithGems', function(source, data)
    if vanguard and vanguard.rateLimit then
        local allowed = vanguard.rateLimit(source, "vip_buy", 1500)
        if allowed == false then
            return { success = false, error = "Aguarde um instante antes de realizar outra transação." }
        end
    end
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return { success = false, error = "Jogador não encontrado." } end

    local tier = data and data.tier
    if not tier then return { success = false, error = "Plano inválido." } end

    local cfg = GetVipConfigs()
    local plan = cfg[tier]
    if not plan or tier == 'nenhum' then
        return { success = false, error = "Plano VIP não configurado." }
    end

    local priceGems = tonumber(plan.priceGems) or 500
    local playerGems = exports.qbx_core:GetMoney(source, 'gems') or 0

    if playerGems < priceGems then
        return { 
            success = false, 
            needGems = true,
            error = string.format("Você possui %d Gemas, mas são necessárias %d Gemas para este plano.", playerGems, priceGems)
        }
    end

    local removed = exports.qbx_core:RemoveMoney(source, 'gems', priceGems, 'Compra VIP ' .. plan.label)
    if not removed then
        return { success = false, error = "Falha ao debitar Gemas. Tente novamente." }
    end

    local cid = player.PlayerData.citizenid
    local granted = GrantVip(cid, tier, 30, 'ingame_gems')
    if not granted then
        exports.qbx_core:AddMoney(source, 'gems', priceGems, 'Estorno VIP ' .. plan.label)
        return { success = false, error = "Erro ao conceder privilégios VIP." }
    end

    local newGems = exports.qbx_core:GetMoney(source, 'gems') or 0
    Player(source).state:set('gems', newGems, true)
    TriggerClientEvent('mri_esc:client:refreshVip', source)

    return { 
        success = true, 
        message = string.format("Parabéns! Seu %s foi ativado por 30 dias!", plan.label),
        newGems = newGems
    }
end)

-- ── PLAN MANAGEMENT ──────────────────────────────────────────
lib.callback.register('mri_esc:admin:getPlans', function(source)
    local cfg = GetVipConfigs()
    local list = {}
    for id, data in pairs(cfg) do
        if id ~= 'nenhum' then
            table.insert(list, {
                id        = id,
                label     = data.label,
                payment   = data.payment,
                inventory = data.inventory,
                benefits  = data.benefits,
                rewards   = data.rewards or {},
                vehicle   = data.vehicle or nil
            })
        end
    end
    return list
end)

lib.callback.register('mri_esc:admin:savePlan', function(source, data)
    if not IsAdminPlayer(source) then return { success = false, error = "Permissão negada" } end
    
    local ok, err = pcall(function()
        MySQL.query.await([[
            INSERT INTO mri_vip_plans (id, label, payment, inventory, benefits, rewards, vehicle_data, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
                label=VALUES(label), payment=VALUES(payment),
                inventory=VALUES(inventory), benefits=VALUES(benefits),
                rewards=VALUES(rewards), vehicle_data=VALUES(vehicle_data), updated_at=VALUES(updated_at)
        ]], { 
            data.id, data.label, data.payment, data.inventory, 
            json.encode(data.benefits or {}), 
            json.encode(data.rewards or {}),
            json.encode(data.vehicle or nil),
            os.time() 
        })
    end)
    
    if ok then
        LoadVipPlans()
        return { success = true }
    end
    return { success = false, error = err }
end)

lib.callback.register('mri_esc:admin:deletePlan', function(source, id)
    if not IsAdminPlayer(source) then return { success = false, error = "Permissão negada" } end
    MySQL.query.await("DELETE FROM mri_vip_plans WHERE id = ?", { id })
    LoadVipPlans()
    return { success = true }
end)

lib.callback.register('mri_esc:admin:getItems', function(source)
    if not IsAdminPlayer(source) then return {} end
    local items = exports.ox_inventory:Items()
    local list = {}
    for name, data in pairs(items) do
        table.insert(list, {
            name  = name,
            label = data.label or name,
            weight = data.weight or 0,
            description = data.description or ""
        })
    end
    table.sort(list, function(a, b) return a.label < b.label end)
    return list
end)

lib.callback.register('mri_esc:admin:getVehicles', function(source)
    if not IsAdminPlayer(source) then return {} end
    
    local VEHICLES = {}
    if GetResourceState('qbx_core') == 'started' then
        VEHICLES = exports.qbx_core:GetVehiclesByName()
    elseif GetResourceState('qb-core') == 'started' then
        local QBCore = exports['qb-core']:GetCoreObject()
        VEHICLES = QBCore.Shared.Vehicles
    end

    local list = {}
    if VEHICLES then
        for model, data in pairs(VEHICLES) do
            list[#list + 1] = {
                model = data.model or model,
                name = data.name or model,
                brand = data.brand or "",
                category = data.category or "",
                hash = data.hash or GetHashKey(model),
                price = data.price or 0
            }
        end
    end
    table.sort(list, function(a, b) return (a.name or "") < (b.name or "") end)
    return list
end)
