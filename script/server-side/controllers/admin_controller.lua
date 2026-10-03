-- =============================================================
--  mri_esc — Admin Controller
-- =============================================================

local adminCooldowns = {}

-- ─────────────────────────────────────────────────────────────
--  ADMIN: LISTAR VIPs
-- ─────────────────────────────────────────────────────────────
lib.callback.register('mri_esc:vip:admin:list', function(source)
    if not IsAdminPlayer(source) then return { list = {}, stats = { total = 0, online = 0, offline = 0 } } end

    local list = {}
    local onlineCount = 0
    local offlineCount = 0

    local ok, records = pcall(function()
        return MySQL.query.await("SELECT * FROM mri_vip_records LIMIT 500")
    end)

    if ok and records then
        for _, r in ipairs(records) do
            local player = exports.qbx_core:GetPlayerByCitizenId(r.citizenid) or exports.qbx_core:GetOfflinePlayer(r.citizenid)
            if player then
                local isOnline = not player.Offline
                if isOnline then onlineCount = onlineCount + 1 else offlineCount = offlineCount + 1 end

                list[#list + 1] = {
                    citizenid      = r.citizenid,
                    name           = player.PlayerData.charinfo.firstname .. " " .. player.PlayerData.charinfo.lastname,
                    tier           = r.tier,
                    online         = isOnline,
                    source         = isOnline and player.PlayerData.source or nil,
                    granted_at     = r.granted_at,
                    expires_at     = r.expires_at,
                    total_earned   = r.total_earned or 0,
                    paycheck_count = r.paycheck_count or 0,
                    granted_by     = r.granted_by,
                }
            end
        end
    end

    -- Fallback for metadata-only VIPs
    for _, player in pairs(exports.qbx_core:GetQBPlayers()) do
        local vip = player.PlayerData.metadata['vip']
        if vip and vip ~= 'nenhum' then
            local found = false
            for _, item in ipairs(list) do
                if item.citizenid == player.PlayerData.citizenid then
                    found = true
                    break
                end
            end
            if not found then
                onlineCount = onlineCount + 1
                list[#list + 1] = {
                    citizenid = player.PlayerData.citizenid,
                    name = player.PlayerData.charinfo.firstname .. " " .. player.PlayerData.charinfo.lastname,
                    tier = vip,
                    online = true,
                    source = player.PlayerData.source,
                    granted_at = 0,
                    expires_at = nil,
                    total_earned = 0,
                    paycheck_count = 0,
                    granted_by = 'mri_qbox_metadata'
                }
            end
        end
    end

    local allPlans = {}
    if VipPlansConfigs then
        for id, cfg in pairs(VipPlansConfigs) do
            allPlans[#allPlans + 1] = { id = id, label = cfg.label, payment = cfg.payment, inventory = cfg.inventory, benefits = cfg.benefits, rewards = cfg.rewards or {} }
        end
    end

    return {
        list = list,
        allPlans = allPlans,
        stats = {
            total = onlineCount + offlineCount,
            online = onlineCount,
            offline = offlineCount
        }
    }
end)

-- ─────────────────────────────────────────────────────────────
--  ADMIN: AUDITORIA VIP (Discord & Structured Server Log)
-- ─────────────────────────────────────────────────────────────
local function AuditLogVipAction(action, executorSource, targetCitizenId, details)
    local timestamp = os.time()
    local executorName = "Console/Admin"
    local executorId = tostring(executorSource or "0")

    if executorSource and tonumber(executorSource) and tonumber(executorSource) > 0 then
        if vanguard and vanguard.player and vanguard.player.getName then
            local vName = vanguard.player.getName(executorSource)
            if vName and vName ~= "" and vName ~= "Unknown Player" then
                executorName = vName
            end
        end
        if executorName == "Console/Admin" then
            local ap = exports.qbx_core:GetPlayer(executorSource)
            if ap and ap.PlayerData and ap.PlayerData.charinfo then
                executorName = string.format("%s %s", ap.PlayerData.charinfo.firstname or "", ap.PlayerData.charinfo.lastname or "")
            else
                executorName = GetPlayerName(executorSource) or "Admin"
            end
        end

        if vanguard and vanguard.player and vanguard.player.getCitizenId then
            local vCid = vanguard.player.getCitizenId(executorSource)
            if vCid and vCid ~= "" then
                executorId = vCid
            end
        end
        if executorId == tostring(executorSource) then
            local ap = exports.qbx_core:GetPlayer(executorSource)
            if ap and ap.PlayerData and ap.PlayerData.citizenid then
                executorId = ap.PlayerData.citizenid
            end
        end
    end

    local logEntry = {
        executorName = executorName,
        executorId   = executorId,
        target       = targetCitizenId,
        ["ação"]     = action,
        acao         = action,
        action       = action,
        timestamp    = timestamp,
        details      = details or {}
    }

    -- 1. Log Estruturado de Servidor
    print(string.format(
        "^5[Vanguard VIP Audit]^0 [^3%s^0] Executor: ^2%s^0 (ID: ^3%s^0) | Alvo: ^3%s^0 | Ação: ^2%s^0 | Timestamp: ^3%d^0 | Detalhes: %s",
        os.date("!%Y-%m-%d %H:%M:%SZ", timestamp),
        executorName,
        executorId,
        tostring(targetCitizenId),
        action,
        timestamp,
        json.encode(details or {})
    ))

    -- 2. Auditoria via Discord API (vanguard.discord.request)
    if vanguard and vanguard.discord and vanguard.discord.request then
        pcall(function()
            local discordChannel = GetConvar("vanguard_vip_audit_channel", "")
            if discordChannel ~= "" then
                local embedColor = (action == "REVOKE" and 15158332 or (action == "GRANT" and 3066993 or 3447003))
                vanguard.discord.request("POST", "channels/" .. discordChannel .. "/messages", {
                    embeds = {{
                        title = "🛡️ [Vanguard VIP Audit] " .. action,
                        color = embedColor,
                        fields = {
                            { name = "Executor", value = string.format("%s (`%s`)", executorName, executorId), inline = true },
                            { name = "Alvo (CitizenID)", value = string.format("`%s`", tostring(targetCitizenId)), inline = true },
                            { name = "Ação", value = action, inline = true },
                            { name = "Timestamp", value = string.format("<t:%d:F> (`%d`)", timestamp, timestamp), inline = true },
                            { name = "Detalhes", value = string.format("```json\n%s\n```", json.encode(details or {})), inline = false }
                        },
                        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ", timestamp)
                    }}
                })
            end
        end)
    end

    return logEntry
end

-- ─────────────────────────────────────────────────────────────
--  ADMIN: CONCEDER VIP
-- ─────────────────────────────────────────────────────────────
lib.callback.register('mri_esc:vip:admin:grant', function(source, data)
    local srcStr = tostring(source)
    if adminCooldowns[srcStr] and (os.time() - adminCooldowns[srcStr]) < 3 then
        return { success = false, error = "Aguarde 3 segundos entre ações" }
    end
    adminCooldowns[srcStr] = os.time()

    if not IsAdminPlayer(source) then return { success = false, error = "Sem permissão" } end
    if not data or not data.citizenId or not data.tier then
        return { success = false, error = "Dados inválidos" }
    end

    local cid = data.citizenId:upper()
    local adminName = "Admin"
    pcall(function()
        if vanguard and vanguard.player and vanguard.player.getName then
            local vName = vanguard.player.getName(source)
            if vName and vName ~= "" and vName ~= "Unknown Player" then
                adminName = vName
                return
            end
        end
        local ap = exports.qbx_core:GetPlayer(source)
        if ap then
            adminName = ap.PlayerData.charinfo.firstname .. " " .. ap.PlayerData.charinfo.lastname
        end
    end)

    local success, result = false, "Erro interno"
    if GrantVip then
        success, result = GrantVip(cid, data.tier, data.durationDays, adminName)
    else
        local ok, err = pcall(function()
            local online = exports.qbx_core:GetPlayerByCitizenId(cid)
            if online then
                online.Functions.SetMetaData('vip', data.tier)
            else
                local off = exports.qbx_core:GetOfflinePlayer(cid)
                if off then
                    off.PlayerData.metadata['vip'] = data.tier
                    exports.qbx_core:SaveOffline(off.PlayerData)
                end
            end
            if MySQL and MySQL.query then
                local now = os.time()
                local exp = data.durationDays and tonumber(data.durationDays) > 0
                    and (now + tonumber(data.durationDays) * 86400) or nil
                MySQL.query([[
                    INSERT INTO mri_vip_records (citizenid, tier, granted_at, expires_at, granted_by, updated_at)
                    VALUES (?, ?, ?, ?, ?, ?)
                    ON DUPLICATE KEY UPDATE
                        tier=VALUES(tier), granted_at=VALUES(granted_at),
                        expires_at=VALUES(expires_at), granted_by=VALUES(granted_by),
                        updated_at=VALUES(updated_at)
                ]], { cid, data.tier, now, exp, adminName, now })
            end
        end)
        success = ok
        result = err
    end

    if success then
        AuditLogVipAction("GRANT", source, cid, { tier = data.tier, durationDays = data.durationDays })
    end

    return success and { success = true } or { success = false, error = tostring(result) }
end)

-- ─────────────────────────────────────────────────────────────
--  ADMIN: REVOGAR VIP
-- ─────────────────────────────────────────────────────────────
lib.callback.register('mri_esc:vip:admin:revoke', function(source, data)
    if not IsAdminPlayer(source) then return { success = false, error = "Sem permissão" } end
    if not data or not data.citizenId then return { success = false, error = "citizenId obrigatório" } end

    local cid = data.citizenId:upper()
    local ok, err = pcall(function()
        if RevokeVip then
            RevokeVip(cid, 'admin')
        else
            local online = exports.qbx_core:GetPlayerByCitizenId(cid)
            if online then
                online.Functions.SetMetaData('vip', nil)
            else
                local off = exports.qbx_core:GetOfflinePlayer(cid)
                if off then
                    off.PlayerData.metadata['vip'] = nil
                    exports.qbx_core:SaveOffline(off.PlayerData)
                end
            end
            if MySQL and MySQL.query then
                MySQL.query("DELETE FROM mri_vip_records WHERE citizenid = ?", { cid })
            end
        end
    end)

    if ok then
        AuditLogVipAction("REVOKE", source, cid, { reason = "admin" })
        return { success = true }
    end

    return { success = false, error = tostring(err) }
end)

-- ─────────────────────────────────────────────────────────────
--  ADMIN: RENOVAR VIP
-- ─────────────────────────────────────────────────────────────
lib.callback.register('mri_esc:vip:admin:extend', function(source, data)
    if not IsAdminPlayer(source) then return { success = false, error = "Sem permissão" } end
    if not data or not data.citizenId or not data.days then return { success = false, error = "Dados inválidos" } end

    local cid = data.citizenId:upper()
    local adminName = "Admin"
    pcall(function()
        if vanguard and vanguard.player and vanguard.player.getName then
            local vName = vanguard.player.getName(source)
            if vName and vName ~= "" and vName ~= "Unknown Player" then
                adminName = vName
                return
            end
        end
        local ap = exports.qbx_core:GetPlayer(source)
        if ap then adminName = ap.PlayerData.charinfo.firstname .. " " .. ap.PlayerData.charinfo.lastname end
    end)

    local ok = false
    if ExtendVip then
        local extOk = pcall(ExtendVip, cid, data.tier, data.days, adminName)
        ok = extOk
    elseif MySQL and MySQL.query then
        ok = true
        pcall(function()
            local now  = os.time()
            local recs = MySQL.query.await("SELECT expires_at FROM mri_vip_records WHERE citizenid = ?", { cid })
            local base = (recs and recs[1] and recs[1].expires_at and recs[1].expires_at > now)
                and recs[1].expires_at or now
            local newExp = base + (tonumber(data.days) * 86400)
            MySQL.query(
                "INSERT INTO mri_vip_records (citizenid, tier, granted_at, expires_at, granted_by, updated_at) VALUES (?, ?, 0, ?, ?, ?) ON DUPLICATE KEY UPDATE tier=VALUES(tier), expires_at=VALUES(expires_at), granted_by=VALUES(granted_by), updated_at=VALUES(updated_at)",
                { cid, data.tier or 'tier1', newExp, adminName, now }
            )
        end)
    end

    if ok then
        AuditLogVipAction("EXTEND", source, cid, { tier = data.tier, days = data.days })
    end

    return ok and { success = true } or { success = false, error = "Falha ao renovar" }
end)

-- ─────────────────────────────────────────────────────────────
--  ADMIN: BUSCA DE JOGADORES
-- ─────────────────────────────────────────────────────────────
lib.callback.register('mri_esc:vip:admin:search', function(source, data)
    if not IsAdminPlayer(source) then return {} end
    if not data or not data.query or #data.query < 2 then return {} end

    local results = {}
    local search  = data.query:lower()

    pcall(function()
        for _, player in pairs(exports.qbx_core:GetQBPlayers()) do
            local pd   = player.PlayerData
            local name = (pd.charinfo.firstname or "") .. " " .. (pd.charinfo.lastname or "")
            if name:lower():find(search, 1, true) or pd.citizenid:lower():find(search, 1, true) then
                results[#results + 1] = {
                    citizenid = pd.citizenid,
                    name      = name,
                    online    = true,
                    vip       = pd.metadata['vip'] or 'nenhum'
                }
            end
        end
    end)

    if MySQL and MySQL.query then
        local s = "%" .. data.query .. "%"
        local ok, rows = pcall(function()
            return MySQL.query.await([[
                SELECT p.citizenid,
                    CONCAT(JSON_UNQUOTE(JSON_EXTRACT(p.charinfo,'$.firstname')),' ',
                           JSON_UNQUOTE(JSON_EXTRACT(p.charinfo,'$.lastname'))) AS name,
                    JSON_UNQUOTE(JSON_EXTRACT(p.metadata,'$.vip')) AS vip
                FROM players p
                WHERE p.citizenid LIKE ?
                   OR JSON_UNQUOTE(JSON_EXTRACT(p.charinfo,'$.firstname')) LIKE ?
                   OR JSON_UNQUOTE(JSON_EXTRACT(p.charinfo,'$.lastname'))  LIKE ?
                LIMIT 10
            ]], { s, s, s })
        end)
        if ok and rows then
            for _, row in ipairs(rows) do
                local found = false
                for _, r in ipairs(results) do
                    if r.citizenid == row.citizenid then found = true; break end
                end
                if not found then
                    results[#results + 1] = {
                        citizenid = row.citizenid,
                        name      = row.name,
                        online    = false,
                        vip       = row.vip or 'nenhum'
                    }
                end
            end
        end
    end

    return results
end)

-- NOTE: getPlans, savePlan, deletePlan, getItems callbacks are registered
-- in modules/vip-manager/server/callbacks.lua (loaded first by fxmanifest).
-- DO NOT re-register them here or rewards data will be lost.
