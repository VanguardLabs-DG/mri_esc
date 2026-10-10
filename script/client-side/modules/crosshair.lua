-- =============================================================
--  mri_esc — Crosshair Module
-- =============================================================

miraConfig = { ativo = false }

--- Aplica e sincroniza as configurações da retícula no client, KVP e NUI
--- @param config table|string
--- @param saveKvp boolean? Se deve salvar no KVP local (padrão true)
--- @return boolean
function SyncMiraFromData(config, saveKvp)
    if not config then return false end
    if type(config) == "string" then
        local ok, decoded = pcall(json.decode, config)
        if ok and decoded then config = decoded else return false end
    end
    if type(config) ~= "table" then return false end

    miraConfig = config
    if saveKvp ~= false then
        SetResourceKvp("mri_esc:mira", json.encode(config))
    end
    SendNUIMessage({ action = "miraData", mira = config })
    return true
end

--- Tenta carregar e aplicar as configurações de mira persistidas nos metadados do Qbox
--- @param pData table? Dados opcionais do jogador
--- @return boolean
function CheckQboxMiraPersistence(pData)
    local data = pData
    if not data then
        if GetResourceState('qbx_core') == 'started' then
            data = exports.qbx_core:GetPlayerData()
        elseif GetResourceState('qb-core') == 'started' then
            local QBCore = exports['qb-core']:GetCoreObject()
            if QBCore and QBCore.Functions then
                data = QBCore.Functions.GetPlayerData()
            end
        end
    end

    if data and data.metadata then
        local persisted = data.metadata.mira or data.metadata.crosshair
        if persisted then
            return SyncMiraFromData(persisted, true)
        end
    end
    return false
end

-- Inicialização e carregamento com prioridade Qbox -> KVP Fallback
CreateThread(function()
    -- 1. Verifica se já existem dados persistidos no Qbox
    local loadedFromQbox = CheckQboxMiraPersistence()

    -- 2. Fallback para KVP local se o Qbox ainda não tiver dados carregados
    if not loadedFromQbox then
        local savedMira = GetResourceKvpString("mri_esc:mira")
        if savedMira then
            local ok, decoded = pcall(json.decode, savedMira)
            if ok and decoded then
                miraConfig = decoded
                SendNUIMessage({ action = "miraData", mira = decoded })
            end
        end
    end
end)

-- Main render loop/thread for crosshair com dynamic sleep throttling
CreateThread(function()
    local hudReticle = (Config and Config.Controls and Config.Controls.hudReticle) or 14
    local idleSleep = (Config and Config.Timings and Config.Timings.crosshairIdleMs) or 500
    local activeSleep = (Config and Config.Timings and Config.Timings.crosshairActiveMs) or 0

    while true do
        local sleep = idleSleep
        if miraConfig and miraConfig.ativo then
            sleep = activeSleep
            HideHudComponentThisFrame(hudReticle) -- Oculta retícula nativa
        end
        Wait(sleep)
    end
end)

-- Eventos de ciclo de vida do Qbox / QBCore para sincronização automática
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    pcall(CheckQboxMiraPersistence)
end)

RegisterNetEvent('qbx_core:client:playerLoaded', function()
    pcall(CheckQboxMiraPersistence)
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(val)
    pcall(function()
        if val and val.metadata and (val.metadata.mira or val.metadata.crosshair) then
            SyncMiraFromData(val.metadata.mira or val.metadata.crosshair, true)
        end
    end)
end)

-- Eventos de rede / locais para sincronizar a mira
RegisterNetEvent('mri_esc:client:syncMira', function(config)
    pcall(SyncMiraFromData, config, true)
end)

RegisterNetEvent('mri_esc:client:setMira', function(config)
    pcall(SyncMiraFromData, config, true)
end)

-- Exports for external interaction
exports('GetMiraConfig', function()
    return miraConfig
end)

exports('SetMiraConfig', function(config)
    return SyncMiraFromData(config, true)
end)

exports('SyncMiraFromData', function(config)
    return SyncMiraFromData(config, true)
end)

exports('CheckQboxMiraPersistence', function(pData)
    return CheckQboxMiraPersistence(pData)
end)

